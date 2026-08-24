#!/usr/bin/env bash
set -eu

# TinkerGame uninstaller.
#
# Finds and removes every TinkerGame installation on the system - it scans
# the usual prefixes (~/.local, /usr, /usr/local, the prefix it was
# installed to and an optional --prefix=DIR) instead of assuming one, so a
# user install is never accidentally left behind.
#
# The Steam compatibility-tool registration is always removed together with
# the installation - it is an install artifact, not user data.
# User data (settings, caches, downloaded tools, game data) is only removed
# with --purge.

PURGE=0
ASSUME_YES=0
CUSTOM_PREFIX=""

# set to the real install prefix by 'make install' - it is scanned in
# addition to the standard locations below
INSTALL_PREFIX="/usr"

usage() {
	printf '%s\n' "Usage: tinkergame-uninstall [--purge] [--yes] [--prefix=DIR]"
	printf '%s\n' ""
	printf '%s\n' "Removes every TinkerGame installation (user and system) and its Steam"
	printf '%s\n' "compatibility-tool registration."
	printf '%s\n' ""
	printf '%s\n' "  --purge        Also remove TinkerGame settings, cache, downloaded tools,"
	printf '%s\n' "                 game data and runtime menu entries"
	printf '%s\n' "  --yes          Skip the confirmation prompt"
	printf '%s\n' "  --prefix=DIR   Also scan a non-standard install prefix"
}

for arg in "$@"; do
	case "$arg" in
		--purge) PURGE=1 ;;
		--yes|-y) ASSUME_YES=1 ;;
		--prefix=*) CUSTOM_PREFIX="${arg#--prefix=}" ;;
		--help|-h) usage; exit 0 ;;
		*) usage >&2; exit 2 ;;
	esac
done

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
	USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
	USER_HOME="${HOME}"
fi

REMOVED_ANY=0
FAILED_ANY=0

# remove a file or directory if it exists, reporting what happened
rm_path() {
	if [ -e "$1" ] || [ -L "$1" ]; then
		if rm -rf -- "$1" 2>/dev/null && [ ! -e "$1" ] && [ ! -L "$1" ]; then
			REMOVED_ANY=1
			printf '  removed %s\n' "$1"
		else
			FAILED_ANY=1
			printf '  FAILED to remove %s - permission denied? (rerun with sudo)\n' "$1" >&2
		fi
	fi
}

# the per-prefix file set of a TinkerGame installation
prefix_has_install() {
	[ -e "$1/bin/tinkergame" ] || [ -e "$1/bin/tinkergame-uninstall" ] \
		|| [ -d "$1/share/tinkergame" ] || [ -d "$1/share/doc/tinkergame" ] \
		|| [ -e "$1/share/applications/tinkergame.desktop" ] \
		|| [ -e "$1/share/icons/hicolor/scalable/apps/tinkergame.svg" ]
}

remove_prefix() {
	printf 'Removing TinkerGame from %s\n' "$1"
	rm_path "$1/bin/tinkergame"
	rm_path "$1/bin/tinkergame-uninstall"
	rm_path "$1/share/applications/tinkergame.desktop"
	rm_path "$1/share/icons/hicolor/scalable/apps/tinkergame.svg"
	rm_path "$1/share/tinkergame"
	rm_path "$1/share/doc/tinkergame"
}

remove_compat_registration() {
	local sd
	for sd in \
		"$USER_HOME/.steam/steam/compatibilitytools.d" \
		"$USER_HOME/.local/share/Steam/compatibilitytools.d" \
		"$USER_HOME/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d"; do
		if [ -e "$sd/TinkerGame" ]; then
			printf 'Removing the Steam compatibility-tool registration in %s\n' "$sd"
			rm_path "$sd/TinkerGame"
		fi
	done
}

