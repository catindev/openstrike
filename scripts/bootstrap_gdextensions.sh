#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
extension_entry="res://addons/goldsrc/goldsrc.gdextension"
extension_file="${project_root}/addons/goldsrc/goldsrc.gdextension"
extension_list="${project_root}/.godot/extension_list.cfg"
bin_dir="${project_root}/addons/goldsrc/bin"

remove_extension_entry() {
	if [[ ! -f "${extension_list}" ]]; then
		return
	fi

	local tmp_file
	tmp_file="$(mktemp "${extension_list}.XXXXXX")"
	grep -vxF "${extension_entry}" "${extension_list}" > "${tmp_file}" || true
	if [[ -s "${tmp_file}" ]]; then
		mv "${tmp_file}" "${extension_list}"
	else
		rm -f "${extension_list}" "${tmp_file}"
	fi
}

add_extension_entry() {
	mkdir -p "$(dirname "${extension_list}")"
	touch "${extension_list}"
	if ! grep -qxF "${extension_entry}" "${extension_list}"; then
		printf '%s\n' "${extension_entry}" >> "${extension_list}"
	fi
}

native_library_candidates() {
	local os_name arch_name
	os_name="$(uname -s)"
	arch_name="$(uname -m)"

	case "${os_name}" in
		Darwin)
			if command -v xattr >/dev/null 2>&1 && [[ -d "${bin_dir}" ]]; then
				xattr -dr com.apple.quarantine "${bin_dir}" 2>/dev/null || true
			fi
			printf '%s\n' \
				"addons/goldsrc/bin/libgoldsrc.macos.template_debug.${arch_name}.dylib" \
				"addons/goldsrc/bin/libgoldsrc.macos.template_release.${arch_name}.dylib" \
				"addons/goldsrc/bin/libgoldsrc.macos.template_debug.universal.dylib" \
				"addons/goldsrc/bin/libgoldsrc.macos.template_release.universal.dylib"
			;;
		Linux)
			if [[ "${arch_name}" == "aarch64" ]]; then
				arch_name="arm64"
			fi
			printf '%s\n' \
				"addons/goldsrc/bin/libgoldsrc.linux.template_debug.${arch_name}.so" \
				"addons/goldsrc/bin/libgoldsrc.linux.template_release.${arch_name}.so"
			;;
		MINGW*|MSYS*|CYGWIN*)
			printf '%s\n' \
				"addons/goldsrc/bin/libgoldsrc.windows.template_debug.x86_64.dll" \
				"addons/goldsrc/bin/libgoldsrc.windows.template_release.x86_64.dll"
			;;
	esac
}

find_native_library() {
	local candidate
	while IFS= read -r candidate; do
		if [[ -n "${candidate}" && -f "${project_root}/${candidate}" ]]; then
			printf '%s\n' "${candidate}"
			return 0
		fi
	done < <(native_library_candidates)
	return 1
}

if [[ ! -f "${extension_file}" ]]; then
	remove_extension_entry
	echo "GoldSrc GDExtension bootstrap: disabled, ${extension_entry} is not vendored."
	exit 0
fi

if native_library="$(find_native_library)"; then
	add_extension_entry
	echo "GoldSrc GDExtension bootstrap: enabled ${extension_entry} using ${native_library}."
else
	remove_extension_entry
	echo "GoldSrc GDExtension bootstrap: disabled, no native goldsrc-godot library for $(uname -s)/$(uname -m)."
fi
