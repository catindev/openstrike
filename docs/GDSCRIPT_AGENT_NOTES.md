# GDScript Agent Notes

This document records GDScript and Godot-specific issues that caused agent
slowdowns during implementation. Add new entries when a parser, type system,
runtime or tooling behavior is easy to miss and likely to affect future agents.

## Rules

* Prefer explicit types in smoke tests and core scripts when a value comes from
  Godot built-ins that may return `Variant`.
* Fix the first parser or dependency compile error before chasing follow-up
  runtime messages. Godot often reports cascade errors after a dependency fails
  to compile.
* Append new dated findings instead of replacing previous agents' notes.
* Keep examples short and concrete. This is a working memory file, not a style
  guide.

## 2026-06-14: `clamp()` and inferred local variable types

### Symptom

Godot 4.6 failed to compile `cs_movement_input.gd` with:

```text
Parse Error: Cannot infer the type of "forward" variable because the value doesn't have a set type.
Parse Error: Cannot infer the type of "side" variable because the value doesn't have a set type.
```

The failing code used `:=` with arithmetic over `clamp()` results:

```gdscript
var forward := clamp(forward_state, 0.0, 1.0) - clamp(back_state, 0.0, 1.0)
```

### Cause

`clamp()` can leave the expression typed as `Variant` in this context, so
GDScript cannot infer the local variable type from `:=`.

### Fix

Use explicit local variable types and cast the `clamp()` result before doing
arithmetic:

```gdscript
var forward: float = (
	float(clamp(forward_state, 0.0, 1.0))
	- float(clamp(back_state, 0.0, 1.0))
)
```

### Follow-up error to ignore until the parse error is fixed

After the dependency script failed to compile, Godot also reported:

```text
Invalid call. Nonexistent function 'new' in base 'GDScript'.
```

In this case it was a cascade error from the failed preload dependency, not a
real missing constructor. Fix the earliest parse error first, then rerun the
smoke test.

## 2026-06-14: Avoid self-constructing `class_name` from a static method

### Symptom

Linux CI failed to compile `cs_movement_input.gd` with:

```text
Compile Error: Identifier not found: CSMovementInput
```

The failing line was inside the same script that declared
`class_name CSMovementInput`:

```gdscript
static func from_button_states(...):
	return CSMovementInput.new(...)
```

This passed on the local macOS Godot run but failed in the Linux CI smoke job.

### Cause

Do not rely on a script's own global `class_name` being available inside that
script during static method compilation. Import/cache timing can differ across
environments.

### Fix

Keep static helpers pure when they live on the same script, and construct the
object from an already preloaded script reference at the call site:

```gdscript
static func button_axis(positive_state: float, negative_state: float) -> float:
	return float(clamp(positive_state, 0.0, 1.0)) - float(clamp(negative_state, 0.0, 1.0))
```

```gdscript
var input = MovementInputRef.new(
	MovementInputRef.button_axis(forward_state, back_state),
	MovementInputRef.button_axis(right_state, left_state)
)
```

When local Godot and CI disagree, trust CI and record the portability issue
here.
