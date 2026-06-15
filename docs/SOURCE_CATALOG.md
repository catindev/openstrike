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
* Local licensed Counter-Strike 1.6/Half-Life installation filename inspection,
  only for confirming relative asset paths and availability. Do not commit
  local absolute paths, asset bytes, extracted caches or local config files.

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

## Local CS 1.6 Asset Filename Inspection

Type: primary local verification for asset availability.

Use for:

* confirming that a relative path such as `models/v_ak47.mdl` exists in a
  licensed local installation;
* deciding whether a candidate path belongs in a committed semantic catalog;
* documenting missing candidates as excluded until verified.

Do not use for:

* copying, extracting, committing or redistributing asset bytes;
* committing local absolute paths or `local_goldsrc.json`;
* inferring animation timing, sequence names or gameplay values without parser
  and source-backed verification.

Current accepted use:

* `data/assets/cs16_pilot_weapon_assets.json` contains only relative paths
  verified from a local licensed Steam installation on 2026-06-14.

## GoldSrc Viewmodel, Asset and HUD References

Type: mixed primary/community reference for PR-06 profile and atlas design.

Use for:

* world/viewmodel profile contracts, source values and smoke expectations when
  cross-checked against primary references;
* GoldSrc folder/domain coverage, format responsibilities and scanner scope;
* HUD/sprite layout, map overview, `.res`, materials and entity vocabulary
  planning;
* identifying what must be verified by a local generated atlas rather than
  written by hand.

Do not use for:

* committing generated data from a real local installation;
* replacing local MDL/SPR/WAV/BSP inspection with public assumptions;
* copying Valve, HLSDK, ReHLDS, Xash3D or other third-party source code;
* treating community wiki/gameplay pages as final CS 1.6 parity constants.

Important references introduced by `VIEWMODEL_WORLD_PROFILE.md` and
`CS16_ASSET_ORCHESTRATION_ATLAS.md`:

* `alanfischer/goldsrc-godot` README for the loader scale default,
  GoldSrc-to-Godot coordinate mapping and BSP conversion flags.
* `alanfischer/goldsrc-godot` GDExtension API inspection for `GoldSrcMDL` and
  `GoldSrcSPR` method availability. Use it only through the OpenStrike adapter;
  do not copy its source into project-owned decoders.
* Godot `Camera3D` documentation for `fov` and `keep_aspect` semantics.
* Valve HLSDK references for eye/view offsets and `default_fov` constants,
  as reference only.
* Valve Developer Community GoldSrc pages for BSP, `.res`, materials and
  mapping documentation.
* Public GoldSrc QC, HUD, overview and weapon-info references as scanner design
  input, not as generated runtime truth.

## `alanfischer/goldsrc-godot`

Type: third-party project dependency and GoldSrc loader API reference.

Use for:

* loading local licensed GoldSrc MDL/SPR files through Godot runtime classes;
* validating which viewmodel facts are exposed by the loader API;
* avoiding project-owned duplicate MDL/SPR decoders before a concrete API gap
  requires one.

Do not use for:

* bundling Valve assets or generated imports;
* bypassing OpenStrike's semantic asset provider and VFS layers;
* claiming support for sockets, attachments or animation events unless the
  loader API exposes those fields or a separate OpenStrike reader is approved.

Current dependency metadata is tracked in
`docs/THIRD_PARTY_DEPENDENCIES.md`.

## GoldSrc Runtime Spine References

Type: primary format/behavior references for BSP30 collision and future PMove.

Use for:

* BSP30 header/lump, plane, clipnode and model byte-layout contracts;
* synthetic BSP30 reader and clipnode trace fixtures;
* clean-room movement/collision terminology and acceptance criteria;
* deciding which facts require `TODO: verify` before implementation.

Do not use for:

* copying source code from any engine;
* opening denylisted Xash3D or HLSDK source files while implementing matching
  OpenStrike modules;
* replacing the current PR packet with neighboring package scope;
* treating Godot scene collision as GoldSrc clipnode/hull parity.

Current project documents:

* `docs/CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md`
* `docs/COMPACT_PR_TASK_PACKETS.md`

Important neutral/public references recorded by the spec:

* TWHL Wiki BSP page for GoldSrc BSP format facts.
* Valve Developer Community BSP (GoldSrc) snippets for BSP30/version/lump
  constants and contents enums where full page access is blocked.
* Half-Life Physics Reference by jwchong for movement behavior, described in
  OpenStrike's own words.
* `docs/VIEWMODEL_WORLD_PROFILE.md` for unit scale and coordinate mapping.
