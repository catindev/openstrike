# Local GoldSrc Configuration

OpenStrike reads Counter-Strike 1.6 and Half-Life assets from a user's local,
licensed installation. The local path file is named `local_goldsrc.json` and
must not be committed.

## Default location

Runtime code looks for the config at:

```text
user://local_goldsrc.json
```

Development tools may pass an explicit path to
`GoldSrcLocalConfig.new().load_from_file(path)`.

## Schema

```json
{
  "half_life_dir": "/absolute/path/to/Half-Life",
  "cstrike_dir": "/absolute/path/to/Half-Life/cstrike",
  "valve_dir": "/absolute/path/to/Half-Life/valve"
}
```

`half_life_dir` is required. If `cstrike_dir` or `valve_dir` are omitted, the
loader derives them from `half_life_dir`.

All paths should be absolute. Relative paths produce diagnostics because they
make asset resolution dependent on the current working directory.

## Search order

The initial VFS searches roots in this order:

1. `cstrike_dir`
2. `valve_dir`
3. `half_life_dir`

This gives mod content priority over base Half-Life content. PAK and WAD
container lookup will be added after raw filesystem lookup is stable.

## Path rules

VFS requests are relative GoldSrc paths such as:

```text
sprites/hud.txt
sound/weapons/ak47-1.wav
models/v_ak47.mdl
```

Absolute paths, empty paths and parent traversal such as `../config.cfg` are
rejected with diagnostics.

The VFS performs case-insensitive lookup so assets can be resolved on
case-sensitive host filesystems.
