# CS 1.6 Feel — инженерный baseline для OpenStrike

Статус: research baseline
Цель: зафиксировать, какие свойства Counter-Strike 1.6 создают ощущение “той самой CS 1.6”, и перевести это в требования к движку, gameplay-коду, presentation-слою и тестам OpenStrike.

---

## 1. Главный вывод

“Feel CS 1.6” — это не одна настройка movement speed и не один recoil pattern. Это сумма нескольких систем:

1. Дискретная GoldSrc-симуляция с исторически важным 100 FPS / 100 Hz поведением.
2. Специфическая модель ускорения, трения, air-strafe, bhop, duck/double-duck, edgefriction и step handling.
3. Простая, жёсткая BSP-геометрия без физического мусора и без современной “скользкости”.
4. Хитскан-стрельба с быстрым first-shot / burst loop, semi-random recoil/spread и сильной зависимостью от стойки, движения и темпа стрельбы.
5. Быстрый, грубый, но очень читаемый feedback: звук, view punch, decals, crosshair expansion, death/headshot animations, muzzle flash, hit/death events.
6. Client prediction + server-authoritative модель, где локальный игрок ощущает input immediately, но итоговое состояние решает сервер.
7. Низкая визуальная перегруженность: читаемые силуэты, простые карты, минимум пропов, понятные материалы и шаги.
8. CFG/cvar-культура: игроки привыкли, что ощущение игры задаётся не только кодом, но и `fps_max`, `rate`, `cl_cmdrate`, `cl_updaterate`, `ex_interp`, mouse settings, resolution, raw input/OS mouse path.

Для OpenStrike это значит: нельзя “примерно сделать контроллер на Godot CharacterBody3D”. Нужно реализовать отдельный CS16 movement solver, hull trace, weapon accuracy model, prediction loop, presentation feedback path и parity tests.

---

## 2. Источниковая база

### 2.1. Источники высокого веса

Использовать как reference, но не копировать код:

* ValveSoftware/halflife, особенно `pm_shared`.
* Valve/Bernier latency compensation article.
* HLSDK constants and behavior.
* ReGameDLL / ReHLDS как reverse-engineering reference, если лицензия и использование явно проверены.

### 2.2. Источники среднего веса

Использовать как инженерные объяснения и тестовые подсказки:

* KZ-Rush physics articles: strafe, bhop, highjump, countjump, longjump.
* Cvar lists and server variable dumps.
* Community measurement posts and demos.

### 2.3. Источники низкого веса, но важные для “feel vocabulary”

Использовать как карту симптомов:

* Reddit / Steam Discussions / HLTV discussions.
* Старые форумы про recoil, rates, FPS, resolution.
* Игроки часто описывают точные инженерные проблемы неточными словами: “floaty”, “muddy”, “random”, “heavy”, “tight”, “instant”, “choppy”, “registration bad”.

---

## 3. Техническое определение “CS 1.6 feel”

Для OpenStrike считать, что CS 1.6 feel достигнут, если игрок получает:

```text
input -> movement command -> 100 Hz movement solve -> immediate local presentation
     -> server-authoritative state -> corrected snapshot
     -> weapon state / accuracy / damage -> deterministic feedback path
```

и при этом выполняются следующие условия:

* движение имеет те же микроповедения: ground friction, fastrun, air-strafe gain, bhop FOG, edgefriction, duck/scroll duck, step height;
* оружие имеет те же боевые ритмы: быстрые taps, 2–3 shot bursts, наказание за длинный spray, влияние crouch/stand/move/jump;
* hit feedback приходит сразу и грубо, без современной “резиновой” задержки;
* карты читаются как BSP-пространства: чистые углы, предсказуемые клипы, нет физического clutter;
* сетевой слой не ломает ощущение локального input.

---

## 4. Movement feel: ядро

### 4.1. Fixed simulation

В оригинальной культуре CS 1.6 ключевой режим — 100 FPS. При 100 FPS игрок получает 100 обработок mouse/input/movement в секунду. Многие трюки и микроповедения описываются в кадрах: 1 FOG, 2 FOG, 21 frame double duck, 40 frame duck transition.

Для OpenStrike нельзя привязывать физику к render FPS. Нужно сделать:

