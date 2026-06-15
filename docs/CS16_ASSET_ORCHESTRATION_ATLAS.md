# CS 1.6 Asset Orchestration Atlas для OpenStrike

Публичные источники дают хорошую карту форматов, папок, сущностей и lifecycle-паттернов, но **не дают финальную таблицу sequence names / durations / frame events / точных socket transforms для конкретной установленной CS 1.6**. Это нужно добывать локальным extractor’ом из файлов игрока.

Основание: BSP/MDL/SPR/WAD описаны как отдельные GoldSrc-форматы в публичной документации Valve Developer Community; `.res`-подход используется для списка зависимостей карты — WAV/TGA/MDL/SPR/WAD с сохранением структуры директорий; GoldSrc QC animation events включают события звуков и 5000-series muzzle flashes; HUD в SDK грузит `hud.txt` и связанные sprites; overview/radar строится из map overview image + txt-настроек; weapon data можно сверять по Weapon Info Dump / AlliedModders, но это не заменяет локальную проверку файлов. ([Valve Developer Community][1]) ([Valve Developer Community][2]) ([the303.org][3]) ([GitHub][4]) ([ModDB][5]) ([wiki.alliedmods.net][6])

Внутренний контракт уже сформулирован правильно: gameplay не должен знать GoldSrc-файлы; он знает `weapon_id`, `state`, semantic events, а `GoldSrcAssetProvider` и `AssetOrchestrator` связывают это с `.mdl/.spr/.wav/.bsp/.wad`. Ниже — карта, которую OpenStrike хранит как `docs/CS16_ASSET_ORCHESTRATION_ATLAS.md`.

Status vocabulary for generated atlas fields is defined separately in
`docs/COVERAGE_STATUS_CONTRACT.md`. This atlas defines what must be covered; the
coverage contract defines how each field is marked as `stage` + `confidence` and
which status pairs are allowed.


## 1. Главный принцип покрытия

Для OpenStrike “ассет покрыт” означает не “файл найден”, а что для него есть полный runtime-контракт:

| Уровень        | Что значит                                                                                    |
| -------------- | --------------------------------------------------------------------------------------------- |
| `discoverable` | движок умеет найти файл через GoldSrc VFS: `cstrike` → `valve` → custom pack                  |
| `parseable`    | движок умеет прочитать формат или metadata                                                    |
| `semantic`     | файл привязан к смыслу: `weapon.ak47.view_model`, `hud.ammo_digits`, `map.de_dust2.bombsites` |
| `orchestrated` | понятен lifecycle: когда загрузить, когда проиграть, где поставить, когда выгрузить           |
| `diagnosed`    | при отсутствии/ошибке есть warning, а не placeholder и не silent fail                         |
| `verified`     | значение подтверждено локальным scanner’ом на установленной CS 1.6                            |

**Публичные источники закрывают первые 3–4 уровня. Последний уровень должен делать extractor.**

---

## 2. Общая карта папок и типов

