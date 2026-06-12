#!/usr/bin/env python3
"""Fail the build if suspicious legacy proprietary resource files are committed.

This is a guardrail, not a legal review substitute.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

SUSPICIOUS_EXTENSIONS = {
    ".bsp",
    ".wad",
    ".mdl",
    ".spr",
    ".pak",
    ".dem",
    ".res",
    ".nav",
}

SKIP_DIRS = {
    ".git",
    ".github",
    "build",
    "dist",
    "out",
    "cmake-build-debug",
    "cmake-build-release",
}


def is_skipped(path: Path, root: Path) -> bool:
    try:
        relative = path.relative_to(root)
    except ValueError:
        return True

    return any(part in SKIP_DIRS for part in relative.parts)


def scan(root: Path) -> list[Path]:
    findings: list[Path] = []

    for current_root, dirs, files in os.walk(root):
        current = Path(current_root)
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]

        if is_skipped(current, root):
            continue

        for filename in files:
            path = current / filename
            if path.suffix.lower() in SUSPICIOUS_EXTENSIONS:
                findings.append(path.relative_to(root))

    return sorted(findings)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", help="repository root to scan")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    findings = scan(root)

    if not findings:
        print("asset_audit: OK")
        return 0

    print("asset_audit: suspicious legacy resource files found", file=sys.stderr)
    for path in findings:
        print(f"  - {path}", file=sys.stderr)

    print("\nDo not commit proprietary game resources. See docs/asset_policy.md.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
