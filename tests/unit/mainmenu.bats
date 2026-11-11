#!/usr/bin/env bash
# Main Menu tests (lib/gui/menus.sh): the single form Main Menu with its tool
# buttons grouped into titled sections, the header and the rc dispatch.
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
	export AID="12345" GN="Test Game" SETMENU="Settings Menu" SGNAID="Test Game (12345)" TGMAINCSS=""
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

# fields of the logged form call, one per line, in order
form_fields() {
	grep '^form:' "$STUB_YAD_LOG" | grep -o -- "--field=[^:]*:[A-Z]*" 
}

@test "mainmenu: one form with all 20 tool buttons in six titled sections" {
	STUB_YAD_RC=6
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/openGameMenu" ]
	# a single plain form, no notebook
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 1 ]
	[ "$(grep -c '^notebook:' "$STUB_YAD_LOG")" -eq 0 ]
	[ "$(form_fields | grep -c ':FBTN$')" -eq 20 ]
	# six section titles, markup escaped
	[ "$(form_fields | grep ':LBL$' | grep -c "fgalpha='65%'")" -eq 6 ]
	grep -qF -- 'Wine &amp; Proton</span>:LBL' "$STUB_YAD_LOG"
	grep -qF -- 'Game Tools</span>:LBL' "$STUB_YAD_LOG"
	# labels and AID-carrying commands intact
	grep -qF -- 'DL CUSTOM PROTON' "$STUB_YAD_LOG"
	grep -qF -- 'proton getslr-gui "12345"' "$STUB_YAD_LOG"
	grep -qF -- 'game compatdata "12345" "s"' "$STUB_YAD_LOG"
	# header text and game picture
	grep -qF -- "--image $SHOWPIC" "$STUB_YAD_LOG"
	grep -qF -- '--columns=4' "$STUB_YAD_LOG"
}