| Область          | GoldSrc / CS 1.6 источники                                                                  | Что делает OpenStrike                                                                           |
| ---------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| VFS / game root  | `cstrike/`, `valve/`, `cstrike_addon/`, `liblist.gam`, PAK/WAD/custom roots                 | строит overlay lookup, case-insensitive index, diagnostics “откуда взят ассет”                  |
| Maps             | `maps/*.bsp`, `maps/*.res`, `maps/*.txt`, иногда `maps/*.nav`                               | импорт BSP, парсинг entities, texture dependencies, collision, map dependency graph             |
| Map textures     | `*.wad`, embedded BSP miptex, `decals.wad`, custom WADs из `.res`                           | WAD registry, material metadata, hit material mapping                                           |
| Skyboxes         | `gfx/env/<sky>up/dn/lf/rt/ft/bk.*`                                                          | skyname из worldspawn → skybox resolver                                                         |
| Models           | `models/*.mdl`, `models/player/<name>/<name>.mdl`                                           | MDL metadata-first loader: bones, sequences, hitboxes, attachments, bodygroups, skins           |
| Weapon models    | `models/v_*.mdl`, `models/p_*.mdl`, `models/w_*.mdl`                                        | viewmodel / third-person / dropped weapon roles                                                 |
| Player models    | `models/player/arctic`, `guerilla`, `leet`, `terror`, `gign`, `gsg9`, `sas`, `urban`, `vip` | team/model selector, third-person animation, hitbox source                                      |
| Sprites          | `sprites/*.spr`, `sprites/hud.txt`, `sprites/weapon_*.txt`, `sprites/observer.txt`          | HUD, crosshair, killfeed icons, muzzle flash, smoke, explosions, impacts                        |
| Audio            | `sound/**/*.wav`, `sound/materials.txt`, `sound/sentences.txt`                              | semantic audio events, 2D/3D routing, reload fragments, entity sounds, footstep material sounds |
| UI / text        | `resource/*.txt`, `*.res`, `titles.txt`, `commandmenu.txt`, `motd.txt`, `gfx/shell/*`       | menu strings, classic UI, MOTD, command menu, localization                                      |
| Sprays / decals  | `tempdecal.wad`, `custom.hpk`, `logos/*`, `decals.wad`                                      | player sprays, bullet decals, blood decals, wall marks                                          |
| Config           | `config.cfg`, `userconfig.cfg`, `autoexec.cfg`, `server.cfg`, `listenserver.cfg`, map cfg   | cvars, binds, server presets; читать осторожно, не как ассеты Valve                             |
| Bot/nav optional | CZ/zBot `.nav`, podbot waypoints, custom bot files                                          | optional import/reference; OpenStrike AI не должен зависеть от YaPB/PODBot форматa              |

---

## 3. Карта по формату

| Формат             | Что содержит                                                                           | OpenStrike loader должен вытащить                                               | Покрытие                                         |
| ------------------ | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------ |
| `.bsp`             | world geometry, BSP tree, clipnodes/hulls, faces, texinfo, lightmaps, entity lump, vis | geometry, collision, entity metadata, texture names, WAD deps, lightmaps, PVS   | публично понятно; нужно production loader        |
| `.wad` / WAD3      | texture lumps, decals, spray textures                                                  | texture names, mip levels, palette/transparency metadata                        | публично понятно; нужен WAD registry             |
| `.mdl`             | meshes, skeleton/bones, sequences, hitboxes, attachments, textures, bodygroups, events | sequence names, fps, duration, events, hitboxes, attachments, bodygroups, skins | формат понятен; значения только через extractor  |
| `.spr`             | 2D animated sprites, palette, frames, sprite type                                      | frame count, fps, size, orientation mode, palette/alpha mode                    | формат понятен; нужна runtime sprite scene       |
| `.wav`             | weapon/radio/entity/player sounds                                                      | sample metadata, channel group, semantic event binding                          | файл прост; mapping сложный                      |
| `.txt` HUD         | sprite atlas layout, weapon icon rects, ammo/crosshair data                            | named rects, scale variants, weapon HUD definitions                             | публичный паттерн; exact rects через local files |
| `.res` map         | список дополнительных файлов для карты                                                 | dependency graph map → required assets                                          | нужно поддержать для custom maps                 |
| `.fgd` entity defs | editor definitions of map entities                                                     | entity schema reference, not runtime truth                                      | использовать как справочник, не source of truth  |

---

## 4. Карта оружия

Для каждого оружия OpenStrike должен иметь **не один asset**, а пакет:

```text
weapon_id
  gameplay definition
  view_model: models/v_*.mdl
  player_model: models/p_*.mdl
  world_model: models/w_*.mdl
  hud layout: sprites/weapon_*.txt
  hud/death/select/ammo/crosshair sprite rects
  fire sounds
  reload fragment sounds
  draw/empty/special sounds
  animation aliases
  extracted sequences
  extracted or configured events
  muzzle socket
  shell socket
  shell visual
  muzzle flash effect
  tracer policy
  impact policy
  pickup/drop policy
  diagnostics coverage
```

## 4.1 Weapon roster