```text
movement_sim_hz = 100
movement_dt = 0.01
render_fps = independent
prediction = same movement solver
```

Если игрок рендерит 144/240 FPS, симуляция всё равно должна иметь CS16 parity mode на 100 Hz. Можно добавить interpolation presentation между movement ticks, но не менять физику.

### 4.2. Базовые cvars / constants

Базовый профиль `data/config/movement/cs16.json`:

```json
{
  "sim_tick_hz": 100,
  "gravity": 800,
  "sv_accelerate": 5,
  "sv_airaccelerate": 10,
  "sv_friction": 4,
  "sv_stopspeed": 75,
  "sv_stepsize": 18,
  "edgefriction": 2,
  "sv_maxvelocity": 2000,
  "sv_maxspeed": 320,
  "cl_forwardspeed": 400,
  "cl_backspeed": 400,
  "cl_sidespeed": 400,
  "cl_upspeed": 320,
  "cl_yawspeed": 210,
  "duck_time_sec": 0.4,
  "ducking_multiplier": 0.333,
  "stand_hull": {
    "mins": [-16, -16, -36],
    "maxs": [16, 16, 36],
    "height": 72
  },
  "duck_hull": {
    "mins": [-16, -16, -18],
    "maxs": [16, 16, 18],
    "height": 36
  },
  "stand_view_height": 28,
  "duck_view_height": 12,
  "max_clients": 32
}
```

Важное расхождение с частью старых гайдов: для CS 1.6 `sv_accelerate` нужно считать `5`, а не `10`. `10` — типичная Half-Life default-логика, но в CS `sv_accelerate` locked to 5. Для OpenStrike лучше завести два профиля: `goldsrc_hl` и `cs16`. В `cs16` ставить `sv_accelerate=5`.

### 4.3. Ground movement

Порядок операций принципиален:

```text
read input
build wish velocity
apply ground friction
clip wishspeed to maxspeed / weapon speed
apply PM_Accelerate
trace / slide / step
```

Не менять порядок. Если сначала ускорять, потом тормозить — feel сломается.

Ground friction при 100 Hz и `sv_friction=4` снимает примерно 4% скорости за кадр, если скорость выше `sv_stopspeed`. Пример для knife/USP speed 250:

```text
speed 250
PM_Friction -> 240
PM_Accelerate with W -> back to 250
```

Игрок ощущает это как “быстрый, но вязкий” ground control: при прямом беге скорость стабильна, но при отпускании клавиш персонаж быстро теряет скорость.

### 4.4. Fastrun / diagonal acceleration

CS 1.6 feel не равен “W всегда 250”. На земле есть микроприбавки скорости из-за того, как velocity projection и wishdir работают при W+A / W+D и повороте мыши.

Ключевой эффект:

```text
W straight: 250 -> friction 240 -> accelerate back to 250
W+A first frame: velocity turns and grows ~251.24
subsequent frames: transient growth up to ~262 for ~14 frames
```

Это значит, что:

* диагональный input нельзя просто нормализовать “по-современному”;
* нужно воспроизвести GoldSrc-style button state, wishdir, scaling and acceleration;
* telemetry должна показывать transient velocity, а не только steady-state speed.

### 4.5. Air movement

Air movement — одна из главных причин, почему 1.6 ощущается “живой”.

Принципы:

```text
no ground friction in air
PM_AirAccelerate instead of PM_Accelerate
sv_airaccelerate = 10
wishspeed is capped to 30 for air gain logic
gain depends on projection of current velocity onto wishdir
optimal input = A/D + mouse control, not W-hold
```

Игрок, который просто держит W в воздухе, почти не получает нужный gain. Игрок, который отпускает W, жмёт A/D и ведёт мышь под нужным углом, получает управляемый прирост скорости.

OpenStrike должен прямо тестировать:

```text
start speed = 250
jump
release W
press A
first air frame:
  accelspeed ~= 25
  resulting speed ~= 251.25
```

### 4.6. Bhop feel

Bhop в CS 1.6 — не просто “можно прыгать подряд”. Это связка из:

