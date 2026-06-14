# Coverage Status Contract (`stage` x `confidence`)

**Status:** Normative. Single status vocabulary for the asset atlas, the scanner
output, and the coverage matrix. Replaces the three earlier overlapping
vocabularies.

The matrix is **machine-generated** from one hand-edited source of truth
(`gen/coverage_status_matrix.json`) and **machine-checked** (`coverage_status.schema.json`,
enforced by smoke, SS6). The markdown table (SS3) and the JSON schema (Appendix A)
are GENERATED artifacts; do not hand-edit them. CI fails if they differ from a
fresh `gen/generate.py` run.

---

## 1. Two orthogonal axes (+ one separate capability flag)

A status is **always a pair**:

- **`stage`** - how far processing has gone for this field.
- **`confidence`** - how much the current value can be trusted (the TRUST axis).

These answer different questions and must not be collapsed into one word.

**Capability is not part of the status.** Whether the scanner *can* check a field
describes the tool, not the datum, so it is an optional boolean
`capability_scanner_supported`, never a confidence value. (PR-06B needs more than a
boolean - see SS7.)

```json
{ "stage": "parsed", "confidence": "local_verified", "capability_scanner_supported": true }
```

Note on naming: the "read from loader, not yet checked" trust state is
`unverified_read` - named for the *trust* it carries (unverified), not for its
provenance. An earlier draft called this `scanner_read`, which described where the
value came from rather than how much to trust it, and so kept leaking the
evidence/trust distinction back into the confidence axis. `unverified_read` lives
honestly on the trust axis.

---

## 2. Vocabularies

### `stage` (processing progress)

| value | meaning |
|---|---|
| `unknown` | not yet investigated |
| `not_applicable` | field does not apply to this asset type |
| `source_missing` | expected source file/key not found |
| `source_found` | file found, not yet parsed |
| `parsed` | metadata extracted from the source |
| `semantic_mapped` | parsed/seeded value bound to an OpenStrike semantic id |
| `orchestration_ready` | a runtime rule/lifecycle exists for it |
| `blocked` | cannot proceed without a decision or tool |

### `confidence` (trust in the value - RESULT axis only)

| value | meaning |
|---|---|
| `none` | no trust assigned yet (incl. "noted missing, not install-verified") |
| `hand_seeded` | value came from the committed hand-authored seed (mapping intent only) |
| `manual_unverified` | set by hand as a placeholder; must be replaced by an extractor |
| `unverified_read` | read mechanically from loader/importer; not checked against an install |
| `local_verified` | value confirmed against a licensed local CS 1.6 install |
| `synthetic_verified` | confirmed against a synthetic CI fixture (no Valve bytes) |
| `local_verified_absence` | the **absence** of the source was confirmed on a local install |

Provenance rule (keeps human-origin trust off filesystem/parse facts):
`hand_seeded` and `manual_unverified` are human-origin and valid **only** at the
intent stages `semantic_mapped` / `orchestration_ready` - never at `source_found`,
`source_missing`, or `parsed`, which are filesystem/parse *facts* a human seed
cannot establish.

---

## 3. Validity matrix (normative, generated)

A pair is valid **iff** the `confidence` appears in the row for its `stage`:

<!-- BEGIN GENERATED STATUS TABLE -->
| stage | allowed confidence |
|---|---|
| `unknown` | `none` |
| `not_applicable` | `none` |
| `source_missing` | `none`, `local_verified_absence` |
| `source_found` | `none`, `unverified_read` |
| `parsed` | `none`, `unverified_read`, `local_verified`, `synthetic_verified` |
| `semantic_mapped` | `none`, `hand_seeded`, `unverified_read`, `manual_unverified`, `local_verified`, `synthetic_verified` |
| `orchestration_ready` | `none`, `hand_seeded`, `unverified_read`, `manual_unverified`, `local_verified`, `synthetic_verified` |
| `blocked` | `none`, `unverified_read` |
<!-- END GENERATED STATUS TABLE -->