| Группа            | `weapon_id`                                                                                                     | Asset contract                                                                      |
| ----------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Pistols           | `glock18`, `usp`, `p228`, `deagle`, `fiveseven`, `elite`                                                        | v/p/w models, fire/reload/dryfire, shell pistol, HUD icon, ammo icon, death icon    |
| Shotguns          | `m3`, `xm1014`                                                                                                  | v/p/w, pump/reload-per-shell events, shotgun shell visual, special reload lifecycle |
| SMG               | `mac10`, `tmp`, `mp5navy`, `ump45`, `p90`                                                                       | v/p/w, auto fire, rifle/smg shell, reload fragments                                 |
| Rifles            | `galil`, `famas`, `ak47`, `m4a1`, `aug`, `sg552`                                                                | v/p/w, auto/burst/silencer/scope-specific states where applicable                   |
| Sniper            | `scout`, `awp`, `g3sg1`, `sg550`                                                                                | v/p/w, zoom scope overlay, bolt/pull events, scoped crosshair suppression           |
| Machine gun       | `m249`                                                                                                          | v/p/w, high-rate audio/effects, heavy maxspeed                                      |
| Equipment / melee | `knife`, `hegrenade`, `flashbang`, `smokegrenade`, `c4`, `shield`, `defuser`, `kevlar`, `helmet`, `nightvision` | not all have v/p/w; some are HUD/equipment state + sounds + effects                 |

**Важно:** нельзя строить пути только формулой `v_<weapon_id>.mdl`. Например `weapon_mp5navy` может использовать короткое имя модели `mp5`. Поэтому atlas должен хранить `asset_stem`, а scanner должен проверять реальные файлы.

Пример записи:

```json
{
  "weapon_id": "mp5navy",
  "entity": "weapon_mp5navy",
  "asset_stem": "mp5",
  "models": {
    "view": "models/v_mp5.mdl",
    "player": "models/p_mp5.mdl",
    "world": "models/w_mp5.mdl"
  },
  "hud": {
    "layout": "sprites/weapon_mp5navy.txt"
  },
  "coverage": {
    "models": "verified",
    "sounds": "generated_unverified",
    "animations": "requires_mdl_scan",
    "events": "requires_mdl_scan"
  }
}
```

---

## 5. Viewmodel / weapon lifecycle

Нужен единый lifecycle для всех weapon assets:

| State                      | Что делает gameplay                                   | Что делает presentation                                            |
| -------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------ |
| `deploying`                | выбирает weapon, блокирует fire до deploy end         | load `v_*.mdl`, play `draw/deploy`, play draw sound if mapped      |
| `idle`                     | оружие готово                                         | play idle loop/sequence, apply bob/sway                            |
| `firing`                   | ammo--, hitscan/projectile, recoil/spread immediately | play fire animation, fire sound, muzzle flash, shell eject, tracer |
| `cooldown`                 | fire rate gate                                        | allow animation finish / recovery                                  |
| `reloading`                | lock fire, schedule ammo commit                       | reload animation + clipout/clipin/bolt/slide sounds                |
| `empty`                    | reject fire if no ammo                                | dryfire sound / empty animation                                    |
| `switching_out`            | validate interrupt rules                              | holster animation or fixed delay                                   |
| `dropping`                 | server creates dropped weapon state                   | instantiate `w_*.mdl`, pickup collider                             |
| `grenade_holding`          | pin pulled, wait release                              | hold animation, pin sound                                          |
| `grenade_throwing`         | spawn projectile at release time                      | throw animation, remove inventory item                             |
| `melee_windup/hit/recover` | delayed melee trace/window                            | slash/stab animation, hit/miss/wall sound                          |

Rule: **damage and ammo are server/gameplay events, not animation events.** Animation events only synchronize presentation.

---

## 6. MDL coverage

MDL надо читать в два этапа:

1. **metadata scan** без рендера;
2. runtime import/render.

Что обязательно извлекать:

| MDL metadata                       | Зачем                                                            |
| ---------------------------------- | ---------------------------------------------------------------- |
| `model_name`, checksum/source path | diagnostics/cache                                                |
| bones/skeleton                     | animation playback                                               |
| sequences                          | alias mapping: `idle`, `draw`, `fire`, `reload`, `throw`, `stab` |
| sequence fps/frame count/duration  | state machine timing                                             |
| sequence events                    | sounds, muzzleflash, shell, melee windows                        |
| attachments                        | muzzle/socket/shell origin                                       |
| hitboxes                           | player damage model                                              |
| bodygroups/skins                   | player/hostage variants, shield/silencer states                  |
| embedded textures                  | material construction                                            |
| bounding boxes                     | collision/pickup/display bounds                                  |

