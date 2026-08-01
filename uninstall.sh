#!/usr/bin/env bash
set -eu

INSTALL_PREFIX="/usr"
PURGE=0
ASSUME_YES=0

usage() {
	printf '%s\n' "Usage: tinkergame-uninstall [--purge] [--yes]"
	printf '%s\n' "  --purge  Also remove TinkerGame settings, cache, data, and Steam registration"
	printf '%s\n' "  --yes    Skip the confirmation prompt"
}

for arg in "$@"; do
	case "$arg" in
		--purge) PURGE=1 ;;
		--yes) ASSUME_YES=1 ;;
		--help|-h) usage; exit 0 ;;
		*) usage >&2; exit 2 ;;
	esac
done

if [ "$ASSUME_YES" -ne 1 ]; then
	printf '%s' "Remove TinkerGame from '$INSTALL_PREFIX'"
	if [ "$PURGE" -eq 1 ]; then
		printf '%s' " and delete its user data"
	fi

	printf '%s' '? [y/N] '
	read -r answer
	case "$answer" in
		y|Y|yes|YES) ;;
		*) printf '%s\n' 'Uninstall cancelled.'; exit 0 ;;
	esac
fi

rm -f \
	"$INSTALL_PREFIX/bin/tinkergame" \
	"$INSTALL_PREFIX/bin/tinkergame-uninstall" \
	"$INSTALL_PREFIX/share/applications/tinkergame.desktop" \
	"$INSTALL_PREFIX/share/icons/hicolor/scalable/apps/tinkergame.svg"
rm -rf \
	"$INSTALL_PREFIX/share/tinkergame" \
	"$INSTALL_PREFIX/share/doc/tinkergame"

if [ "$PURGE" -eq 1 ]; then
	USER_HOME="${HOME}"
	if [ -n "${SUDO_USER:-}" ]; then
		USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
	fi

	XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
	XDG_CACHE_HOME="${XDG_CACHE_HOME:-$USER_HOME/.cache}"
	XDG_DATA_HOME="${XDG_DATA_HOME:-$USER_HOME/.local/share}"
	rm -rf \
		"$XDG_CONFIG_HOME/tinkergame" \
		"$XDG_CACHE_HOME/tinkergame" \
		"$XDG_DATA_HOME/tinkergame" \
		"/dev/shm/tinkergame"

	for steam_dir in \
		"$USER_HOME/.steam/steam/compatibilitytools.d" \
		"$USER_HOME/.local/share/Steam/compatibilitytools.d" \
		"$USER_HOME/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d"; do
		rm -f "$steam_dir/tinkergame"
	done
fi

printf '%s\n' 'TinkerGame was uninstalled.'
if [ "$PURGE" -eq 0 ]; then
	printf '%s\n' 'User data was kept. Re-run with --purge to remove it.'
fi
