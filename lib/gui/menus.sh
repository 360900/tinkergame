#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function prepareMenu {
	writelog "INFO" "${FUNCNAME[0]} - Opening Menu"
	GOBACK=1

	loadCfg "$STLDEFGLOBALCFG"
	loadCfg "$STLGAMECFG"
	loadCfg "$STLURLCFG"

	resetAID "$1"
	createGameCfg
	setGN "$1"

	if [ -z "$GN" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - No game name found for '$AID' - this should not happen"
		exit
	fi
	createDropdownLists
	getAvailableCfgs
}

function openGameMenu {
	prepareMenu "$@"
	if [ -z "$2" ]; then
		FUNC="$NON"
	else
		FUNC="$2"
	fi
	PARGUI="${FUNCNAME[0]}"
	openMenu "$AID" "$FUNC" "$STLGAMECFG" "0" "$GAMEMENU" "$LGAM" "$SHOWPIC" "EMPTY" "EMPTY" "$(strFix "$GUI_SETHEAD1" "$SGNAID")" "MENU_GAME"
}

function openGameDefaultMenu {
	prepareMenu "$@"
	if [ -z "$2" ]; then
		FUNC="$NON"
	else
		FUNC="$2"
	fi
	PARGUI="${FUNCNAME[0]}"
	openMenu "$AID" "$FUNC" "$STLDEFGAMECFG" "0" "$GAMETEMPMENU" "$LGATM" "$NOICON" "EMPTY" "EMPTY" "$GUI_SETHEAD2" "MENU_GAME"
}

function openGlobalMenu {
	prepareMenu "$@"
	autoBumpReShade
	if [ -z "$2" ]; then
		FUNC="$NON"
	else
		FUNC="$2"
	fi
	PARGUI="${FUNCNAME[0]}"
	openMenu "$AID" "$FUNC" "$STLDEFGLOBALCFG" "0" "$GLOBALMENU" "$LGLM" "$NOICON" "EMPTY" "EMPTY" "$GUI_SETHEAD3" "MENU_GLOBAL"
}

function startSteamGame {
	if [ "$ISGAME" -ge 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Starting game"
	else
		if [ "$ISGAME" -ne 1 ] && [ "$AID" != "$PLACEHOLDERAID" ]; then
			STEAMARGS=(-applaunch "$AID")
			writelog "INFO" "${FUNCNAME[0]} - -------- starting game $AID in steam --------" "E"
			FINALSTARTCMD=("$STEAM" "${STEAMARGS[@]}")
			startGame "${FINALSTARTCMD[@]}" 2>/dev/null >/dev/null &
		fi
	fi
}

function openCustMenu {
	MYCAT="$3"
	MYMENU="$4"
	MYFUNC="$5"

	prepareMenu "$@"

	createGameCfg
	createDropdownLists

	TITLE="${PROGNAME}-${MYCAT}"
	pollWinRes "$TITLE" 1

	setShowPic
	cp "$SHOWPIC" "$FAVPIC"

	mkCfgTemp "${FUNCNAME[0]}"

	if [ "$2" == "$NON" ]; then
		BUT0="$BUT_EXIT"
		GOTO="Exit"
	else
		BUT0="$BUT_BACK"
		GOTO="$2"
	fi

	BUT2="$BUT_MAINMENU"
	BUT4="$BUT_RELOAD"
	BUT6="$BUT_SAVERELOAD"
	BUT8="$BUT_SAVEPLAY"
	BUT10="$BUT_PLAY"

	MYTMPL="${MYMENU}-${TMPL}"

	if [ "$MYCAT" == "Favorites" ]; then
		MYTEXT="$(strFix "$GUI_FAVORITESMENU" "$SGNAID")"
	else
		MYTEXT="$(strFix "$GUI_CATMENU" "$SGNAID" "$MYCAT")"
		if [ ! -f "$MYTMPL" ]; then
			grep "CAT_${MYCAT}" "$STLRAWENTRIES" > "$MYTMPL"
		fi
	fi

	# shellcheck disable=SC2028 # doesn't like the newline seperator, but it is valid
	{
		echo "function $MYFUNC {"
		echo "\"$YAD\" --columns=\"$COLCOUNT\" --f1-action=\"$F1ACTIONCG\" --text=\"$(spanFont "$MYTEXT" "H")\" \\"
		echo "--title=\"$TITLE\" --image \"$FAVPIC\" ${YADIMGTOP[*]} --window-icon=\"$STLICON\" --center ${WINDECO[*]} --form --separator=\"\\n\" --quoted-output \\"
		echo "--button=\"$BUT0\":0 --button=\"$BUT2\":2 --button=\"$BUT4\":4 --button=\"$BUT6\":6 --button=\"$BUT8\":8 --button=\"$BUT10\":10 $GEOM \\"
		cat "$MYTMPL"
		echo "--scroll"
		echo "}"
	} >"$MYMENU"

	source "$MYMENU"

	if [ -z "$MYFUNC" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Seems like some arguments are missing - got '$*'"
	else
		"$MYFUNC" > "$MKCFG"
		case $? in
		0)  {
				clickInfo "${FUNCNAME[0]}" "$?" "$BUT0" "Category '$MYCAT' Menu" "$GOTO"
				if [ "$GOTO" == "Exit" ]; then
					GOBACK=0
					closeSTL " ######### STOP EARLY $PROGNAME $PROGVERS #########"
					exit
				else
					rmCfgTemp "${FUNCNAME[0]}"
				fi
			}
		;;
		2) 	{
				clickInfo "${FUNCNAME[0]}" "$?" "$BUT2" "Category '$MYCAT' Menu" "$SETMENU"
				MainMenu "$AID" "${FUNCNAME[0]}"
			}
		;;
		4) 	{
				clickInfo "${FUNCNAME[0]}" "$?" "$BUT4" "Category '$MYCAT' Menu" "restart Menu"
				GOBACK=0
				writelog "INFO" "${FUNCNAME[0]} - Reload Configs and restart Category '$MYCAT' Menu"
				if [ "$SAVESETSIZE" -eq 1 ] ; then	sleep 1;	fi
				"${FUNCNAME[0]}" "$@"
			}
		;;
		6) {
				clickInfo "${FUNCNAME[0]}" "$?" "$BUT6" "Category '$MYCAT' Menu" "restart Menu"
				GOBACK=0
				saveMenuEntries "$MYMENU"
				if [ "$SAVESETSIZE" -eq 1 ] ; then	sleep 1;	fi

				if [ "$MYCAT" == "$GCD" ];then
					setGameCfgDiffs
				fi
				"${FUNCNAME[0]}" "$@"
			}
		;;
		8) 	{
				clickInfo "${FUNCNAME[0]}" "$?" "$BUT8" "Category '$MYCAT' Menu" "Game Start"
				GOBACK=0
				saveMenuEntries "$MYMENU"
				startSteamGame
			}
		;;
		10)	{
				clickInfo "${FUNCNAME[0]}" "$?" "$BUT10" "Category '$MYCAT' Menu" "Game Start"
				GOBACK=0
				startSteamGame
			}
		;;
		esac
		rmCfgTemp "${FUNCNAME[0]}"
		goBackToPrevFunction "${FUNCNAME[0]}" "$2" "$GOBACK"
	fi
}

