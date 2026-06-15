#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${GODOT_BIN:-}" ]]; then
	godot_bin="${GODOT_BIN}"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
	godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
else
	godot_bin="godot"
fi

./scripts/bootstrap_gdextensions.sh
./scripts/check_taint_scope.sh

"${godot_bin}" --headless --path . --quit
"${godot_bin}" --headless --path . --script res://src/dev/smoke/asset_vfs_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/asset_provider_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/asset_manifest_inspection_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/asset_catalog_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/tools/asset_catalog_inspect_local.gd -- --synthetic-smoke --summary-only
"${godot_bin}" --headless --path . --script res://src/dev/smoke/coverage_status_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/viewmodel_world_profile_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/goldsrc_renderable_adapter_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/goldsrc_bsp_runtime_provider_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/tools/viewmodel_manual_preflight.gd -- --capability-smoke
"${godot_bin}" --headless --path . --script res://src/dev/smoke/cvar_config_smoke.gd
"${godot_bin}" --headless --path . --script res://src/dev/smoke/movement_smoke.gd
