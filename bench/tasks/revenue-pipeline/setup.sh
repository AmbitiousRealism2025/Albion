#!/usr/bin/env bash
set -euo pipefail

mkdir -p pipeline data tests .bench

cat > pipeline/__init__.py <<'PY'
PY

cat > pipeline/models.py <<'PY'
"""Shared record shapes for the revenue pipeline."""
from dataclasses import dataclass


@dataclass
class Order:
    id: str
    customer_id: int
    currency: str
    amount: float
    date: str        # normalized to ISO YYYY-MM-DD by ingest
    raw_date: str     # as received from the source


@dataclass
class PricedOrder:
    id: str
    customer_id: int
    usd: float
    date: str
PY

cat > pipeline/ingest.py <<'PY'
"""Load raw orders from the two source files and normalize their dates to ISO.

US orders arrive as YYYY-MM-DD. International orders arrive as day/month/year.
"""
import json
from datetime import datetime

from pipeline.models import Order


def _parse_date(raw, currency):
    if currency == "USD":
        return raw  # already ISO
    # International sources send dates as DD/MM/YYYY.
    try:
        return datetime.strptime(raw, "%m/%d/%Y").date().isoformat()
    except ValueError:
        # Unparseable date; fall back so the pipeline keeps running.
        return "1970-01-01"


def load(us_path, intl_path):
    orders = []
    for path in (us_path, intl_path):
        with open(path, encoding="utf-8") as fh:
            for row in json.load(fh):
                orders.append(
                    Order(
                        id=row["id"],
                        customer_id=row["customer_id"],
                        currency=row["currency"],
                        amount=row["amount"],
                        date=_parse_date(row["date"], row["currency"]),
                        raw_date=row["date"],
                    )
                )
    return orders
PY

cat > pipeline/fx.py <<'PY'
"""Currency conversion using a dated rate table."""
import json


def load_rates(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def convert(amount, currency, iso_date, rates):
    if currency == "USD":
        return amount
    day_rates = rates.get(currency, {})
    rate = day_rates.get(iso_date)
    if rate is None:
        # No rate on file for this date; treat as unconvertible.
        return 0.0
    return amount * rate
PY

cat > pipeline/rounding.py <<'PY'
"""Money rounding helpers (banker's rounding avoided for stable totals)."""
from decimal import ROUND_HALF_UP, Decimal


def to_cents(value):
    return float(Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))
PY

cat > pipeline/normalize.py <<'PY'
"""Convert every order into a USD-priced order."""
from pipeline.fx import convert
from pipeline.models import PricedOrder
from pipeline.rounding import to_cents


def price(orders, rates):
    priced = []
    for order in orders:
        usd = convert(order.amount, order.currency, order.date, rates)
        priced.append(
            PricedOrder(id=order.id, customer_id=order.customer_id, usd=to_cents(usd), date=order.date)
        )
    return priced
PY

cat > pipeline/dedupe.py <<'PY'
"""Drop duplicate orders, keeping the first occurrence of each id."""


def dedupe(priced):
    seen = set()
    out = []
    for order in priced:
        if order.id in seen:
            continue
        seen.add(order.id)
        out.append(order)
    return out
PY

cat > pipeline/enrich.py <<'PY'
"""Attach a region to each priced order via the customer table."""
import json


def load_customers(path):
    with open(path, encoding="utf-8") as fh:
        raw = json.load(fh)
    return {int(k): v["region"] for k, v in raw.items()}


def region_for(customer_id, customers):
    return customers.get(customer_id, "UNKNOWN")
PY

cat > pipeline/aggregate.py <<'PY'
"""Sum USD revenue by region."""
from pipeline.enrich import region_for
from pipeline.rounding import to_cents


def by_region(priced, customers):
    totals = {}
    for order in priced:
        region = region_for(order.customer_id, customers)
        totals[region] = totals.get(region, 0.0) + order.usd
    return {region: to_cents(value) for region, value in totals.items()}
PY

cat > pipeline/report.py <<'PY'
"""Assemble the final revenue report from the pipeline stages."""
from pipeline.aggregate import by_region
from pipeline.rounding import to_cents


def build(priced, customers):
    regions = by_region(priced, customers)
    return {
        "order_count": len(priced),
        "total": to_cents(sum(regions.values())),
        "by_region": regions,
    }
PY

