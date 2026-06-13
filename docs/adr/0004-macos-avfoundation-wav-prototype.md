# ADR 0004: macOS AVFoundation WAV playback prototype

## Status

Accepted

## Context

OpenStrike needs a minimal read-only audio milestone before a full audio system exists. The immediate requirement is to validate local user-provided WAV files and prove that the project can trigger simple playback on the macOS-first target without committing proprietary sounds or generated audio.

The final engine audio architecture still needs later work: mixer ownership, streaming, emitters, resource lifetime, latency targets, and cross-platform backend policy are not settled yet.

## Decision

Use a narrow prototype path:

- `WaveAudio` performs clean-room RIFF/WAVE PCM metadata validation in engine loader code.
- `OpenStrikeWavPlay` prints metadata and supports `--dry-run` for automated validation.
- On macOS, `OpenStrikeWavPlay` uses AVFoundation `AVAudioPlayer` to play the validated local WAV file.
- On non-macOS platforms, the tool builds with a stub playback backend and still supports metadata validation through `--dry-run`.

This decision is limited to the prototype CLI and does not establish AVFoundation as the final engine audio backend.

## Consequences

Positive:

- Keeps the first audio milestone small and testable.
- Uses a native macOS playback path without adding third-party dependencies.
- Preserves read-only handling of user-provided audio files.
- Keeps CI portable through a non-macOS stub.

Negative:

- Playback is macOS-only in this prototype.
- The CLI delegates actual audio device output to AVFoundation.
- A future audio system will need a real backend abstraction and likely a mixer.

## Alternatives considered

- Implement a custom CoreAudio queue immediately: deferred because it is more code than needed for the first WAV milestone.
- Add SDL/OpenAL/miniaudio now: deferred until renderer/audio dependency policy is broader than one debug tool.
- Metadata-only WAV inspection: rejected because #19 explicitly asks for a playback prototype.