function setGuiSortOrder {
	if [ ! -f "$STLMENUSORTCFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - '$STLMENUSORTCFG' missing"
		getCatsFromCode > "$STLMENUSORTCFG" 2>/dev/null
	fi
	export CURWIKI="$PPW/Gui-Sort-Order"
	TITLE="${PROGNAME}-SortCategories"
	pollWinRes "$TITLE"

	NEWSORT="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --center --on-top "${WINDECO[@]}" \
		--list --editable --column "Category" --separator="" --print-all \
		--title="$TITLE" --text="$(spanFont "$GUI_SORTCAT" "H")" "$GEOM" < "$STLMENUSORTCFG")"
	case $? in
		0) 	{
				writelog "INFO" "${FUNCNAME[0]} - Clicked OK - Saving new sortorder into '$STLMENUSORTCFG'"
				echo "$NEWSORT" > "$STLMENUSORTCFG"
			}
		;;
		1)	{
				writelog "INFO" "${FUNCNAME[0]} - Clicked Cancel"
			}
		;;
	esac
}

function setGuiFavoritesSelection {
	export CURWIKI="$PPW/Favorites-Menu"
	TITLE="${PROGNAME}-FavoritesSelection"
	pollWinRes "$TITLE"

	setShowPic

	FAVENTRIES="$(favoritesMenuEntries | \
	"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist \
	--column="$GUI_ADD" --column="$GUI_DESC" --column="$GUI_VAR" --column="LongDesc" --separator="\n" --print-column="3" --tooltip-column 4 --hide-column 4 \
	--text="$(spanFont "$GUI_FAVORITESSEL" "H")" --title="$TITLE" "$GEOM")"
	case $? in
		0)  {
				if [ -n "$FAVENTRIES" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Updating '$STLFAVMENUCFG' with selected Favorites"
					echo "${FAVENTRIES[@]}" > "$STLFAVMENUCFG"
					sort -u "$STLFAVMENUCFG" -o "$STLFAVMENUCFG"
					rm "${FAVMENU}-${TMPL}" 2>/dev/null
				else
					writelog "INFO" "${FUNCNAME[0]} - Nothing selected"
				fi
			}
		;;
		1)  {
				writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL - creating empty '$STLFAVMENUCFG' to skip asking again"
				touch "$STLFAVMENUCFG"
			}
		;;
	esac

	goBackToPrevFunction "${FUNCNAME[0]}" "$2"
}

function setGuiBlockSelection {
	export CURWIKI="$PPW/Gui-Hide-Categories"
	TITLE="${PROGNAME}-EntryBlockSelection"
	pollWinRes "$TITLE"

	BLENTRIES="$(createBlockYadList | \
	"$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --center --list --checklist \
	--column="$GUI_HIDE" --column="$GUI_DESC" --separator=" " --print-column="2" \
	--text="$(spanFont "$GUI_BLOCKSEL" "H")" --title="$TITLE" "$GEOM")"
	case $? in
		0)  {
				writelog "INFO" "${FUNCNAME[0]} - Updating '$STLMENUBLOCKCFG' with selected blocks"
				while read -r blentry; do
					if grep -q "$blentry" <<< "$(printf '%s\n' "$BLENTRIES")"; then
						updateConfigEntry "$blentry" "TRUE" "$STLMENUBLOCKCFG"
					else
						updateConfigEntry "$blentry" "FALSE" "$STLMENUBLOCKCFG"
					fi
				done <<< "$(grep -v "^#" "$STLMENUBLOCKCFG" | cut -d '=' -f1)"

				checkEntryBlocklist
			}
		;;
		1)  writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL"
		;;
	esac

	goBackToPrevFunction "${FUNCNAME[0]}" "$2"
}

function setGameCfgDiffs {
	writelog "INFO" "${FUNCNAME[0]} - Getting changes between game config and default"
	CHTEMP="$STLSHM/${AID}_cfgchanges.txt"
	comm -13 <(grep -v "^#" "$STLDEFGAMECFG" | grep "=" | sort -u) <(grep -v "^#" "$STLGAMECFG" | grep "=" | sort -u) > "$CHTEMP"
	rm "$MTEMP/$GCD" "$MTEMP/$GCD-${TMPL}" 2>/dev/null

	while read -r change; do
		GVAR="${change%=*}"
		TVAL="$(grep "^${GVAR}=" "$STLDEFGAMECFG" | cut -d '=' -f2)"
		TVALO="${TVAL//\"/}"
		if [ -n "$TVAL" ];then
			FRLI="$(sed -n "/^#STARTSETENTRIES/,/^#ENDSETENTRIES/p;/^#ENDSETENTRIES/q" "$TGSRC_SETENTRIES" | grep "'$GVAR'")"
			FRL1="${FRLI//\')/\') - $GUI_TEMPVAL $TVALO}"
			echo "$FRL1" >> "$MTEMP/$GCD-${TMPL}"
		fi
	done < "$CHTEMP"
	sed '/^$/d' -i "$MTEMP/$GCD-${TMPL}"
}

function setGuiCategoryMenuSel {
	export CURWIKI="$PPW/Category-Menus"
	TITLE="${PROGNAME}-CategorySelection"
	pollWinRes "$TITLE"

	setShowPic

	CATDD="$(cleanDropDown "${GCD}" "$(getCatsFromCode | tr '\n' '!' | sed "s:^!::" | sed "s:!$::")")"

	SELECTCAT="$("$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --form --separator="\n" \
	--text="$(spanFont "$(strFix "$GUI_CATSEL" "$PROGNAME")" "H")" \
	--title="$TITLE" --field=" $GUI_CAT!$(strFix "$GUI_CATSEL" "$PROGNAME")":CB "$CATDD" "$GEOM")"
	case $? in
		0)  {
				if [ "$SELECTCAT" == "$GCD" ]; then
					setGameCfgDiffs
				fi

				writelog "INFO" "${FUNCNAME[0]} - Selected '$SELECTCAT' - Opening Category Menu"
				openCustMenu "$AID" "${FUNCNAME[0]}" "$SELECTCAT" "$MTEMP/$SELECTCAT" "$LCM"
			}
		;;
		1)  {
				writelog "INFO" "${FUNCNAME[0]} - Nothing selected - going to the $SETMENU"
				MainMenu "$AID" "${FUNCNAME[0]}"
			}
		;;
	esac
}

function clickInfo {
	writelog "INFO" "$1 - Clicked '$2' - '$3'"
	writelog "INFO" "$1 - exiting '$4' and opening '$5'"
}

