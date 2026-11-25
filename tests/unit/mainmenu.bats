#!/usr/bin/env bash
# Main Menu tests (lib/gui/menus.sh): the single form Main Menu with its
# settings and tool buttons grouped into titled sections, the header, the rc
# dispatch, the autosave of its settings, the section help and Extras.
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
		if [ -n "$STUB_YAD_OUT" ]; then
			cat "$STUB_YAD_OUT"
			exit "${STUB_YAD_RC:-0}"
		fi
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
	export BUT_EXTRAS="EXTRAS" BUT_BACK="BACK" BUT_DONE="DONE"
	export GUI_MMSEC_PLAY="Play settings" GUI_MMSEC_FIX="Fix problems"
	export GUI_MMSEC_LOOK="Look & performance" GUI_MMSEC_MODS="Mods"
	export GUI_MMSEC_TOOLS="Game tools" GUI_MMSEC_MENUS="Steam and menus"
	export GUI_MM_PROTON="PROTON" GUI_MM_ARGS="ARGS" GUI_MM_FPSLIMIT="FPS LIMIT"
	export GUI_MM_FPSCOUNTER="FPS COUNTER" GUI_MM_GAMEMODE="GAMEMODE"
	export GUI_MM_RESHADE="RESHADE" GUI_MM_GAMESCOPE="GAMESCOPE ON"
	export TT_MM_PROTON="Pick the Proton version." TT_MMSECHELP="What do these do?"
	export TT_RECREATEPFX="Start over with a fresh prefix."
	export NOTY_RESHADEHOTKEY="RESHADE NOTE"
	export FBUT_GUISET_DCP="DL CUSTOM PROTON" FBUT_GUISET_DW="DL WINE"
	export FBUT_GUISET_RECREATEPFX="RESET PFX" FBUT_GUISET_WDC="WINE DEBUG"
	export FBUT_GUISET_WTSEL="COMPONENTS" FBUT_GUISET_ADDNSGA="ADD NSG"
	export FBUT_GUISET_CREATEEVALSC="CREATE EVALSC" FBUT_GUISET_OTR="ONE TIME RUN"
	export FBUT_GUISET_DXHSEL="DXVK HUD" FBUT_GUISET_SHADERREPOS="SHADER REPOS"
	export FBUT_GUISET_UPSHADER="UPDATE SHADERS" FBUT_GUISET_FAVSEL="FAVORITES SEL"
	export FBUT_GUISET_BLOCKCAT="BLOCK CAT" FBUT_GUISET_SORTCAT="SORT CAT"
	export FBUT_GUISET_OPURL="GAME HELP" FBUT_GUISET_GASCO="GAMESCOPE"
	export FBUT_GUISET_VORTEX="VORTEX" FBUT_GUISET_MO="MO2" FBUT_GUISET_GETSLR="GET SLR"
	export GUI_GAFI="GAME FILES"
	export PROTYADLIST="GE-Proton11-12!Proton Experimental"
	export USEPROTON="Proton Experimental" GAMEARGS="none" NON="none" DXVK_FPSLIMIT="none"
	export USEMANGOHUD=0 USEGAMEMODERUN=1 USERESHADE=0 USEGAMESCOPE=0
	export STLGAMECFG="$BATS_TEST_TMPDIR/game.conf"
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
	updateConfigEntry() { printf '%s=%s\n' "$1" "$2" >>"$MARK/cfg"; }
	notiShow() { printf '%s\n' "$1" >>"$MARK/noti"; }
}

teardown() {
	pkill -f -- "$BATS_TEST_TMPDIR/stubbin/yad" 2>/dev/null || true
}

# fields of the logged form call, one per line, in order
form_fields() {
	grep '^form:' "$STUB_YAD_LOG" | grep -o -- "--field=[^:]*:[A-Z]*" 
}

