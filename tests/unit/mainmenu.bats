#!/usr/bin/env bash
# Main Menu tests (lib/gui/menus.sh) for the grouped tabbed Main Menu and its
# classic single form fallback.
#
# yad is replaced by a stub faithful to the notebook/plug semantics (see
# tests/unit/tabs.bats) which additionally serves plain --form invocations.

load helpers

setup() {
	tg_load
	export DISPLAY=:99

	# repoint the /dev/shm-derived paths (computed at source time before
	# helpers.bash redirected STLSHM)
	export MTEMP="$STLSHM/menutemp"
	mkdir -p "$MTEMP"

	# smart yad stub replacing the inert one from helpers.bash
	local yadstub="$BATS_TEST_TMPDIR/stubbin/yad"
	cat >"$yadstub" <<'STUB'
#!/bin/bash
LOG="$STUB_YAD_LOG"
mode=""
for a in "$@"; do
	case "$a" in
		--notebook) mode=notebook ;;
		--plug=*) mode=plug ;;
	esac
done
if [ "$1" = "--help-all" ]; then
	printf '  --notebook\n  --plug=KEY\n  --tab=TEXT\n  --image-on-top\n  --decorated\n'
	exit 0
fi
n=0
for a in "$@"; do
	case "$a" in
		--field=*) n=$((n + 1)) ;;
	esac
done
case "$mode" in
	notebook)
		printf 'notebook:%s\n' "$*" >>"$LOG"
		rc="${STUB_YAD_RC:-0}"
		wanted="${STUB_PLUGS:-1}"
		# wait for all plugs to come up (like the real notebook waits for
		# every declared tab to register)
		i=1
		while [ "$i" -le 50 ]; do
			have="$(grep -c '^plug:' "$LOG" 2>/dev/null)" || have=0
			[ "$have" -ge "$wanted" ] && break
			sleep 0.1
			i=$((i + 1))
		done
		# even response codes (not ESC 252 / timeout 70) make the notebook
		# tell every plug to print its field values before exiting
		if [ "$rc" -ne 252 ] && [ "$rc" -ne 70 ] && [ $((rc % 2)) -eq 0 ]; then
			sleep "${STUB_NB_DELAY:-1}"
			pkill -USR1 -f -- "$STUB_YAD_LOGDIR/stubbin/yad --plug" 2>/dev/null
			sleep 0.3
		fi
		exit "$rc"
		;;
	plug)
		printf 'plug:%s\n' "$*" >>"$LOG"
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
		printf 'form:%s\n' "$*" >>"$LOG"
		i=1
		while [ "$i" -le "$n" ]; do
			printf 'formval%d\n' "$i"
			i=$((i + 1))
		done
		exit "${STUB_YAD_RC:-0}"
		;;