function getLaPl {
	if [ -f "$PLAYTIMELOGDIR/$GN.log" ]; then
		echo "<b>$GUI_LASTPLAYED</b> $(tail -n1 "$PLAYTIMELOGDIR/${GN}.log")"
	fi
}

function fixShowGnAid {
	local PRETTYGAMENAME

    # Temp workaround to fix some games not launching because of locale bugs, particularly on Steam Deck
    # Not limited to Steam Deck since this could prevent future bug reports
    # May cause other bugs so keep an eye on this, but probably this is broken because of KDE not correctly setting all locales? Seems to affect KDE on Arch primarily
    if [ -n "$LANG" ]; then
        export LC_ALL="$LANG"  # $LANG should always be defined, unless locales are VERY broken
    fi

	# Will use "real" game name if it exists, e.g. "NieR:Automata" instead of NieRAutomata
	# getTitleFromID prints an error message and fails when it finds nothing
	PRETTYGAMENAME="$( getTitleFromID "$AID" "1" )" || PRETTYGAMENAME=""
	if [ -n "$PRETTYGAMENAME" ]; then
		SGNAID="$PRETTYGAMENAME ($AID)"
		SGNAID="${SGNAID//&/+}"
	elif [ -n "$GN" ]; then
		SGNAID="$GN ($AID)"
		SGNAID="${SGNAID//&/+}"
	else
		SGNAID="$PLACEHOLDERGN ($PLACEHOLDERAID)"
	fi
}

function fixShow {
	echo "${1//&/+}"
}

## This function exists because previously, ReShade and ReShade+SpecialK were thought to need separate directories
## This is not the case; ReShade DLLs still go into the game folder with SpecialK, but are unnnamed, so both have the same SHADDESTDIR
function setShadDestDir {
	autoCollectionSettings

	setFullGameExePath "SHADDESTDIR"
}

function refreshProtList {
	if [ -f "$PROTBUMPTEMP" ]; then
		rm "$PROTONCSV" 2>/dev/null
		unset ProtonCSV
		rm "$PROTBUMPTEMP" 2>/dev/null
		createProtonList X
	fi
}

function MainMenu {
	writelog "INFO" "${FUNCNAME[0]} - Preparing to load Main Menu"

	createDLReShadeList
	createMO2SilentModeExeProfilesList
	prepareMenu "$@"

	setShowPic

	setHuyList
	setOPCustPath

	fixCustomMeta "$CUMETA/$AID.conf" # will be removed again later
	loadCfg "$CUMETA/$AID.conf" X
	loadCfg "$GEMETA/$AID.conf" X

	export CURWIKI="$PPW/Main-Menu"
	TITLE="${PROGNAME}-MainMenu"
	if [ "$ONSTEAMDECK" -eq 1 ]; then
		pollWinRes "$TITLE" 2
	else
		pollWinRes "$TITLE" 4
	fi
	fixShowGnAid

	if [ -z "$STEAMDECKCOMPATRATING" ]; then
		prepareSteamDeckCompatInfo  # Only fetches data once, we might already have it from askSettings so don't fetch again - Minor optimisation
	fi

	LAPL="$(getLaPl)"
	# game name as the title with the muted AppID next to it ($SGNAID is "Name (AppID)")
	MMGNHEAD="${SGNAID% (*}"
	MMAIDHEAD="${SGNAID##* (}"
	MMAIDHEAD="${MMAIDHEAD%)}"
	SETHEAD="$(spanFont "$MMGNHEAD" "H")  <span fgalpha='55%'>${MMAIDHEAD}</span>"

	# plain tooltips unless there is game specific info for them below
	TT_OPENURL=""
	TT_GAFI=""

	# Last played date/time
	if [ -n "$LAPL" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Game Info Gotten!"
		SETHEAD="${SETHEAD}\n$LAPL"
	fi

	# Game config file info, only when there is something to edit
	if [ "${#CfgFiles[@]}" -gt 0 ]; then
		SETHEAD="${SETHEAD}\n${#CfgFiles[@]} $GUI_EDITABLECFGS"
	fi

	# Show Steam Deck compatibility on Main Menu when in Steam Deck Desktop Mode
	if [ "$SMALLDESK" -eq 1 ]; then
		SETHEAD="$SETHEAD \n<b>${GUI_SDCR}:</b> $STEAMDECKCOMPATRATING"
	fi

	if [ "$SMALLDESK" -eq 0 ]; then
		if [ -n "$DEVELOPER" ]; then
			SETHEAD="$SETHEAD \n<b>${GUI_DEV}:</b> $DEVELOPER"
		fi

		if [ -n "$PUBLISHER" ]; then
			SETHEAD="$SETHEAD \n<b>${GUI_PUB}:</b> $PUBLISHER"
		fi

		prepareProtonDBRating
		getGameFiles "$AID"
		setGameFilesArray
		TT_GAFI="$TT_BROWSEFILES"
		TT_GAFI="${TT_GAFI}$(for i in "${!GamFiles[@]}"; do printf "\n<b>%s</b>: %s" "${GamDesc[$i]}" "${GamFiles[$i]}"; done)"

		# Only shown on the Game Files tooltip
		if [ -n "$METACRITIC_SCORE" ] && ! grep -q "${GUI_MCS}" "$PDBRAINFO"; then
			echo "<b>${GUI_MCS}:</b> $METACRITIC_SCORE" >> "$PDBRAINFO"
		fi

		if [ -n "$OSLIST" ] && ! grep -q "${GUI_OSL}" "$PDBRAINFO"; then
			echo "<b>${GUI_OSL}</b>: $OSLIST" >> "$PDBRAINFO"
		fi

		if [ -f "$PDBRAINFO" ] && grep -q "[0-9]" "$PDBRAINFO" ;then
			SETHEAD="$SETHEAD \n$(cat "$PDBRASINF")"
			TT_OPENURL="$(cat "$PDBRAINFO")"
		fi

		if [ -n "$STEAMDECKCOMPATRATING" ]; then
			SETHEAD="$SETHEAD \n<b>${GUI_SDCR}:</b> $STEAMDECKCOMPATRATING"
		fi

		if [ -L "$GPFX/$DRCU/$STUS" ]; then
			SETHEAD="$SETHEAD \n<b>${GUI_SSU}:</b> symlink to $(readlink "$GPFX/$DRCU/$STUS")"
		fi

		if [ "$ISORIGIN" -eq 1 ]; then
			SETHEAD="$SETHEAD \n<b>${GUI_SGW}:</b> Origin interfering"
		else
			if [ -n "$GAMEWINDOW" ] && [ "$GAMEWINDOW" != "$NON" ]; then
				SETHEAD="$SETHEAD \n<b>${GUI_SGW}:</b> $(fixShow "$GAMEWINDOW")"
			fi
		fi

		# Fetch game exe from metadata files if not defined yet
		if [ -z "$GAMEEXE" ]; then
			GAMEEXE="$( basename "$( getGameExe "$AID" "1" )" )"
		fi
		# getGameExe prints this message instead of failing when nothing is found
		if [ -n "$GAMEEXE" ] && [ "$GAMEEXE" != "No Executable or TinkerGame file found for '$AID'" ]; then
			SETHEAD="$SETHEAD \n<b>${GUI_SGE}:</b> $GAMEEXE"
		fi

		if [ "$ISORIGIN" -eq 1 ]; then
			SETHEAD="$SETHEAD \n<b>${GUI_SGA}:</b> Origin $L2EA url"
		else
			if [ "${#ORGCMDARGS[@]}" -ge 1 ]; then
				SETHEAD="$( printf "%s \n<b>%s</b> %q" "${SETHEAD}" "${GUI_SGA}" "${ORGCMDARGS[*]}" )"
			fi
		fi
	fi
	# filter html incompatible chars here
	#SETHEAD="${SETHEAD//&/+}"

	SETHEAD="$SETHEAD \n<span font_size='small' fgalpha='55%'>${PROGNAME} ${PROGVERS}</span>"

	createProtonList X

	setMainMenuContent

	# Sized to its content. On the Steam Deck the fixed screen sized geometry
	# stays, with scrolling as a safety net for the small screen.
	MMGEOM=()
	if [ "$ONSTEAMDECK" -eq 1 ]; then
		MMGEOM=( --scroll "$GEOM" )
	fi

	# the shipped default stylesheet plus the Play button as suggested action
	MMCSS=()
	if [ -n "$TGMAINCSS" ]; then
		MMCSS=( --css="$TGMAINCSS" )
	fi

	# a row picked in one of the tool tabs (see mainMenuPick)
	MMPICKFILE="$MTEMP/mainmenu-pick"
	MMOUTFILE="$MTEMP/mainmenu-tab-out-1"
	rm -f "$MMPICKFILE" "$MMOUTFILE" 2>/dev/null

	MMRC=0
	mainMenuNotebook || MMRC=$?
	if [ "$MMRC" -eq 3 ]; then
		writelog "INFO" "${FUNCNAME[0]} - No notebook support - using the single form Main Menu"
		MMRC=0
		mainMenuSingleForm || MMRC=$?
	fi

	# the Play settings are saved whenever the menu is left with a button or
	# a picked row (yad prints nothing when the window is closed or on ESC)
	saveMainMenuFields "$(cat "$MMOUTFILE" 2>/dev/null)"

	MMPICK=""
	if [ -f "$MMPICKFILE" ]; then
		MMPICK="$(cat "$MMPICKFILE")"
		rm -f "$MMPICKFILE"
	fi

	case "$MMRC" in
	0)  {
			if [ -n "$MMPICK" ]; then
				clickInfo "${FUNCNAME[0]}" "$MMRC" "$MMPICK" "$SETMENU" "Row"
				mainMenuPicked "$MMPICK" "$2"
				return
			fi
			clickInfo "${FUNCNAME[0]}" "$MMRC" "$BUT_EXIT" "$SETMENU" "Exit"
			GOBACK=0
			closeSTL " ######### STOP EARLY $PROGNAME $PROGVERS #########"
			exit
		}
	;;
	10) 	{
			clickInfo "${FUNCNAME[0]}" "$MMRC" "$BUT_GLM" "$SETMENU" "Global Menu"
			refreshProtList
			openGlobalMenu "$AID" "${FUNCNAME[0]}" "1"
		}
	;;
	16)	{
			clickInfo "${FUNCNAME[0]}" "$MMRC" "$BUT_PLAY" "$SETMENU" "Game"
			GOBACK=0
			startSteamGame
		}
	;;
	esac

	goBackToPrevFunction "${FUNCNAME[0]}" "$2" "$GOBACK"
}

