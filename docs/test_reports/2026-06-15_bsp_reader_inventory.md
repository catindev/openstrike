# BSP Reader Inventory, 2026-06-15

## Scope

This report checks whether the current OpenStrike repository already contains
an OpenStrike-owned GoldSrc BSP reader or clipnode/hull trace implementation.
It was created for PR-07.1 before planning TraceBackend or clipnode work.

## Commands

```sh
find addons src -maxdepth 4 \( -iname '*hl_core*' -o -iname '*bsp*reader*' -o -iname '*clipnode*' \) -print
rg -n "trace_hull|point_contents|clipnode" addons src
```

## Findings

| Item | Current branch result |
| --- | --- |
| `addons/hl_core` | Not found. |
| `bsp_reader.gd` | Not found. |
| `bsp_clipnode.gd` | Not found. |
| `trace_hull` implementation | Not found. |
| `point_contents` implementation | Not found. |
| OpenStrike-owned BSP header/lump reader | Not found. |
| OpenStrike-owned clipnode trace backend | Not found. |

`clipnode` appears only in capability strings and smoke assertions that keep the
feature marked as `requires_openstrike_bsp_reader`; no parser or trace backend
implementation was found.

The only current BSP runtime path is
`src/core/maps/goldsrc_bsp_runtime_provider.gd`, which delegates BSP scene
loading to the vendored `alanfischer/goldsrc-godot` dependency.

## Current PR-07 Runtime Reality

Current repo has no OpenStrike-owned BSP reader / clipnode trace
implementation. PR-07 currently relies on `goldsrc-godot` for BSP scene loading
and `godot_scene_collision` for walkable lab collision.

The provider reports this honestly:

* `clipnodes = requires_openstrike_bsp_reader`
* `hull_trace = requires_openstrike_bsp_reader`
* `hull_sizes = requires_openstrike_bsp_reader`
* `collision_source = godot_scene_collision`

## Conclusion

Do not plan work as if `addons/hl_core` or an OpenStrike-owned BSP reader
already exists in this repository. The next architecture step should create a
small TraceBackend boundary and keep Godot collision marked as temporary
non-parity until a clean BSP reader/clipnode backend is implemented or
license-reviewed.
