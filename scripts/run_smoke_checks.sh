#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${GODOT_BIN:-}" ]]; then
	godot_bin="${GODOT_BIN}"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
	godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
else
	godot_bin="godot"
fi

"${godot_bin}" --headless --path . --quit
"${godot_bin}" --headless --path . --script res://src/dev/smoke/asset_vfs_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/asset_provider_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/asset_manifest_inspection_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/asset_catalog_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/tools/asset_catalog_inspect_local.gd -- --synthetic-smoke --summary-only
"${godot_bin}" --headless --path . --script res://src/dev/smoke/cvar_config_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/movement_smoke.gd