function mmAddData {
	# VAR TYPE LABEL TOOLTIP VALUE: appends one setting of the game config to
	# the Play tab; saveMainMenuFields writes it back to VAR
	MM_FIELDVARS[$(( ${#MM_PLAYFORM[@]} / 2 ))]="$1"
	MM_PLAYFORM+=( "--field=${3}!${4}:${2}" "$5" )
}

function mmAddRow {
	# TAB KEY NAME DESCRIPTION [TOOLTIP]: appends one tool to tool tab TAB
	# (2..5): a bold name over a one line description. KEY is what
	# mainMenuRunRow runs when the row is picked.
	local -n MMKEYS="MM_ROWKEYS_$1"
	local -n MMTEXT="MM_ROWTEXT_$1"
	local -n MMTIPS="MM_ROWTIP_$1"
	MMKEYS+=( "$2" )
	MMTEXT+=( "<b>$(tgMarkupEscape "$3")</b>
<span fgalpha='60%'>$(tgMarkupEscape "$4")</span>" )
	MMTIPS+=( "$(tgMarkupEscape "${5:-$4}")" )
}

function mmBoolType {
	# switches look like settings, but yad only has them since version 13
	if [ -n "$YADVER" ] && [ "$(printf '%s\n' "13" "$YADVER" | sort -V | head -n1)" == "13" ]; then
		echo "SW"
	else
		echo "CHK"
	fi
}

function setMainMenuContent {
	# The Main Menu content: the Play tab with the most used game settings
	# (MM_PLAYFORM, mapped to their config variables in MM_FIELDVARS) and the
	# tools grouped by goal into the other tabs (MM_TABS, MM_ROWKEYS_<n>,
	# MM_ROWTEXT_<n>, MM_ROWTIP_<n> for n = 2..5).
	local MMARGS="${GAMEARGS/#-/ -}" MMBOOL MMT
	if [ "$MMARGS" == "$NON" ]; then
		MMARGS=""
	fi
	MMBOOL="$(mmBoolType)"

	MM_TABS=( "$GUI_MMSEC_PLAY" "$GUI_MMSEC_FIX" "$GUI_MMSEC_LOOK" "$GUI_MMSEC_MODS" "$BUT_EXTRAS" )
	MM_PLAYFORM=()
	MM_FIELDVARS=()
	for MMT in 2 3 4 5; do
		declare -ga "MM_ROWKEYS_$MMT=()" "MM_ROWTEXT_$MMT=()" "MM_ROWTIP_$MMT=()"
	done

	mmAddData USEPROTON CB "$GUI_MM_PROTON" "$TT_MM_PROTON" "$(cleanDropDown "${USEPROTON/#-/ -}" "$PROTYADLIST")"
	mmAddData GAMEARGS "" "$GUI_MM_ARGS" "$TT_MM_ARGS" "$MMARGS"
	mmAddData DXVK_FPSLIMIT CBE "$GUI_MM_FPSLIMIT" "$TT_MM_FPSLIMIT" "$(cleanDropDown "${DXVK_FPSLIMIT/#-/ -}" "none!30!60!75!90!120!144!165!240")"
	mmAddData USEMANGOHUD "$MMBOOL" "$GUI_MM_FPSCOUNTER" "$TT_MM_FPSCOUNTER" "${USEMANGOHUD:-0}"
	mmAddData USEGAMEMODERUN "$MMBOOL" "$GUI_MM_GAMEMODE" "$TT_MM_GAMEMODE" "${USEGAMEMODERUN:-0}"
	mmAddData USERESHADE "$MMBOOL" "$GUI_MM_RESHADE" "$TT_MM_RESHADE" "${USERESHADE:-0}"
	mmAddData USEGAMESCOPE "$MMBOOL" "$GUI_MM_GAMESCOPE" "$TT_MM_GAMESCOPE" "${USEGAMESCOPE:-0}"

	mmAddRow 2 fix-prefix "$FBUT_GUISET_RECREATEPFX" "$TT_RECREATEPFX"
	mmAddRow 2 fix-components "$FBUT_GUISET_WTSEL" "$TT_WTSEL"
	mmAddRow 2 fix-help "$FBUT_GUISET_OPURL" "$TT_GAMEHELP" "${TT_OPENURL:-$TT_GAMEHELP}"
	mmAddRow 2 fix-files "$GUI_GAFI" "$TT_BROWSEFILES" "${TT_GAFI:-$TT_BROWSEFILES}"

	mmAddRow 3 look-overlay "$FBUT_GUISET_DXHSEL" "$TT_DXHSEL"
	mmAddRow 3 look-shadersgame "$FBUT_GUISET_UPSHADER" "$TT_UPSHADER"
	mmAddRow 3 look-shadersrc "$FBUT_GUISET_SHADERREPOS" "$TT_SHADERREPOS"
	mmAddRow 3 look-gamescope "$FBUT_GUISET_GASCO" "$TT_GASCO"

	mmAddRow 4 mods-vortex "$FBUT_GUISET_VORTEX" "$TT_VORTEX"
	mmAddRow 4 mods-mo2 "$FBUT_GUISET_MO" "$TT_MO"

	mmAddRow 5 x-protondl "$FBUT_GUISET_DCP" "$TT_DCP"
	mmAddRow 5 x-firstrun "$FBUT_GUISET_CREATEEVALSC" "$TT_CREATEEVALSC"
	mmAddRow 5 x-onetime "$FBUT_GUISET_OTR" "$TT_OTR"
	mmAddRow 5 x-slr "$FBUT_GUISET_GETSLR" "$TT_GETSLR"
	mmAddRow 5 x-wdc "$FBUT_GUISET_WDC" "$TT_WDC"
	mmAddRow 5 x-winedl "$FBUT_GUISET_DW" "$TT_DW"
	mmAddRow 5 x-addns "$FBUT_GUISET_ADDNSGA" "$TT_ADDNSGA"
	mmAddRow 5 x-favsel "$FBUT_GUISET_FAVSEL" "$TT_FAVSEL"
	mmAddRow 5 x-block "$FBUT_GUISET_BLOCKCAT" "$TT_BLOCKCAT"
	mmAddRow 5 x-sort "$FBUT_GUISET_SORTCAT" "$TT_SORTCAT"
	mmAddRow 5 x-search "$BUT_SEARCH" "$TT_MM_SEARCH"
	mmAddRow 5 x-gamemenu "$BUT_GM" "$TT_MM_GAMEMENU"
	mmAddRow 5 x-default "$GUI_MM_DEFAULTMENU" "$TT_MM_DEFAULTMENU"
	mmAddRow 5 x-catmenu "$BUT_GUISET_CATMENUSHORT" "$TT_MM_CATMENU"
	mmAddRow 5 x-favmenu "$BUT_FAV" "$TT_MM_FAVMENU"
	mmAddRow 5 x-editor "$BUT_EDITORMENU" "$TT_MM_EDITOR"
}

function mmPickCmd {
	# the command a tool row runs on double click or Enter. Yad appends the
	# values of the row, the first one being its key.
	local MMSELF
	MMSELF="$(realpath "$0")"
	printf "'%s' game menu-pick" "${MMSELF//\'/\'\\\'\'}"
}

function mmListArgs {
	# yad --list arguments showing the rows of tool tab $1
	local -n MMKEYS="MM_ROWKEYS_$1"
	local -n MMTEXT="MM_ROWTEXT_$1"
	local -n MMTIPS="MM_ROWTIP_$1"
	local MMI
	MMLISTARGS=( --list --no-headers --column=key:HD --column=text --column=tip:HD \
		--hide-column=1 --tooltip-column=3 )
	for MMI in "${!MMKEYS[@]}"; do
		MMLISTARGS+=( "${MMKEYS[$MMI]}" "${MMTEXT[$MMI]}" "${MMTIPS[$MMI]}" )
	done
}

function mmPlugTab {
	# notebook plug of tab $1: the Play settings form or a tool list
	if [ "$1" -eq 1 ]; then
		GDK_BACKEND=x11 "${YAD:-yad}" --plug="$TGKEY" --tabnum=1 --form --separator="\n" "${MM_PLAYFORM[@]}"
	else
		mmListArgs "$1"
		GDK_BACKEND=x11 "${YAD:-yad}" --plug="$TGKEY" --tabnum="$1" "${MMLISTARGS[@]}" \
			--dclick-action="$(mmPickCmd)" >/dev/null
	fi
}

function mainMenuNotebook {
	# the Main Menu as one window with a tab per goal. Returns the notebook
	# exit code, or 3 when there is no notebook support.
	if [ -n "$USETABBEDMENU" ] && [ "$USETABBEDMENU" -eq 0 ]; then
		return 3
	fi

	TGNB_TABS=( "${MM_TABS[@]}" )
	TGNB_FUNCS=( mmPlugTab mmPlugTab mmPlugTab mmPlugTab mmPlugTab )
	TGNB_TITLE="$TITLE"
	TGNB_TEXT="$SETHEAD"
	TGNB_IMAGE="$SHOWPIC"
	TGNB_F1ACTION="$F1ACTIONCG"
	TGNB_OUTPREFIX="$MTEMP/mainmenu"
	TGNB_CSS=( "${MMCSS[@]}" )
	# the tool lists scroll, so the window needs a size of its own
	TGNB_GEOM=( "${MMGEOM[@]}" )
	if [ "${#TGNB_GEOM[@]}" -eq 0 ]; then
		TGNB_GEOM=( --width=640 --height=560 )
	fi
	TGNB_BUTTONS=( --button="$BUT_EXIT":0 --button="$BUT_GLM":10 --button="$BUT_PLAY":16 )

	local MMNBRC=0
	tgNotebookLaunch || MMNBRC=$?
	unset TGNB_CSS TGNB_GEOM
	return "$MMNBRC"
}

function mainMenuSingleForm {
	# Main Menu without notebook support: the Play settings plus one button per
	# tool tab, which opens the tools of that tab in their own window
	local MMT
	local -a MMTABBTNS=()
	for MMT in 2 3 4 5; do
		MMTABBTNS+=( "--field=$(tgMarkupEscape "${MM_TABS[$(( MMT - 1 ))]}")  ›:FBTN" "$(mmPickCmd) tab:$MMT" )
	done

	"$YAD" "${MMCSS[@]}" --image "$SHOWPIC" "${YADIMGTOP[@]}" --center --window-icon="$STLICON" --form "${WINDECO[@]}" --title="$TITLE" \
	--text="$SETHEAD" --f1-action="$F1ACTIONCG" --separator="\n" \
	"${MM_PLAYFORM[@]}" "${MMTABBTNS[@]}" \
	--button="$BUT_EXIT":0 \
	--button="$BUT_GLM":10 \
	--button="$BUT_PLAY":16 \
	"${MMGEOM[@]}" > "$MMOUTFILE" &
	echo "$!" > "$MTEMP/mainmenu-nbpid"

	local MMSFRC=0
	wait "$!" || MMSFRC=$?
	return "$MMSFRC"
}

function mainMenuTabList {
	# the tools of tab $1 in their own window (single form Main Menu).
	# Prints the key of the picked row.
	mmListArgs "$1"
	"$YAD" "${MMCSS[@]}" --center --window-icon="$STLICON" "${WINDECO[@]}" --title="$TITLE" \
	--text="$(spanFont "${MM_TABS[$(( $1 - 1 ))]}" "H")" \
	"${MMLISTARGS[@]}" --print-column=1 --separator="" \
	--button="$BUT_BACK":1 --button="$BUT_RUN":0 "${MMGEOM[@]}" 2>/dev/null
}

function saveMainMenuFields {
	# saves the settings of the Main Menu form output (one value per line, in
	# the field order of MM_PLAYFORM, see MM_FIELDVARS) to the game config.
	# updateConfigEntry only writes values that differ from the loaded ones.
	local MMI MMVAR MMVAL
	local -a MMLINES=()

	if [ -z "$1" ]; then
		return
	fi

	mapfile -t MMLINES <<< "$1"
	for MMI in "${!MM_FIELDVARS[@]}"; do
		MMVAR="${MM_FIELDVARS[$MMI]}"
		MMVAL="${MMLINES[$MMI]}"
		MMVAL="${MMVAL/# -/-}"
		if [ -z "$MMVAL" ]; then
			# an empty dropdown means there was nothing to pick
			if [ "$MMVAR" != "GAMEARGS" ]; then
				continue
			fi
			MMVAL="$NON"
		fi

		if [ "$MMVAR" == "USERESHADE" ] && [ "$MMVAL" == "TRUE" ] && [ "$USERESHADE" != "1" ]; then
			notiShow "$NOTY_RESHADEHOTKEY"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Main Menu setting '$MMVAR' is '$MMVAL'"
		updateConfigEntry "$MMVAR" "$MMVAL" "$STLGAMECFG"
		# the running launch continues with the loaded values, so update them too
		case "$MMVAL" in
			TRUE) MMVAL=1 ;;
			FALSE) MMVAL=0 ;;
		esac
		printf -v "$MMVAR" '%s' "$MMVAL"
	done
}

function mainMenuPick {
	# called by a tool row of the open Main Menu: remembers the row and closes
	# the menu with code 0, MainMenu then runs it. A second quick pick before
	# the menu is gone is ignored.
	local MMPICKFILE="$MTEMP/mainmenu-pick" MMNBPID
	if [ -z "$1" ] || [ -f "$MMPICKFILE" ]; then
		return
	fi
	mkdir -p "$MTEMP"
	echo "$1" > "$MMPICKFILE"
	MMNBPID="$(cat "$MTEMP/mainmenu-nbpid" 2>/dev/null)"
	if [ -n "$MMNBPID" ]; then
		kill -USR1 "$MMNBPID" 2>/dev/null || true
	fi
}

function mainMenuPicked {
	# runs the row KEY picked in the Main Menu, then reopens it (PREV is the
	# function the Main Menu goes back to)
	local MMKEY="$1"
	if [[ "$MMKEY" == tab:* ]]; then
		MMKEY="$(mainMenuTabList "${MMKEY#tab:}")"
		if [ -z "$MMKEY" ]; then
			MainMenu "$AID" "$2"
			return
		fi
	fi

	if mainMenuRunRow "$MMKEY"; then
		return
	fi
	MainMenu "$AID" "$2"
}

function mainMenuRunRow {
	# runs the Main Menu tool KEY. The tools started as separate commands
	# return 1 so the Main Menu reopens afterwards, the menus that come back
	# to the Main Menu on their own return 0. An unknown key returns 1.
	local MMSELF
	local -a MMCMD=()
	MMSELF="$(realpath "$0")"

	case "$1" in
		fix-prefix)       MMCMD=( game compatdata "$AID" s ) ;;
		fix-components)   MMCMD=( wine components "$AID" ) ;;
		fix-help)         MMCMD=( game helpurl "$AID" X ) ;;
		fix-files)        MMCMD=( game files "$AID" ) ;;
		look-overlay)     MMCMD=( game dxvk-hud "$AID" ) ;;
		look-shadersrc)   MMCMD=( update shaders repos ) ;;
		look-shadersgame) MMCMD=( update gameshaders "$SHADDESTDIR" ) ;;
		look-gamescope)   MMCMD=( game gamescope "$AID" "$GN" ) ;;
		mods-vortex)      MMCMD=( mods vortex start ) ;;
		mods-mo2)         MMCMD=( mods mo2 start ) ;;
		x-protondl)       MMCMD=( proton download ) ;;
		x-firstrun)       MMCMD=( game first-install "$AID" ) ;;
		x-onetime)        MMCMD=( game onetimerun "$AID" ) ;;
		x-slr)            MMCMD=( proton getslr-gui "$AID" ) ;;
		x-wdc)            MMCMD=( wine debug-channels "$AID" ) ;;
		x-winedl)         MMCMD=( wine download ) ;;
		x-addns)          MMCMD=( steam add-game ) ;;
		x-favsel)         MMCMD=( config favorites "$AID" set ) ;;
		x-block)          MMCMD=( config block ) ;;
		x-sort)           MMCMD=( config sort ) ;;
		x-search)         refreshProtList; openSearchMenu "$AID" MainMenu; return 0 ;;
		x-gamemenu)       refreshProtList; openGameMenu "$AID" MainMenu; return 0 ;;
		x-default)        refreshProtList; openGameDefaultMenu "$AID" MainMenu; return 0 ;;
		x-catmenu)        refreshProtList; setGuiCategoryMenuSel "$AID" MainMenu; return 0 ;;
		x-favmenu)        refreshProtList; favoritesMenu "$AID" MainMenu; return 0 ;;
		x-editor)         EditorDialog "$AID" MainMenu; return 0 ;;
		*)
			writelog "SKIP" "${FUNCNAME[0]} - Unknown Main Menu row '$1'"
			return 1
		;;
	esac

	writelog "INFO" "${FUNCNAME[0]} - Running '${MMCMD[*]}' for Main Menu row '$1'"
	"$MMSELF" "${MMCMD[@]}" || true
	return 1
}

