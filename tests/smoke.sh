#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n tinkergame

# Regression checks for bugs found in review
# 1. Diagnostics should go through writelog, not a bare 'echo "ERROR"'
if grep -n 'echo "ERROR" ' tinkergame; then
	printf '%s\n' 'bare echo "ERROR" diagnostic found' >&2
	exit 1
fi

# 2. No leftover debug echoes
if grep -n 'echo "STLISLDFD' tinkergame; then
	printf '%s\n' 'debug echo leftover found' >&2
	exit 1
fi

# 3. Numeric -eq/-ne comparisons against a quoted variable are a bug (integer compare on strings)
if grep -nE '\[\s*"[^"]+"\s+-(eq|ne)\s+"\$NON"\s*\]' tinkergame; then
	printf '%s\n' 'numeric comparison against $NON on a quoted variable found' >&2
	exit 1
fi

# 4. Misaligned help lines inside the 'howto' block (space-indent instead of tab)
if ! awk '
	/^function howto \{/ { inhowto=1 }
	inhowto && /^#STARTCMDLINE/ { inhowto=0 }
	inhowto && /^ +echo/ { print NR": "$0; bad=1 }
	END { exit bad }
' tinkergame; then
	printf '%s\n' 'misaligned echo line found in howto help block' >&2
	exit 1
fi

if [ "${TINKERGAME_SKIP_SHELLCHECK:-0}" != 1 ] && command -v shellcheck >/dev/null 2>&1; then
	shellcheck ${SHELLCHECK_OPTIONS:-} tinkergame uninstall.sh
fi

test -x tinkergame
test -x uninstall.sh
test -f misc/tinkergame.desktop
test -f misc/tinkergame.svg
test -f MIGRATION.md

if grep -R -n --exclude=MIGRATION.md --exclude=LICENSE \
	--exclude-dir=.git --exclude-dir=tests \
	-e 'steamtinkerlaunch' -e 'SteamTinkerLaunch' . \
	| grep -v -e 'sonic2kk/steamtinkerlaunch'; then
	printf '%s\n' 'legacy project name found outside migration documentation' >&2
	exit 1
fi

make -n install PREFIX="$ROOT_DIR/.test-prefix" >/dev/null
make -n install PREFIX=/usr DESTDIR="$ROOT_DIR/.test-package" >/dev/null

if [ -f packaging/arch/PKGBUILD ]; then
	bash -n packaging/arch/PKGBUILD
fi

printf '%s\n' 'TinkerGame smoke checks passed.'
