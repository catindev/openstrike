Ниже — инженерный план, а не юридическое заключение. Практическая цель: построить **clean-room open-source FPS client/engine**, совместимый с пользовательскими локальными ресурсами форматов GoldSrc, но без копирования и распространения оригинального кода, ассетов, брендинга, UI, таблиц баланса и сетевых протоколов.

## 1. Краткое описание цели проекта

Мы строим современный игровой клиент/движок для macOS, `OpenStrike`, который:

* запускается нативно на Apple Silicon и Intel Mac;
* рендерит карты BSP эпохи GoldSrc;
* читает локальные WAD/MDL/SPR/WAV и другие поддержанные файлы, которые пользователь сам указывает через путь к установленной копии;
* реализует собственную физику, движение, оружейную систему, game rules, AI и UI;
* изначально работает как single-player sandbox / local match;
* позже расширяется до собственного multiplayer слоя, не совместимого с официальными серверами и не использующего протоколы Valve.

Юридическая граница: в репозитории и релизах нет оригинальных ассетов, оригинального кода, оригинального брендинга, логотипов, названий оружия/команд/интерфейса, decompiled code, leaked code, Steam/DRM обходов или античит-интеграций. Использование оригинальных файлов допускается только как **локальный ввод пользователя**, аналогично тому, как медиа-плеер открывает локальный файл. В README нужно прямо указать, что проект не связан с Valve, не распространяет игровые данные и требует, чтобы пользователь сам обладал правами на используемые файлы.

На macOS основной renderer лучше проектировать не вокруг OpenGL: Apple прямо позиционирует OpenGL как deprecated и рекомендует Metal; SDL3 предоставляет кроссплатформенный доступ к Metal/Vulkan/OpenGL/Direct3D, а bgfx и MoltenVK дают практичные пути к современным backend’ам на macOS. ([Apple Developer][1])

---

## 2. Границы совместимости

### Обязательно для MVP

MVP должен доказать, что архитектура жизнеспособна:

| Область              | MVP-объём                                                                                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| macOS                | Нативный запуск на arm64 и x86_64, window loop, input, app bundle.                                                                                                 |
| Renderer             | Современный backend: Metal через bgfx/wgpu/SDL3 GPU или Vulkan через MoltenVK. OpenGL — только временный fallback/debug.                                           |
| Resource path        | Пользователь выбирает локальную папку с установленными ресурсами. Репозиторий не содержит proprietary assets.                                                      |
| VFS/resource manager | Read-only mount пользовательской директории, поиск файлов, проверка сигнатур, безопасное чтение binary formats.                                                    |
| BSP                  | Чтение BSP v30-подобных GoldSrc maps: entities, planes, vertices, edges, surfedges, faces, texinfo, lighting, visibility, clipnodes, leaves, marksurfaces, models. |
| Geometry             | Отрисовка world geometry без моделей-entity на первом этапе.                                                                                                       |
| WAD/Miptex           | Загрузка 8-bit indexed textures, palette conversion в RGBA, basic transparency.                                                                                    |
| Lightmaps            | Отображение lightmap lump, lightmap atlas, fallback на flat lighting.                                                                                              |
| Collision            | Trace по BSP collision hulls / clipnodes, standing/crouch hull, wall/floor detection.                                                                              |
| Player movement      | Ходьба, прыжок, air movement, crouch, stairs/step movement, basic ladder support.                                                                                  |
| Game loop            | Локальный sandbox с spawn point, player controller, debug weapon raycast.                                                                                          |
| UI                   | Собственный debug HUD и меню выбора resource path/map.                                                                                                             |
| Legal hygiene        | README disclaimer, `.gitignore`/CI-проверки против случайного добавления proprietary files.                                                                        |

GoldSrc BSP и связанные форматы действительно состоят из отдельных lumps; для BSP v30-подобной поддержки критичны lumps вроде entities, planes, textures, vertices, visibility, nodes, texinfo, faces, lighting, clipnodes, leaves, edges/surfedges и models. WAD3 хранит header, texture array с mipmaps/palette и lump list; SPR хранит sprite header, palette и frames. ([abit.g6.cz][2])

### Желательно для первой полноценной версии

| Область         | V1-объём                                                                                                                                      |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Renderer        | PVS culling, frustum culling, batching по material/lightmap, transparent surfaces, animated texture semantics, sky replacement.               |
| Models          | MDL v10-compatible loader: skeleton, sequences, skins, hitboxes, attachment points, basic animation blending.                                 |
| Sprites         | SPR world sprites, additive/alpha render modes, animated frames.                                                                              |
| Audio           | WAV playback, spatial audio, sound channels, attenuation, ambient entities.                                                                   |
| Entity system   | Поддержка базовых world/entity behaviours: spawn points, triggers, ladders, doors, breakables-заглушки, pickups с оригинальными-free именами. |
| Weapons         | Data-driven оружие с generic identifiers, hitscan/projectile modes, recoil/spread, reload, ammo, damage events.                               |
| Hitboxes/damage | Собственные damage groups, loaded model hitboxes если пользовательский MDL их содержит, но без proprietary balance tables.                    |
| Game rules      | Local deathmatch, team-like mode с оригинальными названиями, round timer, score, respawn rules, economy prototype без копирования оригинала.  |
| Bots            | Waypoint-based bots, trace visibility, A*, steering, aim controller.                                                                          |
| Tools           | BSP/WAD/MDL/SPR inspectors, collision visualizer, lightmap viewer, PVS debugger.                                                              |
| Packaging       | Signed/notarized `.app`/`.dmg` для внешней дистрибуции.                                                                                       |

Формат MDL GoldSrc используется для анимированных моделей, а SPR — для 2D sprite-файлов GoldSrc; поэтому их стоит поддерживать как отдельные read-only asset loaders, а не как часть renderer’а. ([Valve Developer Community][3])

### Необязательно или рискованно

Не включать в MVP и, скорее всего, не делать вообще:

* подключение к официальным серверам;
* совместимость с оригинальными сетевыми протоколами;
* обход Steam, DRM, VAC/античита или запуск proprietary game DLL/client DLL;
* воспроизведение оригинального UI, HUD, scoreboard, названий команд, оружия и брендинга;
* копирование оригинальных таблиц баланса, spray логики, buy menu, радиокоманд, текстов и конфигов;
* автоматическое скачивание или извлечение ассетов из Steam depot;
* сохранение конвертированных proprietary textures/models в распространяемом виде;
* decompilation оригинальных бинарников;
* “pixel-perfect” поведение оригинального клиента как обязательная цель;
* multiplayer compatibility с существующими серверами.

---

## 3. Архитектура движка

Рекомендуемая верхнеуровневая схема:

```text
apps/
  client_app
  dedicated_server_later
engine/
  core
  platform
  renderer
  assets
  world
  physics
  game
  input
  audio
  ui
  net
  bots
tools/
  bspdump
  wadinspect
  mdlinspect
  sprinspect
  collision_viewer
```

### 3.1 Core

Ответственность:

* allocator abstraction;
* logging;
* profiling zones;
* job system;
* math library;
* serialization;
* handles/IDs;
* fixed timestep scheduler;
* error reporting;
* config system.

Ключевые решения:

* все binary loaders работают через bounds-checked `ByteReader`;
* endian conversion централизован;
* все asset references — через `AssetId`, а не raw path в gameplay;
* panic/assert только в dev; в release — graceful error.