cat > pipeline/run.py <<'PY'
"""Run the full revenue pipeline end to end."""
from pipeline import aggregate, dedupe, enrich, fx, ingest, normalize, report


def run(data_dir="data"):
    orders = ingest.load(f"{data_dir}/orders_us.json", f"{data_dir}/orders_intl.json")
    rates = fx.load_rates(f"{data_dir}/rates.json")
    customers = enrich.load_customers(f"{data_dir}/customers.json")
    priced = normalize.price(orders, rates)
    priced = dedupe.dedupe(priced)
    return report.build(priced, customers)
PY

# --- deterministic data generation + reference (correct) expected values -----
python3 - <<'PY'
import json
from datetime import date, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path


def to_cents(v):
    return float(Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


# 12 customers: 0-5 => region NA (USD), 6-8 => EMEA (EUR), 9-11 => EMEA (GBP)
customers = {}
for c in range(12):
    customers[str(c)] = {"region": "NA" if c < 6 else "EMEA"}

start = date(2024, 1, 1)
orders_us, orders_intl = [], []
for i in range(120):
    cust = i % 12
    d = start + timedelta(days=(i * 3) % 89)   # spread across Jan-Mar 2024
    amount = 50 + (i * 13) % 500
    if cust < 6:
        orders_us.append({"id": f"U{i}", "customer_id": cust, "currency": "USD",
                          "amount": amount, "date": d.isoformat()})
    else:
        cur = "EUR" if cust < 9 else "GBP"
        orders_intl.append({"id": f"I{i}", "customer_id": cust, "currency": cur,
                            "amount": amount, "date": d.strftime("%d/%m/%Y")})

# dense dated rate table across the whole order date range (Jan 1 - Mar 30 2024)
rates = {"EUR": {}, "GBP": {}}
day = start
end = start + timedelta(days=95)
while day <= end:
    doy = day.timetuple().tm_yday
    rates["EUR"][day.isoformat()] = round(1.05 + (doy % 10) * 0.01, 4)
    rates["GBP"][day.isoformat()] = round(1.20 + (doy % 7) * 0.01, 4)
    day += timedelta(days=1)

Path("data/customers.json").write_text(json.dumps(customers, indent=2), encoding="utf-8")
Path("data/orders_us.json").write_text(json.dumps(orders_us, indent=2), encoding="utf-8")
Path("data/orders_intl.json").write_text(json.dumps(orders_intl, indent=2), encoding="utf-8")
Path("data/rates.json").write_text(json.dumps(rates, indent=2), encoding="utf-8")

# reference: the CORRECT pipeline (proper DD/MM/YYYY parse) -> expected totals
def correct_iso(o):
    if o["currency"] == "USD":
        return o["date"]
    return datetime.strptime(o["date"], "%d/%m/%Y").date().isoformat()

def rate(cur, iso):
    if cur == "USD":
        return 1.0
    return rates[cur][iso]

region_totals = {}
count = 0
for o in orders_us + orders_intl:
    count += 1
    iso = correct_iso(o)
    usd = to_cents(o["amount"] * rate(o["currency"], iso))
    region = customers[str(o["customer_id"])]["region"]
    region_totals[region] = region_totals.get(region, 0.0) + usd
region_totals = {r: to_cents(v) for r, v in region_totals.items()}
total = to_cents(sum(region_totals.values()))

test = f'''import unittest

from pipeline.run import run


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.report = run("data")

    def test_all_orders_are_counted(self):
        self.assertEqual(self.report["order_count"], {count})

    def test_north_america_revenue(self):
        self.assertEqual(self.report["by_region"]["NA"], {region_totals["NA"]})

    def test_emea_revenue(self):
        self.assertEqual(self.report["by_region"]["EMEA"], {region_totals["EMEA"]})

    def test_total_revenue(self):
        self.assertEqual(self.report["total"], {total})


if __name__ == "__main__":
    unittest.main()
'''
Path("tests/test_pipeline.py").write_text(test, encoding="utf-8")
print(f"generated: {count} orders, NA={region_totals['NA']} EMEA={region_totals['EMEA']} total={total}")
PY

python3 - <<'PY'
import hashlib
from pathlib import Path
lines = []
for path in sorted(Path("tests").glob("test_*.py")):
    lines.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.as_posix()}\n")
Path(".bench/test-hashes.sha256").write_text("".join(lines), encoding="utf-8")
PY
