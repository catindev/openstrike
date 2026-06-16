# Godot OpenStrike Agent Skill

Статус: v0.1, 2026-06-14
Назначение: проектная инструкция для Codex/AI-агентов перед разработкой Godot-части OpenStrike.

---

## 0. Когда использовать этот skill

Используй этот skill, если задача касается Godot-кода OpenStrike:

- GDScript;
- сцен `.tscn`;
- ресурсов `.tres` / `.res`;
- Godot-проектной структуры;
- player movement / physics / input;
- HUD, меню, viewmodel, effects;
- asset manager / GoldSrc provider;
- diagnostics/dev scenes/tests;
- Godot export/CI/headless checks.

Если задача касается форматов GoldSrc, CS 1.6 movement, оружия, экономики,
ботов или legal boundary, этот skill не заменяет профильные документы. Сначала
прочитай `AGENTS.md`, затем `docs/README.md`, затем этот skill, затем
профильный документ из reading order.

---

## 1. Базовая позиция OpenStrike

OpenStrike — не обычная Godot-игра и не песочница. Это Godot runtime + собственный gameplay layer + GoldSrc asset provider для воспроизведения опыта CS 1.6 при наличии у пользователя лицензионной копии игры.

Жёсткие правила:

- не коммитить ассеты Valve;
- не коммитить `local_goldsrc.json`;
- не коммитить telemetry dumps, `.DS_Store`, `__MACOSX`, локальные временные файлы;
- не копировать код Valve / HLSDK / GoldSrc / Xash3D;
- старые движки использовать как справочник поведения и форматов, не как source copy;
- не писать свой renderer/audio/input/windowing/export pipeline вместо Godot;
- gameplay должен быть server-authoritative даже в single-player/local mode;
- gameplay-числа должны быть data-driven: cvars/config/resources, а не магические числа в коде.

Главная архитектурная формула:

```text
Input → ClientCommand → LocalTransport → GameServer tick → Snapshot → Presentation
```

Asset boundary:

```text
Game/Presentation → asset manager → asset provider → GoldSrc VFS → local CS 1.6 install
```

Gameplay не знает путей вроде `models/v_ak47.mdl` или `sound/weapons/ak47-1.wav`. Gameplay знает `weapon_id`, `sound_event_id`, `effect_event_id`, `surface_type`, `map_entity_id`.

---

## 2. Перед началом любой задачи

1. Прочитай `AGENTS.md`.
2. Прочитай `docs/README.md` и профильные документы из reading order.
3. Прочитай задачу в issue/PR plan/user request.
4. Определи слой изменения:
   - `core/` — runtime, assets, VFS, BSP, console/cvars, audio bus, net transport;
   - `game/` — серверная игровая логика: player, weapons, rules, economy, entities, bots;
   - `presentation/` — HUD, menus, viewmodel, effects, radar, client input presentation;
   - `dev/` — diagnostics, telemetry, measurement, labs, sandbox;
   - `data/` — cvars, configs, weapon catalog, rules, manifests.
5. Проверь, не нарушает ли изменение legal boundary.
6. Сформулируй acceptance criteria до кода.
7. Для gameplay/parity-задачи добавь telemetry или diagnostic output.
8. Для visual/UI-задачи добавь manual verification steps и, если возможно, screenshot/video note.

Не начинай с хаотичного редактирования сцен. Сначала найди владельца ответственности и точку входа.

---

## 3. Godot version policy

- Используй Godot 4.x stable, закреплённый проектом.
- Не опирайся на `latest` docs, если они описывают будущую/нестабильную версию.
- При изменении engine version обнови `docs/`, CI/export notes и compatibility notes.
- Не добавляй или не обновляй addon/GDExtension без проверки
  `docs/THIRD_PARTY_DEPENDENCIES.md`, license status и платформенной
  совместимости macOS.

---

## 4. GDScript стиль

Следуй official Godot GDScript style guide и держи стиль единым внутри проекта.
Если проектный файл уже использует локальный порядок или naming pattern,
сохраняй surrounding style. Текущие OpenStrike-скрипты обычно пишут `extends`
перед `class_name`.

