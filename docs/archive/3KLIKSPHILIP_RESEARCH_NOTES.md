# 3kliksphilip Research Notes for OpenStrike

Статус: рабочий документ для команды
Назначение: определить, какие материалы и подходы 3kliksphilip полезны для OpenStrike, и перевести их в инженерные задачи, dev-labs и acceptance criteria.

OpenStrike integration note: this document is the full research note. The
operational source catalog lives in `docs/SOURCE_CATALOG.md`, dev-lab rules
live in `docs/DEV_LABS_METHODOLOGY.md`, and the current knowledge-base index
lives in `docs/KNOWLEDGE_BASE.md`.

---

## 1. Короткий вывод

3kliksphilip полезен для OpenStrike не потому, что он даёт готовые формулы GoldSrc, а потому что он много лет делает правильную для нас вещь: превращает спор игроков “оно не так чувствуется” в проверяемый эксперимент.

Для OpenStrike нужно забрать три вещи:

1. Метод исследования:

   * изолированная тестовая сцена;
   * один изменяемый параметр;
   * визуализация невидимого состояния движка;
   * сравнение старой/новой версии;
   * вывод в виде “что игрок реально увидит и почувствует”.

2. Темы, которые он регулярно разбирает:

   * tickrate / subtick / input latency;
   * hitboxes and hit registration;
   * movement differences;
   * accuracy / recoil / spread changes;
   * animation graph and gameplay readability;
   * map entities, buyzones, bombzones, hostages;
   * lighting, cubemaps, reflections, skyboxes;
   * map scale, VIS, compile/runtime optimization;
   * HUD and viewmodel render cost.

3. Формат для OpenStrike:

   * не верить “на глаз”;
   * делать parity-labs;
   * фиксировать результат в telemetry;
   * каждую спорную механику снабжать debug overlay.

---

## 2. Как классифицировать его материалы

### 2.1. High value для OpenStrike

Эти материалы нужно занести в `docs/SOURCE_CATALOG.md` как community-engineering references:

* CS:GO 64 vs 128 tick.
* CS2 input latency testing.
* Further CS2 input latency testing.
* CS:GO movement comparison old vs new.
* Can CS:GO learn anything from CS 1.6?
* CS:GO hitboxes while jumping.
* CS:GO hitboxes while planting.
* CS:GO T / CT hitbox comparisons.
* Do CS:GO models match their hitboxes?
* CS:GO major accuracy update analysed.
* How much does CS2's HUD slow you down?
* CS2 Animgraph 2 isn't perfect.
* Source SDK / Hammer mapping tutorials.
* Map design: lighting.
* Map design: reflections.
* Map design: 2D and 3D skyboxes.
* CS2 / Source 2 map analyses and optimized map videos.

### 2.2. Medium value

Использовать как UX/product references, но не как parity source:

* CS:GO review / competitive matchmaking arguments.
* Source 2 speculation / Source 2 transition videos.
* CS2 map visual comparison videos.
* community map history / workshop videos.

### 2.3. Low value для core parity

Не использовать как основу движка:

* экономика скинов;
* esports drama;
* кейсы;
* speculative videos без технического эксперимента;
* развлекательные истории без измерений.

---

## 3. Главный урок: OpenStrike нужен не только gameplay-код, но и исследовательская лаборатория

Для CS-like проекта нельзя ограничиться обычными unit tests. Нужны dev-labs, которые позволяют увидеть то, что игрок чувствует, но не может объяснить.

Добавить в `src/dev/labs/`:

```text
src/dev/labs/
  movement_lab/
  hitbox_lab/
  hitreg_lab/
  input_latency_lab/
  tickrate_lab/
  shooting_accuracy_lab/
  wall_spray_lab/
  map_entities_lab/
  bsp_visibility_lab/
  lighting_lab/
  hud_cost_lab/
  viewmodel_cost_lab/
  animation_readability_lab/
```

Каждая лаборатория должна иметь:

```text
- controlled setup
- repeatable command script
- on-screen debug overlay
- CSV/JSON telemetry export
- screenshot/video capture points
- reference notes
- acceptance criteria
```

---

## 4. Tickrate, subtick, latency

### 4.1. Что взять у 3kliksphilip

Его материалы по 64/128 tick и CS2 input latency показывают правильный подход: тикрейт, визуальный фидбек и latency надо измерять отдельно. Игрок может говорить “hitreg плохой”, но причина может быть в другом:

