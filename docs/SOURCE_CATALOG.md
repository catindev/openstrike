# Source Catalog

This catalog classifies external references used by OpenStrike. It is a
reference map, not an implementation source. Do not copy source code, assets or
licensed content from any listed material.

## Source Weighting

### Primary technical references

Use for behavior, formats, constants and compatibility targets. Copying code is
still forbidden unless the source license and project decision explicitly allow
it.

* Valve Developer Community documentation.
* Valve/Bernier networking and latency documentation.
* Public Half-Life SDK and ValveSoftware/halflife materials, as reference only.
* ReHLDS/ReGameDLL/Xash3D-family references, only after license constraints are
  checked and without copying GPL/proprietary code.

### Project platform references

Use for Godot API behavior, editor/runtime constraints and GDScript conventions.
These references guide implementation style and tool usage, but they do not
override OpenStrike architecture, legal boundaries or CS 1.6 parity documents.

* Godot official GDScript style guide.
* Godot official static typing in GDScript documentation.
* Godot official warning system documentation.
* Godot official best-practices documentation.
* Godot official autoload, resources, signals, 3D collision shapes, physics
  interpolation and command-line documentation.
* GUT or GdUnit4 documentation only after the project chooses a single test
  framework.

### Community engineering references

Use for methodology, symptom catalogs, experiment design and sanity checks.
These sources can shape labs and acceptance criteria, but they do not override
GoldSrc/CS 1.6 references for exact values.

* KZ-Rush physics articles.
* Server cvar dumps and community measurement posts.
* 3kliksphilip Counter-Strike engine analysis and experiment videos.

### Low-weight feel vocabulary

Use to identify player-facing symptoms. Do not use as standalone proof for
mechanics or constants.

* Reddit, Steam Discussions, HLTV, forum posts and player anecdotes.

## 3kliksphilip / Counter-Strike Engine Analysis

Type: community engineering / educational / experimental analysis.

Use for:

* test methodology;
* movement, hitbox, hit registration, latency and performance symptom catalogs;
* mapping and Source/Hammer concept checklists;
* readability, animation and HUD/viewmodel cost awareness;
* experiment format: isolated setup, one variable, debug visualization,
  before/after comparison and player-visible conclusion.

Do not use for:

* copying code or assets;
* treating CS:GO/CS2 values as CS 1.6 values;
* replacing GoldSrc, CS 1.6 or project-owned measurements;
* legal or asset redistribution assumptions.

Important materials to catalog and revisit by topic:

* Tick/input: CS:GO 64 vs 128 tick, CS2 input latency, further CS2 input
  latency testing.
* Movement symptoms: CS:GO movement comparison old vs new, Can CS:GO learn
  anything from CS 1.6?
* Hitboxes/hit registration: hitboxes while jumping, hitboxes while planting,
  T/CT hitbox comparisons, model-vs-hitbox comparisons.
* Shooting: CS:GO major accuracy update analysed.
* Performance/readability: CS2 HUD cost, CS2 Animgraph 2 isn't perfect.
* Mapping: Source SDK / Hammer mapping tutorials, lighting, reflections, 2D/3D
  skyboxes and optimized map analyses.

The full working notes are in `docs/3KLIKSPHILIP_RESEARCH_NOTES.md`.
