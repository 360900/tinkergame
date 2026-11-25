#!/usr/bin/env bash
# Main Menu tests (lib/gui/menus.sh): one notebook window with the Play
# settings and a tab per goal listing the tools, the single form fallback,
# the header, the rc dispatch, picking and running tool rows and the autosave
# of the Play settings.
#
# yad is replaced by a stub faithful to the notebook/plug semantics (see
# tests/unit/tabs.bats) which additionally serves plain --form and --list
# invocations.

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
		--list) [ -z "$mode" ] && mode=list ;;
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
# a tool row picked once while the menu is open (see mainMenuPick)
stub_pick() {
	if [ -n "$STUB_PICK" ] && [ ! -f "$STUB_YAD_LOGDIR/picked" ]; then
		touch "$STUB_YAD_LOGDIR/picked"
		printf '%s\n' "$STUB_PICK" >"$MTEMP/mainmenu-pick"
	fi
}
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
		stub_pick
		[ -f "$STUB_YAD_LOGDIR/picked" ] && rc=0
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
	list)
		printf 'list:%s\n' "$*" >>"$LOG"
		printf '%s' "$STUB_LIST_OUT"
		exit "${STUB_LIST_RC:-0}"
		;;
	*)
		printf 'form:%s\n' "$*" >>"$LOG"
		stub_pick
		rc="${STUB_YAD_RC:-0}"
		[ -f "$STUB_YAD_LOGDIR/picked" ] && rc=0
		if [ -n "$STUB_YAD_OUT" ]; then
			cat "$STUB_YAD_OUT"
			exit "$rc"
		fi
		i=1
		while [ "$i" -le "$n" ]; do
			printf 'formval%d\n' "$i"
			i=$((i + 1))
		done
		exit "$rc"
		;;
esac
STUB
	chmod +x "$yadstub"
	export YAD="$yadstub"
	export STUB_YAD_LOG="$BATS_TEST_TMPDIR/yad.log"
	export STUB_YAD_LOGDIR="$BATS_TEST_TMPDIR"
	export STUB_YAD_RC=0
	export STUB_NB_DELAY=0.2
	export STUB_PLUGS=5
	export STUB_PICK="" STUB_LIST_OUT="" STUB_LIST_RC=0
	: >"$STUB_YAD_LOG"

	prepareGUI   # fills YADHELP/YADIMGTOP/WINDECO through the stub

	# the program itself, as the tool rows run it: logs one argument per line
	MARK="$BATS_TEST_TMPDIR/markers"
	mkdir -p "$MARK"
	export TGSELF="$BATS_TEST_TMPDIR/stubbin/tinkergame"
	cat >"$TGSELF" <<STUB
#!/bin/bash
printf '%s\n' "\$@" >"$MARK/self"
STUB
	chmod +x "$TGSELF"
	realpath() { echo "$TGSELF"; }

	# ---- environment ----
	export USETABBEDMENU=1 COLCOUNT=4 GEOM="" YADVER="15.0"
	export STLICON="$BATS_TEST_TMPDIR/icon.png"
	export SHOWPIC="$BATS_TEST_TMPDIR/showpic.png"
	export F1ACTIONCG="bash -c setColGui"
	export AID="12345" GN="Test Game" SETMENU="Settings Menu" SGNAID="Test Game (12345)" TGMAINCSS=""
	export SMALLDESK=1 ONSTEAMDECK=0 STEAMDECKCOMPATRATING="Good"
	export SHADDESTDIR="/tmp/shaders" VTX="vortex" HEADLINEFONT="larger"
	export BUT_EXIT="EXIT" BUT_GUISET_CATMENUSHORT="CATEGORIES" BUT_GM="GAME MENU"
	export BUT_GLM="GLOBAL MENU" BUT_FAV="FAVORITES" BUT_EDITORMENU="EDITOR"
	export BUT_SEARCH="SEARCH" BUT_PLAY="PLAY" BUT_EXTRAS="EXTRAS" BUT_BACK="BACK" BUT_RUN="RUN"
	export GUI_MMSEC_PLAY="Play" GUI_MMSEC_FIX="Fix problems"
	export GUI_MMSEC_LOOK="Look & performance" GUI_MMSEC_MODS="Mods"
	export GUI_MM_PROTON="PROTON" GUI_MM_ARGS="ARGS" GUI_MM_FPSLIMIT="FPS LIMIT"
	export GUI_MM_FPSCOUNTER="FPS COUNTER" GUI_MM_GAMEMODE="GAMEMODE"
	export GUI_MM_RESHADE="RESHADE" GUI_MM_GAMESCOPE="GAMESCOPE ON" GUI_MM_DEFAULTMENU="DEFAULTS"
	export TT_MM_PROTON="Pick the Proton version."
	export TT_RECREATEPFX="Start over with a <fresh> prefix."
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
	haveDgpu() { return 1; }
	haveMako() { return 1; }
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