```text
- input sampling
- simulation tick
- command queue
- render frame pacing
- interpolation
- prediction correction
- hitbox pose mismatch
- animation feedback delay
- network latency
- display latency
```

### 4.2. Что это значит для OpenStrike

OpenStrike должен с первого дня иметь `InputLatencyLab`.

Минимальная схема измерения:

```text
hardware/input event
  -> Godot input timestamp
  -> usercmd generated
  -> local prediction tick
  -> server tick accepted
  -> snapshot produced
  -> presentation event emitted
  -> rendered frame displayed
```

Внутри движка логировать:

```json
{
  "frame_id": 18291,
  "input_event_time": 12.340,
  "usercmd_id": 9182,
  "client_prediction_tick": 9182,
  "server_tick": 9182,
  "snapshot_id": 9182,
  "presentation_event": "weapon.fire.feedback",
  "render_frame_time": 12.351,
  "estimated_input_to_feedback_ms": 11.0
}
```

### 4.3. Не брать напрямую

Не нужно копировать CS2 subtick как решение. Для OpenStrike classic parity важнее GoldSrc-like fixed tick / usercmd model. Subtick можно изучать как предупреждение: если визуальный фидбек и gameplay-time расходятся, игроки воспринимают это как “игра не регистрирует”.

### 4.4. Acceptance criteria

```text
LAT-001:
  В local mode выстрел должен давать audio/viewpunch/crosshair feedback в тот же rendered frame или следующий.

LAT-002:
  Debug overlay должен показывать input -> usercmd -> server tick -> presentation path.

LAT-003:
  При искусственной задержке 30/60/100 ms local player должен оставаться responsive через prediction.

LAT-004:
  Любая interpolation/correction должна быть видна в debug mode, а не скрыта.
```

---

## 5. Hitboxes, hit registration, model mismatch

### 5.1. Что взять у 3kliksphilip

Его hitbox-видео важны потому, что показывают: модель, клиентская поза, серверная хитбокс-поза и то, куда игрок “думает, что стреляет”, могут различаться. Это особенно критично при:

```text
- прыжке;
- plant/defuse poses;
- ladder poses;
- crouch/uncrouch;
- animation transitions;
- lag compensation;
- interpolation;
- модельных различиях T/CT.
```

### 5.2. Что это значит для OpenStrike

В OpenStrike нельзя делать “красивая модель = хитбокс”. Нужны отдельные слои:

```text
render_model
  визуальная модель игрока

animation_pose
  то, как игрок выглядит на клиенте

server_hitboxes
  то, что реально принимает damage

client_predicted_hitboxes
  то, что клиент может показать для debug

lag_compensated_hitboxes
  то, что сервер использует при rewind
```

### 5.3. Обязательный debug overlay

Добавить `cl_showimpacts_openstrike`:

```text
0 = off
1 = show bullet traces
2 = show client predicted hitboxes
3 = show server authoritative hitboxes
4 = show lag-compensated rewind hitboxes
5 = show all
```

Цветовая схема:

```text
blue   = server authoritative
red    = client predicted
yellow = lag compensated rewind
green  = actual accepted hit
white  = rejected trace
```

### 5.4. Acceptance criteria

```text
HITBOX-001:
  В hitbox_lab при прыжке видны отдельно render model и server hitbox.

HITBOX-002:
  При plant/defuse/crouch animation gameplay hitbox не зависит слепо от visual skeleton.

HITBOX-003:
  В local deterministic replay можно восстановить, почему выстрел hit или miss.

HITBOX-004:
  Для каждого player model есть validation: визуальный силуэт не должен грубо обманывать hitbox.
```

---

## 6. Movement differences

### 6.1. Что взять у 3kliksphilip

Видео “movement comparison old vs new” и обсуждения “Can CS:GO learn anything from CS 1.6?” полезны как сигнал: игроки очень остро чувствуют не только максимальную скорость, но и:

```text
- как быстро игрок ускоряется;
- как быстро он тормозит;
- как работает counter-strafe;
- как ведёт себя прыжок;
- насколько предсказуемы crouch/jump/ladders;
- как часто игрок цепляется за ступеньки/края;
- насколько “пластиковым” кажется изменение velocity.
```

### 6.2. Что это значит для OpenStrike

