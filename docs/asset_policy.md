# Asset Policy

OpenStrike does not ship with proprietary game assets.

## Allowed assets

Assets may be committed only if they are:

- original assets created specifically for OpenStrike;
- public-domain assets;
- CC0 assets;
- permissively licensed assets with attribution and license files;
- synthetic test files generated for loader tests.

Every committed asset must have a clear license record.

## Disallowed assets

Do not commit:

- commercial game maps;
- commercial game WAD archives;
- commercial game models;
- commercial game sprites;
- commercial game sounds;
- commercial game textures;
- commercial game fonts;
- commercial game icons;
- commercial game configs;
- demo files;
- binary archives extracted from commercial game installations.

## User resources

User-provided resource roots are configured locally through `config.toml`. They are not copied into this repository and are not modified by the engine.

## Scanning

The `tools/asset_audit/asset_audit.py` script is a first-pass guardrail against accidentally committing suspicious legacy resource files. It is not a legal review substitute.