# the logged plug call of tab $1 (list rows span several lines)
plug_of() {
	awk -v t="--tabnum=$1 " '
		/^(notebook|plug|list|form):/ { on = (index($0, "plug:") == 1 && index($0, t) > 0) }
		on
	' "$STUB_YAD_LOG"
}

# keys of the rows of tool tab $1, in order
tab_keys() {
	setMainMenuContent
	local -n keys="MM_ROWKEYS_$1"
	printf '%s ' "${keys[@]}"
}

@test "mainmenu: one notebook with the Play settings and four tool tabs" {
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^notebook:' "$STUB_YAD_LOG")" -eq 1 ]
	[ "$(grep -c '^plug:' "$STUB_YAD_LOG")" -eq 5 ]
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 0 ]
	# tab labels, markup escaped
	grep -qF -- '--tab=Play --tab=Fix problems --tab=Look &amp; performance --tab=Mods --tab=EXTRAS' "$STUB_YAD_LOG"
	# the Play tab is a form of the game settings
	local play
	play="$(plug_of 1)"
	[[ "$play" == *'--form --separator=\n'* ]]
	[[ "$play" == *'--field=PROTON!Pick the Proton version.:CB Proton Experimental!GE-Proton11-12'* ]]
	[[ "$play" == *'--field=ARGS!:  '* ]]
	[[ "$play" == *'--field=FPS LIMIT!:CBE none!30!60'* ]]
	[ "$(grep -o -- ':SW ' <<< "$play" | wc -l)" -eq 4 ]
	# the tool tabs are lists that pick their row on double click
	local t
	for t in 2 3 4 5; do
		[[ "$(plug_of "$t")" == *"--list --no-headers --column=key:HD --column=text --column=tip:HD --hide-column=1 --tooltip-column=3"* ]]
		[[ "$(plug_of "$t")" == *"--dclick-action='$TGSELF' game menu-pick"* ]]
	done
	[[ "$(plug_of 2)" == *"fix-prefix <b>RESET PFX</b>"* ]]
	[[ "$(plug_of 2)" == *"Start over with a &lt;fresh&gt; prefix."* ]]
	[[ "$(plug_of 5)" == *"x-slr <b>GET SLR</b>"* ]]
	# bottom bar
	[ "$(grep '^notebook:' "$STUB_YAD_LOG" | grep -o -- '--button=[^:]*:[0-9]*' | tr '\n' '|')" = "--button=EXIT:0|--button=GLOBAL MENU:10|--button=PLAY:16|" ]
	grep -qF -- "--image=$SHOWPIC" "$STUB_YAD_LOG"
}

@test "mainmenu: the tools are grouped by goal" {
	[ "$(tab_keys 2)" = "fix-prefix fix-components fix-help fix-files " ]
	[ "$(tab_keys 3)" = "look-overlay look-shadersgame look-shadersrc look-gamescope " ]
	[ "$(tab_keys 4)" = "mods-vortex mods-mo2 " ]
	[ "$(tab_keys 5)" = "x-protondl x-firstrun x-onetime x-slr x-wdc x-winedl x-addns x-favsel x-block x-sort x-search x-gamemenu x-default x-catmenu x-favmenu x-editor " ]
}

