#!/usr/bin/env bash
# setWineCmd wraps plain Wine games in the same launch wrappers as Proton games.

setup() {
	load helpers
	tg_load

	printf '#!/bin/sh\necho wine-9.0\n' >"$BATS_TEST_TMPDIR/stubbin/wine"
	printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/stubbin/$MAKOLAUNCH"
	printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/stubbin/$GAMEMODERUN"
	chmod +x "$BATS_TEST_TMPDIR/stubbin/"*

	RUNWINE="$BATS_TEST_TMPDIR/stubbin/wine"
	WINE_LOG_DIR="$BATS_TEST_TMPDIR"
	AID=12345 GN="Test Game"
	GAMESTARTCMD=("waitforexitandrun" "game.exe")
	FINGAMECMD=()
	USEWINE=1 USEGAMEMODERUN=0 USEGAMESCOPE=0 USEOBSCAP=0 USEMAKO=0 USEMANGOHUD=0 USEPRIMERUN=0

	setWineVars() { :; }
	setCommandLaunchVars() { setMakoCmd; GMR=""; [ "$USEGAMEMODERUN" -eq 1 ] && GMR="$(command -v "$GAMEMODERUN")"; :; }
	notiShow() { :; }
	extWine64Run() { printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/run"; }
}

@test "setWineCmd: MAKO wraps a Wine game" {
	USEMAKO=1
	setWineCmd
	[ "$(head -n1 "$BATS_TEST_TMPDIR/run")" = "$BATS_TEST_TMPDIR/stubbin/$MAKOLAUNCH" ]
	sed -n 2p "$BATS_TEST_TMPDIR/run" | grep -qx "$RUNWINE"
}

@test "setWineCmd: GameMode goes before MAKO" {
	USEMAKO=1 USEGAMEMODERUN=1
	setWineCmd
	[ "$(sed -n 1p "$BATS_TEST_TMPDIR/run")" = "$BATS_TEST_TMPDIR/stubbin/$GAMEMODERUN" ]
	[ "$(sed -n 2p "$BATS_TEST_TMPDIR/run")" = "$BATS_TEST_TMPDIR/stubbin/$MAKOLAUNCH" ]
}

@test "setWineCmd: no wrappers starts Wine directly" {
	setWineCmd
	[ "$(head -n1 "$BATS_TEST_TMPDIR/run")" = "$RUNWINE" ]
}