* edge-triggered jump logic;
* невозможности прыгать удержанием Space;
* scroll jump как способ отправить +jump/-jump на нужных кадрах;
* FOG, frames on ground;
* friction loss on ground frames;
* PM_PreventMegaBunnyJumping cap;
* частичной случайности/скилла в 1 FOG vs 2 FOG.

Правило для OpenStrike:

```text
holding +jump must not produce perfect bhop
scroll-like repeated jump commands must reduce FOG
1 FOG at speed <= 300 should avoid friction loss
speed > 300 should trigger mega-bunny damping
```

Для knife/USP maxspeed 250:

```text
maxscaledspeed = 300
if horizontal speed > 300:
  speed becomes 240
```

Это создаёт характерный баланс: bhop даёт контроль и skill expression, но не превращается в бесконечный runaway speed без ограничений.

### 4.7. Duck, double duck, countjump

Ducking — не косметика. Это отдельная физическая подсистема.

Constants:

```text
TIME_TO_DUCK = 0.4 sec
standing hull = 32 x 32 x 72
duck hull = 32 x 32 x 36
standing view height = 28
duck view height = 12
ducking movement multiplier = 0.333
```

На земле duck transition длится примерно 40 frames при 100 Hz. В воздухе duck может применяться почти мгновенно. Scroll duck (`+duck;-duck`) запускает PM_Duck, потом PM_UnDuck и подбрасывает игрока на 18 units вверх. Это даёт double duck / countjump-поведение.

Для OpenStrike это значит:

* duck нельзя реализовать как простое “scale capsule height smoothly”;
* нужно моделировать `usehull`, origin shift, view height, duck timer, PM_UnDuck check;
* double duck должен поднимать на 18 units при корректных условиях;
* duck должен влиять на movement command speed: `250 * 0.333 = 83.25`.

### 4.8. Edgefriction / highjump

Edgefriction создаёт ощущение опасных краёв и KZ/highjump-трюков.

Упрощённая инженерная формула:

```text
each ground frame:
  trace from foot-level point 16 units forward along velocity
  trace down
  if near high edge:
    friction *= edgefriction
```

Default `edgefriction=2`.

В OpenStrike это обязательно, иначе:

* highjump / longjump / countjump parity сломается;
* игроки будут ощущать края как “не те”;
* некоторые jumps на BSP-картах станут легче/сложнее.

### 4.9. Step and hull collision

Нужна не Godot capsule approximation, а GoldSrc-like hull behavior:

```text
player horizontal hull = 32 x 32
standing height = 72
duck height = 36
step height = 18
slide along planes
max 4 bump iterations
floor/wall flags from clip normal
```

Для первого playable этапа можно иметь collision mesh, но для feel parity нужен hull trace. Иначе лестницы, пороги, углы, ящики, прыжки и “цепляние” за геометрию будут отличаться.

---

## 5. Weapon feel

### 5.1. CS 1.6 recoil/spread не равен CS:GO recoil

CS:GO строится вокруг fixed spray patterns. CS 1.6 ощущается иначе: игроки описывают его как semi-random / multiple pattern / stance-sensitive / burst-oriented.

Для OpenStrike нельзя брать CS:GO-подход “одна таблица spray pattern на оружие”. Нужна модель:

```text
per weapon accuracy state
shots fired / continuous fire counter
time since last shot
movement state
duck state
air state
weapon-specific recoil kick
weapon-specific spread function
random seed / pattern family
view punch / crosshair feedback
```

### 5.2. Burst loop

Комьюнити постоянно описывает 1.6 через 2–3 bullet bursts. Это не только баланс, а физика accuracy recovery.

Требование:

```text
AK/M4/USP/Deagle should reward:
  stop -> tap
  stop -> 2-3 shot burst
  crouch -> controlled spray as commitment
  moving/jumping -> severe penalty
```

Длинный spray должен быть возможен, но его нужно контролировать техникой, crouch timing, mouse compensation and burst discipline.

### 5.3. Stance matters

Crouch в CS 1.6 влияет на ощущение spray/accuracy. Игроки старых версий обсуждают, что crouch spray был отдельным skill expression, но при этом делал игрока уязвимым против strafe shooting.

Значит:

```text
standing spread != crouch spread
moving spread != standing spread
air spread != moving spread
ducking affects both movement and weapon behavior
```

