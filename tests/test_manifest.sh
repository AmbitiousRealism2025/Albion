#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/albion-manifest.XXXXXX")"

# shellcheck source=tests/lib/assert.sh
. "${ROOT_DIR}/tests/lib/assert.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

validate_manifest_structure() {
  python3 - "$ROOT_DIR" <<'PY'
from __future__ import annotations

import pathlib
import sys


class ManifestError(Exception):
    pass


def parse_key_value(text: str, line_number: int) -> tuple[str, str]:
    if ":" not in text:
        raise ManifestError(f"line {line_number}: expected key: value")
    key, value = text.split(":", 1)
    key = key.strip()
    value = value.strip()
    if not key:
        raise ManifestError(f"line {line_number}: empty key")
    if not value:
        raise ManifestError(f"line {line_number}: empty value for {key}")
    return key, value


def parse_manifest(path: pathlib.Path) -> dict[str, object]:
    scalars: dict[str, str] = {}
    lists: dict[str, list[dict[str, str]]] = {}
    current_list: str | None = None
    current_item: dict[str, str] | None = None
    lines = path.read_text(encoding="utf-8").splitlines()

    header = "\n".join(lines[:6])
    assert "Strict line-based YAML subset" in header, "manifest must document the line-based subset"
    assert "No anchors" in header, "manifest must document unsupported YAML features"

    for line_number, raw_line in enumerate(lines, start=1):
        if "\t" in raw_line:
            raise ManifestError(f"line {line_number}: tabs are not supported")
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if not raw_line.startswith(" "):
            key, separator, value = raw_line.partition(":")
            key = key.strip()
            value = value.strip()
            if not separator or not key:
                raise ManifestError(f"line {line_number}: expected top-level key")
            current_item = None
            if value:
                scalars[key] = value
                current_list = None
            else:
                current_list = key
                lists.setdefault(key, [])
            continue
        if raw_line.startswith("  - "):
            if current_list is None:
                raise ManifestError(f"line {line_number}: list item outside a list")
            key, value = parse_key_value(raw_line[4:], line_number)
            current_item = {key: value}
            lists[current_list].append(current_item)
            continue
        if raw_line.startswith("    "):
            if current_item is None:
                raise ManifestError(f"line {line_number}: map entry outside a list item")
            key, value = parse_key_value(raw_line[4:], line_number)
            assert key not in current_item, f"line {line_number}: duplicate key {key}"
            current_item[key] = value
            continue
        raise ManifestError(f"line {line_number}: unsupported indentation")

    return {**scalars, **lists}


def relative_set(root: pathlib.Path, paths: list[pathlib.Path]) -> set[str]:
    return {path.relative_to(root).as_posix() for path in paths}


root = pathlib.Path(sys.argv[1])
manifest_path = root / "manifest" / "albion-manifest.yaml"
manifest = parse_manifest(manifest_path)
assert set(manifest) == {"schema", "charter", "skills", "agents"}, f"unexpected top-level keys: {sorted(manifest)}"
assert manifest["schema"] == "albion-manifest/v1", "schema mismatch"

charter = manifest["charter"]
assert isinstance(charter, list) and charter, "charter list is required"
charter_files = []
for index, entry in enumerate(charter, start=1):
    assert set(entry) == {"id", "target", "file"}, f"charter entry {index} has wrong keys"
    assert entry["target"] == "claude-code", f"charter entry {index} has wrong target"
    fragment = root / entry["file"]
    assert fragment.is_file(), f"missing charter fragment: {entry['file']}"
    charter_files.append(entry["file"])

actual_fragments = relative_set(root, sorted((root / "manifest" / "sections").glob("*.md")))
assert set(charter_files) == actual_fragments, "charter fragment registration is not bidirectional"

compiled = b"".join((root / path).read_bytes() for path in charter_files)
charter_bytes = (root / "charter" / "ALBION.md").read_bytes()
assert compiled == charter_bytes, "manifest fragments do not reproduce charter/ALBION.md"

for list_name, glob_pattern in (
    ("skills", "plugin/skills/*/SKILL.md"),
    ("agents", "plugin/agents/*.md"),
):
    entries = manifest[list_name]
    assert isinstance(entries, list) and entries, f"{list_name} list is required"
    registered = set()
    for index, entry in enumerate(entries, start=1):
        assert set(entry) == {"id", "path"}, f"{list_name} entry {index} has wrong keys"
        asset = root / entry["path"]
        assert asset.is_file(), f"missing {list_name} asset: {entry['path']}"
        registered.add(entry["path"])
    actual = relative_set(root, sorted(root.glob(glob_pattern)))
    assert registered == actual, f"{list_name} registration is not bidirectional"
PY
}

