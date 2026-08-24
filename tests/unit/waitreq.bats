#!/usr/bin/env bash

# wait-requester behavior:
# - editorSkipped must NOT silently rewrite WAITEDITOR=0 at MAXASK anymore
# - editorDontAskAgain explicitly disables the requester (WAITEDITOR=0 + ASKCNT=0)
# - askSettings opens the start menu directly - no requester window in between

load helpers

setup() {
	tg_load

	GAMECFG="$BATS_TEST_TMPDIR/game.conf"
	printf 'WAITEDITOR="5"\n' > "$GAMECFG"
	STLGAMECFG="$GAMECFG"
	SWRF="$BATS_TEST_TMPDIR/skip.wrf"

	WAITEDITOR=5
	STARTMENU="Menu"
	MAXASK=5
	AID=12345

	YADIMGTOP=()
	WINDECO=()
	CfgFiles=()

	# yad stub - must NOT be called anymore: askSettings opens the start
	# menu directly, so any yad invocation here is a regression
	cat > "$BATS_TEST_TMPDIR/stubbin/yad" <<'EOF'
#!/bin/bash
echo "yad:$*" >> "$STUB_YAD_LOG"
exit 0
EOF
	chmod +x "$BATS_TEST_TMPDIR/stubbin/yad"
	export YAD="$BATS_TEST_TMPDIR/stubbin/yad"
	export STUB_YAD_LOG="$BATS_TEST_TMPDIR/yad.log"
	: > "$STUB_YAD_LOG"

	MARK="$BATS_TEST_TMPDIR/mark"
	mkdir -p "$MARK"

	writeAllAIMeta() { :; }
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

@test "askSettings: opens the start menu directly without a requester" {
	run askSettings
	[ "$status" -eq 0 ]
	[ -f "$MARK/MainMenu" ]
	# no requester window is spawned anymore
	[ ! -s "$STUB_YAD_LOG" ]
}

@test "askSettings: STARTMENU selects which menu is opened" {
	STARTMENU="Editor" run askSettings
	[ "$status" -eq 0 ]
	[ -f "$MARK/EditorDialog" ]
	[ ! -f "$MARK/MainMenu" ]

	STARTMENU="Favorites" run askSettings
	[ "$status" -eq 0 ]
	[ -f "$MARK/favoritesMenu" ]
	[ ! -f "$MARK/MainMenu" ]

	STARTMENU="Game" run askSettings
	[ "$status" -eq 0 ]
	[ -f "$MARK/openGameMenu" ]
	[ ! -f "$MARK/MainMenu" ]
}

@test "askSettings: nothing happens when WAITEDITOR=0 in the game config" {
	printf 'WAITEDITOR="0"\n' > "$GAMECFG"
	run askSettings
	[ "$status" -eq 0 ]
	[ ! -f "$MARK/MainMenu" ]
	[ ! -s "$STUB_YAD_LOG" ]
}

@test "askSettings: skip file suppresses the start menu" {
	touch "$SWRF"
	run askSettings
	[ "$status" -eq 0 ]
	[ ! -f "$MARK/MainMenu" ]
	[ ! -s "$STUB_YAD_LOG" ]
}

@test "askSettings: game specific WAITEDITOR=0 is honoured" {
	printf 'WAITEDITOR="0"\n' > "$GAMECFG"
	run askSettings
	[ "$status" -eq 0 ]
	[ ! -f "$MARK/MainMenu" ]
}

@test "askSettings: game specific WAITEDITOR larger than 0 still opens the menu" {
	printf 'WAITEDITOR="2"\n' > "$GAMECFG"
	run askSettings
	[ "$status" -eq 0 ]
	[ -f "$MARK/MainMenu" ]
	# the game value overrides the session default
	run bash -c 'grep "^WAITEDITOR" "$0" | cut -d "=" -f2' "$GAMECFG"
	[ "$(tr -d '"' <<< "$output")" = "2" ]
}