Не делать современную модель, где crouch — почти только визуальная поза.

### 5.4. First shot / reset quirks

Вокруг CS 1.6 accuracy есть известные community bug reports и споры: порядок обновления `m_flAccuracy`, reset timing, low-FPS behavior, first bullet after reload/quickswitch folklore. Для OpenStrike нужно не спорить на глаз, а сделать shooting lab.

Требование:

* реализовать `CS16WeaponAccuracyModel`;
* добавить режим `strict_legacy` и `fixed_modern`;
* в `strict_legacy` сохранять подтверждённые quirks;
* в `fixed_modern` можно править баги, но только отдельным mode/cvar, не в classic parity.

### 5.5. Visual feedback weapon loop

Оружейный feel создаётся не только траекторией пули:

```text
fire accepted
  -> ammo decremented immediately
  -> hitscan resolved immediately
  -> view punch/recoil starts immediately
  -> crosshair expands immediately
  -> muzzle flash appears
  -> sound plays
  -> decal/hit effect appears
  -> animation follows, but does not own damage timing
```

Gameplay authority не должен ждать animation marker. Animation events нужны для presentation, но shot/damage должны быть серверной игровой логикой.

---

## 6. Network / hit registration feel

### 6.1. Shared movement / prediction

CS 1.6 feel сильно связан с тем, что локальный input ощущается мгновенно. Half-Life/GoldSrc-подход исторически основан на shared movement logic между client и server: клиент предсказывает движение локально, сервер подтверждает authoritative state, клиент корректирует ошибки.

Для OpenStrike:

```text
GameServer authoritative
Client sends commands, not positions
Client predicts own player with the same movement solver
Server returns snapshots with command ack
Client replays unacknowledged commands
Presentation smooths corrections carefully
```

### 6.2. Rates / interp как часть исторического feel

Игроки CS 1.6 десятилетиями спорили о:

```text
rate
cl_cmdrate
cl_updaterate
ex_interp
fps_max
sys_ticrate
sv_unlag
sv_maxunlag
```

Для OpenStrike это не значит “заставить пользователя чинить cfg”. Это значит:

* иметь diagnostics overlay for networking;
* иметь sane defaults;
* иметь classic config compatibility;
* показывать choke/loss/interp/prediction error;
* не прятать сетевые проблемы за “магическим smoothing”.

### 6.3. Classic defaults to expose

Минимальный набор:

```json
{
  "sv_unlag": 1,
  "sv_maxunlag": 0.5,
  "cl_updaterate": 20,
  "sv_maxupdaterate": 30,
  "sv_minupdaterate": 10,
  "ex_interp": 0.1,
  "sys_ticrate": 100
}
```

Для современного OpenStrike можно иметь improved LAN profile, но classic parity mode должен быть явно сохранён.

---

## 7. Presentation feel

### 7.1. Viewmodel

First-person weapon in CS 1.6 is not a normal world model. It is a viewmodel layer:

```text
separate camera/layer
no world collision
not clipped by walls in normal way
own FOV / offset
own bob/sway/recoil
animation is presentation, not gameplay authority
```

OpenStrike должен держать viewmodel отдельно от gameplay weapon state.

### 7.2. Crosshair and HUD

Crosshair is feedback. It должен отражать:

```text
movement state
duck state
air state
shots fired
accuracy/spread recovery
weapon type
```

HUD должен быть читаемым в 640x480-style bucket. Не надо сразу делать современный scalable tactical HUD. Classic mode должен выглядеть грубо, контрастно и функционально.

### 7.3. Decals and impacts

Игроки CS 1.6 считывают spray через wall decals. Большие, контрастные marks на стене дают мгновенную обратную связь. Если OpenStrike сделает реалистичные мелкие современные bullet holes, оружие будет ощущаться “не так”.

Требование:

```text
decal visible at common 4:3 resolutions
impact appears same frame or next rendered frame
material-aware sound/effect
wall spray lab mandatory
```

### 7.4. Sound

Sound feel состоит из:

* резких weapon WAV;
* material footsteps;
* простого positional audio;
* читаемых reload fragments;
* попаданий/рикошетов/impact sounds;
* отсутствия лишнего ambient clutter.