@test "mainmenu: sections are never split across columns" {
	for cols in 1 2 3 4 6; do
		COLCOUNT="$cols"
		MM_G1=(a 1 b 2 c 3) MM_G2=(a 1 b 2 c 3) MM_G3=(a 1 b 2 c 3)
		MM_G4=(a 1 b 2) MM_G5=(a 1 b 2 c 3 d 4) MM_G6=(a 1 b 2 c 3 d 4 e 5)
		MM_TITLES=(T1 T2 T3 T4 T5 T6)
		MM_ORDER=( 6 4 2 3 1 5 )
		buildMainMenuForm
		# two words per form cell
		cells=$(( ${#MMFORM[@]} / 2 ))
		rows=$(( (cells + cols - 1) / cols ))
		# every title starts a column or follows a whole section in the same column
		i=0
		col_start=0
		while [ "$i" -lt "$cells" ]; do
			f="${MMFORM[$(( i * 2 ))]}"
			if [[ "$f" == *"</span>:LBL" ]]; then
				t="${f%</span>:LBL}"; t="${t##*>}"
				n="${t#T}"
				declare -n G="MM_G$n"
				size=$(( ${#G[@]} / 2 + 1 ))
				unset -n G
				# the whole section fits before the column ends
				[ $(( i % rows + size )) -le "$rows" ]
			fi
			i=$(( i + 1 ))
		done
		# no more columns than asked for
		[ $(( (cells + rows - 1) / rows )) -le "$cols" ]
	done
}

@test "mainmenu: two columns keep the section order and pad with blank labels" {
	COLCOUNT=2
	MM_G1=(a 1 b 2 c 3) MM_G2=(a 1 b 2 c 3) MM_G3=(a 1 b 2 c 3)
	MM_G4=(a 1 b 2) MM_G5=(a 1 b 2 c 3 d 4) MM_G6=(a 1 b 2 c 3 d 4 e 5)
	MM_TITLES=(T1 T2 T3 T4 T5 T6)
	MM_ORDER=( 6 4 2 3 1 5 )
	buildMainMenuForm
	# 6 + 3 + 4 = 13 rows in the first column, 4 + 4 + 5 = 13 in the second
	[ "${#MMFORM[@]}" -eq 52 ]
	[ "$(printf '%s\n' "${MMFORM[@]}" | grep -c -- '^--field= :LBL$')" -eq 0 ]
	[ "$(printf '%s\n' "${MMFORM[@]}" | grep -o 'T[0-9]</span>' | tr -d '\n')" = "T6</span>T4</span>T2</span>T3</span>T1</span>T5</span>" ]

	COLCOUNT=4
	buildMainMenuForm
	# 8 rows: T6 (6) + 2 pad | T4 + T2 (7) + 1 pad | T3 + T1 (8) | T5 (5)
	[ "$(printf '%s\n' "${MMFORM[@]}" | grep -c -- '^--field= :LBL$')" -eq 3 ]
}

@test "mainmenu: invalid COLCOUNT falls back to one column" {
	COLCOUNT="abc"
	MM_G1=(a 1) MM_G2=(a 1) MM_G3=(a 1) MM_G4=(a 1) MM_G5=(a 1) MM_G6=(a 1)
	MM_TITLES=(T1 T2 T3 T4 T5 T6)
	MM_ORDER=( 1 2 3 4 5 6 )
	buildMainMenuForm
	[ "${#MMFORM[@]}" -eq 24 ]
	[ "$(printf '%s\n' "${MMFORM[@]}" | grep -c -- '^--field= :LBL$')" -eq 0 ]
}

@test "mainmenu: header shows the game title, the version and no empty config line" {
	SGNAID="Test Game (12345)"
	fixShowGnAid() { :; }
	PROGVERS="v9.9.9"
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	grep -qF -- "font_weight='bold'>Test Game</span>  <span fgalpha='55%'>12345</span>" "$STUB_YAD_LOG"
	grep -qF -- "TinkerGame v9.9.9</span>" "$STUB_YAD_LOG"
	[ "$(grep -cF -- 'TinkerGame (tinkergame)' "$STUB_YAD_LOG")" -eq 0 ]
	# CfgFiles is empty in setup
	[ "$(grep -cF -- 'editable config files' "$STUB_YAD_LOG")" -eq 0 ]
}

@test "mainmenu: config file count is shown when there are config files" {
	CfgFiles=(a b c)
	GUI_EDITABLECFGS="editable config files found"
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	grep -qF -- '3 editable config files found' "$STUB_YAD_LOG"
}

@test "mainmenu: sized to content off the Steam Deck, fixed geometry with scrolling on it" {
	GEOM="--geometry=1280x800+0+0"
	run MainMenu "12345"
	[ "$(grep -cF -- '--geometry=' "$STUB_YAD_LOG")" -eq 0 ]
	[ "$(grep -cF -- '--scroll' "$STUB_YAD_LOG")" -eq 0 ]

	: >"$STUB_YAD_LOG"
	ONSTEAMDECK=1
	run MainMenu "12345"
	grep -qF -- '--scroll --geometry=1280x800+0+0' "$STUB_YAD_LOG"
}

@test "mainmenu: the Main Menu stylesheet is passed only with the default CSS" {
	TGMAINCSS="/usr/share/tinkergame/misc/tg-one-main.css"
	run MainMenu "12345"
	grep -qF -- "form:--css=$TGMAINCSS " "$STUB_YAD_LOG"

	: >"$STUB_YAD_LOG"
	TGMAINCSS=""
	run MainMenu "12345"
	[ "$(grep -cF -- '--css=' "$STUB_YAD_LOG")" -eq 0 ]
}

@test "mainmenu: Exit is the first and Play the last dialog button" {
	run MainMenu "12345"
	[ "$(grep '^form:' "$STUB_YAD_LOG" | grep -o -- '--button=[^:]*:[0-9]*' | head -n1)" = "--button=EXIT:0" ]
	[ "$(grep '^form:' "$STUB_YAD_LOG" | grep -o -- '--button=[^:]*:[0-9]*' | tail -n1)" = "--button=PLAY:16" ]
}

@test "mainmenu: rc=16 dispatches to the game" {
	STUB_YAD_RC=16
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/startSteamGame" ]
	[ ! -f "$MARK/openGameMenu" ]
}

@test "mainmenu: rc=18 dispatches to the settings search" {
	STUB_YAD_RC=18
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/openSearchMenu" ]
}

@test "mainmenu: rc=0 exits through closeSTL" {
	STUB_YAD_RC=0
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/closeSTL" ]
	[ ! -f "$MARK/goBack" ]
}

@test "mainmenu: ESC (252) falls through without dispatching" {
	STUB_YAD_RC=252
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/goBack" ]
	[ ! -f "$MARK/openGameMenu" ]
	[ ! -f "$MARK/startSteamGame" ]
}

@test "mainmenu: USETABBEDMENU=0 and no DISPLAY open the same single form" {
	USETABBEDMENU=0
	run MainMenu "12345"
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 1 ]
	: >"$STUB_YAD_LOG"
	USETABBEDMENU=1
	unset DISPLAY
	STUB_YAD_RC=16
	run MainMenu "12345"
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 1 ]
	[ -f "$MARK/startSteamGame" ]
}