### 3.2 Platform layer для macOS

Ответственность:

* window creation;
* high-DPI/Retina scale;
* fullscreen/windowed modes;
* relative mouse mode;
* keyboard/mouse/gamepad input;
* file picker для выбора пользовательской папки;
* user config path: `~/Library/Application Support/<Original-Free-App-Name>/`;
* cache path: `~/Library/Caches/<Original-Free-App-Name>/`;
* app bundle integration;
* optional sandbox/security-scoped bookmarks.

На CMake app bundle делается через `MACOSX_BUNDLE TRUE`, а кастомный `Info.plist` — через `MACOSX_BUNDLE_INFO_PLIST`. ([CMake][4])

### 3.3 Renderer

Renderer должен быть независим от BSP loader:

```text
BSP Loader -> WorldRenderData -> Renderer backend
```

Модули:

* `RHI`: backend abstraction: buffers, textures, samplers, pipelines, render passes.
* `ShaderLibrary`: offline-compiled shaders.
* `MaterialSystem`: base texture + lightmap + flags.
* `WorldRenderer`: BSP world mesh, lightmaps, PVS/frustum culling.
* `ModelRenderer`: MDL meshes/skeletons.
* `SpriteRenderer`: billboard/oriented sprites.
* `DebugRenderer`: lines, hulls, BSP leaves, normals, PVS, contact planes.
* `FrameGraph` или простая pass-система: world, models, transparents, UI.

BSP world rendering pipeline:

1. BSP faces → polygons through `surfedges/edges/vertices`.
2. Compute base UV через `texinfo`.
3. Compute lightmap UV через face extents + lightmap offset.
4. Build static vertex/index buffers.
5. Build lightmap atlas.
6. Batch by `(texture, lightmap_page, render_flags)`.
7. На кадр: найти текущий leaf/cluster, применить PVS, затем frustum culling.
8. Draw opaque.
9. Sort/draw transparent surfaces.
10. Draw sprites/models.
11. Draw UI/debug overlays.

### 3.4 Resource manager

Задачи:

* mount пользовательских директорий read-only;
* mount WAD/PAK archives как virtual namespaces;
* безопасная нормализация путей;
* запрет path traversal;
* lazy loading;
* hot reload только для open-source dev assets;
* asset dependency graph;
* typed handles: `TextureHandle`, `ModelHandle`, `SoundHandle`, `MapHandle`;
* async decode на worker threads;
* GPU upload только на render thread.

Важно: resource manager не должен копировать оригинальные файлы в репозиторий, build output или crash reports. Persistent cache для proprietary-derived GPU blobs лучше отключить в MVP. Если cache понадобится позже, хранить его только в user cache directory, с явной опцией очистки и без включения в дистрибутив.

### 3.5 BSP loader

Поддерживаемые данные:

* header/version;
* lump table;
* entities ASCII key-value text;
* planes;
* textures/miptex refs;
* vertices;
* visibility/PVS;
* nodes;
* texinfo;
* faces;
* lighting;
* clipnodes;
* leaves;
* marksurfaces;
* edges;
* surfedges;
* models/submodels.

Особенности:

* strict bounds checking;
* размер lump должен быть кратен размеру структуры;
* fuzz tests;
* graceful fallback, если VIS отсутствует;
* отдельный `BspEntityAdapter`, чтобы gameplay не зависел от raw entity names;
* поддержка variant flags через compatibility profiles, а не через хаки в renderer.

### 3.6 WAD/Miptex loader

Поддержка:

* WAD3 magic;
* lump directory;
* texture lookup by normalized name;
* indexed pixels → RGBA;
* palette decode;
* mip levels;
* transparent texture convention;
* animated texture groups через generic material animation, без использования оригинальных названий в UI.

WAD3 хранит magic `WAD3`, количество textures и offset lump list; texture records включают name, dimensions, mipmap offsets и palette. 

### 3.7 Model loader

Этапы:

1. `mdl_header` validation.
2. Texture decode или external texture model support.
3. Mesh groups/bodyparts.
4. Bones.
5. Sequences.
6. Hitboxes.
7. Attachments.
8. Animation sampling.
9. Animation events — только generic adapter, без копирования оригинальной game logic.

Для MVP можно начать с static pose rendering. Для V1 — sequence playback и basic blending.

### 3.8 Sprite loader

Поддержка:

* SPR magic;
* version;
* sprite type/orientation;
* render format;
* palette;
* frames;
* frame timing.

SPR можно рендерить через `SpriteRenderer`, который знает только generic modes: facing camera, upright, oriented, additive, alpha.

### 3.9 Audio

Модули:

* `AudioDevice`;
* `Mixer`;
* `SoundAsset`;
* `SoundEmitter`;
* `Listener`;
* `AmbientSystem`;
* `AudioDebug`.

Backend:

* C++: miniaudio или SDL audio.
* Rust: kira/rodio/cpal или miniaudio binding.

miniaudio поддерживает macOS/iOS и Core Audio backend, что делает его хорошим простым выбором для C/C++ проекта. ([GitHub][5])

### 3.10 Physics и collision

Модули:

* `CollisionWorld`;
* `BspCollisionModel`;
* `Trace`;
* `PlayerController`;
* `TriggerSystem`;
* `LadderSystem`.

Для MVP:

* trace line/ray;
* trace hull/AABB;
* point contents;
* ground detection;
* slide collision;
* step up/down;
* crouch hull switch;
* ladder volumes;
* moving platforms позже.

Движение должно быть “в стиле классического FPS”, но не копией оригинального кода. Все constants — свои, data-driven, с preset’ами вроде `classic_fast`, `classic_precise`, `modern_accessible`.

### 3.11 Game rules

Архитектура:

```text
GameServerLocal
  WorldState
  EntityRegistry
  PlayerSystem
  WeaponSystem
  DamageSystem
  RoundSystem
  ScoreSystem
  EconomySystem
  BotSystem
```

Даже в local match лучше держать server-authoritative модель:

* client отправляет input commands;
* local server симулирует;
* renderer интерполирует state;
* позже это станет multiplayer-ready.

Game modes:

* `Sandbox`;
* `LocalDeathmatch`;
* `TeamRoundMode` с оригинальными-free названиями;
* `ObjectiveMode` позже, с полностью оригинальными objectives.

### 3.12 Input

* SDL relative mouse mode;
* action mapping;
* keybind profiles;
* raw-ish mouse path через SDL, без macOS private APIs;
* controller позже;
* input recording для regression tests.

### 3.13 UI

Разделить:

* debug UI: Dear ImGui;
* runtime UI: собственные widgets или lightweight immediate UI;
* никакой имитации оригинального HUD/menu;
* все названия generic/original;
* resource path picker;
* map selector;
* console/debug log.

### 3.14 Networking

MVP:

* `LocalTransport`: input/state внутри процесса.

V1+:

* собственный UDP protocol;
* snapshot replication;
* input prediction;
* interpolation;
* rollback только при необходимости;
* dedicated server binary.

Запрет:

* official server browser;
* official protocols;
* Steam auth;
* античит обходы;
* compatibility claims с официальными серверами.

### 3.15 Bots/AI

MVP:

* waypoint graph;
* random roam;
* line-of-sight trace;
* simple aim controller;
* target selection;
* fire weapon.

V1:

