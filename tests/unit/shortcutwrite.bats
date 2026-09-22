#!/usr/bin/env bash
# Writing a shortcut entry must not corrupt shortcuts.vdf.
#
# editSteamShortcutEntry converts the whole file to a hex string, edits it, and
# converts it back. It used to run "sed 's/0a//g'" over that string to drop a
# stray newline -- but on hex *text* that also matches the two characters
# straddling any byte pair X0 AY. A LastPlayTime of 0x6a1368ad reads as
# "...00ad68136a..." and lost a byte, taking the preceding key's terminator with
# it. Steam then logs "CSteamDoc::LoadShortcuts: failed to load shortcut file"
# and drops every Non-Steam game.

setup() {
	load helpers
	tg_load

	STUIDPATH="$BATS_TEST_TMPDIR/user"
	mkdir -p "$STUIDPATH/config"
	cp "$TG_FIXTURES/shortcuts-lastplaytime.vdf" "$STUIDPATH/config/shortcuts.vdf"
	SCVDF="shortcuts.vdf"
	VDFCHECK="$TG_FIXTURES/vdfcheck.py"
}

@test "fixture: the untouched file is structurally valid" {
	run python3 "$VDFCHECK" "$STUIDPATH/config/shortcuts.vdf"
	[ "$status" -eq 0 ]
}

@test "editSteamShortcutEntry: the file is still valid after setting an icon" {
	editSteamShortcutEntry "2884509494" "icon" "/path/to/icon.png"
	run python3 "$VDFCHECK" "$STUIDPATH/config/shortcuts.vdf"
	[ "$status" -eq 0 ]
	[ "$output" = "ok" ]
}

@test "editSteamShortcutEntry: the icon actually lands in the file" {
	editSteamShortcutEntry "2884509494" "icon" "/path/to/icon.png"
	run grep -c "/path/to/icon.png" "$STUIDPATH/config/shortcuts.vdf"
	[ "$output" = "1" ]
}

@test "editSteamShortcutEntry: a LastPlayTime whose bytes read as '0a' survives" {
	# 0x6a1368ad -> "00ad68136a" in hex text; the middle "0a" is not a byte
	editSteamShortcutEntry "2884509494" "icon" "/path/to/icon.png"
	run python3 -c "
import sys
b = open(sys.argv[1], 'rb').read()
i = b.find(b'LastPlayTime')
print(b[i+12:i+17].hex())
" "$STUIDPATH/config/shortcuts.vdf"
	# key terminator 00 followed by the four value bytes, untouched
	[ "$output" = "00ad68136a" ]
}

@test "editSteamShortcutEntry: every entry is still readable afterwards" {
	editSteamShortcutEntry "2884509494" "icon" "/path/to/icon.png"
	run bash -c 'getSteamShortcutHex | grep -c .'
	# both entries, as before the edit
	[ "$(getSteamShortcutHex | grep -c .)" -eq 2 ]
}

@test "editSteamShortcutEntry: the other entry is left byte for byte alone" {
	local before after
	before="$(python3 -c "
import sys
b = open(sys.argv[1], 'rb').read()
i = b.find(b'Second Game')
print(b[i:i+60].hex())
" "$STUIDPATH/config/shortcuts.vdf")"

	editSteamShortcutEntry "2884509494" "icon" "/path/to/icon.png"

	after="$(python3 -c "
import sys
b = open(sys.argv[1], 'rb').read()
i = b.find(b'Second Game')
print(b[i:i+60].hex())
" "$STUIDPATH/config/shortcuts.vdf")"

	[ "$before" = "$after" ]
}

@test "editSteamShortcutEntry: the value is not given a trailing newline" {
	editSteamShortcutEntry "2884509494" "icon" "/tmp/x.png"
	run python3 -c "
import sys
b = open(sys.argv[1], 'rb').read()
i = b.find(b'/tmp/x.png')
print(b[i:i+11].hex())
" "$STUIDPATH/config/shortcuts.vdf"
	# the path, then its NUL terminator -- no 0a in between
	[ "$output" = "2f746d702f782e706e6700" ]
}
