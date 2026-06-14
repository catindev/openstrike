#!/usr/bin/env bash
set -euo pipefail

matches="$(
	find . \
		-path ./.git -prune -o \
		-path ./.godot -prune -o \
		-type f \( \
			-name '*.bsp' -o \
			-name '*.mdl' -o \
			-name '*.spr' -o \
			-name '*.wad' -o \
			-name '*.wav' -o \
			-name '*.bmp' -o \
			-name 'local_goldsrc.json' -o \
			-name 'local_goldsrc.*.json' \
		\) -print
)"

if [[ -n "${matches}" ]]; then
	echo "Forbidden local GoldSrc/Valve asset or user config files found:" >&2
	echo "${matches}" >&2
	exit 1
fi

echo "Forbidden asset scan passed."