* auto waypoint generation from BSP walkable surfaces;
* A*;
* cover spots;
* hearing events;
* team behaviours;
* nav editor.

### 3.16 Tools/debugging

Обязательные tools:

```text
bspdump       # печать header/lumps/entities summary
bspview       # standalone map viewer
wadinspect    # список textures, размер, palette info
mdlinspect    # header/bodyparts/sequences/hitboxes
sprinspect    # frames/modes
tracebench    # collision regression tests
asset_audit   # проверка, что в repo нет proprietary files
```

Debug overlays:

* BSP leaves;
* PVS visible set;
* face normals;
* lightmap UV;
* collision hull;
* ground plane;
* step attempts;
* bot path;
* weapon traces.

---

## 4. Технологический стек

### Вариант A — рекомендуемый C++20/23

Лучший вариант для быстрого engine-level прогресса.

| Компонент    | Выбор                                                |
| ------------ | ---------------------------------------------------- |
| Language     | C++20 или C++23                                      |
| Build        | CMake + Ninja/Xcode generator                        |
| Dependencies | vcpkg manifest или CPM.cmake/FetchContent            |
| Window/input | SDL3                                                 |
| Renderer     | bgfx с Metal backend или SDL3 GPU                    |
| Audio        | miniaudio                                            |
| UI debug     | Dear ImGui                                           |
| Math         | glm, DirectXMath-like custom, или handmade SIMD-lite |
| Logging      | spdlog/fmt                                           |
| Tests        | Catch2/doctest + libFuzzer                           |
| Profiling    | Tracy                                                |
| Sanitizers   | ASan/UBSan/TSan debug builds                         |

Почему:

* проще интегрировать C/C++ libraries;
* хороший контроль памяти и layout binary loaders;
* bgfx уже поддерживает Metal/Vulkan/OpenGL backends и macOS; SDL3 официально поддерживает macOS и low-level access к Metal/Vulkan/OpenGL. ([Б.Караджич][6])

Рекомендация: **SDL3 + bgfx/Metal** для первого renderer. SDL3 GPU тоже интересен, но для engine с BSP batching и future portability bgfx может быть быстрее в production. SDL3 GPU можно держать как экспериментальный backend; его API даёт modern GPU workflow с buffers/textures/pipelines/render passes. ([SDL3][7])

### Вариант B — Rust-first

| Компонент      | Выбор                                   |
| -------------- | --------------------------------------- |
| Language       | Rust stable                             |
| Build          | Cargo workspace                         |
| Window/input   | winit или sdl3 bindings                 |
| Renderer       | wgpu                                    |
| Audio          | cpal/kira/rodio или miniaudio binding   |
| Math           | glam                                    |
| ECS            | hecs, shipyard, bevy_ecs без всего Bevy |
| Binary parsing | nom/binrw/custom checked reader         |
| Tests/fuzz     | cargo test, cargo-fuzz                  |
| Packaging      | cargo-bundle или CMake wrapper          |

Почему:

* безопаснее для binary loaders;
* wgpu даёт Metal backend на macOS;
* меньше risk of memory corruption при чтении пользовательских файлов.

Минусы:

* сложнее интегрировать некоторые C++ rendering/debug tools;
* macOS app bundle/notarization потребует отдельной packaging дисциплины;
* Rust graphics stack быстро развивается, нужен dependency pinning.

### Вариант C — гибрид

Практичный компромисс:

```text
C++ engine/runtime/rendering
Rust asset-loader crates через C ABI
```

Или наоборот:

```text
Rust core/assets/game
C++ renderer backend через bgfx C API
```

Рекомендованный гибрид:

* C++20 runtime, renderer, platform;
* Rust static library для `bsp_loader`, `wad_loader`, `mdl_loader`, `spr_loader`;
* FFI только через POD structs и explicit ownership;
* shared test corpus.

Плюсы:

* unsafe binary parsing изолирован;
* renderer остаётся простым для интеграции bgfx/SDL/ImGui;
* можно fuzz’ить Rust loaders отдельно.

Минусы:

* FFI дисциплина;
* сложнее CI;
* сложнее debug symbols/universal builds.

### Graphics backend decision

Приоритет:

1. **bgfx Metal backend** — основной production путь.
2. **SDL3 GPU** — перспективный native/cross-platform backend.
3. **wgpu** — если Rust-first.
4. **Vulkan + MoltenVK** — полезно для Vulkan-portable architecture, но помнить, что MoltenVK мапит Vulkan на Metal и не является полностью conforming Vulkan driver на macOS; в shipping app нужно правильно bundled runtime. ([vulkan.lunarg.com][8])
5. **OpenGL** — только debug fallback, не стратегическая основа на macOS.

---

## 5. Совместимость с macOS

### 5.1 Apple Silicon build

```bash
cmake -S . -B build/macos-arm64 \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0

cmake --build build/macos-arm64 --config Release
```

### 5.2 Intel Mac build

```bash
cmake -S . -B build/macos-x86_64 \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0

cmake --build build/macos-x86_64 --config Release
```

### 5.3 Universal binary

```bash
cmake -S . -B build/macos-universal \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0

cmake --build build/macos-universal --config Release

lipo -info build/macos-universal/apps/client/OpenStrike.app/Contents/MacOS/OpenStrike
```

CMake использует `CMAKE_OSX_ARCHITECTURES` для выбора Apple architectures; Apple также документирует universal macOS binaries как способ запускаться нативно на Apple silicon и Intel-based Mac. ([CMake][9])

Правила:

* все third-party libs должны быть universal;
* если dependency не universal, собирать отдельно arm64/x86_64 и объединять через `lipo`;
* CI должен проверять `file`/`lipo -info`;
* не использовать Homebrew-only dylib в final app без bundling/codesign.

### 5.4 App bundle

CMake:

```cmake
add_executable(OpenStrike MACOSX_BUNDLE
    apps/client/main.cpp
)

set_target_properties(OpenStrike PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST
        "${CMAKE_SOURCE_DIR}/platform/macos/Info.plist.in"
    MACOSX_BUNDLE_GUI_IDENTIFIER
        "org.openstrike.openstrike"
    MACOSX_BUNDLE_BUNDLE_NAME
        "OpenStrike"
)
```

Bundle layout:

```text
OpenStrike.app/
  Contents/
    Info.plist
    MacOS/
      OpenStrike
    Frameworks/
      optional dylibs/frameworks
    Resources/
      shaders/
      ui/
      open_assets_only/
```

### 5.5 Signing, sandboxing, notarization

Для локальной разработки достаточно ad-hoc signing. Для публичного распространения вне Mac App Store нужен Developer ID signing и notarization workflow; Apple описывает notarization как процесс для macOS software distribution, а начиная с macOS 10.14.5 notarization стала важной частью запуска Developer ID-signed software. ([Apple Developer][10])

Пример release pipeline:

```bash
codesign --force --deep --options runtime \
  --entitlements platform/macos/OpenStrike.entitlements \
  --sign "Developer ID Application: <TEAM>" \
  dist/OpenStrike.app

ditto -c -k --keepParent dist/OpenStrike.app dist/OpenStrike.zip

xcrun notarytool submit dist/OpenStrike.zip \
  --keychain-profile "<profile>" \
  --wait

xcrun stapler staple dist/OpenStrike.app
```

Sandboxing:

* GitHub release `.app`: sandbox не обязателен, но hardened runtime + notarization желательны.
* Mac App Store: sandbox обязателен; тогда пользовательская папка ресурсов должна выбираться через file picker, а доступ сохраняется security-scoped bookmark.
* MVP лучше проектировать так, чтобы sandbox можно было включить позже: никаких implicit reads вне выбранных пользователем директорий.

---

## 6. Загрузка оригинальных пользовательских ресурсов

### Безопасный поток

1. Первый запуск показывает оригинальный экран setup без чужого брендинга.
2. Пользователь выбирает папку локальной установленной игры или конкретную папку с ресурсами.
3. Программа canonicalize’ит путь.
4. Проверяет read access.
5. Сканирует поддерживаемые форматы:

   * `.bsp`;
   * `.wad`;
   * `.mdl`;
   * `.spr`;
   * `.wav`;
   * legacy `.pak` позже.
6. Строит локальный read-only index.
7. Ничего не копирует в репозиторий или install bundle.
8. В gameplay/UI используются оригинальные-free имена:

   * “Map” вместо названия продукта;
   * “Sidearm”, “Rifle”, “Heavy”, “Team A”, “Team B”;
   * собственные icons/fonts/colors.

### Правила

* В репозитории только:

  * синтетические test maps;
  * CC0/CC-BY/open-source textures;
  * open-source sounds;
  * собственные shaders;
  * собственный UI.
* Не добавлять оригинальные `.bsp/.wad/.mdl/.spr/.wav` в git.
* CI должен падать, если в PR добавлен binary asset без license manifest.
* Не писать в директорию установленной игры.
* Не конвертировать пользовательские ассеты в redistributable format.
* Crash reports и logs должны scrub’ить абсолютные пути.
* Asset browser не должен показывать trademark-heavy branding как часть app identity; имена файлов можно показывать как пользовательские локальные данные, но лучше иметь режим “technical filenames only”.

---

## 7. План MVP

### Этап 0 — Charter, repo, legal hygiene

Deliverables:

* `README.md` с disclaimer;
* `docs/legal_policy.md`;
* `CONTRIBUTING.md`: запрет proprietary code/assets;
* `.gitignore` + `asset_audit` script;
* license: MIT/Apache-2.0 или BSD-2/3;
* CI: macOS arm64/x86_64 where possible, Linux for tools/tests.

Definition of done:

* PR template требует подтверждения: “No proprietary assets/code”.
* Test assets имеют license manifests.

### Этап 1 — Окно + render loop

Deliverables:

* SDL3 window;
* fixed timestep;
* basic RHI;
* clear screen;
* ImGui debug overlay;
* keyboard/mouse input;
* FPS camera.

Pseudo milestone:

```text
Open .app -> window -> mouse look -> WASD free camera -> frame stats.
```

### Этап 2 — Resource manager + VFS

Deliverables:

* user path picker;
* mount read-only directory;
* `AssetId`;
* sync file loading;
* extension dispatch;
* path traversal protection.

Definition of done:

* можно выбрать папку и увидеть список найденных `.bsp/.wad`;
* engine не падает на missing files.

### Этап 3 — BSP loader CLI

Deliverables:

* `bspdump`;
* parse header/lumps;
* parse entities;
* parse geometry lumps;
* validate lump sizes;
* unit tests на synthetic BSP;
* fuzz harness.

Definition of done:

```bash
bspdump some_map.bsp
# prints version, lump sizes, entity count, face count, model count
```

### Этап 4 — Отрисовка BSP geometry без textures

Deliverables:

* face triangulation;
* vertex/index buffers;
* normal/debug colors;
* free camera;
* coordinate conversion или Z-up engine convention.

Definition of done:

* карта видна как untextured mesh;
* debug normals работают;
* invalid faces skipped with warnings.

### Этап 5 — Lightmaps

Deliverables:

* read lighting lump;
* compute lightmap rects;
* atlas packer;
* shader: base color * lightmap;
* fallback fullbright.

Definition of done:

* baked lighting визуально совпадает по структуре, даже если gamma/overbright ещё не идеальны.

### Этап 6 — WAD textures

Deliverables:

* WAD3 loader;
* miptex decode;
* palette → RGBA;
* texture name lookup;
* transparent materials;
* material flags.

Definition of done:

* world surfaces textured;
* missing textures replaced by original-free checker pattern;
* no proprietary textures in repo.

### Этап 7 — Visibility/PVS + culling

Deliverables:

* find leaf for camera;
* decode PVS;
* mark visible leaves/faces;
* fallback if VIS absent;
* debug overlay.

Definition of done:

* visible set changes as camera moves;
* `r_show_pvs` debug view.

### Этап 8 — Collision trace

Deliverables:

* collision hull parse;
* point contents;
* ray trace;
* hull trace;
* debug collision planes;
* unit tests: wall, floor, slope, stair, corner.

Definition of done:

* player capsule/AABB cannot pass through world geometry;
* raycast weapon trace hits BSP.

### Этап 9 — Player movement

Deliverables:

* fixed tick movement;
* friction;
* acceleration;
* gravity;
* jump;
* air control;
* crouch;
* step movement;
* ladder.

Definition of done:

* player can traverse map locally;
* stairs/slopes mostly stable;
* movement constants configurable.

### Этап 10 — Models, sprites, audio минимально

Deliverables:

* MDL static pose или placeholder renderer;
* SPR billboard renderer;
* WAV playback;
* spawn point markers;
* simple ambient playback.

Definition of done:

* at least one user-provided model can be inspected/rendered if present;
* open-source placeholder character works without proprietary files.

### Этап 11 — Weapon-заглушка

Deliverables:

* generic weapon definitions;
* raycast fire;
* impact debug decal placeholder;
* damage event;
* reload/cooldown state;
* no original names/balance.

Definition of done:

* player can shoot test targets;
* hit events logged.

### Этап 12 — Basic bots + local deathmatch

Deliverables:

* bot entity;
* simple movement over waypoints;
* line-of-sight trace;
* target selection;
* fire generic weapon;
* scoring;
* respawn.

Definition of done:

* local match with player + bots runs for 10 minutes without crash.

---

## 8. Технические риски

| Риск                    | Что может пойти не так                                                                        | Митигирование                                                                                  |
| ----------------------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| BSP variants            | Разные игры/издания могут менять детали lumps; например существуют game-specific differences. | Compatibility profiles, strict validation, `bspdump`, test corpus, graceful fallback.          |
| Binary parsing security | Пользовательские файлы могут быть повреждены или злонамеренны.                                | Bounds-checked readers, fuzzing, ASan/UBSan, max-size limits, no unchecked pointer casts.      |
| Lightmaps               | Неправильная gamma, atlas bleeding, неверные extents.                                         | Debug lightmap viewer, padding atlas, compare synthetic maps, configurable gamma.              |
| Texture semantics       | Transparent/water/animated conventions могут отличаться.                                      | Material flags layer, fallback materials, staged support.                                      |
| OpenGL на macOS         | Deprecated path, driver quirks, poor future compatibility.                                    | Primary Metal/bgfx/wgpu/MoltenVK backend; OpenGL только debug.                                 |
| MoltenVK portability    | Vulkan features могут не совпадать с Metal, MoltenVK не полностью conforming.                 | Использовать conservative Vulkan subset или bgfx/wgpu; validation layers; backend abstraction. |
| Collision precision     | Step movement, slopes, corners, crouch transitions дают jitter.                               | Deterministic fixed tick, trace regression tests, debug overlay, configurable epsilons.        |
| Movement feel           | “Похоже на classic FPS” сложно без копирования кода/constants.                                | Собственные constants, user-tunable profiles, black-box playtesting на open maps.              |
| MDL animation           | Sequences, controllers, texture groups, hitboxes требуют много edge cases.                    | Начать со static pose; потом animation sampling; потом blending/events.                        |
| Bots                    | Auto navmesh из BSP сложен.                                                                   | Сначала waypoint editor; auto-generation позже.                                                |
| Legal assets            | Кто-то случайно добавит оригинальные файлы в repo.                                            | CI asset scanner, PR policy, license manifest, repository hooks.                               |
| Trademark/UI            | Название/иконки/HUD могут выглядеть как производный продукт.                                  | Собственная визуальная айдентика, generic terminology, legal review перед релизом.             |
| Multiplayer             | Совместимость с чужими серверами юридически и технически рискованна.                          | Только собственный protocol, local-first architecture, no official server connectivity.        |
| macOS packaging         | Universal deps, signing, notarization, Gatekeeper.                                            | CMake presets, release CI, `lipo` checks, notarization script.                                 |

