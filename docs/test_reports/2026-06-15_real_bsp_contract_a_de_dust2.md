# 2026-06-15 Real BSP Contract A Diagnostic

## Scope

This report records a local licensed `maps/de_dust2.bsp` inspection for the
PR-08B hull-extent Contract A question. The goal was to check whether the
synthetic runtime plane-offset fixture can be promoted toward real BSP30
clipnodes.

This was not a movement, PMove or contact-golden test.

## Command

```text
Godot --headless --path . --script res://src/dev/tools/bsp30_real_map_contract_a_inspect.gd -- --map=maps/de_dust2.bsp
```

The run used `user://local_goldsrc.json` and a local licensed GoldSrc
installation. No Valve asset bytes, extracted BSP lumps, local absolute paths
or generated telemetry dumps are committed.

## Observations

* The tool resolved `maps/de_dust2.bsp` through the GoldSrc VFS and loaded it
  into `OpenStrikeBspMapResource`.
* The BSP parsed as version 30 with no reader diagnostics.
* Collision-relevant typed data was present:
  * planes: 9,582
  * clipnodes: 8,321
  * models: 43
* Model 0 exposed these headnodes:
  * `headnode[0] = 0`
  * `headnode[1] = 0`
  * `headnode[2] = 2350`
  * `headnode[3] = 4521`
* Standing and duck hull roots were distinct for model 0:
  * standing hull reachable clipnodes: 2,350
  * duck hull reachable clipnodes: 2,837
* The standing and duck tree walks reported no invalid references.

## Conclusion

The real-map inspection shows separate model-0 clipnode trees for standing and
duck hulls. That is evidence for compiled hull-specific collision data in the
real BSP30 map and is not compatible with promoting PR-08B's synthetic
runtime-offset Contract A as a general real-map assumption.

Contract A remains valid only for the PR-08B synthetic point-space fixture.
Real BSP collision work must not apply runtime hull extents on licensed map
clipnodes until a later contact-level diagnostic proves the plane-space
contract.

## Next Actions

* Keep `OpenStrikeBspClipnodeTraceBackend` marked as synthetic-only.
* Continue with backend capability integration only after preserving this
  Contract A boundary.
* Add a later real-map contact diagnostic before using BSP clipnodes as PMove
  authority.