@test "mainmenu: one form with settings and tool buttons in four titled sections" {
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	# a single plain form, no notebook
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 1 ]
	[ "$(grep -c '^notebook:' "$STUB_YAD_LOG")" -eq 0 ]
	[ "$(form_fields | grep -c ':FBTN$')" -eq 11 ]
	# the settings of the game config
	[ "$(form_fields | grep -c ':CHK$')" -eq 4 ]
	[ "$(form_fields | grep -c ':CB$')" -eq 1 ]
	[ "$(form_fields | grep -c ':CBE$')" -eq 1 ]
	grep -qF -- '--field=ARGS!:' "$STUB_YAD_LOG"
	grep -qF -- '--field=PROTON!Pick the Proton version.:CB' "$STUB_YAD_LOG"
	# four section titles as help buttons, markup escaped
	[ "$(form_fields | grep ':BTN$' | grep -c "fgalpha='65%'")" -eq 4 ]
	grep -qF -- 'Look &amp; performance ⓘ</span>!What do these do?:BTN' "$STUB_YAD_LOG"
	grep -qF -- 'game section-help 3' "$STUB_YAD_LOG"
	# labels and AID-carrying commands intact
	grep -qF -- 'DL CUSTOM PROTON' "$STUB_YAD_LOG"
	grep -qF -- 'RESET PFX!Start over with a fresh prefix.:FBTN' "$STUB_YAD_LOG"
	grep -qF -- 'game compatdata "12345" "s"' "$STUB_YAD_LOG"
	grep -qF -- 'wine components "12345"' "$STUB_YAD_LOG"
	# the rarely used tools are in Extras
	[ "$(grep -cF -- 'proton getslr-gui' "$STUB_YAD_LOG")" -eq 0 ]
	[ "$(grep -cF -- 'ONE TIME RUN' "$STUB_YAD_LOG")" -eq 0 ]
	# header text and game picture
	grep -qF -- "--image $SHOWPIC" "$STUB_YAD_LOG"
	# COLCOUNT=4 puts all four sections side by side
	grep -qF -- '--columns=4' "$STUB_YAD_LOG"
	grep -qF -- '--separator=\n' "$STUB_YAD_LOG"
}

@test "mainmenu: the bottom bar is Exit, Search, Settings, Extras and Play" {
	run MainMenu "12345"
	[ "$(grep '^form:' "$STUB_YAD_LOG" | grep -o -- '--button=[^:]*:[0-9]*' | tr '\n' '|')" = "--button=EXIT:0|--button=SEARCH:18|--button=GLOBAL MENU:10|--button=EXTRAS:20|--button=PLAY:16|" ]
}

@test "mainmenu: rc=10 opens the settings" {
	STUB_YAD_RC=10
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/openGlobalMenu" ]
}

@test "mainmenu: rc=20 opens Extras with the other tools and menus" {
	STUB_YAD_RC=20
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 2 ]
	local extras
	extras="$(grep '^form:' "$STUB_YAD_LOG" | tail -n1)"
	[[ "$extras" == *'proton getslr-gui "12345"'* ]]
	[[ "$extras" == *'game first-install "12345"'* ]]
	[[ "$extras" == *'ONE TIME RUN'* ]]
	[[ "$extras" == *'config favorites "12345" set'* ]]
	[[ "$extras" == *"Steam and menus</span>:LBL"* ]]
	[[ "$extras" != *'section-help'* ]]
	[ "$(grep -o -- '--button=[^:]*:[0-9]*' <<< "$extras" | tr '\n' '|')" = "--button=BACK:0|--button=GAME MENU:6|--button=DEFAULT GAME MENU:8|--button=CATEGORIES:4|--button=FAVORITES:12|--button=EDITOR:14|" ]
}