### 4.1. Naming

```gdscript
class_name WeaponRuntimeState
extends RefCounted

signal ammo_changed(previous: int, current: int)

const MAX_RESERVE_AMMO: int = 90

enum WeaponState {
    HOLSTERED,
    DEPLOYING,
    IDLE,
    FIRING,
    RELOADING,
}

var weapon_id: StringName
var magazine_ammo: int = 0
var reserve_ammo: int = 0

var _cooldown_sec: float = 0.0
```

Rules:

- classes/nodes: `PascalCase`;
- files: `snake_case.gd`;
- variables/functions: `snake_case`;
- constants: `ALL_CAPS`;
- private fields/functions: prefix `_`;
- signals: past-tense/event-like, e.g. `state_changed`, `shot_accepted`, `asset_failed`;
- enums: named, not loose strings, unless data compatibility requires string IDs.

### 4.2. Code order

Preferred order:

```gdscript
class_name Example
extends Node

## Doc comment.

signal something_happened(value: int)

const SOME_CONST: int = 1
enum Mode { A, B }

@export var config: Resource

var public_state: int = 0
var _private_state: int = 0

@onready var _child: Node = %Child

func _ready() -> void:
    pass

func public_method() -> void:
    pass

func _private_method() -> void:
    pass
```

### 4.3. Static typing is default

Use typed GDScript by default:

```gdscript
func calculate_damage(base_damage: float, armor_ratio: float) -> float:
    return base_damage * armor_ratio

var hitgroups: Array[StringName] = []
var weapon_prices: Dictionary[StringName, int] = {}
```

Avoid untyped `Array`, `Dictionary`, `Variant` unless there is a reason. If you must use dynamic data from JSON/CFG/BSP, convert it at the boundary into typed runtime objects.

Bad:

```gdscript
func apply(data):
    health = data["hp"]
```

Good:

```gdscript
func apply_snapshot(snapshot: PlayerSnapshot) -> void:
    _health = snapshot.health
```

### 4.4. Warnings

- Keep GDScript warnings clean.
- Do not blanket-ignore warnings.
- If you use `@warning_ignore`, explain why in a comment.
- Treat unused variables, unsafe casts, unreachable code and shadowing as PR blockers unless there is a clear reason.

---

## 5. Scenes, nodes and scripts

Godot is scene/node oriented, but OpenStrike must not become a scene-tree spaghetti project.

### 5.1. Scene owns presentation, not core gameplay

Use scenes for:

- visual composition;
- HUD/control hierarchy;
- viewmodel rig;
- effect instances;
- dev labs;
- map runner root;
- menu screens.

Do not store authoritative gameplay state in random scene nodes. Server state belongs to `game/server`, `game/player`, `game/weapons`, `game/rules` etc.

### 5.2. Keep nodes thin

A scene node may:

- receive snapshot/event data;
- play animation;
- render HUD;
- spawn effect from a provider-resolved resource;
- forward input into `ClientCommand`.

A scene node must not:

- decide round win conditions;
- own economy rules;
- hardcode weapon damage;
- load GoldSrc file paths directly;
- mutate server state through hidden references;
- decide bot strategy.

### 5.3. Prefer explicit dependencies

Bad:

```gdscript
func _ready() -> void:
    Global.weapon_manager.fire()
```

Good:

```gdscript
func setup(commands: ClientCommandSink, events: PresentationEventBus) -> void:
    _commands = commands
    _events = events
```

Use autoloads sparingly. Good autoload candidates:

- bootstrap-level service registry;
- global diagnostics sink;
- project config loader;
- logging.

Bad autoload candidates:

- every weapon system;
- every bot system;
- gameplay rules;
- global mutable game state.

### 5.4. Signals

Use signals to decouple presentation from gameplay events, but keep signal topology understandable.

Recommended:

```gdscript
signal shot_accepted(event: WeaponFireEvent)
signal asset_failed(asset_id: StringName, reason: String)
signal round_state_changed(previous: RoundState, current: RoundState)
```

Rules:

- child can signal upward to parent/controller;
- domain services can emit typed events through an event bus;
- avoid invisible editor-only signal connections in important systems; prefer code connections for core systems;
- disconnect in `_exit_tree()` if connection lifetime is not owned by the same tree branch;
- do not use signals as replacement for direct function calls inside small cohesive objects.

---

## 6. Resources and data-driven design

Godot Resources are data containers. Use them for typed data that designers/devs edit in Godot. Use JSON/CFG for compatibility with GoldSrc-like configs and external modding.

### 6.1. When to use `.tres` Resource

Use custom Resource for:

- editor-friendly local config;
- typed references to scenes/audio/materials inside our own project;
- dev lab presets;
- presentation themes;
- reusable gameplay definitions when external modding is not the priority.

Example:

```gdscript
class_name WeaponPresentationConfig
extends Resource

@export var weapon_id: StringName
@export var viewmodel_scene: PackedScene
@export var muzzle_flash_effect: PackedScene
@export var draw_animation: StringName = &"draw"
@export var fire_animation: StringName = &"fire"
```

### 6.2. When to use JSON/CFG

Use JSON/CFG for:

- CS 1.6 cvars;
- weapon catalog parity data;
- economy/rules;
- asset pack manifests;
- GoldSrc file mappings;
- configs that may be generated or modded outside Godot.

Always validate external JSON/CFG into typed objects at load time.

Bad:

```gdscript
var price = weapon_json[id]["price"]
```

Good:

```gdscript
var definition: WeaponDefinition = WeaponDefinition.from_dict(raw)
if not definition.is_valid():
    diagnostics.error("weapon_definition_invalid", id)
```

### 6.3. Do not preload local GoldSrc assets

Never do:

```gdscript
const AK_VIEWMODEL = preload("<local Half-Life>/cstrike/models/v_ak47.mdl")
```

Use:

```gdscript
var viewmodel: PackedScene = await asset_manager.load_weapon_view_model(&"ak47")
```

---

## 7. Input, tick and simulation

OpenStrike needs CS-like responsiveness and eventually networking. Therefore input must be transformed into commands, not directly into scene movement.

### 7.1. Input flow

```text
Godot InputEvent
  -> ClientInputMapper
  -> ClientCommand
  -> LocalTransport / NetworkTransport
  -> GameServer fixed tick
  -> Snapshot
  -> Presentation
```

Do not let `Player.tscn` directly own authoritative movement for production gameplay.

### 7.2. `_physics_process` vs `_process`

- Gameplay simulation and movement: fixed tick / `_physics_process` or custom fixed-step loop.
- Rendering interpolation, UI animations, visual-only effects: `_process` is acceptable.
- Do not mutate authoritative transforms in `_process`.
- If physics interpolation is enabled, transforms that need interpolation must be set in physics ticks.

### 7.3. CS-like movement warning

Godot `CharacterBody3D` is acceptable for early dev scenes only. It is not the final CS 1.6 movement solver.

For parity movement implement explicit solver:

```text
usercmd -> wishdir/wishspeed -> friction -> acceleration -> trace/clip -> step solver -> state
```

Keep telemetry:

```json
{
  "tick": 1200,
  "cmd": "+forward +moveleft",
  "grounded": true,
  "wishspeed": 250.0,
  "speed_before": 250.0,
  "speed_after_friction": 240.0,
  "speed_after_accel": 251.2
}
```

---

## 8. 3D physics and collision policy

Godot collision shapes have tradeoffs. Primitive shapes are more reliable for dynamic bodies. Concave/trimesh shapes are accurate for static level collision but slowest and only valid for static bodies. For OpenStrike this maps well to:

- dynamic players/weapons/projectiles: primitive/convex/custom hull traces;
- BSP world: static collision / BSP hull/clipnode implementation;
- final CS feel: GoldSrc-like hull trace, not generic capsule feel.

Rules:

- do not use detailed render meshes as dynamic collision;
- do not use concave shapes for moving bodies;
- do not assume Godot capsule == CS hull;
- for BSP, build a clear separation between render mesh, static collision, and later hull/clipnode collision;
- keep debug overlays for collision hull, trace planes, step attempts, floor normals.

