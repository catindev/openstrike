# Release policy

Openstrike uses versioned releases.

## Version meaning

- `0.1.0`: project foundation and local debug sandbox.
- `0.x.y`: unstable development releases.
- `1.0.0`: first complete compatibility target.

## Release requirements

A release may be tagged only when:

- the repository builds or the release is explicitly docs-only;
- release notes list user-visible changes;
- no third-party game data is bundled;
- known gaps are documented;
- local setup instructions are current.

## Release notes template

```md
# Openstrike vX.Y.Z

## Added

## Changed

## Fixed

## Known gaps

## Verification

## Asset note

This package contains Openstrike code and documentation only. Users must provide their own legal local installation for original game data.
```
