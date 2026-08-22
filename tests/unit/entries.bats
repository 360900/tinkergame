#!/usr/bin/env bash

load helpers

ENTRYSSRC=""

setup() {
	tg_load
	STLSHM="$BATS_TEST_TMPDIR/shm"
	mkdir -p "$STLSHM"
	STLRAWENTRIES="$STLSHM/rawentries.txt"
	STLSETENTRIES="$STLSHM/setentries.txt"
	MTEMP="$STLSHM/menutemp"
	ENTRYSSRC="$BATS_TEST_TMPDIR/srcentries.sh"
	TGSRC_SETENTRIES="$ENTRYSSRC"
	cat >"$ENTRYSSRC" <<'EOF'
function AllSettingsEntriesDummyFunction {
#STARTSETENTRIES
	--field="     $GUI_A!$DESC_A ('USEA')":CHK "${USEA/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` \
	--field="     $GUI_B!$DESC_B ('USEB')":CHK "${USEB/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` \
#ENDSETENTRIES
}
EOF
}

@test "listAllSettingsEntries: creates raw entries and var list when missing" {
	run listAllSettingsEntries
	[ "$status" -eq 0 ]
	[ "$(grep -c -- "--field" "$STLRAWENTRIES")" -eq 2 ]
	[ "$(grep -cx "USEA" "$STLSETENTRIES")" -eq 1 ]
	[ "$(grep -cx "USEB" "$STLSETENTRIES")" -eq 1 ]
}

@test "listAllSettingsEntries: keeps an up-to-date cache untouched" {
	run listAllSettingsEntries
	printf 'STALEMARKER\n' >>"$STLSETENTRIES"
	printf 'STALEMARKER\n' >>"$STLRAWENTRIES"
	# make the source older than the caches: no refresh expected
	touch -d '2020-01-01 00:00:00' "$ENTRYSSRC"

	run listAllSettingsEntries
	[ "$status" -eq 0 ]
	grep -qx "STALEMARKER" "$STLSETENTRIES"
	grep -qx "STALEMARKER" "$STLRAWENTRIES"
}

@test "listAllSettingsEntries: refreshes stale caches and clears MTEMP" {
	run listAllSettingsEntries
	printf 'STALEMARKER\n' >>"$STLSETENTRIES"
	printf 'STALEMARKER\n' >>"$STLRAWENTRIES"
	mkdir -p "$MTEMP"
	touch "$MTEMP/stale-template"
	# make the source newer than the caches: refresh expected
	touch -d '2035-01-01 00:00:00' "$ENTRYSSRC"

	run listAllSettingsEntries
	[ "$status" -eq 0 ]
	[ "$(grep -cx "USEA" "$STLSETENTRIES")" -eq 1 ]
	[ "$(grep -cx "USEB" "$STLSETENTRIES")" -eq 1 ]
	! grep -qx "STALEMARKER" "$STLSETENTRIES"
	! grep -qx "STALEMARKER" "$STLRAWENTRIES"
	[ "$(grep -c -- "--field" "$STLRAWENTRIES")" -eq 2 ]
	[ ! -f "$MTEMP/stale-template" ]
	[ -d "$MTEMP" ]
}
