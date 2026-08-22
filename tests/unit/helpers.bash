#!/usr/bin/env bash
# Shared helpers for TinkerGame bats tests.
#
# tg_load sources the (monolithic) script with main() execution disabled
# (TINKERGAME_NO_MAIN=1, see bottom of the script) and then redirects all
# scratch paths (log, /dev/shm cache, meta dirs) into the per-test temp dir
# so tests never touch the developer's real config or /dev/shm.

TG_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
TG_SCRIPT="$TG_ROOT/tinkergame"
TG_FIXTURES="$TG_ROOT/tests/fixtures"

tg_load() {
	export TINKERGAME_NO_MAIN=1
	# shellcheck source=/dev/null
	source "$TG_SCRIPT"

	# Route all runtime scratch paths away from /dev/shm and $HOME
	export LOGLEVEL=0
	export TEMPLOG="$BATS_TEST_TMPDIR/tinkergame.log"
	: >"$TEMPLOG" 2>/dev/null || true
	export STLSHM="$BATS_TEST_TMPDIR/shm"
	mkdir -p "$STLSHM"
	export FUPDATE="$STLSHM/fupdate.txt"
	export GEMETA="$BATS_TEST_TMPDIR/gemeta"
	mkdir -p "$GEMETA"
	# The script wraps awk in a function dispatching to $AWKBIN -- pointing it
	# at "awk" itself would recurse infinitely (bash segfaults), so pick a real binary.
	if command -v gawk >/dev/null 2>&1; then
		export AWKBIN="gawk"
	else
		export AWKBIN="mawk"
	fi

	# setDefaultCfgValues resolves optional tools via 'command -v'; under the
	# test runner's errexit a missing binary would abort those lookups, so
	# provide inert stubs for every looked-up program:
	local stubbin="$BATS_TEST_TMPDIR/stubbin"
	mkdir -p "$stubbin"
	local stub
	for stub in yad geany firefox notify-send netstat vr-video-player xterm mangohud; do
		# shellcheck disable=SC2292  # explicit 'test -x' for clarity
		if ! test -x "$stubbin/$stub"; then
			printf '#!/bin/sh\nexit 0\n' >"$stubbin/$stub"
			chmod +x "$stubbin/$stub"
		fi
	done
	export PATH="$stubbin:$PATH"
}
