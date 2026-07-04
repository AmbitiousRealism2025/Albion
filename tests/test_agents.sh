#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

validate_agents() {
  python3 - "$ROOT_DIR" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])

expected = {
    "scout": {
        "tools": {"Read", "Grep", "Glob"},
        "effort": "high",
        "model": None,
        "forbidden_tools": {"Write", "Edit", "Bash"},
    },
    "counterexample-hunter": {
        "tools": {"Read", "Grep", "Glob", "Bash", "Write"},
        "effort": "xhigh",
        "model": None,
        "forbidden_tools": set(),
    },
    "verifier": {
        "tools": {"Read", "Grep", "Glob", "Bash"},
        "effort": "xhigh",
        "model": None,
        "forbidden_tools": set(),
    },
    "simplifier": {
        "tools": {"Read", "Grep", "Glob"},
        "effort": "high",
        "model": None,
        "forbidden_tools": {"Write", "Edit", "Bash"},
    },
    "quick": {
        "tools": {"Read", "Grep", "Glob", "Bash", "Edit"},
        "effort": "low",
        "model": "haiku",
        "forbidden_tools": set(),
    },
}

allowed_keys = {"name", "description", "tools", "model", "effort"}


def parse_frontmatter(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    assert len(lines) <= 80, f"{path} exceeds 80 lines"
    assert lines and lines[0] == "---", f"{path} missing opening frontmatter"
    try:
        end = lines.index("---", 1)
    except ValueError as exc:
        raise AssertionError(f"{path} missing closing frontmatter") from exc

    data = {}
    index = 1
    while index < end:
        line = lines[index]
        if not line or line.startswith("  - "):
            raise AssertionError(f"{path} malformed frontmatter near line {index + 1}")
        if ":" not in line:
            raise AssertionError(f"{path} malformed frontmatter near line {index + 1}")
        key, value = line.split(":", 1)
        value = value.strip()
        assert key in allowed_keys, f"{path} has unsupported frontmatter key: {key}"
        if key == "tools":
            tools = []
            index += 1
            while index < end and lines[index].startswith("  - "):
                tool = lines[index][4:].strip()
                assert tool, f"{path} has empty tool entry"
                tools.append(tool)
                index += 1
            assert tools, f"{path} has empty tools list"
            data[key] = tools
            continue
        assert value, f"{path} has empty {key}"
        data[key] = value
        index += 1

    body = "\n".join(lines[end + 1 :]).strip()
    assert body, f"{path} body is empty"
    return data


for name, contract in expected.items():
    path = root / "plugin" / "agents" / f"{name}.md"
    assert path.is_file(), f"missing agent file: {path}"
    data = parse_frontmatter(path)
    assert data.get("name") == name, f"{path} name mismatch"
    assert data.get("description"), f"{path} description is empty"
    assert set(data.get("tools", [])) == contract["tools"], f"{path} tools mismatch: {data.get('tools')!r}"
    assert data.get("effort") == contract["effort"], f"{path} effort mismatch"
    assert not (set(data["tools"]) & contract["forbidden_tools"]), f"{path} includes forbidden read-only tools"
    if contract["model"] is None:
        assert "model" not in data, f"{path} must not set model"
    else:
        assert data.get("model") == contract["model"], f"{path} model mismatch"
PY
}

validate_agents