OpenStrike должен проверять не только `maxspeed`, но и кривые скорости по тик-трейсу.

Логировать каждый tick:

```json
{
  "tick": 1221,
  "cmd": "+forward +moveleft",
  "grounded": true,
  "ducked": false,
  "wishspeed": 250.0,
  "velocity_before": [250.0, 0.0, 0.0],
  "velocity_after_friction": [240.0, 0.0, 0.0],
  "velocity_after_accel": [251.2, 3.1, 0.0],
  "surface_friction": 1.0,
  "edgefriction": false
}
```

### 6.3. Movement labs

Добавить сценарии:

```text
MVT-001 straight acceleration curve
MVT-002 stop curve
MVT-003 counter-strafe stop time
MVT-004 W+A fastrun transient
MVT-005 air-strafe gain
MVT-006 bhop 1 FOG / 2 FOG
MVT-007 crouch / uncrouch transition
MVT-008 ladder movement
MVT-009 18-unit step
MVT-010 ramp and slope edge cases
```

### 6.4. Acceptance criteria

```text
MVT-ACCEPT:
  Команда не принимает movement PR без графика speed-over-time и tick telemetry.

MVT-ACCEPT:
  Любая правка movement должна иметь before/after CSV.

MVT-ACCEPT:
  “Feels better” не является аргументом без telemetry и test scene.
```

---

## 7. Accuracy, recoil, spread

### 7.1. Что взять у 3kliksphilip

Материал про major accuracy update полезен как пример: изменение accuracy надо оценивать не по описанию патча, а через стенд:

```text
- fixed distance;
- fixed weapon;
- fixed stance;
- fixed fire rhythm;
- controlled random seed;
- visible bullet impacts;
- before/after comparison.
```

### 7.2. Что это значит для OpenStrike

Нужен `shooting_accuracy_lab` и `wall_spray_lab`.

Сценарии:

```text
ACC-001 first bullet standing
ACC-002 first bullet crouched
ACC-003 first bullet walking
ACC-004 first bullet airborne
ACC-005 2-shot burst
ACC-006 3-shot burst
ACC-007 full spray standing
ACC-008 full spray crouched
ACC-009 recovery after 100/200/300/500/1000 ms
ACC-010 weapon switch / reload accuracy reset quirks
```

### 7.3. Данные

Для каждого выстрела:

```json
{
  "shot_index": 4,
  "weapon": "ak47",
  "stance": "standing",
  "moving": false,
  "airborne": false,
  "time_since_last_shot": 0.098,
  "recoil_index": 4,
  "spread_x": 0.018,
  "spread_y": -0.011,
  "impact_position": [12.0, 4.0, 0.0],
  "seed": 12345
}
```

### 7.4. Acceptance criteria

```text
ACC-ACCEPT:
  AK/M4/USP/Deagle не принимаются без wall-spray image diff.

ACC-ACCEPT:
  Classic mode не должен незаметно использовать CS:GO fixed spray pattern.

ACC-ACCEPT:
  Recoil/spread должны быть data-driven и reproducible через seed.
```

---

## 8. Mapping: test maps, entity semantics, leaks

### 8.1. Что взять у 3kliksphilip

Его Steam mapping guide хорош не как tutorial для OpenStrike-мэпперов, а как компактная спецификация минимальной playable CS-карты:

```text
- sealed/hollow world to avoid leaks;
- spawn point for each team;
- lighting entity;
- buyzone;
- bomb target;
- hostage entity;
- hostage rescue zone;
- overlays/signage;
- bot navmesh generation in CS:GO.
```

### 8.2. Что это значит для OpenStrike

Для OpenStrike надо сделать набор собственных fixture maps, без ассетов Valve:

```text
fixtures/maps/os_entity_minimal/
fixtures/maps/os_buyzone_test/
fixtures/maps/os_bombsite_test/
fixtures/maps/os_hostage_test/
fixtures/maps/os_leak_test/
fixtures/maps/os_step_height_test/
fixtures/maps/os_skybox_test/
fixtures/maps/os_lightmap_test/
fixtures/maps/os_material_footstep_test/
```

Каждая карта должна проверять один аспект.

### 8.3. Entity adapters

Минимальные adapters:

```text
info_player_start
info_player_deathmatch
info_player_terrorist
info_player_counterterrorist
func_buyzone
func_bomb_target
info_bomb_target
hostage_entity
func_hostage_rescue
light
light_environment
env_sprite
func_door
func_button
trigger_multiple
```