@test "mainmenu: every tool row has a command" {
	local t k
	mainMenuRunRow() { :; }
	eval "$(sed -n '/^function mainMenuRunRow {/,/^}/p' "$TG_ROOT/lib/gui/menus.sh")"
	writelog() { [ "$1" != "SKIP" ]; }
	for t in 2 3 4 5; do
		for k in $(tab_keys "$t"); do
			rm -f "$MARK/self" "$MARK"/open* "$MARK"/catsel "$MARK"/favoritesMenu "$MARK"/EditorDialog
			mainMenuRunRow "$k" || true
			[ -f "$MARK/self" ] || [ "$(ls "$MARK" | grep -cv '^cfg$\|^noti$')" -ge 1 ]
		done
	done
}

@test "mainmenu: old yad versions get check boxes instead of switches" {
	YADVER="7.2"
	setMainMenuContent
	[ "$(printf '%s\n' "${MM_PLAYFORM[@]}" | grep -c ':CHK$')" -eq 4 ]
	[ "$(printf '%s\n' "${MM_PLAYFORM[@]}" | grep -c ':SW$')" -eq 0 ]
	YADVER="13.0"
	setMainMenuContent
	[ "$(printf '%s\n' "${MM_PLAYFORM[@]}" | grep -c ':SW$')" -eq 4 ]
}

@test "mainmenu: rc=10 opens the settings" {
	STUB_YAD_RC=10
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/openGlobalMenu" ]
}

@test "mainmenu: rc=16 dispatches to the game" {
	STUB_YAD_RC=16
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/startSteamGame" ]
	[ ! -f "$MARK/closeSTL" ]
}

@test "mainmenu: rc=0 exits through closeSTL" {
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/closeSTL" ]
	[ ! -f "$MARK/goBack" ]
}

@test "mainmenu: a pick left over from an earlier menu does not run on Exit" {
	echo "fix-prefix" >"$MTEMP/mainmenu-pick"
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/closeSTL" ]
	[ ! -f "$MARK/self" ]
}

@test "mainmenu: ESC (252) falls through without dispatching or saving" {
	STUB_YAD_RC=252
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/goBack" ]
	[ ! -f "$MARK/startSteamGame" ]
	[ ! -f "$MARK/cfg" ]
}

@test "mainmenu: a picked tool runs with the game name intact, then the menu reopens" {
	GN="It's \"Quoted\" \$HOME \`x\`"
	STUB_PICK="look-gamescope"
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ "$(cat "$MARK/self")" = "game
gamescope
12345
$GN" ]
	# reopened and left with Exit
	[ "$(grep -c '^notebook:' "$STUB_YAD_LOG")" -eq 2 ]
	[ -f "$MARK/closeSTL" ]
	# the Play settings were saved on the way
	grep -q '^USEPROTON=plugval1$' "$MARK/cfg"
}

@test "mainmenu: a picked menu row opens that menu and comes back to the Main Menu" {
	STUB_PICK="x-gamemenu"
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ -f "$MARK/openGameMenu" ]
	[ "$(grep -c '^notebook:' "$STUB_YAD_LOG")" -eq 1 ]
}

@test "mainMenuRunRow: CLI rows get their arguments one by one" {
	local pair
	for pair in "fix-prefix:game compatdata 12345 s" "fix-components:wine components 12345" \
		"look-shadersgame:update gameshaders /tmp/shaders" "x-slr:proton getslr-gui 12345" \
		"x-favsel:config favorites 12345 set" "mods-mo2:mods mo2 start"; do
		rm -f "$MARK/self"
		run mainMenuRunRow "${pair%%:*}"
		[ "$status" -eq 1 ]
		[ "$(tr '\n' ' ' < "$MARK/self")" = "${pair#*:} " ]
	done
}

