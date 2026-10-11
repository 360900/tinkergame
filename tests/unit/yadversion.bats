#!/usr/bin/env bash
# The yad version gate in checkIntDeps.
#
# "Could not determine the version" and "the version is too old" are different
# situations. A systemd user unit started at login gets a DISPLAY that does not
# answer yet, yad exits without printing anything, and the probe reads back an
# empty string -- which used to abort the run with "Yad version '' is too old",
# even for commands that never open a window.

setup() {
	load helpers
	tg_load

	# shellcheck source=/dev/null
	source "$TG_ROOT/lang/english.txt"

	SKIPINTDEPCHECK=0
	ONSTEAMDECK=0
	INFLATPAK=0
	DEPSMISSING=0
	USENOTIFIER=0

	STLCFGDIR="$BATS_TEST_TMPDIR/cfg"
	mkdir -p "$STLCFGDIR"
	STLDEFGLOBALCFG="$STLCFGDIR/global.conf"
	printf 'YAD="placeholder"\n' > "$STLDEFGLOBALCFG"

	# A steam on PATH, so the unrelated dependency checks stay quiet
	printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/stubbin/steam"
	chmod +x "$BATS_TEST_TMPDIR/stubbin/steam"

	YAD="$BATS_TEST_TMPDIR/fakeyad"
}

# Writes a yad stub whose '--version' prints $1 (nothing when empty)
tg_fakeyad() {
	if [ -z "$1" ]; then
		printf '#!/bin/sh\nexit 1\n' > "$YAD"
	else
		printf '#!/bin/sh\necho "%s (GTK+ 3.24.52)"\n' "$1" > "$YAD"
	fi
	chmod +x "$YAD"
}

@test "checkIntDeps: a yad that reports no version does not abort the run" {
	# This is the login-time case: yad exists, but cannot talk to the display yet
	tg_fakeyad ""
	run checkIntDeps
	[ "$status" -eq 0 ]
	! printf '%s\n' "$output" | grep -q "too old"
}

@test "checkIntDeps: a yad that reports no version is reported as unknown" {
	tg_fakeyad ""
	run checkIntDeps
	printf '%s\n' "$output" | grep -qi "could not read a version"
}

@test "checkIntDeps: a genuinely old yad is still rejected" {
	tg_fakeyad "6.0"
	run checkIntDeps
	printf '%s\n' "$output" | grep -q "Yad version '6.0' is too old"
}

@test "checkIntDeps: a new enough yad passes" {
	tg_fakeyad "9.3"
	run checkIntDeps
	[ "$status" -eq 0 ]
	! printf '%s\n' "$output" | grep -q "too old"
}

@test "checkIntDeps: an unknown version is not written to the global config" {
	# Only a version we could actually verify should be recorded as good
	printf 'YAD=""\n' > "$STLDEFGLOBALCFG"
	tg_fakeyad ""
	run checkIntDeps
	grep -q 'YAD=""' "$STLDEFGLOBALCFG"
}

@test "checkIntDeps: a verified version is written to the global config" {
	printf 'YAD=""\n' > "$STLDEFGLOBALCFG"
	tg_fakeyad "9.3"
	run checkIntDeps
	grep -q "YAD=\"$YAD\"" "$STLDEFGLOBALCFG"
}
