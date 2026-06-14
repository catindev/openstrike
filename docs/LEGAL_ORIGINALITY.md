# Legal Originality and Licensing

OpenStrike is committed to respecting the intellectual property of others while delivering a faithful reimplementation of *Counter‑Strike 1.6*.  This document clarifies the legal boundaries of the project and how we handle original and third‑party materials.

## No Valve assets included

OpenStrike does **not** include any game data from *Half‑Life* or *Counter‑Strike*.  Assets such as maps (`.bsp`), models (`.mdl`), sprites (`.spr`), textures (`.wad`), sounds (`.wav`/`.bmp`) and any other proprietary resources are the property of Valve and must never be distributed with this project.

To play OpenStrike, users **must own a licensed copy** of *Counter‑Strike 1.6* or *Half‑Life*.  The engine will read assets from the user’s local installation via a configuration file (`local_goldsrc.json`), which remains solely on the user’s machine.

## Source code

Only original code resides in this repository.  Contributors may refer to the behaviour, file format specifications and numerical values of existing engines (GoldSrc, Xash3D, HLSDK) as reference, but **copying source code** from these projects is forbidden.  In particular:

* Do not copy or port code from Valve’s SDK or HLSDK.
* Do not import GPL‑licensed code from projects like Xash3D into OpenStrike.

Reimplementations of behaviour or loaders may use publicly known specifications and constants, but the implementations themselves must be original.

## Distribution and usage

OpenStrike itself is distributed under the MIT License (see `LICENSE`).  This license applies only to the code in this repository.  When users run OpenStrike with their own *Counter‑Strike* assets, they must abide by Valve’s end‑user license agreement.  Distribution of proprietary assets alongside OpenStrike is strictly prohibited.

## Reference sources

The following sources may be consulted **as reference only** to verify behaviour and specifications:

* Valve Developer Community articles.
* Godot documentation.
* Projects like OpenMW and OpenRA (for architectural inspiration).
* Xash3D FWGS and HLSDK codebases for understanding behaviours, formats and tests—**not** for copying code.
* Internal prototypes such as Readytostrike.

Always clearly mark any imported facts from these sources in documentation with a `reference only` note, and do not treat them as a licensing basis for copying.
