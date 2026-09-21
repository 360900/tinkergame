#!/usr/bin/env bash
# Regression tests for the X11 yad wrapper built in prepareGUI.
#
# The wrapper replaces $YAD with a small script that re-execs yad on the X11
# backend. Building one around a yad that cannot run produces a script that
# execs nothing, and since that script exists and is executable, every later
# "is yad usable?" check sees a healthy looking $YAD.

setup() {
	load helpers
	tg_load

	STLSHM="$BATS_TEST_TMPDIR/shm"
	mkdir -p "$STLSHM"

	# prepareGUI probes yad for supported options; a failing probe is harmless
	yadSupportsOption() { return 1; }
}

@test "prepareGUI: an empty YAD produces no wrapper" {
	YAD=""
	prepareGUI
	[ ! -e "$STLSHM/yad-x11" ]
}

@test "prepareGUI: an empty YAD stays empty so yad detection can still recover" {
	# checkIntDeps recovers with 'if [ -z "$YAD" ]; then YAD=$(command -v yad)'.
	# Pointing YAD at a wrapper here would make that test false forever, and the
	# user could not even fix it with 'set YAD global ...' because the dependency
	# check aborts before the command runs.
	YAD=""
	prepareGUI
	[ -z "$YAD" ]
}

@test "prepareGUI: a YAD that does not exist produces no wrapper" {
	YAD="$BATS_TEST_TMPDIR/definitely-not-yad"
	# The option probe earlier in prepareGUI runs $YAD too and returns 127 here.
	# Production does not use errexit and carries on with an empty probe result;
	# under the test runner it aborts the function, which is fine for this check.
	prepareGUI || true
	[ ! -e "$STLSHM/yad-x11" ]
	[ "$YAD" = "$BATS_TEST_TMPDIR/definitely-not-yad" ]
}

@test "prepareGUI: a usable YAD is wrapped as before" {
	YAD="$BATS_TEST_TMPDIR/fakeyad"
	printf '#!/bin/sh\necho "fake yad $*"\n' > "$YAD"
	chmod +x "$YAD"

	prepareGUI

	[ -x "$STLSHM/yad-x11" ]
	[ "$YAD" = "$STLSHM/yad-x11" ]
	grep -q "GDK_BACKEND=x11" "$STLSHM/yad-x11"
}

@test "prepareGUI: the wrapper actually runs the real yad" {
	YAD="$BATS_TEST_TMPDIR/fakeyad"
	printf '#!/bin/sh\necho "fake yad $*"\n' > "$YAD"
	chmod +x "$YAD"

	prepareGUI

	run "$STLSHM/yad-x11" --version
	[ "$status" -eq 0 ]
	[ "$output" = "fake yad --version" ]
}

@test "prepareGUI: a wrapper is never left execing nothing" {
	# The original failure: 'exec  "$@"' with an empty command, which reports
	# an empty yad version and aborts the whole run
	YAD=""
	prepareGUI
	if [ -e "$STLSHM/yad-x11" ]; then
		run grep -c "^exec ''" "$STLSHM/yad-x11"
		[ "$output" = "0" ]
	fi
}