function createBlockYadList {
	checkEntryBlocklist
	while read -r block; do
		BLCAT="${block%=*}"
		BLVALR="${block#*=}"
		BLVAL="${BLVALR//\"/}"
		if [ "$BLVAL" -eq 1 ] ; then
			echo TRUE
			echo "$BLCAT"
		else
			echo FALSE
			echo "$BLCAT"
		fi
	done <<< "$(grep -v "^#" "$STLMENUBLOCKCFG" | grep "=")"
}

function getCatsFromCode {
	sed "s:CAT_:\nCAT_:g" "$STLRAWENTRIES" | grep "^CAT_" | cut -d '`' -f1 | cut -d '_' -f2 | sort -u
}

function updateMenuSortFile {
	if [ -f "$STLMENUSORTCFG" ] && [ -s "$STLMENUSORTCFG" ]; then
		while read -r catent; do
			if ! grep -q "^$catent" "$STLMENUSORTCFG"; then
				writelog "INFO" "${FUNCNAME[0]} - Adding missing Category '$catent' to '$STLMENUSORTCFG'"
				echo "$catent" >> "$STLMENUSORTCFG"
			fi
		done <<< "$(getCatsFromCode)"
	fi
}

function checkEntryBlocklist {
	# create blocklist with disabled categories
	if [ ! -f "$STLMENUBLOCKCFG" ]; then
		echo "#All enabled categories will be hidden in the menus" >"$STLMENUBLOCKCFG"
		while read -r block; do
			echo "${block}=\"0\"" >> "$STLMENUBLOCKCFG"
		done <<< "$(getCatsFromCode)"
	fi

	if [ -f "$STLMENUBLOCKCFG" ]; then
		# autoadding new (commented out) categories
		while read -r block; do
			if ! grep -q "^${block}" "$STLMENUBLOCKCFG"; then
				echo "${block}=\"0\"" >> "$STLMENUBLOCKCFG"
			fi
		done <<< "$(getCatsFromCode)"

		# create validity check file
		if [ ! -f "$STLMENUVALBLOCKCFG" ]; then
			cp "$STLMENUBLOCKCFG" "$STLMENUVALBLOCKCFG"
		fi

		# if validity check file differs - remove temporary menu files
		if ! cmp -s "$STLMENUBLOCKCFG" "$STLMENUVALBLOCKCFG"; then
			writelog "INFO" "${FUNCNAME[0]} - Removing temp menufiles in '$STLSHM'"
			find "$MTEMP" -maxdepth 1 -type f -name "*menu*" -exec rm {} \;
			cp "$STLMENUBLOCKCFG" "$STLMENUVALBLOCKCFG"
		fi
	fi
}