Two invariants are baked into the table and **also asserted directly** in smoke,
so a future source-of-truth edit that breaks them is caught:

- **Invariant A - no value-verified before parse.** `local_verified` /
  `synthetic_verified` require `stage >= parsed`. A verified trust on an unparsed
  source is meaningless - the "looks strong, backs nothing" failure this contract
  exists to prevent.
- **Invariant B - absence is its own confidence.** Verified *absence* is
  `local_verified_absence` at `stage = source_missing` only, never `local_verified`,
  so "verified-present" aggregates cannot be inflated by verified-missing fields.

---

## 4. Transitions that matter

### PR-05 seed catalog -> local report (committed seed is immutable)

The committed `cs16_pilot_weapon_assets.json` seed starts at:

```
stage = semantic_mapped, confidence = hand_seeded
```

The scanner validates/enriches it **into a local, git-ignored report only**. The
promotion `hand_seeded -> local_verified` (and stage advance) happens in that local
report, never written back into the committed seed. The scanner never writes
Valve-derived metadata into committed files.

### Read-then-verify

```
source_found / unverified_read
  -> parsed / unverified_read     (auto-parsed from loader, not yet install-checked)
  -> parsed / local_verified      (after a licensed-install run)
```

### Missing

```
source_missing / none                    (noted missing; not install-verified, e.g. CI/synthetic)
source_missing / local_verified_absence  (confirmed missing on a licensed install)
```

---

## 5. CI vs local boundary

CI has no licensed install and commits no Valve bytes, so it can only prove the
lower-trust states; `local_verified` / `local_verified_absence` are **local**
evidence.

| Provable in CI | Local-only |
|---|---|
| `unverified_read`, `synthetic_verified`, `source_missing/none`, schema validity, lint, path normalization, forbidden-asset scan, profile math | `local_verified`, `local_verified_absence` |

A green CI run never implies `local_verified`; it implies `scanner_ready /
schema_valid / synthetic_passed / no_forbidden_assets`.

---

## 6. Smoke obligation (`coverage_status_smoke.gd` + a generation check)

1. **Generation check (makes "one source of truth" real):** run `gen/generate.py`;
   fail if the committed `coverage_status.schema.json` or the SS3 table differ from
   the freshly generated output. `gen/coverage_status_matrix.json` is the ONLY
   hand-edited artifact.
2. Validate every status pair in committed seed/schema fixtures against
   `coverage_status.schema.json`.
3. Assert Invariant A directly (independent of the table): `confidence in
   {local_verified, synthetic_verified}` => `stage in {parsed, semantic_mapped,
   orchestration_ready}`.
4. Assert Invariant B directly: `local_verified_absence` => `stage == source_missing`.
5. Assert provenance rule: `hand_seeded`/`manual_unverified` => `stage in
   {semantic_mapped, orchestration_ready}`.

---

## 7. Capability for PR-06B (not just a boolean)

The boolean `capability_scanner_supported` is enough for a *status record*, but
PR-06B's MDL-API inspection must classify *how* a field is obtainable, or it will
hide uncertainty behind a boolean (the "where available" trap). PR-06B uses a
capability enum per field:

```
unsupported
supported_by_loader_api
supported_by_imported_scene_inspection
requires_openstrike_mdl_reader
deferred
```

Example: `mdl.attachments -> { scanner_supported: false, method:
requires_openstrike_mdl_reader, checked_in_pr: PR-06B }`. This is the contract for
the PR-06B spike; this document only owns the status pair, not the capability enum.

---

## Appendix A - `coverage_status.schema.json` (generated)

