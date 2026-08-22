#!/usr/bin/env bash
# Tabbed settings menu tests (lib/gui/tabs.sh).
#
# yad is replaced by a faithful stub: the notebook process waits until all
# plugs are up, then - on an even response code - signals them with SIGUSR1 so
# they print their field values, exactly like the real yad notebook does.

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
	export STLMENUBLOCKCFG="$BATS_TEST_TMPDIR/menublock.conf"
	export STLMENUSORTCFG="$BATS_TEST_TMPDIR/menusort.cfg"

	# smart yad stub replacing the inert one from helpers.bash
	local yadstub="$BATS_TEST_TMPDIR/stubbin/yad"
	cat >"$yadstub" <<'STUB'
#!/bin/bash
case "$1" in
	--help-all)
		printf '  --notebook\n  --plug=KEY\n  --tab=TEXT\n  --image-on-top\n  --decorated\n'
		exit 0
		;;
	--notebook)
		printf 'notebook:%s\n' "$*" >>"$STUB_YAD_LOG"
		rc="${STUB_YAD_RC:-0}"
		wanted="${STUB_PLUGS:-1}"
		# wait for all plugs to come up (like the real notebook waits for
		# every declared tab to register)
		i=1
		while [ "$i" -le 50 ]; do
			have="$(grep -c '^plug:' "$STUB_YAD_LOG" 2>/dev/null)" || have=0
			[ "$have" -ge "$wanted" ] && break
			sleep 0.1
			i=$((i + 1))
		done
		# even response codes (not ESC 252 / timeout 70) make the notebook
		# tell every plug to print its field values before exiting
		if [ "$rc" -ne 252 ] && [ "$rc" -ne 70 ] && [ $((rc % 2)) -eq 0 ]; then
			sleep "${STUB_NB_DELAY:-2}"
			pkill -USR1 -f -- "$STUB_YAD_LOGDIR/stubbin/yad --plug" 2>/dev/null
			sleep 0.3
		fi
		exit "$rc"
		;;
	--plug=*)
		n=0
		for a in "$@"; do
			case "$a" in
				--field=*) n=$((n + 1)) ;;
			esac
		done
		printf 'plug:%s\n' "$*" >>"$STUB_YAD_LOG"
		plug_out() {
			i=1
			while [ "$i" -le "$n" ]; do
				printf 'plugval%d\n' "$i"
				i=$((i + 1))
			done
		}
		trap 'plug_out; exit 0' USR1
		trap 'exit 0' TERM USR2 INT
		# stay alive like a real plug in gtk_main until we get signaled
		sleep 10 &
		wait $!
		exit 0
		;;
	*)
		exit 0
		;;
esac
STUB
	chmod +x "$yadstub"
	export YAD="$yadstub"
	export STUB_YAD_LOG="$BATS_TEST_TMPDIR/yad.log"
	export STUB_YAD_LOGDIR="$BATS_TEST_TMPDIR"
	export STUB_YAD_RC=0
	: >"$STUB_YAD_LOG"

	prepareGUI   # fills YADHELP/YADIMGTOP/WINDECO through the stub

	export COLCOUNT=1
	export GEOM=""
	export STLICON="$BATS_TEST_TMPDIR/icon.png"
	export BUT_EXIT="Exit" BUT_BACK="Back" BUT_MAINMENU="MainMenu"
	export BUT_RELOAD="Reload" BUT_SAVERELOAD="SaveReload" BUT_SAVEPLAY="SavePlay" BUT_PLAY="Play"

	# fixture settings template in the exact raw-grepped format:
	# Gui header (MENU_GAME+MENU_GLOBAL), a MENU_GLOBAL-only Gui field,
	# one Proton and two Tools fields with MENU_GAME
	cat >"$STLRAWENTRIES" <<'ENTRIES'