esac
STUB
	chmod +x "$yadstub"
	export YAD="$yadstub"
	export STUB_YAD_LOG="$BATS_TEST_TMPDIR/yad.log"
	export STUB_YAD_LOGDIR="$BATS_TEST_TMPDIR"
	export STUB_YAD_RC=0
	export STUB_NB_DELAY=1
	: >"$STUB_YAD_LOG"

	prepareGUI   # fills YADHELP/YADIMGTOP/WINDECO through the stub

	# ---- environment ----
	export USETABBEDMENU=1 COLCOUNT=4 GEOM=""
	export STLICON="$BATS_TEST_TMPDIR/icon.png"
	export SHOWPIC="$BATS_TEST_TMPDIR/showpic.png"
	export F1ACTIONCG="bash -c setColGui"
	export AID="12345" GN="Test Game" SETMENU="Settings Menu"
	export SMALLDESK=1 ONSTEAMDECK=0 STEAMDECKCOMPATRATING="Good"
	export SHADDESTDIR="/tmp/shaders" VTX="vortex" HEADLINEFONT="larger"
	export BUT_EXIT="EXIT" BUT_GUISET_CATMENUSHORT="CATEGORIES" BUT_GM="GAME MENU"
	export BUT_DGM="DEFAULT GAME MENU" BUT_GLM="GLOBAL MENU" BUT_FAV="FAVORITES"
	export BUT_EDITORMENU="EDITOR" BUT_SEARCH="SEARCH" BUT_PLAY="PLAY"
	export GUI_MMTAB_DL="Downloads" GUI_MMTAB_WP="Wine & Proton" GUI_MMTAB_SH="Shaders & HUD"
	export GUI_MMTAB_MODS="Mod Managers" GUI_MMTAB_STEAM="Steam" GUI_MMTAB_GT="Game Tools"
	export FBUT_GUISET_DCP="DL CUSTOM PROTON" FBUT_GUISET_DW="DL WINE"
	export FBUT_GUISET_RECREATEPFX="RECREATE PFX" FBUT_GUISET_WDC="WINE DEBUG"
	export FBUT_GUISET_WTSEL="WINETRICKS" FBUT_GUISET_ADDNSGA="ADD NSG"
	export FBUT_GUISET_CREATEEVALSC="CREATE EVALSC" FBUT_GUISET_OTR="ONE TIME RUN"
	export FBUT_GUISET_DXHSEL="DXVK HUD" FBUT_GUISET_SHADERREPOS="SHADER REPOS"
	export FBUT_GUISET_UPSHADER="UPDATE SHADERS" FBUT_GUISET_FAVSEL="FAVORITES SEL"
	export FBUT_GUISET_BLOCKCAT="BLOCK CAT" FBUT_GUISET_SORTCAT="SORT CAT"
	export FBUT_GUISET_OPURL="OPEN HELP URL" FBUT_GUISET_GASCO="GAMESCOPE"
	export FBUT_GUISET_VORTEX="VORTEX" FBUT_GUISET_MO="MO2" FBUT_GUISET_GETSLR="GET SLR"
	export GUI_GAFI="GAME FILES"
	export TT_GETSLR="" TT_SHADERREPOS="" TT_UPSHADER="" TT_FAVSEL=""
	export TT_SORTCAT="" TT_ADDNSGA="" TT_OTR="" TT_GASCO="" TT_VORTEX="" TT_MO=""
	CfgFiles=()
	MARK="$BATS_TEST_TMPDIR/markers"
	mkdir -p "$MARK"

	# ---- function overrides ----
	createDLReShadeList() { :; }
	createMO2SilentModeExeProfilesList() { :; }
	prepareMenu() { :; }
	setShowPic() { :; }
	setHuyList() { :; }
	setOPCustPath() { :; }
	fixCustomMeta() { :; }
	loadCfg() { :; }
	prepareSteamDeckCompatInfo() { :; }
	getLaPl() { echo "Last played: yesterday"; }
	fixShowGnAid() { :; }
	prepareProtonDBRating() { :; }
	getGameFiles() { :; }
	setGameFilesArray() { :; }
	createProtonList() { :; }
	pollWinRes() { COLCOUNT=4; }
	refreshProtList() { :; }
	clickInfo() { :; }
	setGuiCategoryMenuSel() { touch "$MARK/catsel"; }
	openGameMenu() { touch "$MARK/openGameMenu"; }
	openGameDefaultMenu() { touch "$MARK/openGameDefaultMenu"; }
	openGlobalMenu() { touch "$MARK/openGlobalMenu"; }
	favoritesMenu() { touch "$MARK/favoritesMenu"; }
	EditorDialog() { touch "$MARK/EditorDialog"; }
	openSearchMenu() { touch "$MARK/openSearchMenu"; }
	startSteamGame() { touch "$MARK/startSteamGame"; }
	closeSTL() { touch "$MARK/closeSTL"; }
	goBackToPrevFunction() { touch "$MARK/goBack"; }
}

teardown() {
	pkill -f -- "$BATS_TEST_TMPDIR/stubbin/yad" 2>/dev/null || true
}