Публичный QC reference подтверждает, что animation events могут запускать звуки, sentence lines, muzzle flashes и другие события; 5000-series events используются для muzzleflash и требуют `$attachment` на модели. ([the303.org][3])

Для OpenStrike это означает: **не хардкодить muzzle/socket offsets до extractor’а**. Временный config offset разрешён, но должен иметь `confidence: "manual_unverified"`.

---

## 7. HUD / sprites coverage

HUD в CS 1.6 — это не “нарисовать UI руками”, а sprite/layout system.

Обязательные источники:

| Источник                       | Назначение                                                       |
| ------------------------------ | ---------------------------------------------------------------- |
| `sprites/hud.txt`              | общий sprite atlas registry                                      |
| `sprites/weapon_*.txt`         | weapon HUD icons, ammo icons, crosshair, autoaim/crosshair rects |
| `sprites/observer.txt`         | spectator HUD                                                    |
| `sprites/*.spr`                | actual sprite atlases/effects                                    |
| `resource/*.res`               | VGUI/menu layouts, если включаем classic shell                   |
| `titles.txt`, localization txt | текстовые сообщения                                              |

SDK-структура HUD прямо хранит массив sprites, rectangles и names, загружаемых из `hud.txt` и связанных sprites. ([GitHub][4])

OpenStrike должен покрыть:

| HUD элемент       | Источник                       | Runtime                 |
| ----------------- | ------------------------------ | ----------------------- |
| health            | hud sprites + game state       | bottom-left classic HUD |
| armor/helmet      | hud sprites + player equipment | armor indicator         |
| ammo clip/reserve | weapon layout + ammo state     | bottom-right            |
| weapon select     | weapon sprites                 | slot carousel           |
| crosshair         | weapon layout + spread state   | dynamic gap/visibility  |
| money             | HUD font/sprite or text style  | `$` amount              |
| round timer       | HUD font/sprite/text           | timer                   |
| buy icon          | game state + buyzone           | icon/message            |
| C4/defuse kit     | item state + sprites           | status icon             |
| death notice      | weapon kill icons              | killfeed                |
| radar             | overview files                 | minimap/radar           |
| spectator         | observer layout                | spectator mode          |
| scoreboard        | UI layout + game state         | TAB                     |

Coverage status: **layout parser можно делать сразу; визуальное совпадение требует локальной загрузки `hud.txt`, `weapon_*.txt` и sprites из установленной CS.**

---

## 8. Effects coverage

| Effect             | Asset source                                               | Trigger                            | Notes                                                      |
| ------------------ | ---------------------------------------------------------- | ---------------------------------- | ---------------------------------------------------------- |
| muzzle flash       | `sprites/muzzleflash*.spr`, `sprites/muz*.spr`, MDL events | accepted fire                      | first-person layer, random roll, short lifetime            |
| shell ejection     | `models/*shell*.mdl` or sprite fallback                    | fire timeline / MDL event / config | spawn from shell socket; fake physics acceptable initially |
| tracer             | sprite/beam/material config                                | weapon tracer policy               | not every shot                                             |
| bullet impact puff | `sprites/wall_puff*.spr`, material mapping                 | hitscan hit                        | material-aware later                                       |
| wall decal         | `decals.wad` / decal textures                              | hit result                         | persistent but capped                                      |
| blood              | blood sprites/decals                                       | hit flesh                          | team/player damage event                                   |
| explosion          | grenade sprites/sounds                                     | HE detonation                      | radius damage + sprite/sound                               |
| smoke              | smoke sprites                                              | smoke grenade lifecycle            | long-lived volume, not just sprite                         |
| flash              | mostly shader/screen effect + sounds                       | flashbang detonation               | asset-light, gameplay-heavy                                |
| water splash       | sprites/sounds                                             | hit water / movement               | material event                                             |
| dynamic light      | no asset or config                                         | muzzle/explosion                   | optional, short-lived                                      |

Strict rule: **нет procedural placeholder effect.** Если sprite отсутствует — warning и feature off.

---

## 9. Audio coverage

Audio mapping должен быть semantic, не filepath-driven.