---

## 9. Asset manager / GoldSrc provider coding rules

### 9.1. Gameplay cannot load files directly

Bad:

```gdscript
var stream = load("res://sound/weapons/m4a1-1.wav")
var model = load("res://models/v_m4a1.tscn")
```

Good:

```gdscript
audio_orchestrator.play_weapon_event(&"weapon.m4a1.fire", context)
viewmodel_orchestrator.equip_weapon(&"m4a1")
```

### 9.2. Provider resolves physical paths

Only provider/VFS layer may know:

```text
cstrike/models/v_m4a1.mdl
cstrike/sound/weapons/m4a1_unsil-1.wav
valve/sprites/muzzleflash1.spr
maps/de_dust2.bsp
```

### 9.3. Missing asset behavior

If asset is missing:

- log diagnostics;
- disable that feature/weapon/effect if needed;
- keep editor/game running when possible;
- do not spawn placeholder cubes/sounds/textures in production path.

Allowed:

```text
missing muzzle flash -> no muzzle flash + warning
missing shell model -> no shell ejection + warning
missing map -> map unavailable + warning
```

Not allowed:

```text
fake white box weapon
random placeholder sound
procedural rectangle muzzle flash in classic path
```

---

## 10. Presentation architecture

Presentation displays server/client state. It does not decide gameplay.

### 10.1. Viewmodel

Viewmodel must be separate from world model logic.

```text
PlayerClientView
  HeadPivot
    WorldCamera3D
    ViewModelRig
      ViewModelCamera3D or ViewModelLayer
      ViewModelRoot
```

Rules:

- first-person `v_*.mdl` is presentation-only;
- viewmodel does not participate in gameplay collision;
- animation event may trigger sound/effect timing, but damage/fire authority comes from weapon server state;
- recoil visual kick and gameplay recoil/spread are separate layers;
- no direct GoldSrc file loads in viewmodel scripts; use asset provider/config.

### 10.2. HUD

- HUD receives snapshots/events.
- HUD does not pull random gameplay state from scene tree.
- HUD sprite/layout assets are cached.
- No per-frame file loading.
- Procedural/debug HUD remains dev-only; classic HUD uses sprite/layout pipeline.

### 10.3. Effects

Effects are event-driven:

```text
WeaponFireAccepted
  -> Audio event
  -> Muzzle flash request
  -> Shell ejection request
  -> Tracer request
  -> Impact/decal request
```

Use pools for high-frequency effects when feature exits prototype.

---

## 11. Diagnostics and labs are mandatory

OpenStrike is a parity project. “Feels right” is not enough.

For every movement/weapon/physics/system task, prefer adding one of:

- debug overlay;
- telemetry CSV/JSON;
- dev scene/lab;
- deterministic replay fixture;
- map/entity diagnostic panel;
- asset resolution report.

Recommended labs:

```text
src/dev/labs/movement_lab/
src/dev/labs/hitbox_lab/
src/dev/labs/input_latency_lab/
src/dev/labs/wall_spray_lab/
src/dev/labs/map_entities_lab/
src/dev/labs/hud_cost_lab/
src/dev/labs/bsp_collision_lab/
```

---

## 12. Tests and CI

### 12.1. Test levels

Use three test categories:

```text
tests/unit/         pure GDScript logic, no full scene needed
tests/integration/  nodes/services together
tests/fixtures/     synthetic assets/maps, no Valve assets
```

### 12.2. Godot test framework

Prefer one test framework and keep it consistent:

- GUT is mature and works with GDScript/Godot 4;
- GdUnit4 is also viable, especially if the team wants embedded editor workflows and scene testing.

Do not add both unless there is a project decision.

### 12.3. Headless commands

Keep CI commands documented. Current project checks are script-based:

```bash
scripts/run_smoke_checks.sh
scripts/check_no_forbidden_assets.sh
git diff --check
```

If `Godot` is not on `PATH`, set `GODOT_BIN` for `scripts/run_smoke_checks.sh`.
Use exact commands from `docs/TESTING.md` and CI when they change.

