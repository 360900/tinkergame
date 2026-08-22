#!/usr/bin/env bash
# Settings search tests (lib/gui/search.sh).
#
# yad is replaced by a stub that answers --entry / --info dialogs and
# emulates settings forms: it prints one value line per --field argument,
# using a configurable sequence of response codes (STUB_FORM_RC_SEQ) so
# recursive save+reload flows can be exercised deterministically.

load helpers

setup() {
	tg_load
	export DISPLAY=:99

	# repoint the /dev/shm-derived paths (they were computed at source time
	# from the real /dev/shm before helpers.bash redirected STLSHM)
	export MTEMP="$STLSHM/menutemp"
	mkdir -p "$MTEMP"
	export STLRAWENTRIES="$STLSHM/rawentries.txt"
	export STLSETENTRIES="$STLSHM/setentries.txt"
	export STLNOBLOCKENTRIES="$STLSHM/noblockentries.txt"
	export STLCATSORTENTRIES="$STLSHM/catsortentries.txt"

	# smart yad stub replacing the inert one from helpers.bash
	local yadstub="$BATS_TEST_TMPDIR/stubbin/yad"
	cat >"$yadstub" <<'STUB'
#!/bin/bash
case "$1" in
	--help-all)
		printf '  --notebook\n  --plug=KEY\n  --tab=TEXT\n  --image-on-top\n  --decorated\n'
		exit 0
		;;
	--entry)
		printf 'entry:%s\n' "$*" >>"$STUB_YAD_LOG"
		printf '%s\n' "${STUB_QUERY:-}"
		exit "${STUB_ENTRY_RC:-0}"
		;;
	--info)
		printf 'info:%s\n' "$*" >>"$STUB_YAD_LOG"
		exit 0
		;;
esac

# form mode: one --field argument means one value line on stdout
n=0
for a in "$@"; do
	case "$a" in
		--field=*) n=$((n + 1)) ;;
	esac
done
if [ "$n" -gt 0 ]; then
	printf 'form:%s\n' "$*" >>"$STUB_YAD_LOG"
	cntf="$STUB_YAD_LOGDIR/formcount"
	c=0
	[ -f "$cntf" ] && c=$(cat "$cntf" 2>/dev/null)
	c=$((c + 1))
	echo "$c" >"$cntf"
	rc="$(printf '%s' "${STUB_FORM_RC_SEQ:-0}" | cut -d' ' -f"$c")"
	[ -n "$rc" ] || rc="$(printf '%s' "${STUB_FORM_RC_SEQ:-0}" | awk '{print $NF}')"
	i=1
	while [ "$i" -le "$n" ]; do
		printf 'plugval%d\n' "$i"
		i=$((i + 1))
	done
	exit "$rc"
fi
exit 0
STUB
	chmod +x "$yadstub"
	export YAD="$yadstub"
	export STUB_YAD_LOG="$BATS_TEST_TMPDIR/yad.log"
	export STUB_YAD_LOGDIR="$BATS_TEST_TMPDIR"
	export STUB_QUERY=""
	export STUB_ENTRY_RC=0
	export STUB_FORM_RC_SEQ="0"
	: >"$STUB_YAD_LOG"

	prepareGUI   # fills YADHELP/YADIMGTOP/WINDECO through the stub

	export COLCOUNT=1
	export GEOM=""
	export STLICON="$BATS_TEST_TMPDIR/icon.png"
	export NOICON="$BATS_TEST_TMPDIR/noicon.png"
	export BUT_EXIT="Exit" BUT_BACK="Back" BUT_MAINMENU="MainMenu"
	export BUT_RELOAD="Reload" BUT_SAVERELOAD="SaveReload" BUT_SAVEPLAY="SavePlay" BUT_PLAY="Play"
	export BUT_SEL="Select" BUT_SEARCH="Search"
	export GUI_SEARCHBOX="Search settings"
	export GUI_SEARCHRESULTS="Settings matching 'XXX'"
	export GUI_SEARCHNORESULTS="No settings found matching your search"
	export SAVESETSIZE=0
	export GAMETEMPMENU="$MTEMP/gametmpmenu"

	# label/desc variables the search expands to find label text matches
	export GUI_OPTSGUI="General Settings Menu Options"
	export GUI_STLLANG="Language" DESC_STLLANG="the language to use"
	export GUI_USEPROTON="Use Proton" DESC_USEPROTON="use proton instead of wine"
	export GUI_USEMANGOHUD="Use MangoHud" DESC_USEMANGOHUD="start the game with the mangohud overlay"
	export GUI_USEGAMESCOPE="Use GameScope" DESC_USEGAMESCOPE="start the game with gamescope"

	# fixture settings template in the exact raw-grepped format
	cat >"$STLRAWENTRIES" <<'ENTRIES'