### 8.4. Acceptance criteria

```text
MAP-001:
  MapEntitiesLab показывает count по classname.

MAP-002:
  Buyzone/bombsite/rescue zone показываются debug-volume overlay.

MAP-003:
  Unknown entity не ломает карту, а сохраняется как metadata.

MAP-004:
  На fixture-карте можно пройти round bootstrap: spawn -> buyzone -> objective metadata.
```

---

## 9. Lighting, reflections, cubemaps, skyboxes

### 9.1. Что взять у 3kliksphilip

Его lighting/reflection/skybox материалы важны как design discipline:

```text
- lighting affects readability;
- sunlight direction важнее позиции light_environment;
- baked lightmaps и realtime lighting могут давать разный вид на расстоянии;
- cubemap/reflection placement влияет на внезапные изменения отражений;
- 3D skybox уменьшает playable area и помогает VIS/performance;
- distant scenery не должна быть частью playable collision.
```

### 9.2. Что применимо к CS 1.6

Для CS 1.6 / GoldSrc нельзя напрямую переносить Source cubemap pipeline. Но применимы принципы:

```text
- отделить playable BSP geometry от distant background;
- не превращать skybox/distant scenery в collision;
- lightmap fidelity важна для classic look;
- visibility/PVS matters;
- texture/material metadata должна сохраняться;
- debug view нужен для lightmap density / missing textures.
```

### 9.3. OpenStrike modules

```text
src/core/bsp/lightmap_loader.gd
src/core/bsp/visibility_pvs.gd
src/presentation/maps/skybox_renderer.gd
src/dev/labs/lighting_lab/
src/dev/labs/pvs_lab/
```

### 9.4. Acceptance criteria

```text
LIGHT-001:
  BSP lightmaps загружаются отдельно от albedo texture.

LIGHT-002:
  Missing lightmap/debug mode clearly visible.

LIGHT-003:
  Sky/background geometry не участвует в player hull collision.

LIGHT-004:
  PVS/visibility debug показывает active leaf/visible leaves.
```

---

## 10. Map optimization and performance

### 10.1. Что взять у 3kliksphilip

Его материалы про map limits, optimized maps, skyboxes и VIS подводят к одному правилу: карта — это не просто mesh. Для CS-like feel важна стабильность frametime.

### 10.2. OpenStrike performance budget

Ввести budgets:

```text
classic target:
  100 Hz game simulation stable
  no frame spikes from HUD
  no frame spikes from viewmodel
  no runtime BSP conversion during match
  map import/cache happens before match start
  effect pools for muzzle flashes/shells/decals/audio
```

### 10.3. Profiling overlays

```text
os_perf_graph 1:
  frame time
  game tick time
  physics trace count
  active decals
  active sounds
  active particles
  HUD draw cost
  viewmodel draw cost
  BSP visible surface count
```

### 10.4. Acceptance criteria

```text
PERF-001:
  HUD and viewmodel have separate profiler counters.

PERF-002:
  Shooting full-auto for 30 seconds does not allocate/free per shot in hot path.

PERF-003:
  BSP map import/cache never runs during live round.

PERF-004:
  Dev overlay can show worst 1% frame time.
```

---

## 11. HUD and viewmodel cost

### 11.1. Что взять у 3kliksphilip

Материал про HUD slowdown полезен как напоминание: UI и viewmodel не “бесплатны”. Даже если HUD выглядит простым, он может съедать performance или давать frametime spikes.

### 11.2. OpenStrike policy

```text
HUD is presentation only.
HUD must not query gameplay state directly from random nodes.
HUD receives snapshots/events.
HUD sprite atlas must be cached.
HUD layout must avoid per-frame asset lookup.
Viewmodel must be on separate layer/camera/subviewport only if measured acceptable.
```

### 11.3. Acceptance criteria

```text
HUD-001:
  No file loads from HUD draw path.

HUD-002:
  HUD profiler shows draw calls / nodes / frame cost.

HUD-003:
  Classic HUD has 640x480 bucket layout but scales cleanly.

HUD-004:
  Procedural/debug HUD remains dev-only.
```

---

## 12. Animation and gameplay readability

### 12.1. Что взять у 3kliksphilip

Материалы про Animgraph полезны как предупреждение: анимация может улучшить внешний вид, но сломать читаемость gameplay, если:

