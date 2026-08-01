#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n tinkergame

if command -v shellcheck >/dev/null 2>&1; then
	 shellcheck --extended-analysis=false tinkergame
fi

test -x tinkergame
test -f misc/tinkergame.desktop
test -f misc/tinkergame.svg
test -f MIGRATION.md

if grep -R -n --exclude=MIGRATION.md --exclude=LICENSE \
	--exclude-dir=.git --exclude-dir=tests \
	-e 'steamtinkerlaunch' -e 'SteamTinkerLaunch' .; then
	printf '%s\n' 'legacy project name found outside migration documentation' >&2
	exit 1
fi

make -n install PREFIX="$ROOT_DIR/.test-prefix" >/dev/null

printf '%s\n' 'TinkerGame smoke checks passed.'