| Audio domain     | Папки                                           | Trigger                         |
| ---------------- | ----------------------------------------------- | ------------------------------- |
| weapon fire      | `sound/weapons/*.wav`                           | `weapon.<id>.fire`              |
| reload fragments | `sound/weapons/*clipin/clipout/bolt/slide*.wav` | animation timeline              |
| dry fire         | weapon/common sounds                            | empty state                     |
| grenade          | pinpull, throw, bounce, explode                 | grenade lifecycle               |
| radio            | `sound/radio/*.wav`                             | radio command / bot comm        |
| player           | footsteps, pain, death, land, jump              | movement/damage state           |
| hostage          | hostage voice/actions                           | hostage AI                      |
| doors/buttons    | `sound/doors`, `sound/buttons`                  | BSP entity events               |
| debris/materials | `sound/debris`, `sound/materials.txt`           | breakable/impact/footstep       |
| ambient          | `sound/ambience`, entity keys                   | `ambient_generic`, map ambience |
| UI/menu          | shell/resource sounds                           | menu actions                    |

`materials.txt` is documented as the GoldSrc file that maps materials to footstep sounds, so material-aware audio should not be guessed only from texture prefixes. ([Valve Developer Community][7])

Coverage status:

| Item                                | Status                                |
| ----------------------------------- | ------------------------------------- |
| WAV loader                          | можно делать сразу                    |
| semantic event names                | можно делать вручную                  |
| exact per-weapon reload timing      | только extractor + manual calibration |
| first-person vs world audio routing | engine architecture                   |
| radio command catalog               | local scan + text/radio config        |

---

## 10. Map coverage

BSP map coverage is the biggest block.

| Map layer        | Source                              | Required OpenStrike behavior                 |
| ---------------- | ----------------------------------- | -------------------------------------------- |
| map list         | `maps/*.bsp`                        | map browser with status                      |
| map dependencies | `.res`, BSP entity paths, WAD names | dependency graph + missing files diagnostics |
| geometry         | BSP faces/edges/texinfo             | world mesh                                   |
| textures         | BSP miptex + WAD3                   | material creation                            |
| collision        | BSP clipnodes/hulls                 | player movement collision                    |
| entities         | BSP entity lump                     | spawn/buy/bomb/hostage/doors/triggers        |
| light            | lightmaps/lightstyles               | classic visual parity                        |
| visibility       | VIS/PVS                             | performance and correctness                  |
| sky              | worldspawn `skyname`, `gfx/env/*`   | skybox                                       |
| overview         | `overviews/<map>.txt`, `.bmp`       | radar/minimap                                |
| map cfg          | `maps/<map>.cfg` / server cfg       | optional cvar overrides                      |

`.res` files are important for custom maps because they enumerate assets such as WAV, TGA, MDL, SPR and WAD and preserve directory structure; Valve issue reports also show that CS fastdownload depends on valid paths inside `.res`. ([Valve Developer Community][2]) ([GitHub][8])

## 10.1 Entity coverage

| Entity class                                       |    Priority | OpenStrike adapter                          |
| -------------------------------------------------- | ----------: | ------------------------------------------- |
| `worldspawn`                                       |          P0 | map name, skyname, WAD refs                 |
| `info_player_start` / deathmatch starts            |          P0 | fallback/player spawn                       |
| `info_player_terrorist`                            |          P0 | T spawn                                     |
| `info_player_counterterrorist`                     |          P0 | CT spawn                                    |
| `func_buyzone`                                     |          P0 | buy permission volume                       |
| `func_bomb_target` / `info_bomb_target`            |          P0 | bombsite                                    |
| `hostage_entity`                                   |          P1 | hostage spawn and model                     |
| `func_hostage_rescue` / rescue info                |          P1 | rescue zone                                 |
| `func_door`, `func_door_rotating`                  |          P1 | moving doors                                |
| `func_button`, `button_target`                     |          P1 | buttons/use targets                         |
| `trigger_multiple`, `trigger_once`, `trigger_hurt` |          P1 | trigger system                              |
| `armoury_entity`                                   |          P1 | map weapon spawn                            |
| `ambient_generic`                                  |          P1 | map ambience                                |
| `env_sprite`, `env_glow`, `env_smoke`              |          P2 | map visual sprite effects                   |
| `light`, `light_spot`, `light_environment`         |          P2 | if lightmaps absent or for dynamic behavior |
| `func_breakable`, `func_pushable`                  |          P2 | breakables/physics-ish                      |
| unknown entities                                   | P0 behavior | preserve metadata, do not crash             |

