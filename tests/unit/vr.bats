#!/usr/bin/env bash
# Tests for the bounded game-pid wait (waitForGamePid) and the WDIB prefix
# cleanup (killPrefixOnGameExit). tail and wineserver are replaced by stubs
# recording their calls, so the whole wait/kill flow runs without wine.

load helpers

setup() {
	tg_load

	# minimal environment for waitForGamePid / killPrefixOnGameExit
	export NON="isnot"
	export WAITFORTHISPID="$NON"
	export USECUSTOMCMD=0
	export ONLY_CUSTOMCMD=0
	export USEWINE=0
	export CLOSETMP="$BATS_TEST_TMPDIR/close.tmp"

	# wineserver stub recording the kill call
	export WSERVER_LOG="$BATS_TEST_TMPDIR/wineserver.log"
	printf '#!/usr/bin/env bash\necho "WINEPREFIX=$WINEPREFIX args=$*" >> "$WSERVER_LOG"\n' \
		> "$BATS_TEST_TMPDIR/stubbin/wineserver"
	chmod +x "$BATS_TEST_TMPDIR/stubbin/wineserver"
	export RUNWINESERVER="$BATS_TEST_TMPDIR/stubbin/wineserver"

	# tail stub recording the --pid argument (returns immediately)
	export TAIL_LOG="$BATS_TEST_TMPDIR/tail.log"
	printf '#!/usr/bin/env bash\necho "tail $*" >> "$TAIL_LOG"\n' \
		> "$BATS_TEST_TMPDIR/stubbin/tail"
	chmod +x "$BATS_TEST_TMPDIR/stubbin/tail"

	GPFX="$BATS_TEST_TMPDIR/pfx"
	mkdir -p "$GPFX"
}

@test "waitForGamePid: returns success when the game pid is found" {
	GAMEPID() { echo 12345; }
	run waitForGamePid
	[ "$status" -eq 0 ]
}

@test "waitForGamePid: gives up when TinkerGame is closing" {
	GAMEPID() { :; }
	touch "$CLOSETMP"
	run waitForGamePid
	[ "$status" -eq 1 ]
}

@test "waitForGamePid: gives up after the timeout instead of looping forever" {
	GAMEPID() { :; }
	rm -f "$CLOSETMP"
	TG_WAITFORGAMEPID_MAX=1 run waitForGamePid
	[ "$status" -eq 1 ]
}

@test "killPrefixOnGameExit: waits for the game pid and kills the prefix afterwards" {
	waitForGamePid() { return 0; }
	GAMEPID() { echo 4242; }
	rm -f "$CLOSETMP"
	run killPrefixOnGameExit
	[ "$status" -eq 0 ]
	grep -q -- "--pid=4242" "$TAIL_LOG"
	grep -q "WINEPREFIX=$GPFX args=-k" "$WSERVER_LOG"
	[ -f "$CLOSETMP" ]
}

@test "killPrefixOnGameExit: without a game pid it kills the prefix when the session closes" {
	waitForGamePid() { return 1; }
	GAMEPID() { :; }
	touch "$CLOSETMP"
	run killPrefixOnGameExit
	[ "$status" -eq 0 ]
	# no game pid, so no tail wait happened - but the prefix was still killed
	[ ! -f "$TAIL_LOG" ]
	grep -q "WINEPREFIX=$GPFX args=-k" "$WSERVER_LOG"
	[ -f "$CLOSETMP" ]
}

@test "killPrefixOnGameExit: no stale closing marker when the session died silently" {
	waitForGamePid() { return 1; }
	GAMEPID() { :; }
	rm -f "$CLOSETMP"
	# simulate that the TinkerGame main process is already gone, so the
	# fallback wait ends via the dead-parent check
	kill() { return 1; }
	run killPrefixOnGameExit
	[ "$status" -eq 0 ]
	grep -q "WINEPREFIX=$GPFX args=-k" "$WSERVER_LOG"
	# CLOSETMP was never created by the session - it must not appear now
	[ ! -e "$CLOSETMP" ]
}

setup_openvr_fsr() {
	EFD="$BATS_TEST_TMPDIR/game dir"
	STLDLDIR="$BATS_TEST_TMPDIR/downloads"
	mkdir -p "$EFD/bin" "$STLDLDIR/$OVFS"
	printf 'original\n' > "$EFD/bin/$OVRA"
	printf 'fsr\n' > "$STLDLDIR/$OVFS/$OVRA"
	writelog() { :; }
}

@test "checkOpenVRFSR: the install log uses the tg name the Editor Menu reads" {
	setup_openvr_fsr
	[ "$OVRFSENA" = "openvr_fsr-tg-enabled.txt" ]
	USEOPENVRFSR=1
	checkOpenVRFSR
	[ "$(cat "$EFD/bin/$OVRA")" = "fsr" ]
	grep -qx "/bin/$OVRA" "$EFD/$OVRFSENA"
	grep -q 'OVRFP="$EFD/$OVRFSENA"' "$TG_ROOT/lib/gui/menu-core.sh"

	USEOPENVRFSR=0
	checkOpenVRFSR
	[ "$(cat "$EFD/bin/$OVRA")" = "original" ]
	[ ! -e "$EFD/$OVRFSENA" ]
}

@test "checkOpenVRFSR: an install log under the old long name is still restored" {
	setup_openvr_fsr
	USEOPENVRFSR=1
	checkOpenVRFSR
	mv "$EFD/$OVRFSENA" "$EFD/openvr_fsr-tinkergame-enabled.txt"

	USEOPENVRFSR=0
	checkOpenVRFSR
	[ "$(cat "$EFD/bin/$OVRA")" = "original" ]
	[ ! -e "$EFD/$OVRFSENA" ]
	[ ! -e "$EFD/openvr_fsr-tinkergame-enabled.txt" ]
}

@test "checkOpenVRFSR: uninstalling removes the installed mod config" {
	setup_openvr_fsr
	OVRMOD="openvr_mod.cfg"
	printf 'cfg\n' > "$STLDLDIR/$OVFS/$OVRMOD"
	USEOPENVRFSR=1
	checkOpenVRFSR
	[ -f "$EFD/bin/$OVRMOD" ]
	grep -qx "/bin/$OVRMOD" "$EFD/$OVRFSENA"

	USEOPENVRFSR=0
	checkOpenVRFSR
	[ ! -e "$EFD/bin/$OVRMOD" ]
	[ "$(cat "$EFD/bin/$OVRA")" = "original" ]
}