--field="$(spanFont "$GUI_OPTSGUI" "H")":LBL "SKIP" `#CAT_Gui` `#HEAD_Gui` `#MENU_GAME` `#MENU_GLOBAL` \
--field="     $GUI_STLLANG!$DESC_STLLANG ('STLLANG')":CB "${STLLANG/#-/ -}" `#CAT_Gui` `#MENU_GLOBAL` \
--field="     $GUI_USEPROTON!$DESC_USEPROTON ('USEPROTON')":CB "${USEPROTON/#-/ -}" `#CAT_Proton` `#MENU_GAME` \
--field="     $GUI_USEMANGOHUD!$DESC_USEMANGOHUD ('USEMANGOHUD')":CHK "${USEMANGOHUD/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` \
--field="     $GUI_USEGAMESCOPE!$DESC_USEGAMESCOPE ('USEGAMESCOPE')":CHK "${USEGAMESCOPE/#-/ -}" `#CAT_Tools` `#SUB_Checkbox` `#MENU_GAME` \
ENTRIES

	TGMENU="$MTEMP/testmenu"
	export MKCFG="$MTEMP/mkcfg"
}

teardown() {
	# kill stray stub processes (orphaned sleeping plugs)
	pkill -f -- "$BATS_TEST_TMPDIR/stubbin/yad" 2>/dev/null || true
}

@test "tabs: splitter buckets template lines per category without losing any" {
	cat >"$MTEMP/split-test" <<'TPL'
--field="Z ('VAR_Z')":CHK "0" \
--field="A ('VAR_A')":CHK "0" `#CAT_One` `#MENU_GAME` \
--field="B ('VAR_B')":CHK "0" \
--field="C ('VAR_C')":CHK "0" `#CAT_Two` `#MENU_GAME` \
TPL
	run tgSplitTemplateByCat "$MTEMP/split-test" "$MTEMP/split-out"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "Misc" ]
	[ "${lines[1]}" = "One" ]
	[ "${lines[2]}" = "Two" ]
	[ "$(wc -l <"$MTEMP/split-out-tab-1")" -eq 1 ]
	[ "$(wc -l <"$MTEMP/split-out-tab-2")" -eq 2 ]
	[ "$(wc -l <"$MTEMP/split-out-tab-3")" -eq 1 ]
	# no template line lost: 1 + 2 + 1 == 4
	[ "$(cat "$MTEMP/split-out-tab-1" "$MTEMP/split-out-tab-2" "$MTEMP/split-out-tab-3" | wc -l)" -eq 4 ]
}

@test "tabs: notebook menu assembles per-tab outputs aligned with the template" {
	STUB_PLUGS=3 STUB_YAD_RC=6 run openTabbedMenu 0 "$TGMENU" "TestMenu" "$STLICON" "EMPTY" "1" "Test Title" "none" "MENU_GAME"
	[ "$status" -eq 6 ]

	# three tab chunks in category order
	[ -f "${TGMENU}-tab-1" ]
	[ -f "${TGMENU}-tab-2" ]
	[ -f "${TGMENU}-tab-3" ]

	# combined template: Gui header, USEPROTON, USEMANGOHUD, USEGAMESCOPE
	# (the MENU_GLOBAL-only STLLANG field is filtered out by ARGSPAT)
	[ "$(wc -l <"${TGMENU}-${TMPL}")" -eq 4 ]
	! grep -q "STLLANG" "${TGMENU}-${TMPL}"
	grep -q "('USEPROTON')" "${TGMENU}-${TMPL}"
	grep -q "('USEMANGOHUD')" "${TGMENU}-${TMPL}"
	grep -q "('USEGAMESCOPE')" "${TGMENU}-${TMPL}"

	# per-tab outputs concatenated in the same order:
	# 1 field (header), 1 field (Proton), 2 fields (Tools)
	[ "$(wc -l <"$MKCFG")" -eq 4 ]
	[ "$(sed -n '2p' "$MKCFG")" = "plugval1" ]
	[ "$(sed -n '4p' "$MKCFG")" = "plugval2" ]

	# the notebook got one --tab per category and an integer --key
	grep -q -- "--notebook --key=" "$STUB_YAD_LOG"
	grep -q -- "--tab=Gui --tab=Proton --tab=Tools" "$STUB_YAD_LOG"
	# three plugs were launched with the right tabnums
	[ "$(grep -c '^plug:' "$STUB_YAD_LOG")" -eq 3 ]
	grep -q -- "--tabnum=1" "$STUB_YAD_LOG"
	grep -q -- "--tabnum=3" "$STUB_YAD_LOG"
}