Step sounds должны зависеть от texture/material type: concrete, metal, dirt, vent, grate, tile, slosh, wood, glass, flesh etc. Это уже заложено в HLSDK texture-type constants и должно быть перенесено как data mapping.

---

## 8. Map / level feel

CS 1.6 карты ощущаются не только из-за текстур. Их feel задают:

```text
BSP brush geometry
clean collision
simple silhouettes
few/no physics props
predictable corners
legacy step heights
wallbangable materials
large readable decals
material footsteps
known spawn/buy/bomb/hostage entities
```

OpenStrike должен приоритизировать:

1. BSP geometry.
2. Entity lump.
3. Team spawns.
4. Buyzones.
5. Bomb/hostage metadata.
6. Collision hulls / clipnodes.
7. Material names for sound and bullet impacts.
8. Lightmaps/PVS later.

Не делать карты “красивее” через современные dynamic props, если цель — CS 1.6 feel.

---

## 9. Implementation architecture for OpenStrike

### 9.1. Required modules

```text
src/game/player/
  cs16_movement_solver.gd
  cs16_duck_state.gd
  cs16_jump_state.gd
  cs16_surface_state.gd

src/core/physics/
  goldsrc_hull_trace.gd
  goldsrc_clip_velocity.gd
  goldsrc_step_solver.gd

src/game/weapons/
  cs16_weapon_accuracy_model.gd
  cs16_recoil_model.gd
  cs16_spread_model.gd
  weapon_runtime_state.gd

src/presentation/viewmodel/
  viewmodel_orchestrator.gd
  recoil_view_kick.gd
  weapon_bob_sway.gd

src/presentation/effects/
  muzzle_flash_effect.gd
  bullet_decal_effect.gd
  material_impact_effect.gd

src/core/net/
  usercmd.gd
  prediction_buffer.gd
  snapshot_reconciliation.gd
  lag_compensation_history.gd

src/dev/parity/
  movement_lab.tscn
  shooting_range.tscn
  wall_spray_lab.tscn
  net_prediction_lab.tscn
```

### 9.2. Data files

```text
data/config/movement/cs16.json
data/config/weapons/cs16_weapons.json
data/config/weapons/cs16_accuracy.json
data/config/weapons/cs16_recoil.json
data/config/surfaces/goldsrc_surface_materials.json
data/config/net/classic_cs16.json
data/config/feel/cs16_classic_profile.json
```

### 9.3. No direct asset dependency in gameplay

Gameplay sees:

```text
weapon_id
surface_type
material_id
animation_event_id
sound_event_id
effect_event_id
```

Gameplay must not know:

```text
models/v_ak47.mdl
sound/weapons/ak47-1.wav
sprites/muzzleflash1.spr
```

Asset resolution belongs to AssetManager / Provider / Presentation orchestration.

---

## 10. Acceptance criteria

### 10.1. Movement parity tests

#### Test M-001: Straight run

Setup:

```text
weapon_speed = 250
sim_tick_hz = 100
hold W
```

Expected:

```text
after steady state: horizontal speed = 250 ± epsilon
per tick: friction may reduce to 240 then acceleration restores to 250
```

#### Test M-002: W+A fastrun transient

Setup:

```text
run W at 250
press A
```

Expected:

```text
first frame speed ≈ 251.24
transient peak ≈ 262
peak duration around 14 frames
```

#### Test M-003: Air strafe first frame

Setup:

```text
run 250
jump
release W
press A
```

Expected:

```text
wishspd = 30
accelspeed = 25
final speed ≈ 251.25
```

#### Test M-004: Bhop FOG

Setup:

```text
simulate jump command distributions
```

Expected:

```text
holding jump does not perfect-bhop
scroll-like +jump/-jump can produce 1-2 FOG
1 FOG <= 300 speed avoids friction loss
speed > 300 triggers mega-bunny damping
```

#### Test M-005: Duck transition

Setup:

```text
press duck on ground
```

Expected:

```text
duck transition time = 0.4 sec / 40 ticks
movement command speed multiplier = 0.333
standing hull height = 72
duck hull height = 36
```

#### Test M-006: Scroll duck / double duck

Setup:

```text
send +duck;-duck
```

Expected:

```text
PM_UnDuck-like lift = 18 units
can climb/handle 18-35 unit obstacles according to legacy behavior
```

#### Test M-007: Edgefriction

Setup:

```text
run toward edge
```

Expected:

```text
forward/down trace detects edge
friction multiplied by edgefriction=2
highjump/countjump behavior becomes possible
```

#### Test M-008: Step handling

Setup:

```text
walk against 18-unit step
walk against 19+ unit obstacle
```

Expected:

```text
18 units step is walkable
higher obstacles require jump/duck tricks depending exact height
```

### 10.2. Weapon parity tests

#### Test W-001: First shot

For AK/M4/USP/Deagle:

```text
standing still first shot
crouched first shot
walking first shot
jumping first shot
```

Expected:

```text
standing/crouched first shot follows CS16 profile
movement/jump penalties are obvious
```

#### Test W-002: Burst recovery

Setup:

```text
fire 1 shot
wait variable delay
fire again
repeat for 2-3 shot bursts
```

Expected:

```text
tap/burst rhythm is viable
recovery feels faster than CS:GO-style long spray reset
```

#### Test W-003: Spray wall

Setup:

```text
full auto spray at wall
standing and crouched
```

Expected:

```text
standing spray opens heavily
crouch spray changes distribution
decal pattern readable at 4:3 resolution
```

#### Test W-004: Accuracy quirk mode

Setup:

```text
compare strict_legacy and fixed_modern
```

Expected:

```text
strict_legacy preserves confirmed CS16 quirks
fixed_modern fixes only behind explicit cvar/profile
```

### 10.3. Network feel tests

#### Test N-001: Local input latency

Expected:

```text
movement feedback visible same rendered frame or next frame
shot feedback immediate
server correction not noticeable in local mode
```

#### Test N-002: Prediction error

Expected:

```text
cl_showerror-style debug shows prediction deltas
corrections are visible in debug, not hidden
```

#### Test N-003: Artificial ping

Setup:

```text
simulate 30/60/100 ms ping
```

Expected:

```text
local player remains responsive
remote player interpolation readable
hitscan uses lag compensation history
```

### 10.4. Presentation tests

#### Test P-001: Viewmodel

Expected:

```text
viewmodel on own layer/camera
not physically clipped like world model
bob/sway/recoil separated from gameplay aim
```

#### Test P-002: Impact feedback

Expected:

```text
muzzle flash, shot sound, view punch, crosshair expansion, impact decal occur immediately
```

#### Test P-003: Footsteps

Expected:

```text
material-based footstep sounds
no generic single footstep for all surfaces
```

---

## 11. Anti-goals

Do not do this:

* Do not use Godot default CharacterBody movement as final CS16 controller.
* Do not use capsule-only physics as final player collision.
* Do not smooth movement until fastrun/bhop/edgefriction disappear.
* Do not implement CS:GO fixed spray as CS 1.6 recoil.
* Do not make crouch purely visual.
* Do not wait for animation event to apply damage.
* Do not make decals too small/realistic.
* Do not hide net/interp problems without diagnostics.
* Do not improve classic mode silently. Improvements must be explicit profile/cvar.

---

## 12. Immediate backlog

### TASK-FEEL-001 — CS16 movement solver

Implement fixed 100 Hz movement solver with:

* friction;
* accelerate;
* airaccelerate;
* wishspeed cap;
* jump edge behavior;
* duck state;
* edgefriction;
* telemetry.

### TASK-FEEL-002 — GoldSrc hull trace

Implement:

* stand/duck hull;
* plane clip;
* step solver;
* slope/floor/wall flags;
* trace debug overlay.

### TASK-FEEL-003 — Movement parity lab

Create dev scene that records:

* speed per tick;
* ground/air state;
* FOG;
* duck timer;
* edgefriction trigger;
* command input;
* wishdir/wishspeed/current speed.

### TASK-FEEL-004 — CS16 weapon accuracy model

Implement data-driven per-weapon model:

* shots fired;
* spread;
* recoil;
* accuracy recovery;
* stance/movement modifiers;
* strict legacy quirk flag.

### TASK-FEEL-005 — Wall spray lab

Create wall target range:

