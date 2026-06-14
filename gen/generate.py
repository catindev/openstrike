#!/usr/bin/env python3
"""Generate coverage status schema and markdown table from the matrix.

The hand-edited source of truth is `gen/coverage_status_matrix.json`.
Generated artifacts:
- `data/schemas/coverage_status.schema.json`
- generated sections in `docs/COVERAGE_STATUS_CONTRACT.md`
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MATRIX_PATH = ROOT / "gen" / "coverage_status_matrix.json"
SCHEMA_PATH = ROOT / "data" / "schemas" / "coverage_status.schema.json"
DOC_PATH = ROOT / "docs" / "COVERAGE_STATUS_CONTRACT.md"

TABLE_START = "<!-- BEGIN GENERATED STATUS TABLE -->"
TABLE_END = "<!-- END GENERATED STATUS TABLE -->"
SCHEMA_START = "<!-- BEGIN GENERATED COVERAGE STATUS SCHEMA -->"
SCHEMA_END = "<!-- END GENERATED COVERAGE STATUS SCHEMA -->"


def load_matrix() -> dict:
    with MATRIX_PATH.open("r", encoding="utf-8") as file:
        matrix = json.load(file)
    required = ["stages", "confidence", "allowed"]
    for key in required:
        if key not in matrix:
            raise ValueError(f"coverage status matrix missing required key: {key}")
    return matrix


def build_schema(matrix: dict) -> dict:
    stages = list(matrix["stages"])
    confidence_values = list(matrix["confidence"])
    allowed = dict(matrix["allowed"])

    all_of: list[dict] = []
    for stage in stages:
        if stage not in allowed:
            raise ValueError(f"coverage status matrix has no allowed confidences for stage: {stage}")
        all_of.append({
            "if": {
                "properties": {
                    "stage": {
                        "const": stage,
                    },
                },
            },
            "then": {
                "properties": {
                    "confidence": {
                        "enum": list(allowed[stage]),
                    },
                },
            },
        })

    return {
        "$schema": "http://json-schema.org/draft-07/schema#",
        "$id": "https://openstrike/schemas/coverage_status.schema.json",
        "title": "OpenStrike asset coverage status (stage x confidence)",
        "type": "object",
        "required": [
            "stage",
            "confidence",
        ],
        "additionalProperties": True,
        "properties": {
            "stage": {
                "enum": stages,
            },
            "confidence": {
                "enum": confidence_values,
            },
            "capability_scanner_supported": {
                "type": "boolean",
                "description": (
                    "Capability, NOT result. Whether the scanner CAN check this field. "
                    "PR-06B uses a richer capability enum; see PR-06B spec."
                ),
            },
        },
        "allOf": all_of,
    }


def dumps_json(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def build_table(matrix: dict) -> str:
    lines = [
        "| stage | allowed confidence |",
        "|---|---|",
    ]
    allowed = dict(matrix["allowed"])
    for stage in matrix["stages"]:
        values = ", ".join(f"`{value}`" for value in allowed[stage])
        lines.append(f"| `{stage}` | {values} |")
    return "\n".join(lines)


def replace_between(text: str, start_marker: str, end_marker: str, replacement: str) -> str:
    start_index = text.find(start_marker)
    end_index = text.find(end_marker)
    if start_index == -1 or end_index == -1 or end_index < start_index:
        raise ValueError(f"generated markers not found or invalid: {start_marker} / {end_marker}")

    before = text[:start_index + len(start_marker)]
    after = text[end_index:]
    return f"{before}\n{replacement}\n{after}"


def build_doc(matrix: dict, schema_json: str) -> str:
    current = DOC_PATH.read_text(encoding="utf-8")
    updated = replace_between(current, TABLE_START, TABLE_END, build_table(matrix))
    schema_block = f"```json\n{schema_json.rstrip()}\n```"
    return replace_between(updated, SCHEMA_START, SCHEMA_END, schema_block)


def write_if_changed(path: Path, content: str) -> bool:
    old_content = path.read_text(encoding="utf-8") if path.exists() else ""
    if old_content == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate coverage status artifacts.")
    parser.add_argument("--check", action="store_true", help="Fail if generated artifacts differ.")
    args = parser.parse_args()

    matrix = load_matrix()
    schema = build_schema(matrix)
    schema_json = dumps_json(schema)
    doc_text = build_doc(matrix, schema_json)

    if args.check:
        errors: list[str] = []
        if not SCHEMA_PATH.exists() or SCHEMA_PATH.read_text(encoding="utf-8") != schema_json:
            errors.append(str(SCHEMA_PATH.relative_to(ROOT)))
        if not DOC_PATH.exists() or DOC_PATH.read_text(encoding="utf-8") != doc_text:
            errors.append(str(DOC_PATH.relative_to(ROOT)))
        if errors:
            print("Generated coverage status artifacts are stale:", file=sys.stderr)
            for path in errors:
                print(f"  {path}", file=sys.stderr)
            print("Run: python3 gen/generate.py", file=sys.stderr)
            return 1
        print("Coverage status generated artifacts are up to date.")
        return 0

    changed = [
        write_if_changed(SCHEMA_PATH, schema_json),
        write_if_changed(DOC_PATH, doc_text),
    ]
    if any(changed):
        print("Coverage status artifacts regenerated.")
    else:
        print("Coverage status artifacts already up to date.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