@test "mainmenu: tabbed Main Menu with grouped tabs and rc dispatch to the game menu" {
	STUB_PLUGS=6
	STUB_YAD_RC=6
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/openGameMenu" ]
	# one notebook with six tabs
	[ "$(grep -c '^notebook:' "$STUB_YAD_LOG")" -eq 1 ]
	grep -qF 'notebook:--notebook --key=' "$STUB_YAD_LOG"
	[ "$(grep '^notebook:' "$STUB_YAD_LOG" | grep -o -- '--tab=' | wc -l)" -eq 6 ]
	grep -qF -- '--tab=Downloads' "$STUB_YAD_LOG"
	grep -qF -- '--tab=Steam' "$STUB_YAD_LOG"
	grep -qF -- '--tab=Game Tools' "$STUB_YAD_LOG"
	# the header text and the game picture are on the notebook
	grep -qF -- '--text=<span' "$STUB_YAD_LOG"
	grep -qF -- "TinkerGame" "$STUB_YAD_LOG"
	grep -qF -- "--image=$SHOWPIC" "$STUB_YAD_LOG"
	# six plugs, one per tab, with the grouped buttons (3/3/3/2/4/5 fields).
	# the plug lines appear in race order, so match per tabnum.
	[ "$(grep -c '^plug:' "$STUB_YAD_LOG")" -eq 6 ]
	[ "$(grep '^plug:' "$STUB_YAD_LOG" | grep -o -- '--field=' | wc -l)" -eq 20 ]
	[ "$(grep '^plug:' "$STUB_YAD_LOG" | grep -o -- '--tabnum=[0-9]*' | sort | tr '\n' ' ')" = "--tabnum=1 --tabnum=2 --tabnum=3 --tabnum=4 --tabnum=5 --tabnum=6 " ]
	[ "$(grep '^plug:.*--tabnum=1 ' "$STUB_YAD_LOG" | grep -o -- '--field=' | wc -l)" -eq 3 ]
	[ "$(grep '^plug:.*--tabnum=6 ' "$STUB_YAD_LOG" | grep -o -- '--field=' | wc -l)" -eq 5 ]
	# plug outputs were flushed to files on the even response code
	[ "$(wc -l < "$MTEMP/mainmenu-tab-out-1")" -eq 3 ]
	[ "$(wc -l < "$MTEMP/mainmenu-tab-out-6")" -eq 5 ]
}

@test "mainmenu: tabbed rc=16 dispatches to the game" {
	STUB_PLUGS=6
	STUB_YAD_RC=16
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/startSteamGame" ]
	[ ! -f "$MARK/openGameMenu" ]
}

@test "mainmenu: tabbed rc=18 dispatches to the settings search" {
	STUB_PLUGS=6
	STUB_YAD_RC=18
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/openSearchMenu" ]
}

@test "mainmenu: tabbed rc=0 exits through closeSTL" {
	STUB_PLUGS=6
	STUB_YAD_RC=0
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/closeSTL" ]
	[ ! -f "$MARK/goBack" ]
}

@test "mainmenu: tabbed ESC (252) falls through without dispatching" {
	STUB_PLUGS=6
	STUB_YAD_RC=252
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/goBack" ]
	[ ! -f "$MARK/openGameMenu" ]
	[ ! -f "$MARK/startSteamGame" ]
	# ESC never asks the plugs to print values
	[ ! -s "$MTEMP/mainmenu-tab-out-1" ]
}

@test "mainmenu: USETABBEDMENU=0 falls back to the classic single form" {
	USETABBEDMENU=0
	STUB_YAD_RC=16
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^notebook:' "$STUB_YAD_LOG")" -eq 0 ]
	[ "$(grep -c '^plug:' "$STUB_YAD_LOG")" -eq 0 ]
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 1 ]
	# all 20 buttons in one form, labels and AID-carrying commands intact
	[ "$(grep '^form:' "$STUB_YAD_LOG" | grep -o -- '--field=' | wc -l)" -eq 20 ]
	grep -qF -- 'DL CUSTOM PROTON' "$STUB_YAD_LOG"
	grep -qF -- 'VORTEX' "$STUB_YAD_LOG"
	grep -qF -- 'GAME FILES' "$STUB_YAD_LOG"
	grep -qF -- 'getslrbtn "12345"' "$STUB_YAD_LOG"
	grep -qF -- 'ccd "12345" "s"' "$STUB_YAD_LOG"
	[ -f "$MARK/startSteamGame" ]
}

@test "mainmenu: no DISPLAY falls back to the classic single form" {
	unset DISPLAY
	STUB_YAD_RC=16
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^notebook:' "$STUB_YAD_LOG")" -eq 0 ]
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 1 ]
	[ -f "$MARK/startSteamGame" ]
}
