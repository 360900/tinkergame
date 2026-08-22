#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n tinkergame

# Layout sanity: the thin entry point plus every library module must exist
test -f lib/core/common.sh
test -f lib/core/bootstrap.sh
test -f lib/config/schema.sh
test -f data/options.def
for f in lib/*/*.sh; do
	bash -n "$f"
done

# The option schema is the source of truth: lib/config/defaults.sh must match it
bash tools/gen-options.sh --check

# Regression checks for bugs found in review
# 1. Diagnostics should go through writelog, not a bare 'echo "ERROR"'
if grep -n 'echo "ERROR" ' tinkergame lib/*/*.sh; then
	printf '%s\n' 'bare echo "ERROR" diagnostic found' >&2
	exit 1
fi

# 2. No leftover debug echoes
if grep -n 'echo "STLISLDFD' tinkergame lib/*/*.sh; then
	printf '%s\n' 'debug echo leftover found' >&2
	exit 1
fi

# 3. Numeric -eq/-ne comparisons against a quoted variable are a bug (integer compare on strings)
if grep -nE '\[\s*"[^"]+"\s+-(eq|ne)\s+"\$NON"\s*\]' tinkergame lib/*/*.sh; then
	printf '%s\n' 'numeric comparison against $NON on a quoted variable found' >&2
	exit 1
fi

# 4. Misaligned help lines inside the 'howto' block (space-indent instead of tab)
if ! awk '
	/^function howto \{/ { inhowto=1; next }
	inhowto && /^function/ { inhowto=0 }
	inhowto && /^ +echo/ { print FILENAME":"NR": "$0; bad=1 }
	END { exit bad }
' lib/cli/help.sh; then
	printf '%s\n' 'misaligned echo line found in howto help block' >&2
	exit 1
fi

# ShellCheck: default to the same options CI uses (extended analysis is very
# slow on large codebases and its extra checks differ between ShellCheck
# versions). Set SHELLCHECK_OPTIONS="" to run the full analysis locally.
if [ "${TINKERGAME_SKIP_SHELLCHECK:-0}" != 1 ] && command -v shellcheck >/dev/null 2>&1; then
	shellcheck ${SHELLCHECK_OPTIONS:---extended-analysis=false} tinkergame uninstall.sh lib/*/*.sh tools/gen-options.sh
fi

# Data file and consistency checks
./tests/validate-data.sh
./tests/i18n-parity.sh
./tests/check-versions.sh

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