<!-- BEGIN GENERATED COVERAGE STATUS SCHEMA -->
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://openstrike/schemas/coverage_status.schema.json",
  "title": "OpenStrike asset coverage status (stage x confidence)",
  "type": "object",
  "required": [
    "stage",
    "confidence"
  ],
  "additionalProperties": true,
  "properties": {
    "stage": {
      "enum": [
        "unknown",
        "not_applicable",
        "source_missing",
        "source_found",
        "parsed",
        "semantic_mapped",
        "orchestration_ready",
        "blocked"
      ]
    },
    "confidence": {
      "enum": [
        "none",
        "hand_seeded",
        "manual_unverified",
        "unverified_read",
        "local_verified",
        "synthetic_verified",
        "local_verified_absence"
      ]
    },
    "capability_scanner_supported": {
      "type": "boolean",
      "description": "Capability, NOT result. Whether the scanner CAN check this field. PR-06B uses a richer capability enum; see PR-06B spec."
    }
  },
  "allOf": [
    {
      "if": {
        "properties": {
          "stage": {
            "const": "unknown"
          }
        }
      },
      "then": {
        "properties": {
          "confidence": {
            "enum": [
              "none"
            ]
          }
        }
      }
    },
    {
      "if": {
        "properties": {
          "stage": {
            "const": "not_applicable"
          }
        }
      },
      "then": {
        "properties": {
          "confidence": {
            "enum": [
              "none"
            ]
          }
        }
      }
    },
    {
      "if": {
        "properties": {
          "stage": {
            "const": "source_missing"
          }
        }
      },
      "then": {
        "properties": {
          "confidence": {
            "enum": [
              "none",
              "local_verified_absence"
            ]
          }
        }
      }
    },
    {
      "if": {
        "properties": {
          "stage": {
            "const": "source_found"
          }
        }
      },
      "then": {
        "properties": {
          "confidence": {
            "enum": [
              "none",
              "unverified_read"
            ]
          }
        }
      }
    },
    {
      "if": {
        "properties": {
          "stage": {
            "const": "parsed"
          }
        }
      },
      "then": {
        "properties": {
          "confidence": {
            "enum": [
              "none",
              "unverified_read",
              "local_verified",
              "synthetic_verified"
            ]
          }
        }
      }
    },
    {
      "if": {
        "properties": {
          "stage": {
            "const": "semantic_mapped"
          }
        }
      },
      "then": {
        "properties": {
          "confidence": {
            "enum": [
              "none",
              "hand_seeded",
              "unverified_read",
              "manual_unverified",
              "local_verified",
              "synthetic_verified"
            ]
          }
        }
      }
    },
    {
      "if": {
        "properties": {
          "stage": {
            "const": "orchestration_ready"
          }
        }
      },
      "then": {
        "properties": {
          "confidence": {
            "enum": [
              "none",
              "hand_seeded",
              "unverified_read",
              "manual_unverified",
              "local_verified",
              "synthetic_verified"
            ]
          }
        }
      }
    },
    {
      "if": {
        "properties": {
          "stage": {
            "const": "blocked"
          }
        }
      },
      "then": {
        "properties": {
          "confidence": {
            "enum": [
              "none",
              "unverified_read"
            ]
          }
        }
      }
    }
  ]
}
```
<!-- END GENERATED COVERAGE STATUS SCHEMA -->

---

## Appendix B - what changed from the prior draft, and why

1. **`scanner_read` -> `unverified_read`**, redefined as a trust state, not a
   provenance/evidence tag. The old name kept evidence and trust conflated and made
   the read-then-verify transition incoherent.
2. **Matrix tightened to forbid contradictory pairs:** `unknown` and `source_found`
   no longer allow `hand_seeded` (a seed expresses mapping intent, not a filesystem
   fact); `parsed` no longer allows `manual_unverified` (extracted != hand-set);
   `source_missing` no longer carries a "read" confidence (nothing is read when the
   file is absent) - only `none` or `local_verified_absence`.
3. **"Generated from one source" made real:** `gen/coverage_status_matrix.json` is
   the sole hand-edited source; schema + table are generated; CI diffs them (SS6.1).
4. **Capability split for PR-06B (SS7):** a richer capability enum replaces a bare
   boolean for MDL-field inspection.

The matrix passes a self-test before shipping: invariant audit clean, every real
field state has a valid home (the tightening false-rejects nothing), and all five
formerly-wrong pairs are now rejected.