@test "mainMenuRunRow: unknown rows run nothing" {
	run mainMenuRunRow "zz-nope"
	[ "$status" -eq 1 ]
	[ ! -f "$MARK/self" ]
}

@test "mainMenuPick: remembers the row and closes the menu, a second quick pick is ignored" {
	sleep 30 &
	local first=$!
	echo "$first" >"$MTEMP/mainmenu-nbpid"
	mainMenuPick "fix-help"
	[ "$(cat "$MTEMP/mainmenu-pick")" = "fix-help" ]
	wait "$first" || true
	! kill -0 "$first" 2>/dev/null

	sleep 30 &
	local second=$!
	echo "$second" >"$MTEMP/mainmenu-nbpid"
	mainMenuPick "fix-files"
	[ "$(cat "$MTEMP/mainmenu-pick")" = "fix-help" ]
	kill -0 "$second"
	kill "$second"
}

@test "mainMenuPick: an empty row is ignored" {
	mainMenuPick ""
	[ ! -f "$MTEMP/mainmenu-pick" ]
}

@test "mainmenu: without notebook support one form with a button per tool tab" {
	USETABBEDMENU=0
	STUB_YAD_RC=16
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^notebook:' "$STUB_YAD_LOG")" -eq 0 ]
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 1 ]
	local form
	form="$(grep '^form:' "$STUB_YAD_LOG")"
	[ "$(grep -o -- ':FBTN ' <<< "$form" | wc -l)" -eq 4 ]
	[[ "$form" == *"Look &amp; performance  ›:FBTN '$TGSELF' game menu-pick tab:3"* ]]
	[ -f "$MARK/startSteamGame" ]
	grep -q '^USEPROTON=formval1$' "$MARK/cfg"

	: >"$STUB_YAD_LOG"
	USETABBEDMENU=1
	unset DISPLAY
	run MainMenu "12345"
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 1 ]
}

@test "mainmenu: the single form opens the tools of a tab in their own list" {
	USETABBEDMENU=0
	STUB_PICK="tab:4"
	STUB_LIST_OUT="mods-mo2"
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	local list
	list="$(awk '/^(notebook|plug|list|form):/ { on = (index($0, "list:") == 1) } on' "$STUB_YAD_LOG")"
	[[ "$list" == *"mods-vortex <b>VORTEX</b>"* ]]
	[[ "$list" == *"--print-column=1"* ]]
	[[ "$list" == *"--button=BACK:1 --button=RUN:0"* ]]
	[ "$(tr '\n' ' ' < "$MARK/self")" = "mods mo2 start " ]
	# back in the Main Menu afterwards
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 2 ]
}

@test "mainmenu: Back in a tab list returns to the Main Menu without running anything" {
	USETABBEDMENU=0
	STUB_PICK="tab:2"
	STUB_LIST_OUT=""
	STUB_LIST_RC=1
	run MainMenu "12345"
	[ "$status" -eq 0 ]
	[ ! -f "$MARK/self" ]
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 2 ]
}

