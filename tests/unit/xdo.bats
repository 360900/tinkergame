#!/usr/bin/env bash
# xdotool is optional: it is not part of the hard dependency check, and every
# feature that uses it steps aside cleanly when it is missing.

bats_require_minimum_version 1.5.0

setup() {
	load helpers
	tg_load
	LOGLEVEL=2
}

@test "xdotool is not a hard dependency" {
	run grep -x 'XDO="xdotool"' <(sed -n '/^#STARTINTDEPS/,/^#ENDINTDEPS/p' "$TG_ROOT/lib/core/common.sh")
	[ "$status" -ne 0 ]
	# but still defined for the features that use it
	[ "$XDO" = "xdotool" ]
}

@test "tgHaveXdo: succeeds when xdotool is on PATH" {
	printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/stubbin/xdotool"
	chmod +x "$BATS_TEST_TMPDIR/stubbin/xdotool"
	run tgHaveXdo "a test feature"
	[ "$status" -eq 0 ]
}

@test "tgHaveXdo: fails and logs the skipped feature when xdotool is missing" {
	XDO="$BATS_TEST_TMPDIR/no-such-xdotool"
	run tgHaveXdo "a test feature"
	[ "$status" -eq 1 ]
	grep -q "is not installed - skipping a test feature" "$TEMPLOG"
}

@test "getGameWindowPID: returns none right away without xdotool" {
	XDO="$BATS_TEST_TMPDIR/no-such-xdotool"
	GAMEWINPID=""
	# without the guard this would poll the active window until MAXWAIT
	run getGameWindowPID
	[ "$status" -eq 0 ]
	[ "$output" = "$NON" ]
}

@test "getGameWinXIDFromPid and getGameWinNameFromXid: nothing without xdotool" {
	XDO="$BATS_TEST_TMPDIR/no-such-xdotool"
	run getGameWinXIDFromPid 1234
	[ "$status" -eq 1 ]
	[ -z "$output" ]
	run getGameWinNameFromXid 0x1
	[ "$status" -eq 1 ]
	[ -z "$output" ]
}

@test "togWindows: does nothing without xdotool" {
	XDO="$BATS_TEST_TMPDIR/no-such-xdotool"
	TOGGLEWINDOWS=1
	XPROP="$BATS_TEST_TMPDIR/xprop-must-not-run"
	run togWindows windowminimize
	[ "$status" -eq 0 ]
	[ ! -e "$XPROP" ]
	grep -q "skipping toggling open windows" "$TEMPLOG"
}

@test "checkUUUPatchLaunch: no patch command without xdotool" {
	XDO="$BATS_TEST_TMPDIR/no-such-xdotool"
	UUUSEPATCH=1
	UUUSEVR=0
	UUUPATCHCOMMAND="$BATS_TEST_TMPDIR/uuu.sh"
	run checkUUUPatchLaunch
	[ "$status" -eq 0 ]
	[ ! -e "$UUUPATCHCOMMAND" ]
}

@test "getScreenRes: two monitors without xdotool use the first one" {
	XDO="$BATS_TEST_TMPDIR/no-such-xdotool"
	cat > "$BATS_TEST_TMPDIR/stubbin/xrandr" <<'STUB'
#!/bin/sh
case "$1" in
	--verbose)
		printf '  1920x1080 (0x1) *current\n        h: width  1920 start\n        v: height 1080 start\n'
		printf '  2560x1440 (0x2) *current\n        h: width  2560 start\n        v: height 1440 start\n'
		;;
	--listactivemonitors)
		printf 'Monitors: 2\n 0: +*A 1920/1x1080/1+0+0 A\n 1: +B 2560/1x1440/1+1920+0 B\n'
		;;
esac
STUB
	chmod +x "$BATS_TEST_TMPDIR/stubbin/xrandr"
	XRANDR="$BATS_TEST_TMPDIR/stubbin/xrandr"
	run getScreenRes r
	[ "$status" -eq 0 ]
	[ "$output" = "1920x1080" ]
}