```text
- ноги/корпус показывают не тот motion state;
- grenade/ladder/jump pose расходится с hitboxes;
- ramp/height transitions выглядят иначе, чем collision state;
- animation blending скрывает реальное начало/конец действия.
```

### 12.2. OpenStrike policy

```text
Gameplay state is authoritative.
Animation follows gameplay.
Animation never owns hit/damage timing, except explicitly configured melee windows.
Hitboxes are gameplay objects, not render skeleton by default.
```

### 12.3. Acceptance criteria

```text
ANIM-001:
  Прыжок, crouch, ladder, reload и plant имеют отдельный gameplay-state debug label.

ANIM-002:
  Animation pose mismatch can be visualized.

ANIM-003:
  Для каждого player action есть event timing table.

ANIM-004:
  Viewmodel animation не наносит damage; damage event приходит из server weapon state.
```

---

## 13. What to add to SOURCE_CATALOG.md

Добавить группу источников:

```markdown
## 3kliksphilip / Counter-Strike engine analysis

Type:
  community engineering / educational / experimental analysis

Use for:
  - test methodology
  - movement/hitbox/latency symptom catalog
  - mapping and Source/Hammer concepts
  - performance and readability concerns
  - UI/HUD/viewmodel cost awareness

Do not use for:
  - copying code
  - treating CS:GO/CS2 values as CS 1.6 values
  - replacing GoldSrc references
  - legal or asset redistribution assumptions

Important materials:
  - CS:GO - 64 VS 128 Tick
  - CS:GO Movement Comparison - New VS Old
  - Can CS:GO learn anything from CS 1.6?
  - CS GO Hitboxes while jumping
  - CS GO Hitboxes while planting
  - CS:GO T Hitboxes Compared
  - CS:GO CT Hitboxes Compared
  - CS:GO's Major Accuracy Update Analysed
  - CS2's Input Latency
  - Further CS2 Input Latency Testing
  - How Much Does CS2's HUD Slow You Down?
  - CS2's Animgraph 2 isn't Perfect
  - Making your first CSGO map using the SDK
  - Map design - Lighting
  - Map design - Reflections
  - Map design - 2D and 3D skyboxes
```

---

## 14. Immediate tasks for OpenStrike

### TASK-3K-001 — Add 3kliksphilip source catalog entry

Files:

```text
docs/SOURCE_CATALOG.md
docs/3KLIKSPHILIP_RESEARCH_NOTES.md
```

Acceptance:

```text
- source classification added
- use/do-not-use rules added
- links grouped by topic
- no claims treated as primary source without verification
```

### TASK-3K-002 — Create dev-lab methodology document

Files:

```text
docs/DEV_LABS_METHODOLOGY.md
```

Acceptance:

```text
- every lab has controlled setup / variable / telemetry / screenshot capture
- every “feel” claim must map to a lab
```

### TASK-3K-003 — Build HitboxLab

Files:

```text
src/dev/labs/hitbox_lab/*
src/game/player/hitbox_debug_overlay.gd
```

Acceptance:

```text
- render model vs server hitbox can be displayed separately
- jump/crouch/plant/reload pose tests exist
- bullet trace result is explainable
```

### TASK-3K-004 — Build InputLatencyLab

Files:

```text
src/dev/labs/input_latency_lab/*
src/core/net/usercmd.gd
src/core/net/prediction_debug.gd
```

Acceptance:

```text
- input-to-feedback timeline is logged
- local fire feedback timestamped
- artificial ping/loss can be simulated
```

### TASK-3K-005 — Build MapEntityFixturePack

Files:

```text
tests/fixtures/maps/*
src/dev/labs/map_entities_lab/*
```

Acceptance:

```text
- own fixture maps contain spawns, buyzones, bombzones, hostages/rescue zones
- no Valve assets
- entity-lump parser tested
```

### TASK-3K-006 — Build HudCostLab

Files:

```text
src/dev/labs/hud_cost_lab/*
src/presentation/hud/hud_profiler.gd
```

Acceptance:

```text
- HUD draw cost measurable
- viewmodel cost separately measurable
- no per-frame asset loads
```

---

## 15. Итоговая позиция

3kliksphilip не заменяет HLSDK, GoldSrc references, Xash3D, ReHLDS/ReGameDLL или прямые CS 1.6 измерения. Его роль другая: он показывает, как правильно исследовать Counter-Strike как движковую систему.