--field="$(spanFont "$GUI_OPTSGUI" "H")":LBL "SKIP" `#CAT_Gui` `#HEAD_Gui` `#MENU_GAME` `#MENU_GLOBAL` \
--field="     $GUI_STLLANG!$DESC_STLLANG ('STLLANG')":CB "${STLLANG/#-/ -}" `#CAT_Gui` `#MENU_GLOBAL` \
--field="     $GUI_USEPROTON!$DESC_USEPROTON ('USEPROTON')":CB "${USEPROTON/#-/ -}" `#CAT_Proton` `#MENU_GAME` \
--field="     $GUI_USEMANGOHUD!$DESC_USEMANGOHUD ('USEMANGOHUD')":CHK "${USEMANGOHUD/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` \
--field="     $GUI_USEGAMESCOPE!$DESC_USEGAMESCOPE ('USEGAMESCOPE')":CHK "${USEGAMESCOPE/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` \
ENTRIES

	# config targets for saveMenuEntries routing
	export STLGAMECFG="$BATS_TEST_TMPDIR/game.conf"
	export STLDEFGLOBALCFG="$BATS_TEST_TMPDIR/global.conf"
	export STLURLCFG="$BATS_TEST_TMPDIR/url.conf"
	printf 'USEMANGOHUD="0"\nUSEPROTON="none"\nUSEGAMESCOPE="0"\n' >"$STLGAMECFG"
	printf 'STLLANG="english"\n' >"$STLDEFGLOBALCFG"

	# override the heavy context helpers - not what these tests are about
	prepareMenu() { GOBACK=1; }
	pollWinRes() { COLCOUNT=1; }
	clickInfo() { :; }
	MainMenu() { touch "$BATS_TEST_TMPDIR/mainmenu-called"; }
	startSteamGame() { touch "$BATS_TEST_TMPDIR/started"; }
	closeSTL() { touch "$BATS_TEST_TMPDIR/closed"; }
	goBackToPrevFunction() { :; }

	SEARCHOUT="$STLSHM/search-out"
}

@test "search: matches the variable name case-insensitively" {
	run tgSearchEntries "mAnGo" "$SEARCHOUT"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$SEARCHOUT")" -eq 1 ]
	grep -q "USEMANGOHUD" "$SEARCHOUT"
}

@test "search: matches the expanded GUI label text" {
	run tgSearchEntries "language" "$SEARCHOUT"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$SEARCHOUT")" -eq 1 ]
	grep -q "'STLLANG'" "$SEARCHOUT"
}

@test "search: matches the expanded description text" {
	run tgSearchEntries "overlay" "$SEARCHOUT"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$SEARCHOUT")" -eq 1 ]
	grep -q "USEMANGOHUD" "$SEARCHOUT"
}

@test "search: heading lines are never matched" {
	run tgSearchEntries "menu options" "$SEARCHOUT"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$SEARCHOUT")" -eq 0 ]
}

@test "search: no match yields an empty result file" {
	run tgSearchEntries "zzznothing" "$SEARCHOUT"
	[ "$status" -eq 0 ]
	[ ! -s "$SEARCHOUT" ]
}

@test "search: empty query yields an empty result file" {
	run tgSearchEntries "" "$SEARCHOUT"
	[ "$status" -eq 0 ]
	[ ! -s "$SEARCHOUT" ]
}

@test "search: openSearchMenu shows a form and saves game fields on SAVE" {
	STUB_FORM_RC_SEQ="6 252"
	run openSearchMenu 12345 MainMenu mango
	[ "$status" -eq 0 ]
	# the form ran twice: save+reload, then ESC
	[ "$(cat "$BATS_TEST_TMPDIR/formcount")" -eq 2 ]
	# USEMANGOHUD was saved to the game config
	grep -q '^USEMANGOHUD="plugval1"$' "$STLGAMECFG"
	# the results form carried the actual matched field
	grep -q '^form:.*USEMANGOHUD' "$STUB_YAD_LOG"
}

@test "search: global fields are saved to the global config" {
	STUB_FORM_RC_SEQ="6 252"
	run openSearchMenu 12345 MainMenu language
	[ "$status" -eq 0 ]
	grep -q '^STLLANG="plugval1"$' "$STLDEFGLOBALCFG"
	# nothing leaked into the game config
	if grep -q 'plugval1' "$STLGAMECFG"; then
		return 1
	fi
}

@test "search: back button returns to the calling menu" {
	STUB_FORM_RC_SEQ="0"
	run openSearchMenu 12345 MainMenu mango
	[ "$status" -eq 0 ]
	[ -f "$BATS_TEST_TMPDIR/mainmenu-called" ]
}

@test "search: no results shows an info dialog and re-prompts" {
	run openSearchMenu 12345 MainMenu zzznothing
	[ "$status" -eq 0 ]
	grep -q '^info:' "$STUB_YAD_LOG"
	# the query prompt re-opened and no form was ever shown
	grep -q '^entry:' "$STUB_YAD_LOG"
	[ ! -f "$BATS_TEST_TMPDIR/formcount" ]
}

@test "search: cancel in the query prompt aborts the search" {
	STUB_ENTRY_RC=1
	run openSearchMenu 12345 MainMenu
	[ "$status" -eq 0 ]
	grep -q '^entry:' "$STUB_YAD_LOG"
	[ ! -f "$BATS_TEST_TMPDIR/formcount" ]
	[ ! -f "${MTEMP}/searchmenu-template" ]
}

@test "search: generated menu function carries buttons and matched fields only" {
	run tgSearchEntries "gamescope" "$SEARCHOUT"
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$SEARCHOUT")" -eq 1 ]

	STUB_FORM_RC_SEQ="252"
	run openSearchMenu 12345 MainMenu gamescope
	[ "$status" -eq 0 ]
	# ESC (252) prints nothing - no case matches, falls through
	grep -q -- '--button="Back":0 --button="MainMenu":2' "${MTEMP}/searchmenu"
	grep -q -- '--field="     $GUI_USEGAMESCOPE' "${MTEMP}/searchmenu"
	if grep -q 'USEMANGOHUD' "${MTEMP}/searchmenu"; then
		return 1
	fi
}
