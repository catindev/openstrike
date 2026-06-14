# OpenStrike

**OpenStrike** is a free and open‑source reimplementation of *Counter‑Strike 1.6* built on the Godot 4 game engine.  The goal of the project is to allow owners of a legitimate copy of *Counter‑Strike 1.6* / *Half‑Life* to play the game on modern and otherwise unsupported platforms (such as macOS) without bundling any proprietary assets.

This repository contains only the source code for the OpenStrike engine.  **No Valve assets are included**, and OpenStrike will not run without a local installation of *Half‑Life* or *Counter‑Strike 1.6*.  Users must supply their own game data; the engine reads assets from the local installation via a future `local_goldsrc.json` configuration file (which should **never be committed** to this repository).

## Project status

The current milestone is **`0.1.0`** (`0.1.0-dev` in code), which focuses on bootstrapping the project with a minimal Godot project and documentation.  The first working target platform is macOS.  Future milestones will add an asset manager, movement parity with the original game, BSP loading, server‑authoritative game loop and eventually a full feature set comparable to *Counter‑Strike 1.6*.

## Getting started

* Clone this repository and open it in Godot 4.x.
* When first run you will see a bootstrap screen with the name, version and legal notice.
* You must own a licensed copy of *Counter‑Strike 1.6* / *Half‑Life* and point OpenStrike to your local installation in a later milestone; this PR does not yet implement asset loading.

## Development

Development follows **GitHub Flow**: every task is implemented in its own branch and submitted as a pull request.  See the `docs/` directory for the roadmap, development plan and architecture.  In particular, please consult **`AGENTS.md`** for AI‑agent guidelines and non‑negotiable legal rules before contributing.

Documentation lives in the `docs/` directory.  The `local_goldsrc.json` configuration file mentioned in the docs will be created by users locally and must **never** be committed to the repository.
