# ADR 0002: Config-first resource roots

## Status

Accepted

## Context

OpenStrike needs access to local user-provided files, but the runtime UI should not ask the user to browse for a specific commercial game folder or imply affiliation with a rights holder.

## Decision

Resource roots are configured through `config.toml`, not through an in-game asset picker.

Default config path on macOS:

```text
~/Library/Application Support/OpenStrike/config.toml
```

The config uses neutral terminology:

```toml
[resources]
roots = [
  "/absolute/path/to/local/user/files"
]
```

Configured roots are mounted read-only. The app creates a template config when missing.

## Consequences

Positive:

- Startup remains explicit and auditable.
- The UI does not need to mention third-party products.
- Works well for local development and CLI tools.

Negative:

- Manual config editing is less convenient for non-technical users.
- A sandboxed app-store style build may later need security-scoped bookmarks or a separate permission workflow.

## Alternatives considered

- Runtime folder picker: deferred.
- Auto-discovery of installed games or store directories: rejected.
- Storing resources inside the repository: rejected.