### 12.4. Required checks before PR

At minimum:

```bash
scripts/run_smoke_checks.sh
scripts/check_no_forbidden_assets.sh
git diff --check
```

Also search for direct asset path usage in gameplay when touching asset,
weapon or presentation code:

```bash
rg -n "models/v_|sound/weapons/|sprites/" src/game src/core
```

Direct references may be allowed in provider/config only, not gameplay.

---

## 13. Filesystem and version control

Do commit:

- `.gd`, `.tscn`, `.tres`, `.res` authored by project;
- `project.godot`;
- `.import` files for project-owned assets if the project policy requires reproducible imports;
- docs;
- configs/examples;
- synthetic fixtures created by OpenStrike.

Do not commit:

- `.godot/` cache;
- exports/build outputs;
- `local_goldsrc.json`;
- original CS/Valve assets;
- telemetry dumps;
- `.DS_Store`, `__MACOSX`;
- local absolute paths.

Use `.gdignore` in directories that Godot should not import, for example large external work dirs or generated outputs, but do not rely on it as a legal safety mechanism.

---

## 14. Error handling and diagnostics

Prefer structured diagnostics over `print()` spam.

Example:

```gdscript
diagnostics.warn(&"asset_missing", {
    "asset_id": asset_id,
    "provider": &"goldsrc",
    "tried": tried_paths,
})
```

Error categories:

```text
config_invalid
asset_missing
asset_load_failed
map_entity_unsupported
movement_parity_warning
prediction_error
state_transition_rejected
legal_boundary_violation
```

In user-facing modes, show useful message. In dev mode, show full provider/path diagnostics without leaking local paths into committed docs/tests.

---

## 15. Performance rules

- No `load()` in hot paths such as `_process`, `_physics_process`, firing loop, HUD draw.
- Preload project-owned static resources where appropriate.
- Provider-loaded external resources must be cached with manifest keys.
- Pool high-frequency objects: muzzle flashes, shell casings, tracers, decals, audio players.
- Avoid unnecessary nodes for pure data/logic; use `RefCounted` or `Resource` where node lifecycle is not needed.
- Add profiler counters for HUD, viewmodel, active effects, physics trace count, BSP visible surfaces when working on those systems.

---

## 16. Godot code templates

### 16.1. Typed service object

```gdscript
class_name WeaponCatalog
extends RefCounted

var _definitions: Dictionary[StringName, WeaponDefinition] = {}

func register_definition(definition: WeaponDefinition) -> void:
    assert(definition != null)
    assert(definition.weapon_id != StringName())
    _definitions[definition.weapon_id] = definition

func get_definition(weapon_id: StringName) -> WeaponDefinition:
    if not _definitions.has(weapon_id):
        push_error("Unknown weapon_id: %s" % weapon_id)
        return null
    return _definitions[weapon_id]
```

### 16.2. Event DTO

```gdscript
class_name WeaponFireEvent
extends RefCounted

var tick: int
var shooter_id: int
var weapon_id: StringName
var origin: Vector3
var direction: Vector3
var seed: int
var accepted: bool
```

### 16.3. Thin presentation node

```gdscript
class_name WeaponViewModelPresenter
extends Node3D

var _asset_manager
var _current_weapon_id: StringName = &""
var _active_scene: Node3D

func setup(asset_manager) -> void:
    _asset_manager = asset_manager

func present_weapon_equipped(weapon_id: StringName) -> void:
    _current_weapon_id = weapon_id
    if _active_scene != null:
        _active_scene.queue_free()
        _active_scene = null

    var packed_scene: PackedScene = _asset_manager.load_weapon_view_model(weapon_id)
    if packed_scene == null:
        push_warning("Missing viewmodel for %s" % weapon_id)
        return

    _active_scene = packed_scene.instantiate() as Node3D
    add_child(_active_scene)
```

### 16.4. Validation result

```gdscript
class_name ValidationResult
extends RefCounted

var ok: bool = true
var errors: Array[String] = []
var warnings: Array[String] = []

func add_error(message: String) -> void:
    ok = false
    errors.append(message)

func add_warning(message: String) -> void:
    warnings.append(message)
```