---

## 9. Юридически безопасная стратегия проекта

### Жёсткие правила

1. **Не включать оригинальный код**: ни SDK-код, ни decompiled code, ни leaked code, ни фрагменты из бинарников.
2. **Не включать оригинальные ассеты**: maps, textures, models, sprites, sounds, fonts, icons, configs.
3. **Не использовать торговые марки в названии проекта**.
4. **Не имитировать оригинальный UI/branding**: HUD, меню, scoreboard, icons, color scheme, logos.
5. **Не использовать оригинальные названия оружия/команд/режимов как game content**.
6. **Не обходить DRM/Steam/античит**.
7. **Не подключаться к официальным серверам**.
8. **Не реализовывать official protocol compatibility**.
9. **Не загружать proprietary DLL/game logic binaries**.
10. **Поддерживать только локально предоставленные пользователем файлы**.
11. **Все default assets — open-source или собственные**.
12. **Все gameplay data tables — собственные, data-driven, с оригинальными именами**.
13. **Любой contributor подтверждает clean-room происхождение кода**.

### README disclaimer

Пример формулировки:

```text
This project is an independent clean-room game engine/client implementation.
It is not affiliated with, endorsed by, sponsored by, or approved by Valve or
any other rights holder.

The repository does not contain proprietary game assets, proprietary game code,
trademarks, logos, or original game UI. The program may read certain legacy
resource formats from files that the user provides locally. Users are responsible
for ensuring they have the rights to access those files.

This project does not bypass DRM, does not connect to official game servers,
does not implement official network protocols, and does not include anti-cheat
circumvention.
```

### Contributor policy

```text
By contributing, you certify that:
- you did not copy proprietary source code;
- you did not use leaked/decompiled code;
- you did not add proprietary assets;
- all new assets have an explicit license;
- any compatibility work is based on public documentation, clean-room research,
  or black-box testing with locally owned files.
```

---

## 10. Пример структуры репозитория

```text
openstrike/
  CMakeLists.txt
  CMakePresets.json
  vcpkg.json                         # если выбран vcpkg
  LICENSE
  README.md
  CONTRIBUTING.md

  docs/
    architecture.md
    legal_policy.md
    asset_policy.md
    file_formats/
      bsp_notes.md
      wad_notes.md
      mdl_notes.md
      spr_notes.md
    roadmap.md

  cmake/
    warnings.cmake
    sanitizers.cmake
    dependencies.cmake
    macos_bundle.cmake

  platform/
    macos/
      Info.plist.in
      OpenStrike.entitlements
      notarize.sh

  apps/
    client/
      main.cpp
      ClientApp.cpp
      ClientApp.h
    server/
      main.cpp                       # позже

  engine/
    core/
      Assert.h
      ByteReader.h
      Endian.h
      FileSystem.h
      Handle.h
      JobSystem.cpp
      Logger.cpp
      Math.h
      Time.cpp

    platform/
      Platform.h
      SdlPlatform.cpp
      MacFileDialog.mm

    renderer/
      Rhi.h
      ShaderLibrary.cpp
      MaterialSystem.cpp
      WorldRenderer.cpp
      ModelRenderer.cpp
      SpriteRenderer.cpp
      DebugRenderer.cpp
      backends/
        bgfx/
        sdlgpu/
        wgpu_later/

    assets/
      AssetId.h
      ResourceManager.cpp
      VirtualFileSystem.cpp
      loaders/
        BspLoader.cpp
        WadLoader.cpp
        MdlLoader.cpp
        SprLoader.cpp
        WavLoader.cpp
        PakLoader_later.cpp

    world/
      World.cpp
      EntityParser.cpp
      BspWorld.cpp
      EntityAdapter.cpp

    physics/
      CollisionWorld.cpp
      BspCollision.cpp
      Trace.cpp
      PlayerMovement.cpp

    game/
      GameServerLocal.cpp
      GameRules.cpp
      Player.cpp
      WeaponSystem.cpp
      DamageSystem.cpp
      RoundSystem.cpp
      EconomySystem.cpp

    input/
      InputSystem.cpp
      ActionMap.cpp

    audio/
      AudioDevice.cpp
      Mixer.cpp
      SoundEmitter.cpp

    ui/
      DebugUi.cpp
      MainMenu.cpp
      ResourceSetupView.cpp
      Hud.cpp

    net/
      LocalTransport.cpp
      UdpTransport_later.cpp
      Snapshot_later.cpp

    bots/
      BotController.cpp
      WaypointGraph.cpp
      PathFinding.cpp

  tools/
    bspdump/
      main.cpp
    bspview/
      main.cpp
    wadinspect/
      main.cpp
    mdlinspect/
      main.cpp
    sprinspect/
      main.cpp
    asset_audit/
      main.py

  assets_open/
    README.md
    licenses/
    textures/
    models/
    sounds/
    maps/
      synthetic_test_map.bsp          # только если создан с open-source assets

  tests/
    unit/
    integration/
    fuzz/
      fuzz_bsp.cpp
      fuzz_wad.cpp
    golden/
      synthetic_bsp/
      synthetic_wad/

  scripts/
    format.sh
    build_macos_universal.sh
    run_sanitizers.sh
```

---

## 11. Псевдокод ключевых систем

### 11.1 Resource manager