* fixed distance;
* controlled seeds;
* decal capture;
* CSV export;
* standing/crouch/move/jump comparison.

### TASK-FEEL-006 — Feedback path

Wire immediate feedback:

* shot accepted;
* audio;
* muzzle flash;
* view punch;
* crosshair;
* decal;
* hit effect.

### TASK-FEEL-007 — Prediction diagnostics

Implement:

* usercmd buffer;
* local prediction;
* authoritative snapshot;
* replay unacked commands;
* prediction error overlay.

---

## 13. Definition of Done for “CS 1.6 feel”

OpenStrike may claim CS 1.6 feel only when:

1. Movement tests M-001 to M-008 pass.
2. Weapon tests W-001 to W-004 pass for AK/M4/USP/Deagle at minimum.
3. Local input/shot feedback feels immediate under N-001.
4. Prediction diagnostics exist and can show errors.
5. BSP map collision uses hull-like behavior, not only generic capsule.
6. Viewmodel, sound, muzzle flash and decals are presentation-only, driven by gameplay events.
7. Classic mode is separate from modern/fixed mode.
8. All relevant constants are cvars/configs, not hidden magic numbers.

### Ключевые основания под документ

Самое сильное техническое основание по movement — KZ-Rush: там разложены GoldSrc/HL movement-файлы, 100 FPS обработка input, ground friction/accelerate порядок, fastrun, airaccelerate и wishspeed cap 30. Эти материалы прямо подтверждают необходимость 100 Hz parity solver, а не обычного Godot-контроллера. ([KZ-Rush - International Kreedz Community][2])

Bhop, duck/double-duck и edgefriction — не “фановые баги сбоку”, а часть того, почему 1.6 ощущается живой: scroll jump минимизирует FOG, 1 FOG может избежать ground friction, mega-bunny cap режет скорость выше 300 при knife/USP maxspeed 250; ground duck длится 0.4 сек, duck multiplier равен 0.333, а edgefriction по умолчанию удваивает friction у края. ([KZ-Rush - International Kreedz Community][3])

По cvars есть важная правка к текущим черновикам OpenStrike: для CS 1.6 `sv_accelerate` нужно брать как `5`, `sv_airaccelerate=10`, `sv_friction=4`, `sv_gravity=800`, `sv_stepsize=18`, `sv_stopspeed=75`, `sv_maxvelocity=2000`, `sv_maxspeed=320`; в этом cvar list также отдельно указано, что `sv_clienttrace=1` относится к collision bounding box, а не bullet hitbox. ([txdv.github.io][4])

По оружию форумные данные менее формальны, но картина стабильная: игроки описывают 1.6 как semi-random/multiple-pattern recoil, где stance, crouch, movement и burst timing важнее, чем CS:GO-style fixed spray table. Поэтому для OpenStrike нужен weapon accuracy lab и legacy profile, а не перенос современного CS:GO-подхода. ([Reddit][5])

По net feel опорная архитектурная идея — shared prediction: в Half-Life расхождения между клиентом и сервером минимизировались за счёт одинаковой movement logic на client/server, а клиент переигрывает неподтверждённые команды для responsiveness. Это ложится в уже выбранную для OpenStrike server-authoritative модель: input → usercmd → local prediction → server snapshot → reconciliation. ([developer.valvesoftware.com][6])

[1]: https://github.com/ValveSoftware/halflife/blob/master/LICENSE "halflife/LICENSE at master · ValveSoftware/halflife · GitHub"
[2]: https://kz-rush.ru/en/page/strafe-physics "Strafe Physics"
[3]: https://kz-rush.ru/en/page/bhop-physics "Bhop Physics"
[4]: https://txdv.github.io/cstrike-cvarlist/ "Counter Strike 1.6 CVar list"
[5]: https://www.reddit.com/r/GlobalOffensive/comments/1ypve8/why_reduced_recoil_spread_when_crouching_was_so/ "Why reduced recoil spread when crouching was SO important in CSS/1.6 : r/GlobalOffensive"
[6]: https://developer.valvesoftware.com/wiki/Latency_Compensating_Methods_in_Client/Server_In-game_Protocol_Design_and_Optimization?utm_source=chatgpt.com "Server In-game Protocol Design and Optimization"
