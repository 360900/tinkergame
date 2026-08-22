#!/usr/bin/env bash

# Phase 3d: wait-requester behavior
# - editorSkipped must NOT silently rewrite WAITEDITOR=0 at MAXASK anymore
# - editorDontAskAgain explicitly disables the requester (WAITEDITOR=0 + ASKCNT=0)
# - askSettings gains the DON'T ASK AGAIN button (exit code 2)

load helpers

setup() {
	tg_load

	GAMECFG="$BATS_TEST_TMPDIR/game.conf"
	printf 'WAITEDITOR="5"\n' > "$GAMECFG"
	STLGAMECFG="$GAMECFG"
	SWRF="$BATS_TEST_TMPDIR/skip.wrf"
	EWRF="$BATS_TEST_TMPDIR/en.wrf"
	UWRF="$BATS_TEST_TMPDIR/un.wrf"

	WAITEDITOR=5
	STARTMENU="Menu"
	SETMENU="Menu"
	MAXASK=5
	AID=12345
	GN="Test Game"
	SGNAID="Test Game (12345)"
	PPW="wiki"
	HEADLINEFONT="larger"
	GEOM=""
	STLICON="icon"
	SHOWPIC="pic"
	F1ACTION="echo"
	BUT_SKIP="SKIP"
	BUT_SKIPCG="DON'T ASK AGAIN"
	BUT_MAINMENU="MAIN MENU"
	GUI_ASKOPENSET="Open the settings menu?"
	GUI_EDITABLECFGS="editable configs"
	GUI_EDITABLEGAMECFGS="editable game configs"
	NOTY_CANCELREQ1="Canceled the settings requester XXX times for game 'YYY (ZZZ)'. It can be disabled permanently with the 'DON'T ASK AGAIN' button"
	NOTY_CANCELREQ2="Canceled the settings requester XXX times for game 'YYY (ZZZ)'"
	NOTY_DONTASK="Disabled the settings requester for game 'XXX (YYY)'"
	USENOTIFIER=0
	ONSTEAMDECK=0
	STLQUIET=0
	DLSTEAMDECKCOMPATINFO=0
	STLGDECKCOMPAT="$BATS_TEST_TMPDIR/deck"
	PDBRASINF="$BATS_TEST_TMPDIR/pdbr.json"

	YADIMGTOP=()
	WINDECO=()
	CfgFiles=()

	# simple yad stub: any --field invocation is the wait requester form
	cat > "$BATS_TEST_TMPDIR/stubbin/yad" <<'EOF'
#!/bin/bash
for arg in "$@"; do
	case "$arg" in
		--field*)
			echo "form:$*" >> "$STUB_YAD_LOG"
			exit "${STUB_YAD_RC:-0}"
			;;
	esac
done
echo "other:$*" >> "$STUB_YAD_LOG"
exit 0
EOF
	chmod +x "$BATS_TEST_TMPDIR/stubbin/yad"
	export YAD="$BATS_TEST_TMPDIR/stubbin/yad"
	export STUB_YAD_LOG="$BATS_TEST_TMPDIR/yad.log"
	export STUB_YAD_RC=0
	: > "$STUB_YAD_LOG"

	MARK="$BATS_TEST_TMPDIR/mark"
	mkdir -p "$MARK"

	writeAllAIMeta() { :; }
	getAvailableCfgs() { :; }
	fixShowGnAid() { :; }
	pollWinRes() { :; }
	setShowPic() { :; }
	getLaPl() { echo "last played today"; }
	prepareProtonDBRating() { :; }
	prepareSteamDeckCompatInfo() { :; }
	MainMenu() { touch "$MARK/MainMenu"; }
	EditorDialog() { touch "$MARK/EditorDialog"; }
	favoritesMenu() { touch "$MARK/favoritesMenu"; }
	openGameMenu() { touch "$MARK/openGameMenu"; }
}

teardown() {
	pkill -f "$BATS_TEST_TMPDIR/stubbin/yad" 2>/dev/null || true
}

@test "editorSkipped: first skip writes ASKCNT=1 and leaves WAITEDITOR alone" {
	run editorSkipped
	[ "$status" -eq 0 ]
	grep -q '^ASKCNT="1"$' "$GAMECFG"
	grep -q '^WAITEDITOR="5"$' "$GAMECFG"
}

@test "editorSkipped: increments an existing counter" {
	printf 'WAITEDITOR="5"\nASKCNT="2"\n' > "$GAMECFG"
	run editorSkipped
	[ "$status" -eq 0 ]
	grep -q '^ASKCNT="3"$' "$GAMECFG"
}

@test "editorSkipped: at MAXASK no longer disables the requester silently" {
	printf 'WAITEDITOR="5"\nASKCNT="5"\n' > "$GAMECFG"
	run editorSkipped
	[ "$status" -eq 0 ]
	# counter keeps counting, is NOT reset
	grep -q '^ASKCNT="6"$' "$GAMECFG"
	# the silent rewrite is gone
	grep -q '^WAITEDITOR="5"$' "$GAMECFG"
	! grep -q '^WAITEDITOR="0"$' "$GAMECFG"
}

@test "editorDontAskAgain: explicitly disables the requester and resets the counter" {
	printf 'WAITEDITOR="5"\nASKCNT="3"\n' > "$GAMECFG"
	ASKCNT=3
	run editorDontAskAgain
	[ "$status" -eq 0 ]
	grep -q '^WAITEDITOR="0"$' "$GAMECFG"
	grep -q '^ASKCNT="0"$' "$GAMECFG"
}

@test "askSettings: SKIP (rc=1) counts a skip, requester stays enabled" {
	STUB_YAD_RC=1 run askSettings
	[ "$status" -eq 0 ]
	grep -q '^ASKCNT="1"$' "$GAMECFG"
	grep -q '^WAITEDITOR="5"$' "$GAMECFG"
}

@test "askSettings: DON'T ASK AGAIN (rc=2) disables the requester" {
	STUB_YAD_RC=2 run askSettings
	[ "$status" -eq 0 ]
	grep -q '^WAITEDITOR="0"$' "$GAMECFG"
	grep -q '^ASKCNT="0"$' "$GAMECFG"
}

@test "askSettings: opening the menu (rc=0) dispatches to the menu" {
	STUB_YAD_RC=0 run askSettings
	[ "$status" -eq 0 ]
	[ -f "$MARK/MainMenu" ]
	! grep -q '^ASKCNT' "$GAMECFG"
}

@test "askSettings: requester offers the DON'T ASK AGAIN button" {
	run askSettings
	[ "$status" -eq 0 ]
	grep -q -- "--button=DON'T ASK AGAIN:2" "$STUB_YAD_LOG"
	grep -q -- "--button=SKIP:1" "$STUB_YAD_LOG"
}

@test "askSettings: nothing happens when WAITEDITOR=0 in the game config" {
	printf 'WAITEDITOR="0"\n' > "$GAMECFG"
	run askSettings
	[ "$status" -eq 0 ]
	[ ! -s "$STUB_YAD_LOG" ]
}

@test "askSettings: TIMEOUT (rc=70) starts the game without side effects" {
	STUB_YAD_RC=70 run askSettings
	[ "$status" -eq 0 ]
	! grep -q '^ASKCNT' "$GAMECFG"
	grep -q '^WAITEDITOR="5"$' "$GAMECFG"
}
