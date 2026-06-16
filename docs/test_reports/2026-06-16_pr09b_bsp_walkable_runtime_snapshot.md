# PR-09B BSP Walkable Runtime Snapshot Verification

Date: 2026-06-16

## Scope

Verified the BSP walkable lab after moving player movement authority to
`OpenStrikeLocalGameSession`. The lab now queues `OpenStrikeUserCommand`
instances, steps the runtime session and presents player state from
`session.snapshot()`.

## Commands

```sh
Godot --headless --path . --script res://src/dev/labs/bsp_walkable/bsp_walkable_lab.gd -- --load-smoke --map=maps/de_dust2.bsp
Godot --headless --path . --script res://src/dev/labs/bsp_walkable/bsp_walkable_lab.gd -- --map=maps/de_dust2.bsp --auto-exit-sec=1.0 --auto-forward-sec=0.6 --windowed --uncaptured
Godot --path . --script res://src/dev/labs/bsp_walkable/bsp_walkable_lab.gd -- --map=maps/de_dust2.bsp --auto-exit-sec=3.0 --auto-forward-sec=1.2 --windowed --uncaptured
```

## Observations

* The real local `maps/de_dust2.bsp` load smoke passed with 40 spawn entities and
  imported Godot scene collision available.
* The runtime-snapshot lab launched on the real map and wrote telemetry under
  `user://telemetry/bsp_walkable/`.
* The windowed run launched the lab and rendered the map; a screenshot attempt
  did not reliably capture the Godot window, so telemetry is the review
  evidence for this run.

## Telemetry facts

Latest windowed run session: `20260616_082741_6400`.

* `tick_count`: 301
* `duration_sec`: 3.01
* `movement_authority`: `OpenStrikeLocalGameSession`
* `movement_adapter`: `local_game_session_snapshot`
* `presentation_follows_snapshot`: `true`
* final `presentation_snapshot_position_delta`: `0.0`
* `max_speed_ups`: `249.999984741211`
* `max_horizontal_speed_ups`: `249.999984741211`
* `collision_source`: `godot_scene_collision`
* `collision_confidence`: `godot_collision_unverified`
* `goldsrc_parity_collision`: `false`
* final `movement_state.last_trace_summary.mode`: `free_volume`

## Conclusion

PR-09B now moves BSP walkable presentation from runtime snapshots instead of a
lab-owned movement controller. Telemetry confirms nonzero movement, the 250 ups
walkable-lab cap, and exact presentation/snapshot position alignment.

This run does not claim real-map GoldSrc hull-trace contact parity. The current
Godot scene trace backend remains explicitly non-golden and does not provide a
runtime `trace_hull` path to `PlayerMoveService`, so real-map wall-contact
goldens remain future work.

## Next actions

* Keep `GodotSceneTraceBackend` marked as `godot_collision_unverified`.
* Add a separately scoped runtime collision bridge only if the project decides
  to support non-golden Godot scene hull traces inside `PlayerMoveService`.
