#!/usr/bin/env bash
# One-command installer for TinkerGame.
#
# Usage:
#   ./install.sh               ask where to install (user or system)
#   ./install.sh --user        install to ~/.local (default choice, no sudo)
#   ./install.sh --system      install to /usr (uses sudo)
#   ./install.sh --prefix=DIR  install to a custom prefix
#
# All real work is delegated to the Makefile; DESTDIR is passed through
# for packaging builds (DESTDIR=... ./install.sh ...).

set -eu

SCRIPTDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$SCRIPTDIR"

MODE=""
PREFIX_ARG=""
DESTDIR_ARG="${DESTDIR:-}"

usage() {
	cat <<EOF
Usage: ./install.sh [--user|--system|--prefix=DIR]

  (no argument)   ask whether to install for the current user or system-wide
  --user          install to ~/.local (no sudo required)
  --system        install to /usr (uses sudo)
  --prefix=DIR    install to a custom prefix
  -h, --help      show this help
EOF
}

die() {
	printf 'install.sh: %s\n' "$1" >&2
	exit 1
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--user) MODE="user" ;;
		--system) MODE="system" ;;
		--prefix=*) MODE="prefix"; PREFIX_ARG="${1#--prefix=}" ;;
		-h|--help) usage; exit 0 ;;
		*) usage >&2; exit 2 ;;
	esac
	shift
done

command -v make >/dev/null 2>&1 || die "'make' is required but was not found"
test -f Makefile || die "run this script from a TinkerGame checkout (Makefile not found)"
command -v yad >/dev/null 2>&1 || printf '%s\n' "note: 'yad' was not found - TinkerGame needs it at runtime"

if [ -z "$MODE" ]; then
	printf '%s\n' "" "Where should TinkerGame be installed?" \
		"  1) For the current user only (~/.local - no sudo required)  [recommended]" \
		"  2) System-wide (/usr - requires sudo)"
	if [ -t 0 ]; then
		printf '%s' "Choose [1]: "
		read -r REPLY || REPLY=""
	else
		REPLY="1"
	fi
	case "${REPLY:-1}" in
		2) MODE="system" ;;
		*) MODE="user" ;;
	esac
fi

case "$MODE" in
	user)
		echo "Installing TinkerGame for the current user to '$HOME/.local'"
		make install-user
		BINDIR="$HOME/.local/bin"
		;;
	system)
		echo "Installing TinkerGame system-wide to '/usr'"
		if [ "$(id -u)" -eq 0 ]; then
			make install
		else
			sudo make install
		fi
		BINDIR="/usr/bin"
		;;
	prefix)
		[ -n "$PREFIX_ARG" ] || die "--prefix=DIR requires a directory"
		echo "Installing TinkerGame to '$PREFIX_ARG'"
		make install PREFIX="$PREFIX_ARG"
		BINDIR="$PREFIX_ARG/bin"
		;;
esac

if [ -n "$DESTDIR_ARG" ]; then
	echo "Staged into DESTDIR '$DESTDIR_ARG' - no further steps."
	exit 0
fi

echo ""
echo "TinkerGame installed ('$BINDIR/tinkergame')."
case ":$PATH:" in
	*":$BINDIR:"*) : ;;
	*) echo "note: '$BINDIR' is not in your PATH - add it to use the 'tinkergame' command" ;;
esac

cat <<EOF

Next steps:
  1. Restart Steam if it is running.
  2. Proton games: pick TinkerGame in the game's Properties > Compatibility
     (or set it as the default Steam Play tool).
     Native games: use the launch option 'tinkergame %command%'.
  3. Explore the per-game menu at runtime or run 'tinkergame help'.

Uninstall anytime with 'tinkergame-uninstall' (add --purge to also remove
settings and data).
EOF
