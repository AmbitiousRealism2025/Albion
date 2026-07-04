#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
. "${ROOT_DIR}/tests/lib/assert.sh"

validate_skills() {
  python3 - "$ROOT_DIR" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
skill_names = [
    "maturity-assessment",
    "delegation",
    "recovery",
    "completion-gate",
    "conductor",
]
secret_patterns = {
    "aws_access_key": re.compile(r"AKIA[0-9A-Z]{16}"),
    "github_token": re.compile(r"gh[pousr]_[A-Za-z0-9_]{20,}"),
    "openai_key": re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    "slack_token": re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"),
    "private_key": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "bearer_token": re.compile(r"Bearer [A-Za-z0-9._~+/=-]{30,}"),
    "jwt": re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"),
    "generic_secret": re.compile(
        r"(?i)(token|secret|password|api[_-]?key)\s*[:=]\s*['\"]?[A-Za-z0-9._~+/=-]{16,}"
    ),
}


def fail(message: str) -> None:
    raise AssertionError(message)


def parse_frontmatter(path: pathlib.Path, expected_name: str) -> tuple[dict[str, str], str, int]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        fail(f"{path}: frontmatter must start with ---")
    try:
        close_index = lines[1:].index("---") + 1
    except ValueError:
        fail(f"{path}: frontmatter must close with ---")
    raw_frontmatter = lines[1:close_index]
    data = {}
    for line in raw_frontmatter:
        if ":" not in line:
            fail(f"{path}: malformed frontmatter line: {line!r}")
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if key in data:
            fail(f"{path}: duplicate frontmatter key: {key}")
        data[key] = value
    if set(data) != {"name", "description"}:
        fail(f"{path}: frontmatter keys must be exactly name and description")
    if data["name"] != expected_name:
        fail(f"{path}: name {data['name']!r} does not match directory {expected_name!r}")
    if not data["description"]:
        fail(f"{path}: description must be non-empty")
    body = "\n".join(lines[close_index + 1 :]).strip()
    if not body:
        fail(f"{path}: body must be non-empty")
    return data, body, len(lines)


for skill_name in skill_names:
    skill_path = root / "plugin" / "skills" / skill_name / "SKILL.md"
    if not skill_path.is_file():
        fail(f"{skill_path}: missing SKILL.md")
    _frontmatter, body, line_count = parse_frontmatter(skill_path, skill_name)
    if line_count > 120:
        fail(f"{skill_path}: {line_count} lines exceeds 120-line limit")
    for label, pattern in secret_patterns.items():
        if pattern.search(body):
            fail(f"{skill_path}: body contains secret-shaped literal matching {label}")
PY
}

validate_skills

assert_exit_code 0 0 "skill structure checks passed"