```cpp
struct AssetId {
    string normalizedPath;
    AssetType type;
};

class ResourceManager {
public:
    void mountDirectory(string userChosenPath, MountFlags flags) {
        Path p = canonicalize(userChosenPath);
        requireExists(p);
        requireReadable(p);
        mounts.push_back(Mount{p, flags | ReadOnly});
        indexMount(p);
    }

    void mountWad(string wadPath) {
        auto wad = WadLoader::open(vfs.readFile(wadPath));
        for (auto& entry : wad.entries()) {
            archiveIndex.add(entry.name, ArchiveRef{wadPath, entry.offset});
        }
        archives.push_back(std::move(wad));
    }

    TextureHandle loadTexture(string name) {
        AssetId id = normalizeTextureId(name);

        if (textureCache.contains(id)) {
            return textureCache[id];
        }

        ByteBlob bytes;
        TextureSource source;

        if (vfs.exists(id.normalizedPath)) {
            bytes = vfs.readFile(id.normalizedPath);
            source = TextureSource::LooseFile;
        } else if (archiveIndex.contains(id.normalizedPath)) {
            bytes = archiveIndex.read(id.normalizedPath);
            source = TextureSource::Archive;
        } else {
            return fallbackTexture("missing_checker");
        }

        DecodedTexture decoded = TextureLoader::decode(bytes, source);
        TextureHandle gpu = renderer.uploadTexture(decoded);
        textureCache[id] = gpu;
        return gpu;
    }

    MapHandle loadMap(string bspPath) {
        AssetId id = normalizeMapId(bspPath);
        if (mapCache.contains(id)) return mapCache[id];

        ByteBlob bytes = vfs.readFile(id.normalizedPath);
        BspMap map = BspLoader::load(bytes, BspLoadOptions{
            .strict = true,
            .loadCollision = true,
            .loadVisibility = true,
            .loadLighting = true
        });

        for (string wadRef : map.entityData.referencedWads()) {
            optional<Path> resolved = resolveWadRef(wadRef);
            if (resolved) mountWad(*resolved);
        }

        MapHandle handle = world.createMap(std::move(map));
        mapCache[id] = handle;
        return handle;
    }

private:
    VirtualFileSystem vfs;
    vector<Mount> mounts;
    vector<WadArchive> archives;
    ArchiveIndex archiveIndex;
    HashMap<AssetId, TextureHandle> textureCache;
    HashMap<AssetId, MapHandle> mapCache;
};
```

### 11.2 BSP loader

```cpp
BspMap BspLoader::load(ByteBlob bytes, BspLoadOptions opt) {
    ByteReader r(bytes, Endian::Little);

    int32 version = r.readI32();
    if (version != 30) {
        throw FormatError("unsupported BSP version");
    }

    Lump lumps[15];
    for (int i = 0; i < 15; ++i) {
        lumps[i].offset = r.readU32();
        lumps[i].length = r.readU32();
        validateRange(bytes.size(), lumps[i].offset, lumps[i].length);
    }

    BspMap out;
    out.entities    = parseEntities(readLump(bytes, lumps[LUMP_ENTITIES]));
    out.planes      = parseArray<Plane>(bytes, lumps[LUMP_PLANES]);
    out.textures    = parseTextureLump(bytes, lumps[LUMP_TEXTURES]);
    out.vertices    = parseArray<Vec3>(bytes, lumps[LUMP_VERTICES]);
    out.visibility  = parseVisibility(bytes, lumps[LUMP_VISIBILITY]);
    out.nodes       = parseArray<Node>(bytes, lumps[LUMP_NODES]);
    out.texInfos    = parseArray<TexInfo>(bytes, lumps[LUMP_TEXINFO]);
    out.faces       = parseArray<Face>(bytes, lumps[LUMP_FACES]);
    out.lightBytes  = readLump(bytes, lumps[LUMP_LIGHTING]);
    out.clipNodes   = parseArray<ClipNode>(bytes, lumps[LUMP_CLIPNODES]);
    out.leaves      = parseArray<Leaf>(bytes, lumps[LUMP_LEAVES]);
    out.markFaces   = parseArray<uint16>(bytes, lumps[LUMP_MARKSURFACES]);
    out.edges       = parseArray<Edge>(bytes, lumps[LUMP_EDGES]);
    out.surfEdges   = parseArray<int32>(bytes, lumps[LUMP_SURFEDGES]);
    out.models      = parseArray<BspModel>(bytes, lumps[LUMP_MODELS]);

    out.renderMeshes = buildRenderMeshes(out);
    out.collision    = buildCollisionData(out);
    out.entityData   = adaptEntities(out.entities);

    return out;
}

vector<RenderFace> buildRenderMeshes(const BspMap& bsp) {
    vector<RenderFace> faces;

    for (Face f : bsp.faces) {
        vector<Vertex> poly;

        for (int i = 0; i < f.edgeCount; ++i) {
            int32 surfEdgeIndex = bsp.surfEdges[f.firstEdge + i];
            Edge edge = bsp.edges[abs(surfEdgeIndex)];

            uint16 vertexIndex = surfEdgeIndex >= 0 ? edge.v0 : edge.v1;
            Vec3 pos = bsp.vertices[vertexIndex];

            TexInfo ti = bsp.texInfos[f.texInfoIndex];

            Vec2 baseUv = {
                dot(pos, ti.sAxis.xyz) + ti.sAxis.w,
                dot(pos, ti.tAxis.xyz) + ti.tAxis.w
            };

            Vec2 lightUv = computeLightmapUv(pos, f, ti);

            poly.push_back(Vertex{
                .position = pos,
                .normal = bsp.planes[f.planeIndex].normal,
                .uv0 = baseUv,
                .uv1 = lightUv
            });
        }

        faces.push_back(triangulateFanOrRobust(poly, f));
    }

    return faces;
}
```

### 11.3 Render loop

```cpp
int main() {
    Platform platform;
    platform.initWindow("OpenStrike");

    Renderer renderer;
    renderer.init(platform.windowHandle());

    ResourceManager resources;
    GameServerLocal server;
    ClientWorld clientWorld;
    InputSystem input;
    AudioSystem audio;
    UiSystem ui;

    FixedTimestep tickRate(1.0 / 100.0);

    while (!platform.shouldQuit()) {
        platform.pollEvents(input);

        InputFrame inputFrame = input.buildFrame();

        tickRate.accumulate(platform.deltaTime());
        while (tickRate.shouldTick()) {
            server.submitInput(localPlayerId, inputFrame);
            server.tick(tickRate.dt());
            clientWorld.receiveSnapshot(server.makeLocalSnapshot());
            audio.tick(server.audioEvents());
            tickRate.consume();
        }

        float alpha = tickRate.interpolationAlpha();
        RenderScene scene = clientWorld.buildRenderScene(alpha);

        renderer.beginFrame();
        renderer.drawWorld(scene.world);
        renderer.drawModels(scene.models);
        renderer.drawSprites(scene.sprites);
        renderer.drawDebug(scene.debug);
        ui.draw(scene, server.debugState());
        renderer.endFrame();
    }

    renderer.shutdown();
    return 0;
}
```

### 11.4 Collision trace