@test "tabs: ESC (252) closes without printing plug values" {
	STUB_PLUGS=3 STUB_YAD_RC=252 run openTabbedMenu 0 "$TGMENU" "TestMenu" "$STLICON" "EMPTY" "1" "Test Title" "none" "MENU_GAME"
	[ "$status" -eq 252 ]
	[ ! -s "$MKCFG" ]
}

@test "tabs: saveMenuEntries maps concatenated output onto the template" {
	STLGAMECFG="$BATS_TEST_TMPDIR/game.conf"
	printf 'USEPROTON="none"\nUSEMANGOHUD="none"\nUSEGAMESCOPE="none"\n' >"$STLGAMECFG"

	STUB_PLUGS=3 STUB_YAD_RC=6 run openTabbedMenu 0 "$TGMENU" "TestMenu" "$STLICON" "EMPTY" "1" "Test Title" "none" "MENU_GAME"
	[ "$status" -eq 6 ]

	# production runs without errexit; updateConfigEntry ends with a best
	# effort 'rm $FUPDATE' that is allowed to fail
	( set +e
		saveMenuEntries "$TGMENU"
	)

	grep -q '^USEPROTON="plugval1"$' "$STLGAMECFG"
	grep -q '^USEMANGOHUD="plugval1"$' "$STLGAMECFG"
	grep -q '^USEGAMESCOPE="plugval2"$' "$STLGAMECFG"
}

@test "tabs: fallback when disabled via USETABBEDMENU=0" {
	USETABBEDMENU=0
	run openTabbedMenu 0 "$TGMENU" "TestMenu" "$STLICON" "EMPTY" "1" "Test Title" "none" "MENU_GAME"
	[ "$status" -eq 3 ]
	# returned before creating anything
	[ ! -f "${TGMENU}-${TMPL}" ]
	[ ! -f "$STUB_YAD_LOG" ] || [ ! -s "$STUB_YAD_LOG" ]
}

@test "tabs: fallback without DISPLAY" {
	unset DISPLAY
	run openTabbedMenu 0 "$TGMENU" "TestMenu" "$STLICON" "EMPTY" "1" "Test Title" "none" "MENU_GAME"
	[ "$status" -eq 3 ]
}

@test "tabs: fallback when the yad build has no notebook support" {
	# prepareGUI is the only writer of YADHELP - empty it out
	YADHELP=""
	run openTabbedMenu 0 "$TGMENU" "TestMenu" "$STLICON" "EMPTY" "1" "Test Title" "none" "MENU_GAME"
	[ "$status" -eq 3 ]
}

@test "tabs: fallback with only one category" {
	cat >"${TGMENU}-${TMPL}" <<'TPL'
--field="     A!B ('VAR_A')":CHK "0" `#CAT_Only` `#MENU_GAME` \
TPL
	run openTabbedMenu 0 "$TGMENU" "TestMenu" "$STLICON" "EMPTY" "1" "Test Title" "none" "MENU_GAME"
	[ "$status" -eq 3 ]
	# no notebook was started
	! grep -q '^notebook:' "$STUB_YAD_LOG"
}

@test "tabs: fallback when a plug dies during setup" {
	# stub notebook that never exits + a plug mode that dies instantly:
	# the liveness check must detect this and return the fallback code
	local yadstub="$BATS_TEST_TMPDIR/stubbin/yad"
	cat >"$yadstub" <<'STUB'
#!/bin/bash
case "$1" in
	--help-all)
		printf '  --notebook\n  --plug=KEY\n  --tab=TEXT\n'
		exit 0
		;;
	--notebook)
		printf 'notebook:%s\n' "$*" >>"$STUB_YAD_LOG"
		while true; do sleep 1; done
		;;
	--plug=*)
		printf 'plug:%s\n' "$*" >>"$STUB_YAD_LOG"
		exit 1
		;;
esac
exit 0
STUB
	chmod +x "$yadstub"

	run openTabbedMenu 0 "$TGMENU" "TestMenu" "$STLICON" "EMPTY" "1" "Test Title" "none" "MENU_GAME"
	[ "$status" -eq 3 ]
}