Counter-Strike FGD/public FGD references are useful for entity schema, but runtime truth still comes from BSP entity lump and GameDLL behavior. ReGameDLL’s FGD changelog also documents CS-specific entity notes like `hostage_entity`, `env_sprite`, `func_button`, `func_door_rotating`, `game_text`, and older limitations around `armoury_entity` and newer 1.6 weapons. ([GitHub][9])

---

## 11. Player model coverage

| Team              | Models                                    | Required extraction                    |
| ----------------- | ----------------------------------------- | -------------------------------------- |
| Terrorist         | `arctic`, `guerilla`, `leet`, `terror`    | model path, sequences, hitboxes, skins |
| Counter-Terrorist | `gign`, `gsg9`, `sas`, `urban`            | model path, sequences, hitboxes, skins |
| VIP               | `vip`                                     | VIP model/logic                        |
| Hostage           | `hostage` variants / hostage entity model | hostage animations, body/skin variants |

Runtime states to map:

```text
idle
walk
run
crouch
jump
swim/water optional
shoot
reload
die/death variants
hostage idle/follow/rescue/death
```

Coverage risk: player hitboxes and animation sequences are essential for gameplay parity; they must be extracted from the actual MDL, not guessed.

---

## 12. Buy/menu/UI coverage

Buy zone behavior is gameplay + map + UI. Public Counter-Strike docs describe buy zones as areas around team spawns where players can buy weapons/equipment, with team restrictions, time restrictions, money dependency, and old weapon dropping when buying into an occupied slot. ([counterstrike.fandom.com][10])

OpenStrike needs:

| UI block     | Assets/config                                             |
| ------------ | --------------------------------------------------------- |
| main menu    | `gfx/shell/*`, `resource/*.res`, localization text        |
| create game  | map list + cvars + game mode config                       |
| team select  | team/model UI + player model previews                     |
| buy menu     | weapon catalog, prices, team restrictions, ammo/equipment |
| options      | binds, mouse, audio, video, multiplayer name/spray        |
| MOTD         | `motd.txt` / server-provided text                         |
| command menu | `commandmenu.txt`                                         |
| scoreboard   | UI layout + game state                                    |
| console      | cvars/binds/config files                                  |

Coverage status: classic VGUI replication can wait, but **semantic buy flow cannot wait**. `func_buyzone` + `mp_buytime` + money + team restrictions must exist before a real CS loop.

---

## 13. Radar / overview coverage

Overview coverage requires:

```text
overviews/<map>.txt
overviews/<map>.bmp
map coordinate transform
zoom
origin
rotation
player blip rendering
C4 / hostage / teammate states
spectator overview mode
```

ModDB overview tutorial describes retail-like overviews for CS 1.6 / Condition Zero and uses `dev_overview` workflow to generate the map image and coordinate values. ([ModDB][5])

Coverage status: `overview.txt + bmp parser` can be implemented before full radar gameplay. Accurate radar blips need server snapshots.

---

## 14. VFS coverage

OpenStrike VFS must behave like a GoldSrc content resolver:

```text
requested semantic asset
  -> asset pack override
  -> cstrike root
  -> cstrike_addon/custom roots, if supported
  -> valve fallback
  -> PAK/WAD/container lookup where applicable
  -> diagnostics with tried paths
```

Xash3D FWGS explicitly advertises advanced VFS features such as `.pk3/.pk3dir`, GoldSrc FS compatibility, and fast case-insensitivity emulation; for OpenStrike the important part is not copying Xash code, but reproducing lookup semantics and diagnostics. ([GitHub][11])

Coverage requirements:

| Feature                          |           Priority |
| -------------------------------- | -----------------: |
| case-insensitive lookup          |                 P0 |
| `cstrike` over `valve` overlay   |                 P0 |
| normalized slash/path cache      |                 P0 |
| mounted custom asset pack        |                 P1 |
| PAK support                      |                 P1 |
| WAD registry                     |        P0 for maps |
| `.res` dependency graph          | P0 for custom maps |
| source provenance in diagnostics |                 P0 |

---