purge_user_data() {
	local XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
	local XDG_CACHE_HOME="${XDG_CACHE_HOME:-$USER_HOME/.cache}"
	local XDG_DATA_HOME="${XDG_DATA_HOME:-$USER_HOME/.local/share}"
	local df

	printf 'Removing TinkerGame user data\n'
	rm_path "$XDG_CONFIG_HOME/tinkergame"
	rm_path "$XDG_CACHE_HOME/tinkergame"
	rm_path "$XDG_DATA_HOME/tinkergame"
	rm_path "/dev/shm/tinkergame"

	# runtime-created application menu entries (vortex/modorganizer/hedgemodmanager
	# download launchers and the like) - they are only removed with --purge
	shopt -s nullglob
	for df in \
		"$USER_HOME/.local/share/applications/tinkergame.desktop" \
		"$USER_HOME/.local/share/applications/"*-tinkergame*.desktop \
		"$USER_HOME/.local/share/applications/"tinkergame*.desktop; do
		rm_path "$df"
	done
	shopt -u nullglob
}

# ---- scan ----

PREFIX_LIST=()
add_prefix() {
	local p
	for p in "${PREFIX_LIST[@]}"; do
		[ "$p" == "$1" ] && return 0
	done
	PREFIX_LIST+=("$1")
}

add_prefix "$USER_HOME/.local"
add_prefix "/usr"
add_prefix "/usr/local"
add_prefix "$INSTALL_PREFIX"
[ -n "$CUSTOM_PREFIX" ] && add_prefix "$CUSTOM_PREFIX"

FOUND_PREFIXES=()
for p in "${PREFIX_LIST[@]}"; do
	if [ -d "$p" ] && prefix_has_install "$p"; then
		FOUND_PREFIXES+=("$p")
	fi
done

FOUND_COMPAT=0
for sd in \
	"$USER_HOME/.steam/steam/compatibilitytools.d" \
	"$USER_HOME/.local/share/Steam/compatibilitytools.d" \
	"$USER_HOME/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d"; do
	if [ -e "$sd/TinkerGame" ]; then
		FOUND_COMPAT=1
	fi
done

if [ "${#FOUND_PREFIXES[@]}" -eq 0 ] && [ "$FOUND_COMPAT" -eq 0 ] && [ "$PURGE" -ne 1 ]; then
	printf '%s\n' "No TinkerGame installation found - nothing to do." >&2
	exit 1
fi

# ---- confirm ----

printf '%s\n' "The following will be removed:"
for p in "${FOUND_PREFIXES[@]}"; do
	printf '  TinkerGame installation in %s\n' "$p"
done
if [ "$FOUND_COMPAT" -eq 1 ]; then
	printf '%s\n' "  the Steam compatibility-tool registration"
fi
if [ "$PURGE" -eq 1 ]; then
	printf '%s\n' "  TinkerGame user data (settings, cache, downloaded tools, game data)"
fi

if [ "$ASSUME_YES" -ne 1 ]; then
	printf '%s' 'Proceed? [y/N] '
	read -r answer || answer=""
	case "$answer" in
		y|Y|yes|YES) ;;
		*) printf '%s\n' 'Uninstall cancelled.'; exit 0 ;;
	esac
fi

# ---- remove ----

for p in "${FOUND_PREFIXES[@]}"; do
	remove_prefix "$p"
done

remove_compat_registration

if [ "$PURGE" -eq 1 ]; then
	purge_user_data
fi

if [ "$FAILED_ANY" -ne 0 ]; then
	printf '%s\n' 'Some files could not be removed - rerun with sudo to clean up the rest.' >&2
	exit 1
fi

if [ "$REMOVED_ANY" -eq 0 ]; then
	printf '%s\n' "No TinkerGame installation found - nothing was removed." >&2
	exit 1
fi

printf '%s\n' 'TinkerGame was uninstalled completely.'
if [ "$PURGE" -eq 0 ]; then
	printf '%s\n' 'User data was kept. Re-run with --purge to remove it as well.'
fi