```cpp
struct TraceResult {
    bool hit = false;
    bool startSolid = false;
    bool allSolid = false;
    float fraction = 1.0f;
    Vec3 endPos;
    Vec3 normal;
    int contents = CONTENTS_EMPTY;
};

TraceResult traceHull(const BspCollisionModel& model,
                      HullId hull,
                      Vec3 start,
                      Vec3 end) {
    TraceResult tr;
    tr.endPos = end;

    int rootNode = model.hulls[hull].firstClipNode;
    recursiveHullTrace(model, hull, rootNode, 0.0f, 1.0f, start, end, tr);

    if (tr.hit) {
        tr.endPos = lerp(start, end, tr.fraction);
    }

    return tr;
}

void recursiveHullTrace(const BspCollisionModel& model,
                        HullId hull,
                        int nodeIndex,
                        float p1f,
                        float p2f,
                        Vec3 p1,
                        Vec3 p2,
                        TraceResult& tr) {
    if (tr.fraction <= p1f) return;

    if (nodeIndex < 0) {
        int contents = decodeContents(nodeIndex);
        if (contentsIsSolid(contents)) {
            tr.hit = true;
            if (p1f == 0.0f) tr.startSolid = true;
            tr.fraction = min(tr.fraction, p1f);
            tr.contents = contents;
        }
        return;
    }

    ClipNode node = model.clipNodes[nodeIndex];
    Plane plane = model.planes[node.planeIndex];

    float d1 = dot(p1, plane.normal) - plane.dist;
    float d2 = dot(p2, plane.normal) - plane.dist;

    if (d1 >= 0.0f && d2 >= 0.0f) {
        recursiveHullTrace(model, hull, node.children[0], p1f, p2f, p1, p2, tr);
        return;
    }

    if (d1 < 0.0f && d2 < 0.0f) {
        recursiveHullTrace(model, hull, node.children[1], p1f, p2f, p1, p2, tr);
        return;
    }

    float denom = d1 - d2;
    float frac = clamp((d1 - TRACE_EPSILON) / denom, 0.0f, 1.0f);
    float midf = lerp(p1f, p2f, frac);
    Vec3 mid = lerp(p1, p2, frac);

    int firstSide = d1 < 0.0f ? 1 : 0;
    int secondSide = 1 - firstSide;

    recursiveHullTrace(model, hull, node.children[firstSide],
                       p1f, midf, p1, mid, tr);

    recursiveHullTrace(model, hull, node.children[secondSide],
                       midf, p2f, mid, p2, tr);

    if (tr.hit && tr.fraction == midf) {
        tr.normal = firstSide == 0 ? plane.normal : -plane.normal;
    }
}
```

### 11.5 Player movement

```cpp
void PlayerMovement::tick(Player& p,
                          const InputCommand& cmd,
                          const CollisionWorld& world,
                          float dt) {
    updateViewAngles(p, cmd.mouseDelta);

    HullId hull = p.isCrouching ? HullId::Crouch : HullId::Stand;

    p.onGround = checkGround(p, world, hull);
    p.onLadder = checkLadder(p, world);

    Vec3 wishDir;
    float wishSpeed;
    buildWishMove(cmd, p.viewAngles, wishDir, wishSpeed);

    if (p.onLadder) {
        moveLadder(p, cmd, world, dt);
        return;
    }

    if (p.onGround) {
        applyFriction(p, dt);

        if (cmd.jumpPressed && canJump(p)) {
            p.velocity.z = config.jumpSpeed;
            p.onGround = false;
        } else {
            accelerate(p.velocity, wishDir, wishSpeed,
                       config.groundAccel, dt);
        }
    } else {
        accelerate(p.velocity, wishDir, wishSpeed,
                   config.airAccel, dt);
        p.velocity.z -= config.gravity * dt;
    }

    Vec3 desiredMove = p.velocity * dt;

    if (p.onGround) {
        stepSlideMove(p, desiredMove, world, hull);
    } else {
        slideMove(p, desiredMove, world, hull);
    }

    resolveCrouchTransition(p, world);
}

void slideMove(Player& p, Vec3 move, const CollisionWorld& world, HullId hull) {
    Vec3 remaining = move;

    for (int bump = 0; bump < MAX_BUMPS; ++bump) {
        TraceResult tr = world.traceHull(hull, p.position, p.position + remaining);

        if (!tr.hit) {
            p.position = tr.endPos;
            return;
        }

        p.position = tr.endPos;
        p.velocity = clipVelocity(p.velocity, tr.normal, OVERCLIP);

        float remainingFrac = 1.0f - tr.fraction;
        remaining = p.velocity * remainingFrac * fixedDt;
    }
}

void stepSlideMove(Player& p, Vec3 move, const CollisionWorld& world, HullId hull) {
    Vec3 originalPos = p.position;
    Vec3 originalVel = p.velocity;

    slideMove(p, move, world, hull);
    Vec3 noStepPos = p.position;
    Vec3 noStepVel = p.velocity;

    p.position = originalPos;
    p.velocity = originalVel;

    TraceResult up = world.traceHull(hull, p.position,
                                     p.position + Vec3{0, 0, config.stepHeight});
    if (up.hit) {
        p.position = noStepPos;
        p.velocity = noStepVel;
        return;
    }

    p.position = up.endPos;
    slideMove(p, move, world, hull);

    TraceResult down = world.traceHull(hull, p.position,
                                       p.position - Vec3{0, 0, config.stepHeight});
    if (!down.hit) {
        p.position = noStepPos;
        p.velocity = noStepVel;
        return;
    }

    p.position = down.endPos;

    if (distanceSqXY(p.position, originalPos) <
        distanceSqXY(noStepPos, originalPos)) {
        p.position = noStepPos;
        p.velocity = noStepVel;
    }
}
```

### 11.6 Weapon system

```cpp
struct WeaponDef {
    string id;                 // "rifle_a", not proprietary name
    FireMode mode;             // Hitscan, Projectile, Melee
    float damage;
    float cooldownSeconds;
    float range;
    float spreadDegrees;
    int pellets;
    int magazineSize;
    float reloadSeconds;
    RecoilPattern recoil;
};

struct WeaponState {
    WeaponDefId def;
    int ammoInMag;
    int reserveAmmo;
    float cooldownRemaining;
    bool reloading;
    float reloadRemaining;
};

void WeaponSystem::tick(Player& owner,
                        WeaponState& weapon,
                        const InputCommand& cmd,
                        GameWorld& world,
                        float dt) {
    WeaponDef def = defs.get(weapon.def);

    weapon.cooldownRemaining = max(0.0f, weapon.cooldownRemaining - dt);

    if (weapon.reloading) {
        weapon.reloadRemaining -= dt;
        if (weapon.reloadRemaining <= 0.0f) {
            finishReload(weapon, def);
        }
        return;
    }

    if (cmd.reloadPressed) {
        startReload(weapon, def);
        return;
    }

    if (!cmd.firePressed) return;
    if (weapon.cooldownRemaining > 0.0f) return;
    if (weapon.ammoInMag <= 0) {
        startReload(weapon, def);
        return;
    }

    weapon.ammoInMag--;
    weapon.cooldownRemaining = def.cooldownSeconds;

    for (int i = 0; i < def.pellets; ++i) {
        Vec3 dir = applySpread(owner.viewForward(), def.spreadDegrees, world.rng);

        if (def.mode == FireMode::Hitscan) {
            TraceResult tr = world.traceRay(owner.eyePosition(),
                                            owner.eyePosition() + dir * def.range);

            if (tr.hit) {
                DamageEvent ev;
                ev.attacker = owner.id;
                ev.target = tr.entity;
                ev.amount = computeDamage(def, tr.hitGroup, tr.distance);
                ev.position = tr.endPos;
                ev.normal = tr.normal;
                world.damageQueue.push(ev);
                world.effects.spawnImpact(tr.endPos, tr.normal);
            }
        } else if (def.mode == FireMode::Projectile) {
            world.spawnProjectile(owner.id, owner.eyePosition(), dir, def);
        }
    }

    world.audio.emit(owner.position, def.fireSound);
    world.netEvents.emitWeaponFired(owner.id, def.id);
}
```

---

## 12. Roadmap на 6–12 месяцев

Предположение: 1–3 core-разработчика, part-time art/tools support, без задачи official multiplayer compatibility.

### Месяц 1 — Foundation

Цель: проект собирается, окно открывается, архитектура не мешает развитию.

Deliverables:

