#!/usr/bin/env bash
# requestMissingSLR asks Steam to install the Steam Linux Runtime a Proton
# build needs (require_tool_appid in toolmanifest.vdf) when it is missing.

setup() {
	load helpers
	tg_load

	PROTDIR="$BATS_TEST_TMPDIR/GE-Proton11-12"
	mkdir -p "$PROTDIR"
	printf '"manifest"\n{\n\t"version" "2"\n\t"require_tool_appid" "1628350"\n}\n' >"$PROTDIR/$TOMA"

	STEAMLOG="$BATS_TEST_TMPDIR/steam.log"
	printf '#!/bin/sh\necho "$@" >>"%s"\n' "$STEAMLOG" >"$BATS_TEST_TMPDIR/stubbin/steam"
	chmod +x "$BATS_TEST_TMPDIR/stubbin/steam"

	NOTIFIED=""
	notiShow() { NOTIFIED="$1"; }
	NOTY_SLRREQUESTED="requested"
}

@test "requestMissingSLR: asks Steam to install a missing runtime" {
	getGameDir() { :; }
	requestMissingSLR "$PROTDIR"
	wait
	grep -qx "steam://install/1628350" "$STEAMLOG"
	[ "$NOTIFIED" = "requested" ]
}

@test "requestMissingSLR: does nothing when the runtime is installed" {
	getGameDir() { echo "$BATS_TEST_TMPDIR"; }
	run requestMissingSLR "$PROTDIR"
	[ "$status" -ne 0 ]
	[ ! -f "$STEAMLOG" ]
}

@test "requestMissingSLR: does nothing when Proton needs no runtime" {
	getGameDir() { :; }
	printf '"manifest"\n{\n\t"version" "2"\n}\n' >"$PROTDIR/$TOMA"
	run requestMissingSLR "$PROTDIR"
	[ "$status" -ne 0 ]
	[ ! -f "$STEAMLOG" ]
}
