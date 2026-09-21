#!/usr/bin/env bash
set -euo pipefail

if [[ $(uname -s) != "Linux" ]]; then
	echo "linux-system-config: Linux is required" >&2
	exit 1
fi

as_root=()
if (( EUID != 0 )); then
	if ! command -v sudo >/dev/null 2>&1; then
		echo "linux-system-config: sudo is required" >&2
		exit 1
	fi
	as_root=(sudo)
fi

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

install_config() {
	local source=$1
	local target=$2
	local mode=${3:-0644}

	if "${as_root[@]}" cmp -s "$source" "$target" 2>/dev/null; then
		echo "linux-system-config: $target is already current"
		return
	fi

	"${as_root[@]}" install -D -m "$mode" "$source" "$target"
	echo "linux-system-config: updated $target"
}

configure_sysctl() {
	local config=$temp_dir/99-matt-dotfiles.conf
	local target=/etc/sysctl.d/99-matt-dotfiles.conf

	{
		printf '%s\n' "# Managed by Matt's dotfiles: .scripts/linux-system-config.sh"
		printf '%s\n' 'fs.inotify.max_user_watches = 524288'
		printf '%s\n' 'fs.inotify.max_user_instances = 512'
		printf '%s\n' 'fs.inotify.max_queued_events = 32768'
	} > "$config"

	install_config "$config" "$target"
	"${as_root[@]}" sysctl --load "$target"
}

configure_sysctl