* CMake presets;
* SDL3 platform layer;
* renderer skeleton;
* ImGui debug overlay;
* input system;
* logging/profiling;
* macOS arm64/x86_64 builds;
* app bundle skeleton;
* legal/contribution docs.

Exit criteria:

* `cmake --preset macos-arm64-debug`;
* `.app` запускается;
* free camera работает;
* CI зелёный.

### Месяц 2 — Resource system + BSP parser

Deliverables:

* VFS;
* path picker;
* `bspdump`;
* BSP lump parsing;
* entity parser;
* basic mesh extraction;
* fuzz tests.

Exit criteria:

* можно выбрать пользовательскую папку;
* `bspdump` печатает summary карты;
* loader не падает на corrupted corpus.

### Месяц 3 — BSP renderer

Deliverables:

* untextured BSP render;
* face triangulation;
* camera navigation;
* basic culling;
* debug overlays;
* synthetic open-source BSP test.

Exit criteria:

* несколько локальных пользовательских карт открываются в viewer без crash;
* geometry визуально узнаваема;
* invalid faces logged, not fatal.

### Месяц 4 — Textures + lightmaps

Deliverables:

* WAD3 loader;
* texture lookup;
* palette conversion;
* missing texture fallback;
* lightmap atlas;
* lightmap shader;
* material flags.

Exit criteria:

* textured BSP world рендерится;
* lightmaps работают;
* screenshots можно сравнивать между builds.

### Месяц 5 — Collision + movement

Deliverables:

* BSP clipnodes collision;
* ray/hull trace;
* point contents;
* player controller;
* stairs/slopes/crouch;
* ladder prototype;
* movement test maps.

Exit criteria:

* игрок ходит по карте;
* не проходит сквозь стены;
* прыжки/ступени/наклоны работают достаточно стабильно.

### Месяц 6 — Local sandbox gameplay

Deliverables:

* local server architecture;
* spawn system;
* debug weapon;
* damageable test targets;
* simple HUD;
* audio device + WAV playback;
* basic menu.

Exit criteria:

* playable sandbox: spawn, walk, shoot, hit target;
* no proprietary UI/assets;
* 30–60 minutes run without crash.

### Месяцы 7–8 — Assets V1: MDL/SPR/audio/entities

Deliverables:

* MDL static rendering;
* MDL animation sampling basic;
* SPR rendering;
* entity adapter expansion;
* ambient sounds;
* simple pickups;
* placeholder original-free character/weapon models.

Exit criteria:

* user-provided MDL/SPR can be inspected and rendered if present;
* open-source fallback assets fully playable.

### Месяцы 8–9 — Bots + local deathmatch

Deliverables:

* waypoint graph;
* bot locomotion;
* target selection;
* line-of-sight;
* generic weapons;
* scoring/respawn;
* local deathmatch rules.

Exit criteria:

* player + 3–7 bots на local map;
* match loop работает;
* bots не требуют proprietary nav files.

### Месяцы 9–10 — Game rules polish

Deliverables:

* team-like mode;
* round timer;
* basic economy prototype;
* buy/loadout menu с original-free names;
* damage groups;
* hitbox integration;
* spectator/freecam debug.

Exit criteria:

* полноценный local match loop;
* game rules data-driven;
* никакие оригинальные balance tables не используются.

### Месяцы 10–11 — macOS release engineering

Deliverables:

* universal binary;
* dependency bundling;
* codesign;
* notarization;
* crash-safe logs;
* settings migration;
* packaged `.dmg`.

Exit criteria:

* `.app` запускается на Apple Silicon и Intel;
* Gatekeeper-friendly release;
* `lipo -info` подтверждает universal binary;
* resource folder selection survives relaunch.

### Месяцы 11–12 — Multiplayer foundation или compatibility polish

Выбор зависит от состояния MVP.

Ветка A: networking foundation:

* own UDP transport;
* local dedicated server;
* snapshots;
* client prediction prototype;
* no official protocol.

Ветка B: compatibility polish:

* больше BSP variants;
* better PVS;
* better lightmap/gamma;
* MDL animation fixes;
* collision edge cases;
* toolchain hardening.

Exit criteria:

* первая публичная alpha release;
* чёткий список supported/unsupported features;
* legal policy соблюдается.

---

## 13. Критерии готовности MVP

MVP успешен, если выполняется всё ниже:

1. **Сборка**

   * `arm64`, `x86_64`, universal macOS builds работают.
   * `.app` запускается из Finder.
   * CI собирает tools/tests.

2. **Юридическая чистота**

   * В repo нет оригинальных proprietary assets.
   * В repo нет оригинального/decompiled/leaked кода.
   * UI и branding полностью оригинальные.
   * README disclaimer присутствует.
   * Asset audit проходит.

3. **Resource flow**

   * Пользователь сам выбирает локальную папку.
   * Программа валидирует путь и поддерживаемые файлы.
   * Ничего не пишет в директорию игры.
   * Missing assets дают fallback, а не crash.

4. **BSP rendering**

   * BSP map загружается.
   * World geometry отображается.
   * WAD textures отображаются.
   * Lightmaps работают или корректно fallback’ятся.
   * PVS/frustum culling не ломает видимость критически.

5. **Collision/movement**

   * Игрок спавнится.
   * Ходит, прыгает, crouch’ится.
   * Не проходит сквозь static world.
   * Stairs/steps работают на тестовых картах.
   * Raycast weapon trace попадает в BSP/world targets.

6. **Local gameplay**

   * Есть sandbox или local deathmatch.
   * Есть generic weapon-заглушка.
   * Есть damage/respawn/score.
   * Есть хотя бы простой bot или dummy target.

7. **Stability**

   * 10+ минут local run без crash.
   * Fuzz tests для BSP/WAD не находят obvious memory issues.
   * ASan/UBSan debug build чистый на synthetic tests.
   * Corrupted files дают controlled errors.

8. **Extensibility**

   * Можно заменить все пользовательские ресурсы на open-source assets.
   * Game rules и weapons data-driven.
   * Renderer не зависит напрямую от BSP parser.
   * Local server architecture готова к будущему networking layer.

[1]: https://developer.apple.com/documentation/Metal/migrating-opengl-code-to-metal "Migrating OpenGL code to Metal | Apple Developer Documentation"
[2]: https://abit.g6.cz/game_coding/formats/gold_source/bsp.html "BSP v30"
[3]: https://developer.valvesoftware.com/wiki/MDL_%28GoldSrc%29 "MDL (GoldSrc)"
[4]: https://cmake.org/cmake/help/latest/prop_tgt/MACOSX_BUNDLE.html "MACOSX_BUNDLE — CMake 4.4.0-rc1 Documentation"
[5]: https://github.com/mackron/miniaudio "GitHub - mackron/miniaudio: Audio playback and capture library written in C, in a single source file. · GitHub"
[6]: https://bkaradzic.github.io/bgfx/overview.html "Overview — bgfx 1.142.9194 documentation"
[7]: https://wiki.libsdl.org/SDL3/CategoryGPU "SDL3/CategoryGPU - SDL Wiki"
[8]: https://vulkan.lunarg.com/doc/view/1.4.304.1/mac/getting_started.html "vulkan.lunarg.com"
[9]: https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html "cmake-toolchains(7) — CMake 4.4.0-rc1 Documentation"
[10]: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution "Notarizing macOS software before distribution | Apple Developer Documentation"
