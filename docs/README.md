# OpenStrike Documentation

This directory is the source of truth for project context. New agents and contributors should read these documents before changing code.

## Start here

- [`../AGENTS.md`](../AGENTS.md) - rules for agents and contributors.
- [`project-status.md`](project-status.md) - current implemented state and manual validation record.
- [`roadmap.md`](roadmap.md) - issue-backed roadmap.
- [`architecture.md`](architecture.md) - module layout and current technical architecture.
- [`first_vision.md`](first_vision.md) - original long-form technical vision and staged MVP plan.
- [`legal_policy.md`](legal_policy.md) - clean-room legal guardrails.
- [`asset_policy.md`](asset_policy.md) - what may and may not be committed.

## Architecture Decision Records

ADRs live in [`adr/`](adr/). Add or update an ADR when a decision affects future direction.

Current ADRs:

- [`0001-clean-room-and-local-resources.md`](adr/0001-clean-room-and-local-resources.md)
- [`0002-config-first-resource-roots.md`](adr/0002-config-first-resource-roots.md)
- [`0003-native-macos-bootstrap-before-final-renderer.md`](adr/0003-native-macos-bootstrap-before-final-renderer.md)

## Documentation rules

- If a PR changes architecture, update docs in the same PR.
- If a PR completes a roadmap task, close or update the linked GitHub issue.
- If a decision changes, add a new ADR rather than silently rewriting history.
- Keep terms neutral and independent. Do not make OpenStrike branding depend on third-party product names.