# Play tab output with VAR=VALUE at the line of the field of VAR
mm_output() {
	local -A want=()
	local kv i
	for kv in "$@"; do
		want["${kv%%=*}"]="${kv#*=}"
	done
	for (( i = 0; i < ${#MM_PLAYFORM[@]} / 2; i++ )); do
		printf '%s\n' "${want[${MM_FIELDVARS[$i]}]}"
	done
}

@test "mainmenu: every Play field maps to its config variable" {
	setMainMenuContent
	[ "${MM_FIELDVARS[*]}" = "USEPROTON GAMEARGS DXVK_FPSLIMIT USEMANGOHUD USEGAMEMODERUN USERESHADE USEGAMESCOPE" ]
	[ "$(( ${#MM_PLAYFORM[@]} / 2 ))" -eq 7 ]
}

@test "mainmenu: dedicated GPU and MAKO switches only show when available" {
	haveDgpu() { return 0; }
	haveMako() { return 0; }
	export GUI_MM_DGPU="DGPU" GUI_MM_MAKO="MAKO"
	setMainMenuContent
	[ "${MM_FIELDVARS[*]}" = "USEPROTON GAMEARGS DXVK_FPSLIMIT USEMANGOHUD USEGAMEMODERUN USEPRIMERUN USEMAKO USERESHADE USEGAMESCOPE" ]
	printf '%s\n' "${MM_PLAYFORM[@]}" | grep -q '^--field=DGPU!'
	printf '%s\n' "${MM_PLAYFORM[@]}" | grep -q '^--field=MAKO!'

	haveMako() { return 1; }
	setMainMenuContent
	[ "${MM_FIELDVARS[*]}" = "USEPROTON GAMEARGS DXVK_FPSLIMIT USEMANGOHUD USEGAMEMODERUN USEPRIMERUN USERESHADE USEGAMESCOPE" ]
}

@test "mainmenu: dedicated GPU and MAKO switches are saved" {
	haveDgpu() { return 0; }
	haveMako() { return 0; }
	setMainMenuContent
	saveMainMenuFields "$(mm_output USEPRIMERUN=TRUE USEMAKO=TRUE)"
	grep -qx 'USEPRIMERUN=TRUE' "$MARK/cfg"
	grep -qx 'USEMAKO=TRUE' "$MARK/cfg"
	[ "$USEPRIMERUN" = "1" ]
	[ "$USEMAKO" = "1" ]
}

@test "mainmenu: leaving with a button saves the settings to the game config" {
	setMainMenuContent
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

@test "mainmenu: empty launch options are saved as none, an empty Proton list is skipped" {
	PROTYADLIST=""
	USEPROTON=""
	setMainMenuContent
	saveMainMenuFields "$(mm_output USEPROTON= GAMEARGS= USEMANGOHUD=FALSE)"
	grep -qx 'GAMEARGS=none' "$MARK/cfg"
	[ "$(grep -c '^USEPROTON=' "$MARK/cfg")" -eq 0 ]
}

@test "mainmenu: closing the window saves nothing" {
	setMainMenuContent
	saveMainMenuFields ""
	[ ! -f "$MARK/cfg" ]
}

@test "mainmenu: turning ReShade on shows the hotkey note once" {
	setMainMenuContent
	saveMainMenuFields "$(mm_output USERESHADE=TRUE)"
	[ "$(cat "$MARK/noti")" = "RESHADE NOTE" ]
	[ "$USERESHADE" = "1" ]
	# already on: no note
	saveMainMenuFields "$(mm_output USERESHADE=TRUE)"
	[ "$(wc -l < "$MARK/noti")" -eq 1 ]
}

@test "mainmenu: header shows the game title, the version and no empty config line" {
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

@test "mainmenu: a fixed size off the Steam Deck, screen geometry with scrolling on it" {
	GEOM="--geometry=1280x800+0+0"
	run MainMenu "12345"
	grep -qF -- '--width=640 --height=560' "$STUB_YAD_LOG"
	[ "$(grep -cF -- '--geometry=' "$STUB_YAD_LOG")" -eq 0 ]

	: >"$STUB_YAD_LOG"
	ONSTEAMDECK=1
	run MainMenu "12345"
	grep -qF -- '--scroll --geometry=1280x800+0+0' "$STUB_YAD_LOG"
}

@test "mainmenu: the Main Menu stylesheet is passed only with the default CSS" {
	TGMAINCSS="/usr/share/tinkergame/misc/tg-one-main.css"
	run MainMenu "12345"
	grep -qF -- "notebook:--css=$TGMAINCSS --notebook" "$STUB_YAD_LOG"

	: >"$STUB_YAD_LOG"
	TGMAINCSS=""
	run MainMenu "12345"
	[ "$(grep -cF -- '--css=' "$STUB_YAD_LOG")" -eq 0 ]
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
