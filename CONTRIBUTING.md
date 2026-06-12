# Contributing to OpenStrike

OpenStrike is a clean-room project. Contributions must preserve that boundary.

## Contribution certificate

By contributing, you certify that:

- You did not copy proprietary source code.
- You did not use leaked or decompiled code.
- You did not add proprietary assets.
- You did not add trademarks, logos, original commercial UI, or branded game content.
- All new assets have an explicit open-source license.
- Compatibility work is based on public documentation, clean-room research, or black-box testing with locally owned files.

## Assets

Do not commit user-provided commercial game files. This includes, but is not limited to:

- maps;
- textures;
- models;
- sprites;
- sounds;
- fonts;
- icons;
- configuration files extracted from commercial games;
- demo files;
- binary archives from commercial games.

Only original or explicitly open-source assets may be committed.

## Code style

- C++20 is the baseline for engine/runtime code.
- Prefer small, testable modules.
- Binary file loaders must use bounds-checked reads.
- Resource roots must be treated as read-only.
- Avoid global state except for narrow platform/bootstrap boundaries.

## Pull requests

Every PR should include:

- a concise summary;
- build/test notes;
- confirmation that no proprietary assets or code were added.
