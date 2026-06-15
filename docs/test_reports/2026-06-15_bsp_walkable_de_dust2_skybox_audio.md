# BSP Walkable Lab: de_dust2 Skybox and Movement Audio

Date: 2026-06-15

## Command

```sh
Godot --path . --script res://src/dev/labs/bsp_walkable/bsp_walkable_lab.gd -- --map=maps/de_dust2.bsp
```

Primary telemetry session: `user://telemetry/bsp_walkable/20260615_102118_3753/`

Follow-up skybox telemetry session:
`user://telemetry/bsp_walkable/20260615_104314_4358/`

## User-Visible Observations

* Previous user feedback after the texture/WAD pass: the map looked close to
  the real game, with the missing skybox being the main visual gap.
* This run was launched after adding fullscreen, `worldspawn.skyname` skybox
  loading and basic first-person movement sounds.
* The first skybox implementation found all `des*.tga` faces but still showed
  black sky because imported BSP `sky` render meshes occluded the background.
* Hiding imported `sky` render meshes exposed the local cubemap, but drawing
  it as in-world quads made the faces visibly square.
* The latest follow-up renders the faces through a Godot environment panorama.
  The sky is now visible in the map view, but the panorama bridge still shows
  cubemap seam/blockiness artifacts.
* User feedback: the jump sound is not the original map/game sound, but exact
  movement-audio parity is not a target for this PR.
* The application exited through the normal window lifecycle; Esc is not bound
  to quit.

## Trace and Log Facts

* Session status: `exit_tree`.
* Duration: `281.58s`, `28158` movement ticks.
* Window: `fullscreen=true`.
* Collision source: `godot_scene_collision`; GoldSrc hull trace remains
  `requires_openstrike_bsp_reader`.
* `worldspawn.skyname=des`; first skybox status `loaded`.
* Loaded skybox faces:
  `gfx/env/desft.tga`, `desbk.tga`, `deslf.tga`, `desrt.tga`,
  `desup.tga`, `desdn.tga`.
* Follow-up skybox status: `loaded_panorama`, render mode
  `environment_panorama`, generated panorama size `1024x512`.
* Imported BSP sky render meshes hidden in the lab: `33` mesh instances
  matching `MeshInstance3D.name == sky`.
* Movement audio files loaded:
  `4` footstep WAVs, `2` jump WAVs and `1` landing WAV.
* Movement audio events recorded:
  `529` footsteps, `30` jump sounds, `57` landing sounds.
* Input/movement facts:
  `33` jump presses, `273` duck ticks, `2581` air ticks,
  `25577` floor ticks.
* Step bridge facts:
  `593` step-up attempts, `30` step-up successes.
* Speed facts:
  max horizontal speed `271.99 ups`; max total speed `536.39 ups`.
* Non-blocking map collisions disabled for `50` trigger/light/illusionary
  entities, affecting `64` collision objects and `64` collision shapes.

## Conclusions

* The BSP lab now validates a much stronger real-map presentation path:
  textures, skybox, fullscreen first-person view and basic movement audio all
  resolve from the local licensed installation without committing asset bytes.
* The skybox path is good enough to prove that local `worldspawn.skyname`
  resolution works and that imported BSP sky render meshes must not occlude the
  background. The current equirectangular panorama conversion is still visibly
  imperfect, so skybox parity remains a follow-up, not done.
* Basic movement sounds load and are traceable. Exact jump sound parity and
  material-aware footsteps remain deferred until the engine has reliable
  surface/material tracing and an audio event contract.
* The movement/collision bridge is still not final parity: horizontal speed can
  exceed the 250 ups lab cap during real-map movement, and step-up behavior is
  mediated by Godot scene collision rather than GoldSrc hull tracing.

## Next Actions

* Keep PR-07 focused on the real-BSP walkable lab and telemetry contract.
* Reviewers should treat the skybox as a dev-stand bridge with known visual
  artifacts. Before polishing it, verify the correct GoldSrc cubemap face
  orientation and whether Godot should use a proper cubemap/canvas path instead
  of the current generated equirectangular panorama.
* Next map-work PR should prioritize GoldSrc hull/clipnode trace investigation
  before deeper movement tuning on `de_dust2`.
* Add material-aware footstep routing only after the map collision/surface
  query contract can report reliable surface/material data.
