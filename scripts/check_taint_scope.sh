#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

if [[ -d "addons/goldsrc" ]] && ! grep -q "goldsrc-godot" docs/TAINT_LEDGER.md 2>/dev/null; then
	echo "addons/goldsrc exists but docs/TAINT_LEDGER.md does not mention goldsrc-godot." >&2
	exit 1
fi

if [[ -d "src/dev/tainted" ]]; then
	if rg -n 'res://src/dev/tainted|src/dev/tainted' src/core src/game src/presentation; then
		echo "Production paths must not import src/dev/tainted." >&2
		exit 1
	fi
fi

if [[ "${OPENSTRIKE_RELEASE_GATE:-0}" == "1" ]]; then
	if grep -q "Accepted pre-release risk" docs/TAINT_LEDGER.md; then
		echo "Release gate blocked by accepted pre-release taint entries." >&2
		exit 1
	fi
fi

echo "Taint scope check passed."