---

## 17. Layer-specific rules

### 17.1. `core/`

Allowed:

- VFS;
- asset loading abstractions;
- BSP format parsing;
- cvars/config infrastructure;
- generic audio bus;
- generic transport/prediction primitives;
- units/conversion helpers.

Forbidden:

- CT/T round rules;
- weapon damage semantics;
- buy menu logic;
- CS-specific bot decisions;
- UI assumptions.

### 17.2. `game/`

Allowed:

- server-authoritative game state;
- rules/economy/weapons/player/bots;
- command handling;
- deterministic simulation;
- gameplay events.

Forbidden:

- direct file loading of GoldSrc assets;
- direct HUD/node manipulation;
- viewmodel animation decisions;
- local user paths.

### 17.3. `presentation/`

Allowed:

- displaying snapshots/events;
- HUD and menus;
- viewmodel/effects/audio presentation;
- input mapping before command creation.

Forbidden:

- authoritative damage/round/economy decisions;
- hardcoded CS asset paths outside config/provider;
- server state mutation through node references.

### 17.4. `dev/`

Allowed:

- labs;
- measurement scenes;
- telemetry tools;
- overlays;
- debug UI.

Forbidden:

- production-only dependency on dev tools;
- committed telemetry sessions;
- Valve assets in fixtures.

---

## 18. PR checklist for Codex

Every PR must include:

```markdown
## Goal

## Changed files

## Layer touched
- [ ] core
- [ ] game
- [ ] presentation
- [ ] dev
- [ ] data/docs

## Architecture check
- [ ] gameplay remains server-authoritative
- [ ] core/game/presentation boundary preserved
- [ ] no direct GoldSrc file paths in gameplay
- [ ] no local absolute paths
- [ ] data-driven values where needed

## Legal check
- [ ] no Valve assets
- [ ] no copied Valve/HLSDK/Xash3D code
- [ ] no local_goldsrc.json
- [ ] no telemetry dumps

## Tests / diagnostics
- [ ] unit/integration test updated or added
- [ ] diagnostic overlay/log added if relevant
- [ ] manual verification steps included

## Manual verification
1.
2.
3.

## Docs
- [ ] docs updated if architecture/behavior changed
```

---

## 19. Common mistakes Codex must avoid

1. Creating a giant `Main.gd` that owns gameplay, UI, assets, input and debugging.
2. Letting `Player.tscn` be the authoritative game server.
3. Loading `models/v_*.mdl` or `sound/weapons/*.wav` directly from gameplay code.
4. Adding placeholder art/audio into production path.
5. Treating Godot capsule movement as final CS 1.6 movement.
6. Implementing CS:GO recoil for CS 1.6 parity.
7. Adding global autoload singletons for everything.
8. Silently fixing classic quirks without profile/cvar separation.
9. Moving transforms in `_process` for authoritative physics objects.
10. Changing scenes manually in a way that breaks persistent services.
11. Adding addon dependencies without license/platform check.
12. Forgetting diagnostics for asset lookup failures.
13. Adding tests that require original Valve assets.
14. Treating `latest` Godot docs as stable project target.

---

## 20. Source references to record in `docs/SOURCE_CATALOG.md`

Use these as the starting source list for this skill:

- Godot official GDScript style guide.
- Godot official static typing in GDScript.
- Godot official GDScript warning system.
- Godot official best practices section.
- Godot official autoloads versus regular nodes.
- Godot official resources documentation.
- Godot official signals documentation.
- Godot official 3D collision shapes documentation.
- Godot official physics interpolation documentation.
- Godot official command line tutorial.
- GUT repository / docs, if chosen as test framework.
- GdUnit4 repository / docs, if chosen as test framework.
- OpenStrike `AGENTS.md`, `docs/README.md`, `docs/LEGAL_ORIGINALITY.md`,
  `docs/ARCHITECTURE.md`, `docs/COMPACT_PR_TASK_PACKETS.md` and
  `docs/DECISIONS.md`.