function getFilteredEntries {
	if [ -z "$1" ]; then
		INLIST="$STLRAWENTRIES"
	else
		INLIST="$1"
	fi

	# first remove blocked entries
	if grep -q "=\"1\"" "$STLMENUBLOCKCFG"; then
		writelog "INFO" "${FUNCNAME[0]} - Excluding blocked elements from '$STLMENUBLOCKCFG'"
		unset BlockCats
		while read -r line; do
			mapfile -t -O "${#BlockCats[@]}" BlockCats <<< "CAT_${line}"
		done <<< "$(grep "=\"1\"" "$STLMENUBLOCKCFG" | cut -d '=' -f1)"

		while read -r outline; do
			INCAT="CAT_$(grep -oP '#CAT_\K[^`]+' <<< "${outline}")"
			if [[ ! "${BlockCats[*]}" =~ $INCAT ]]; then
				echo "$outline" >> "$STLNOBLOCKENTRIES"
			fi
		done < "$INLIST"
	else
		writelog "INFO" "${FUNCNAME[0]} - No blocked elements found in '$STLMENUBLOCKCFG' - working with '$INLIST'"
		cp "$INLIST" "$STLNOBLOCKENTRIES"
	fi

	# now the sort order
	if [ ! -f "$STLMENUSORTCFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - '$STLMENUSORTCFG' missing - creating a default one"
		getCatsFromCode > "$STLMENUSORTCFG" 2>/dev/null
	fi

	writelog "INFO" "${FUNCNAME[0]} - Sort config '$STLMENUSORTCFG' found - sorting"

	while read -r line; do
		if [ -n "$line" ]; then
			grep "\`#CAT_${line}\`" "$STLNOBLOCKENTRIES" >> "$STLCATSORTENTRIES"
		fi
	done < "$STLMENUSORTCFG"
	cat "$STLCATSORTENTRIES"
	rm "$STLNOBLOCKENTRIES" 2>/dev/null
	rm "$STLCATSORTENTRIES" 2>/dev/null
}