## 15. Coverage matrix

| Domain                  | Public knowledge coverage | Local extraction needed | OpenStrike target                |
| ----------------------- | ------------------------: | ----------------------: | -------------------------------- |
| Folder structure        |                      high |                  medium | VFS scanner                      |
| BSP format              |                      high |                 per-map | BSP typed loader                 |
| BSP entities            |               medium-high |                 per-map | entity adapter registry          |
| WAD textures            |                      high |         per-map/per-wad | WAD registry                     |
| Skyboxes                |                    medium |                 per-map | sky resolver                     |
| MDL format              |                      high |               per-model | metadata-first MDL scanner       |
| Weapon v/p/w convention |                      high |   per-weapon exceptions | weapon atlas                     |
| Sequence names          |                low-medium |                required | generated sequence table         |
| Sequence durations      |                       low |                required | generated timing table           |
| Animation events        |                    medium |                required | generated event table            |
| Attachments/sockets     |                    medium |                required | socket resolver                  |
| Player hitboxes         |                    medium |                required | damage model                     |
| HUD txt/sprite layout   |                      high |                required | HUD atlas parser                 |
| Weapon sprites          |                    medium |                required | weapon HUD atlas                 |
| Muzzle/shell sprites    |                    medium |                required | effect atlas                     |
| Sounds                  |                    medium |                required | audio event atlas                |
| Reload sound timing     |                       low |                required | weapon timeline config           |
| Map overviews           |               medium-high |                 per-map | overview parser                  |
| UI resources            |                    medium |                required | classic UI parser/approx         |
| Sprays/decals           |                    medium |                optional | decal/spray system               |
| Game rules numbers      |          public/community |   separate verification | gameplay config, not asset atlas |
| Network protocol        |                 not asset |               not in v1 | out of scope                     |

---

## 16. Нужный инструмент: `goldsrc_asset_atlas`

Markdown руками не решит задачу. Нужен extractor, который запускается на локальной CS 1.6 и генерирует diffable JSON/MD.

### Команда

```bash
openstrike-goldsrc-atlas \
  --half-life-dir "/path/to/Half-Life" \
  --mod cstrike \
  --out .local/asset_atlas \
  --no-copy-assets
```

### Outputs

```text
.local/asset_atlas/
  asset_inventory.generated.json
  weapon_assets.generated.json
  weapon_model_metadata.generated.json
  weapon_animation_sequences.generated.json
  weapon_animation_events.generated.json
  sprite_layouts.generated.json
  audio_inventory.generated.json
  map_inventory.generated.json
  map_dependencies.generated.json
  player_models.generated.json
  coverage_report.md
```

### Пример `coverage_report.md`

```text
CS 1.6 Asset Coverage Report

Install:
  mod root: cstrike
  fallback root: valve
  generated_at: ...

Weapons:
  ak47:
    view_model: ready
    player_model: ready
    world_model: ready
    hud_layout: ready
    fire_sounds: ready
    reload_sounds: partial
    sequences: ready
    mdl_events: ready
    attachments: ready
    confidence: extracted

Maps:
  de_dust2:
    bsp: ready
    entity_lump: ready
    wad_dependencies: ready
    overview: ready
    buyzones: ready
    bombsites: ready
    lightmaps: ready
    clipnodes: ready
```

---

## 17. Что должно попасть в репозиторий

В репозиторий можно и нужно положить:

```text
docs/CS16_ASSET_ORCHESTRATION_ATLAS.md
docs/CS16_ASSET_COVERAGE_POLICY.md
docs/CS16_ASSET_SCANNER_SPEC.md

data/config/asset_packs/goldsrc_cs16/
  semantic_manifest.schema.json
  weapon_assets.schema.json
  weapon_animation_aliases.json
  weapon_event_timelines.schema.json
  audio_events.schema.json
  effects.schema.json
  hud_layout.schema.json
  map_entities.schema.json

tools/goldsrc_asset_atlas/
  scanner source code
  README.md
```

Нельзя класть:

```text
generated JSON from a real CS install
any .bsp/.mdl/.spr/.wad/.wav/.bmp/.tga from Valve
local_goldsrc.json
absolute local paths
screenshots containing extracted assets, unless legal review says OK
```