@test "extras: the buttons open the full settings menus" {
	local pair
	for pair in 6:openGameMenu 8:openGameDefaultMenu 4:catsel 12:favoritesMenu 14:EditorDialog; do
		rm -f "$MARK"/*
		STUB_YAD_RC="${pair%%:*}"
		run ExtrasMenu "12345" MainMenu
		[ "$status" -eq 0 ]
		[ -f "$MARK/${pair#*:}" ]
		[ -f "$MARK/goBack" ]
	done
}

# Main Menu form output with VAR=VALUE at the line of the field of VAR
mm_output() {
	local -A want=()
	local kv i
	for kv in "$@"; do
		want["${kv%%=*}"]="${kv#*=}"
	done
	for (( i = 0; i < ${#MMFORM[@]} / 2; i++ )); do
		if [ -n "${MM_FIELDVARS[$i]}" ]; then
			printf '%s\n' "${want[${MM_FIELDVARS[$i]}]}"
		else
			printf '\n'
		fi
	done
}

mm_build() {
	setMainMenuSections
	MM_ORDER=( 1 3 2 4 )
	buildMainMenuForm
}

@test "mainmenu: every setting field maps to its config variable" {
	mm_build
	[ "$(printf '%s\n' "${MM_FIELDVARS[@]}" | sort | tr '\n' ' ')" = "DXVK_FPSLIMIT GAMEARGS USEGAMEMODERUN USEGAMESCOPE USEMANGOHUD USEPROTON USERESHADE " ]
	local i
	for i in "${!MM_FIELDVARS[@]}"; do
		[[ "${MMFORM[$(( i * 2 ))]}" == *":CB" || "${MMFORM[$(( i * 2 ))]}" == *":CBE" || "${MMFORM[$(( i * 2 ))]}" == *":CHK" || "${MMFORM[$(( i * 2 ))]}" == *"!:" ]]
	done
}

@test "mainmenu: leaving with a button saves the settings to the game config" {
	mm_build
	mm_output USEPROTON=GE-Proton11-12 "GAMEARGS= -fullscreen" DXVK_FPSLIMIT=60 USEMANGOHUD=TRUE USEGAMEMODERUN=FALSE USERESHADE=FALSE USEGAMESCOPE=TRUE >"$BATS_TEST_TMPDIR/out"
	saveMainMenuFields "$(cat "$BATS_TEST_TMPDIR/out")"
	grep -qx 'USEPROTON=GE-Proton11-12' "$MARK/cfg"
	grep -qx 'GAMEARGS=-fullscreen' "$MARK/cfg"
	grep -qx 'DXVK_FPSLIMIT=60' "$MARK/cfg"
	grep -qx 'USEMANGOHUD=TRUE' "$MARK/cfg"
	grep -qx 'USEGAMEMODERUN=FALSE' "$MARK/cfg"
	grep -qx 'USEGAMESCOPE=TRUE' "$MARK/cfg"
	# the running launch uses the new values
	[ "$USEPROTON" = "GE-Proton11-12" ]
	[ "$GAMEARGS" = "-fullscreen" ]
	[ "$USEMANGOHUD" = "1" ]
	[ "$USEGAMEMODERUN" = "0" ]
	[ ! -f "$MARK/noti" ]
}

@test "mainmenu: empty launch options are saved as none, an empty dropdown is skipped" {
	mm_build
	saveMainMenuFields "$(mm_output USEPROTON= GAMEARGS= USEMANGOHUD=FALSE)"
	grep -qx 'GAMEARGS=none' "$MARK/cfg"
	[ "$(grep -c '^USEPROTON=' "$MARK/cfg")" -eq 0 ]
	[ "$USEPROTON" = "Proton Experimental" ]
}

@test "mainmenu: closing the window saves nothing" {
	mm_build
	saveMainMenuFields ""
	[ ! -f "$MARK/cfg" ]
}

@test "mainmenu: the form output of MainMenu is saved" {
	STUB_YAD_RC=16
	mm_build
	mm_output USEPROTON=GE-Proton11-12 USEGAMEMODERUN=TRUE >"$BATS_TEST_TMPDIR/out"
	export STUB_YAD_OUT="$BATS_TEST_TMPDIR/out"
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/startSteamGame" ]
	grep -qx 'USEPROTON=GE-Proton11-12' "$MARK/cfg"
	grep -qx 'USEGAMEMODERUN=TRUE' "$MARK/cfg"
}

@test "mainmenu: turning ReShade on shows the hotkey note once" {
	mm_build
	saveMainMenuFields "$(mm_output USERESHADE=TRUE)"
	[ "$(cat "$MARK/noti")" = "RESHADE NOTE" ]
	[ "$USERESHADE" = "1" ]
	# already on: no note
	saveMainMenuFields "$(mm_output USERESHADE=TRUE)"
	[ "$(wc -l < "$MARK/noti")" -eq 1 ]
}

@test "mainMenuSectionHelp: explains every entry of the section" {
	run mainMenuSectionHelp 2
	[ "$status" -eq 0 ]
	local help
	help="$(grep '^form:' "$STUB_YAD_LOG")"
	[[ "$help" == *"--title=Fix problems"* ]]
	[[ "$help" == *'<b>RESET PFX</b>\nStart over with a fresh prefix.'* ]]
	[[ "$help" == *'<b>GAME FILES</b>'* ]]
	[[ "$help" == *"--button=DONE:0"* ]]

	: >"$STUB_YAD_LOG"
	run mainMenuSectionHelp 3
	[[ "$(grep '^form:' "$STUB_YAD_LOG")" == *"Look &amp; performance</span>"* ]]
}

@test "mainMenuSectionHelp: invalid sections open nothing" {
	local sec
	for sec in 0 9 abc ""; do
		run mainMenuSectionHelp "$sec"
		[ "$status" -eq 0 ]
	done
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 0 ]
}

# test sections: sizes with title 4, 4, 4, 3, 5, 6 (sections 1..6)
mm_sections() {
	MM_G1=(a 1 b 2 c 3) MM_G2=(a 1 b 2 c 3) MM_G3=(a 1 b 2 c 3)
	MM_G4=(a 1 b 2) MM_G5=(a 1 b 2 c 3 d 4) MM_G6=(a 1 b 2 c 3 d 4 e 5)
	MM_TITLES=(T1 T2 T3 T4 T5 T6)
	MM_ORDER=( 6 5 2 3 1 4 )
}

# row index of every section title, keyed by title, for the current MMFORM
# laid out in MMCOLUMNS columns (yad fills columns top to bottom)
mm_title_rows() {
	local cells rows i f t
	cells=$(( ${#MMFORM[@]} / 2 ))
	rows=$(( cells / MMCOLUMNS ))
	for (( i = 0; i < cells; i++ )); do
		f="${MMFORM[$(( i * 2 ))]}"
		if [[ "$f" == *"</span>:LBL" ]]; then
			t="${f%</span>:LBL}"; t="${t##*>}"
			printf '%s %d %d\n' "$t" $(( i % rows )) $(( i / rows ))
		fi
	done
}

@test "mainmenu: every column holds the same number of cells" {
	mm_sections
	for cols in 1 2 3 4 5 6 9; do
		COLCOUNT="$cols"
		buildMainMenuForm
		[ $(( ${#MMFORM[@]} / 2 % MMCOLUMNS )) -eq 0 ]
	done
}

@test "mainmenu: columns are the largest divisor of the section count up to COLCOUNT" {
	mm_sections
	for pair in 1:1 2:2 3:3 4:3 5:3 6:6 9:6; do
		COLCOUNT="${pair%:*}"
		buildMainMenuForm
		[ "$MMCOLUMNS" -eq "${pair#*:}" ]
	done
}

@test "mainmenu: section titles of a band share one row across the columns" {
	mm_sections
	COLCOUNT=4
	buildMainMenuForm
	[ "$MMCOLUMNS" -eq 3 ]
	# band 1: T6 (6), T5 (5), T2 (4) -> 6 rows; band 2: T3, T1, T4 -> 4 rows
	[ "$(( ${#MMFORM[@]} / 2 ))" -eq 30 ]
	run mm_title_rows
	[ "$(sort <<< "$output" | tr '\n' '|')" = "T1 6 1|T2 0 2|T3 6 0|T4 6 2|T5 0 1|T6 0 0|" ]

	COLCOUNT=2
	buildMainMenuForm
	# bands: T6 T5 (6), T2 T3 (4), T1 T4 (4) -> 14 rows per column
	[ "$(( ${#MMFORM[@]} / 2 ))" -eq 28 ]
	run mm_title_rows
	[ "$(sort <<< "$output" | tr '\n' '|')" = "T1 10 0|T2 6 0|T3 6 1|T4 10 1|T5 0 1|T6 0 0|" ]
}

@test "mainmenu: invalid COLCOUNT falls back to one column" {
	COLCOUNT="abc"
	MM_G1=(a 1) MM_G2=(a 1) MM_G3=(a 1) MM_G4=(a 1) MM_G5=(a 1) MM_G6=(a 1)
	MM_TITLES=(T1 T2 T3 T4 T5 T6)
	MM_ORDER=( 1 2 3 4 5 6 )
	buildMainMenuForm
	[ "$MMCOLUMNS" -eq 1 ]
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

@test "fixShowGnAid: a failed title lookup falls back to the game name, not its error text" {
	# setup stubs fixShowGnAid out; load the real one
	eval "$(sed -n '/^function fixShowGnAid {/,/^}/p' "$TG_ROOT/lib/gui/menus.sh")"
	getTitleFromID() { echo "No Title found for '$1'"; return 1; }
	AID="413150" GN="Stardew Valley"
	fixShowGnAid
	[ "$SGNAID" = "Stardew Valley (413150)" ]

	getTitleFromID() { echo "Stardew Valley"; }
	GN=""
	fixShowGnAid
	[ "$SGNAID" = "Stardew Valley (413150)" ]
}