Для OpenStrike его главный вклад — дисциплина:

```text
не спорить о feel,
а строить маленькую лабораторию,
визуализировать невидимый state,
измерять,
сравнивать,
фиксировать acceptance criteria.
```

Если команда примет этот подход, OpenStrike будет меньше зависеть от вкусовщины и больше — от проверяемой совместимости.

### Что конкретно уже можно забрать

Из Steam-гайда 3kliksphilip по мэппингу можно прямо вынести минимальный набор entity-tests: sealed/hollow map, минимум один spawn на команду, `info_player_counterterrorist`, `FUNC_BUYZONE`, `FUNC_BOMB_TARGET`, `HOSTAGE_ENTITY`, `FUNC_HOSTAGE_RESCUE`, а также проверку bot/nav metadata как отдельный слой. Это хорошо ложится на наш план `0.4.0`: entity-lump, team spawns, buy zones, bomb targets, rescue zones и debug overlay. ([Steam Community][2])

По картам и визуалу: его гайды по lighting/reflections/skyboxes стоит использовать не как прямой Source→GoldSrc перенос, а как принципы: свет и фон должны помогать читаемости, distant scenery не должна становиться игровой collision-геометрией, а visibility/compile/runtime cost нужно учитывать заранее. В гайде по 3D skybox он прямо объясняет, что 3D skybox уменьшает playable area, помогает VIS/оптимизации и позволяет делать дальние объекты вне игровой зоны; для OpenStrike это аргумент в пользу разделения playable BSP, sky/background layer и PVS/debug tooling. ([Steam Community][3])

По feel/movement: материалы “CS:GO Movement Comparison — New VS Old” и “Can CS:GO learn anything from CS 1.6?” надо добавить в source catalog как symptom references. Они не дают нам точные формулы GoldSrc, но помогают формализовать вопросы: скорость ускорения, торможение, counter-strafe, прыжки, crouch/ladders и “smoothness” должны проверяться tick-telemetry, а не на глаз. ([YouTube][4])

По hitreg: его hitbox-видео и обсуждения вокруг них подтверждают необходимость `showimpacts`-подобного overlay: отдельно рисовать render model, client-predicted hitboxes, server-authoritative hitboxes и lag-compensated rewind. Особенно это важно для прыжков, plant/defuse poses и любых animation transitions. ([YouTube][5])

По latency/performance: его CS2 input-latency тесты и HUD-cost видео надо использовать как требования к инструментам: OpenStrike должен уметь измерять input→usercmd→server tick→presentation→render feedback, а HUD/viewmodel должны иметь отдельные profiler counters. Valve в своём официальном CS2 FAQ тоже подчёркивает, что frame pacing, V-Sync/G-Sync/Reflex и latency — это не “магия настроек”, а часть воспринимаемой отзывчивости, значит в OpenStrike надо иметь режимы и диагностику, а не просто “выключить vsync и забыть”. ([YouTube][6])

И главный architectural guardrail остаётся прежним: 3kliksphilip — reference для методологии и симптомов, но не замена нашему legal/architecture baseline. OpenStrike должен брать поведенческие контракты, тестовые идеи и исследовательский подход, а не чужой код/ассеты; существующий план уже фиксирует, что Xash3D/HLSDK и старые движки читаются как справочники, а не копируются, и что compatibility foundation важнее бинарной совместимости.

[1]: https://www.youtube.com/channel/UCmu9PVIZBk-ZCi-Sk2F2utA?utm_source=chatgpt.com "3kliksphilip"
[2]: https://steamcommunity.com/sharedfiles/filedetails/?id=165009177 "Steam Community :: Guide :: Making your first CSGO map using the SDK"
[3]: https://steamcommunity.com/sharedfiles/filedetails/?id=170357805 "Steam Community :: Guide :: Map design - Lighting"
[4]: https://www.youtube.com/watch?v=5J0yRhNP2v4&utm_source=chatgpt.com "CS:GO Movement Comparison - New VS Old"
[5]: https://www.youtube.com/watch?v=snZqkGJQ3qM&utm_source=chatgpt.com "CS GO Hitboxes while jumping"
[6]: https://www.youtube.com/watch?v=NE0qg_8k0BE&utm_source=chatgpt.com "CS2's Input Latency"