OpenStrike project plan already фиксирует эту границу: проект читает карты, модели, текстуры, звуки и спрайты из локальной лицензионной копии, но не распространяет ассеты Valve; также запрещает копировать чужой код/ассеты и требует data-driven configs .

---

## 18. Definition of Done для PR-06 / atlas-first

PR-06 не должен начинаться с “покажем AK красиво”. Он должен начинаться с покрытия.

### Acceptance criteria

1. `docs/CS16_ASSET_ORCHESTRATION_ATLAS.md` добавлен.
2. Есть schema для semantic asset atlas.
3. Есть scanner skeleton, который:

   * монтирует `cstrike` и `valve`;
   * строит case-insensitive index;
   * находит `models`, `sprites`, `sound`, `maps`, `gfx/env`, `resource`;
   * не копирует ассеты;
   * пишет diagnostics.
4. Для weapon roster создаётся generated report:

   * model paths;
   * HUD layout file;
   * candidate sounds;
   * sequence list if MDL parser доступен;
   * missing coverage warnings.
5. Для maps создаётся generated report:

   * BSP exists;
   * `.res` exists / missing;
   * WAD deps;
   * entity class counts;
   * overview exists / missing.
6. Gameplay/presentation код не содержит прямых путей `models/v_*.mdl` или `sound/weapons/*.wav`.
7. Missing asset = warning + feature unavailable, not placeholder.
8. В PR описано, какие поля `verified`, какие `manual_unverified`, какие `unknown`.

---

## 19. Итог по покрытию

На сегодня можно считать **публично покрытыми**:

* структура доменов ассетов CS/GoldSrc;
* форматы BSP/MDL/SPR/WAD на уровне loader design;
* `.res` как карта зависимостей custom maps;
* `hud.txt`/sprite-layout подход;
* v/p/w weapon model convention;
* overview/radar file concept;
* FGD/entity vocabulary;
* общая audio/effect/event модель.

Нельзя считать покрытыми без локального extractor’а:

* точные sequence names/durations всех `v_*.mdl`;
* точные animation events всех моделей;
* attachment/socket transforms;
* reload fragment timings;
* точные sprite rects из локальных `hud.txt`/`weapon_*.txt`;
* полный audio-event mapping;
* per-map WAD/entity/overview completeness;
* hitboxes конкретных player models;
* все custom/server/community assets.

**Вывод:** разработчику нужно ставить не задачу “знать все ассеты”, а задачу “сделать систему, которая доказывает, что она знает ассеты конкретной установки”. Ручной markdown — контракт. Истина — generated atlas из локальной CS 1.6.

[1]: https://developer.valvesoftware.com/wiki/BSP_%28GoldSrc%29?utm_source=chatgpt.com "BSP (GoldSrc)"
[2]: https://developer.valvesoftware.com/wiki/Porting_maps_from_one_mod_to_another_%28GoldSrc%29 "Porting maps from one mod to another - Valve Developer Community"
[3]: https://the303.org/tutorials/gold_qc.htm "GOLDSRC MDL QC COMMANDS"
[4]: https://github.com/ValveSoftware/halflife/blob/master/cl_dll/hud.h "halflife/cl_dll/hud.h at master · ValveSoftware/halflife · GitHub"
[5]: https://www.moddb.com/tutorials/map-overview-creation-for-gold-source-engine-games "Map Overview Creation for Gold Source engine games tutorial - ModDB"
[6]: https://wiki.alliedmods.net/Cs_weapons_information "Cs weapons information - AlliedModders Wiki"
[7]: https://developer.valvesoftware.com/wiki/Materials.txt?utm_source=chatgpt.com "Materials.txt"
[8]: https://github.com/ValveSoftware/halflife/issues/234?utm_source=chatgpt.com "[CS 1.6] When downloading maps with fastdownload, files ..."
[9]: https://raw.githubusercontent.com/rehlds/ReGameDLL_CS/master/regamedll/extra/Toolkit/GameDefinitionFile/regamedll-cs.fgd "raw.githubusercontent.com"
[10]: https://counterstrike.fandom.com/wiki/Buy_zone "Buy zone | Counter-Strike Wiki | Fandom"
[11]: https://github.com/fwgs/xash3d-fwgs?utm_source=chatgpt.com "Xash3D FWGS engine"
