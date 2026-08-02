#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n tinkergame

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