function splitMenu {
	ARGSPLIT="$1"
	MYTMPL="$2"
	if [ "$ARGSPLIT" -gt 0 ]; then
		FUCO="$(wc -l < "$MYTMPL")"
		CUTCO=$((FUCO / 2 ))
		RESTCO=$((FUCO - CUTCO))
		head -n "$CUTCO" "$MYTMPL" > "${MYTMPL}_${ARGSPLIT}"

		if [ "$ARGSPLIT" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - ARGSPLIT is set to '$ARGSPLIT' - so using first half of '$MYTMPL' for the menu"
			head -n "$CUTCO" "$MYTMPL" > "${MYTMPL}_${ARGSPLIT}"
			mv "${MYTMPL}_${ARGSPLIT}" "$MYTMPL"
		elif [ "$ARGSPLIT" -eq 2 ]; then
			writelog "INFO" "${FUNCNAME[0]} - ARGSPLIT is set to '$ARGSPLIT' - so using second half of '$MYTMPL' for the menu"
			head -n "$CUTCO" "$MYTMPL" | grep "#HEAD" | tail -n 1 > "${MYTMPL}_${ARGSPLIT}"
			tail -n "$RESTCO" "$MYTMPL" >> "${MYTMPL}_${ARGSPLIT}"
			mv "${MYTMPL}_${ARGSPLIT}" "$MYTMPL"
		else
			writelog "INFO" "${FUNCNAME[0]} - ARGSPLIT is set to '$ARGSPLIT' - so using the whole '$MYTMPL' for the menu"
		fi
	fi
}

function createMenu {
	ARGSPLIT="$1"
	ARGMENU="$2"
	ARGFUNC="$3"
	ARGPIC="$4"
	UNUSED="$5"
	ARGCOLS="$6"
	ARGTITLE="$7"
	ARGPCMD="$8"
	ARGSPAT="$9"

	NEEDARG="9"

	MYTMPL="${ARGMENU}-${TMPL}"

	if [ "$#" -ne "$NEEDARG" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Need $NEEDARG arguments and got '$#':"
		writelog "ERROR" "${FUNCNAME[0]} - '$*'"
	else
		writelog "INFO" "${FUNCNAME[0]} - got '$#' elements: '$*'"
	fi

	if [ ! -f "$MYTMPL" ] || [ ! -s "$MYTMPL" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating menu template '$MYTMPL'"
		getFilteredEntries "$STLRAWENTRIES" | grep "$ARGSPAT" > "$MYTMPL"
		rmDupLines "$MYTMPL"
		splitMenu "$ARGSPLIT" "$MYTMPL"
	fi

	if [ "$ARGPCMD" == "$NON" ]; then
		QBUT0="$BUT_EXIT"
	else
		QBUT0="$BUT_BACK"
	fi

	TITLE="${PROGNAME}-$ARGFUNC"

	echo "" >"$ARGMENU"
	# shellcheck disable=SC2028 # doesn't like the newline seperator, but it is valid
	{
		echo "function $ARGFUNC {"
		echo "\"$YAD\" --columns=\"$COLCOUNT\" --f1-action=\"$F1ACTIONCG\" --text=\"$(spanFont "$ARGTITLE" "H")\" \\"
		echo "--title=\"$TITLE\" --image \"$ARGPIC\" ${YADIMGTOP[*]} --window-icon=\"$STLICON\" --center ${WINDECO[*]} --form --separator=\"\\n\" --quoted-output \\"
		echo "--button=\"$QBUT0\":0 --button=\"$BUT_MAINMENU\":2 --button=\"$BUT_RELOAD\":4 --button=\"$BUT_SAVERELOAD\":6 --button=\"$BUT_SAVEPLAY\":8 --button=\"$BUT_PLAY\":10 $GEOM \\"
		cat "$MYTMPL"
		echo "--scroll"
		echo "}"
	} >>"$ARGMENU"
}

function openMenu {
	ARGID="$1"
	ARGPCMD="$2"		# "$9"
	ARGLOADCFG="$3"
	# most args for createMenu:
	ARGSPLIT="$4"
	ARGMENU="$5"
	ARGFUNC="$6"
	ARGPIC="$7"
	UNUSED="$8"
	ARGCOLS="$9"
	ARGTITLE="${10}"
	ARGSPAT="${11}"

	resetAID "$ARGID"
	createGameCfg
	setGN "$ARGID"
	createDropdownLists

	mkCfgTemp "${FUNCNAME[0]}"

	if [ "$LOADCFG" == "$STLGAMECFG" ] ; then
		setShowPic
	fi

	loadCfg "$ARGLOADCFG" X

	TITLE="${PROGNAME}-$ARGFUNC"
	pollWinRes "$TITLE"

	writelog "INFO" "${FUNCNAME[0]} - Starting createMenu \"$ARGMENU\" \"$ARGFUNC\" \"$ARGPIC\" \"$UNUSED\" \"$ARGCOLS\" \"$ARGTITLE\" \"$ARGPCMD\" \"$ARGSPAT\""

	# tabbed notebook menu first - openTabbedMenu steps aside with rc 3 whenever
	# tabs are not possible, then the classic single form menu takes over
	TG_TAB_RC=3
	openTabbedMenu "$ARGSPLIT" "$ARGMENU" "$ARGFUNC" "$ARGPIC" "$UNUSED" "$ARGCOLS" "$ARGTITLE" "$ARGPCMD" "$ARGSPAT"
	TG_TAB_RC=$?

	if [ "$TG_TAB_RC" -eq 3 ]; then
		createMenu "$ARGSPLIT" "$ARGMENU" "$ARGFUNC" "$ARGPIC" "$UNUSED" "$ARGCOLS" "$ARGTITLE" "$ARGPCMD" "$ARGSPAT"

		source "$ARGMENU"
		writelog "INFO" "${FUNCNAME[0]} - Currently used tempfile is '$MKCFG'"
		TG_TAB_RC=0
		"$ARGFUNC" > "$MKCFG" || TG_TAB_RC=$?
	fi

	case "$TG_TAB_RC" in
	0) 	{
			if [ "$ARGPCMD" == "$NON" ]; then
				clickInfo "${FUNCNAME[0]}" "$TG_TAB_RC" "$QBUT0" "$GAMMENU" "Exit"
				GOBACK=0
				closeSTL " ######### STOP EARLY $PROGNAME $PROGVERS #########"
				exit
			else
				clickInfo "${FUNCNAME[0]}" "$TG_TAB_RC" "$QBUT0" "$GAMMENU" "$ARGPCMD"
				"$ARGPCMD" "$AID" "${FUNCNAME[0]}"
			fi
		}
	;;
	2)  {
			clickInfo "${FUNCNAME[0]}" "$TG_TAB_RC" "$BUT_MAINMENU" "$FAVOMENU" "$SETMENU"
			MainMenu "$AID" "${FUNCNAME[0]}"
		}
	;;
	4) 	{
			GOBACK=0
			clickInfo "${FUNCNAME[0]}" "$TG_TAB_RC" "$BUT_RELOAD" "$FAVOMENU" "$PARGUI"
			if [ "$SAVESETSIZE" -eq 1 ] ; then	sleep 1;	fi
			"$PARGUI" "$AID" "$ARGPCMD" "$ARGSPLIT"
		}
	;;
	6) 	{
			clickInfo "${FUNCNAME[0]}" "$TG_TAB_RC" "$BUT_SAVERELOAD" "$FAVOMENU" "$PARGUI"
			GOBACK=0
			writelog "INFO" "${FUNCNAME[0]} - Saving config '$ARGLOADCFG' and restart '$PARGUI' GUI"
			saveMenuEntries "$ARGMENU"
			if [ "$SAVESETSIZE" -eq 1 ] ; then	sleep 1;	fi
			"$PARGUI" "$AID" "$ARGPCMD" "$ARGSPLIT"
		}
	;;
	8)  {
			clickInfo "${FUNCNAME[0]}" "$TG_TAB_RC" "$BUT_SAVEPLAY" "$FAVOMENU" "Game Start"
			GOBACK=0
			writelog "INFO" "${FUNCNAME[0]} - Saving config '$ARGLOADCFG' and starting the game"
			saveMenuEntries "$ARGMENU"
			startSteamGame
		}
	;;
	10)	{
			clickInfo "${FUNCNAME[0]}" "$TG_TAB_RC" "$BUT_PLAY" "$FAVOMENU" "Game Start"
			GOBACK=0
			startSteamGame
		}
	;;
	esac
}

