# 2026-06-15 TraceBackend + MapEntityIndex Runner Smoke

## Scope

This report records a short local `bsp_walkable_lab` auto-exit run after
PR-07.2 introduced `OpenStrikeGodotSceneTraceBackend` and
`OpenStrikeMapEntityIndex`.

## Command

```text
Godot --headless --path . --script res://src/dev/labs/bsp_walkable/bsp_walkable_lab.gd -- --map=maps/de_dust2.bsp --auto-exit-sec=0.05 --windowed --uncaptured
```

The run used a local licensed GoldSrc installation through `user://local_goldsrc.json`.
No asset bytes or local filesystem paths are committed.

## Observations

* The lab loaded `maps/de_dust2.bsp`, started the runner and wrote
  `summary.json` plus `trace.jsonl` under `user://telemetry/bsp_walkable/`.
* The runner summary reports `collision_source=godot_scene_collision`,
  `collision_confidence=godot_collision_unverified` and
  `goldsrc_parity_collision=false`.
* `trace_backend.trace_ray` is `supported_by_godot_space_state` after `World3D`
  setup, while `trace_backend.trace_hull` and `trace_backend.point_contents`
  are both `requires_openstrike_bsp_reader`.
* `map_entity_index.entity_count=101` and `map_entity_index.spawn_count=40`.
* The map entity index marked player-collision disable policy for
  `func_bomb_target=2`, `func_buyzone=2`, `func_illusionary=28` and
  `trigger_camera=3`.
* The lab disabled collision on 35 indexed semantic/trigger entities, covering
  64 collision objects and 64 collision shapes.

## Conclusions

* PR-07.2 moves entity collision truth out of the BSP walkable runner without
  changing the manual lab's temporary Godot scene collision backend.
* Telemetry now has enough backend source/confidence data for later manual-test
  analysis to distinguish imported Godot collision from future GoldSrc hull
  trace parity.
* The next backend replacement point is explicit: add an OpenStrike-owned BSP
  reader/clipnode trace backend instead of expanding `godot_scene_collision`
  into parity claims.

## Next Actions

* Keep PR-07.2 limited to TraceBackend and MapEntityIndex cleanup.
* Do not add contact movement golden tests on `godot_scene_collision`.
* Use `MapEntityIndex` for future spawn/buyzone/bombsite consumers before
  adding gameplay systems.