run_compile_check() {
  local output

  output="$("${ROOT_DIR}/bin/albion-compile" --check)"
  assert_contains "$output" "PASS charter in sync" "compiler check reports clean drift state"
}

run_mutation_probe() {
  python3 - "$ROOT_DIR" "$TMP_DIR" <<'PY'
from __future__ import annotations

import difflib
import pathlib
import shutil
import subprocess
import sys


def replace_line(lines: list[str], old: str, new: str) -> list[str]:
    replaced = False
    output = []
    for line in lines:
        if line == old:
            output.append(new)
            replaced = True
        else:
            output.append(line)
    assert replaced, f"did not find manifest line: {old.strip()}"
    return output


def remove_charter_entry(lines: list[str], entry_id: str) -> list[str]:
    output = []
    in_charter = False
    skipping = False
    for line in lines:
        if line == "charter:\n":
            in_charter = True
            output.append(line)
            continue
        if in_charter and line and not line.startswith(" "):
            in_charter = False
            skipping = False
        if in_charter and line == f"  - id: {entry_id}\n":
            skipping = True
            continue
        if skipping and line.startswith("    "):
            continue
        if skipping:
            skipping = False
        output.append(line)
    assert len(output) < len(lines), f"did not remove charter entry {entry_id}"
    return output


root = pathlib.Path(sys.argv[1])
tmp_dir = pathlib.Path(sys.argv[2])
manifest_path = root / "manifest" / "albion-manifest.yaml"
compiler = root / "bin" / "albion-compile"
charter = root / "charter" / "ALBION.md"
original_bytes = charter.read_bytes()
lines = manifest_path.read_text(encoding="utf-8").splitlines(keepends=True)

mutated_fragment = tmp_dir / "01-contract-mutated.md"
shutil.copyfile(root / "manifest" / "sections" / "01-contract.md", mutated_fragment)
with mutated_fragment.open("ab") as handle:
    handle.write(b"\nMUTATION PROBE\n")

mutated_manifest = tmp_dir / "mutated-manifest.yaml"
mutated_manifest.write_text(
    "".join(
        replace_line(
            lines,
            "    file: manifest/sections/01-contract.md\n",
            f"    file: {mutated_fragment.as_posix()}\n",
        )
    ),
    encoding="utf-8",
)
mutated_output = tmp_dir / "mutated-ALBION.md"
subprocess.run(
    [str(compiler), "--manifest", str(mutated_manifest), "--output", str(mutated_output)],
    check=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
mutated_bytes = mutated_output.read_bytes()
assert mutated_bytes != original_bytes, "mutated fragment produced byte-identical charter"
diff = list(
    difflib.unified_diff(
        original_bytes.decode("utf-8").splitlines(),
        mutated_bytes.decode("utf-8").splitlines(),
        fromfile="charter/ALBION.md",
        tofile="mutated-output",
    )
)
assert diff, "mutated compile did not produce a diff"

shrunk_manifest = tmp_dir / "shrunk-manifest.yaml"
shrunk_manifest.write_text("".join(remove_charter_entry(lines, "contract")), encoding="utf-8")
shrunk_output = tmp_dir / "shrunk-ALBION.md"
subprocess.run(
    [str(compiler), "--manifest", str(shrunk_manifest), "--output", str(shrunk_output)],
    check=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
shrunk_size = len(shrunk_output.read_bytes())
assert shrunk_size < len(original_bytes), "removing a fragment did not shrink compiled output"
PY
}

validate_manifest_structure
run_compile_check
run_mutation_probe
