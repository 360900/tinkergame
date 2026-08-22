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
	PRETTYGAMENAME="$( getTitleFromID "$AID" "1" )"
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
	SETHEAD="$(spanFont "${PROGNAME} (${PROGNAME,,}) - ${PROGVERS} \n \n$SGNAID" "H")"

	TT_OPENURL="Help Url Gui"

	# Last played date/time with STL
	if [ -n "$LAPL" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Game Info Gotten!"
		SETHEAD="${SETHEAD}\n<i>$LAPL</i>"
	fi

	# Game config file info
	# TODO hide if no gamecfgs - Maybe this check needs an overhaul?
	SETHEAD="${SETHEAD}\n<i>(${#CfgFiles[@]} $GUI_EDITABLECFGS)\n($GUI_EDITABLEGAMECFGS)</i>"

	# Show Steam Deck compatibility on Main Menu when in Steam Deck Desktop Mode
	if [ "$SMALLDESK" -eq 1 ]; then
		SETHEAD="$SETHEAD \n<b>${GUI_SDCR}:</b> $STEAMDECKCOMPATRATING"
	fi

	if [ "$SMALLDESK" -eq 0 ]; then
		if [ -n "$DEVELOPER" ]; then
			SETHEAD="$SETHEAD \n\n<b>${GUI_DEV}:</b> $DEVELOPER"
		fi

		if [ -n "$PUBLISHER" ]; then
			SETHEAD="$SETHEAD \n<b>${GUI_PUB}:</b> $PUBLISHER"
		fi

		prepareProtonDBRating
		getGameFiles "$AID"
		setGameFilesArray
		TT_GAFI="$( printf "<u>%s</u>" "${GUI_GAFI}" )"
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
		if [ -n "$GAMEEXE" ]; then
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

	createProtonList X

	"$YAD" --image "$SHOWPIC" "${YADIMGTOP[@]}" --scroll --center --window-icon="$STLICON" --form "${WINDECO[@]}" --title="$TITLE" \
	--text="$SETHEAD" \
	--columns="$COLCOUNT" --f1-action="$F1ACTIONCG" --separator="" \
	--field="$FBUT_GUISET_DCP":FBTN "$(realpath "$0") dcp" \
	--field="$FBUT_GUISET_DW":FBTN "$(realpath "$0") dw" \
	--field="$FBUT_GUISET_RECREATEPFX":FBTN "$(realpath "$0") ccd \"$AID\" \"s\"" \
	--field="$FBUT_GUISET_WDC":FBTN "$(realpath "$0") wdc \"$AID\"" \
	--field="$FBUT_GUISET_WTSEL":FBTN "$(realpath "$0") wt \"$AID\"" \
	--field="$FBUT_GUISET_ADDNSGA!$TT_ADDNSGA":FBTN "$(realpath "$0") ansg" \
	--field="$FBUT_GUISET_CREATEEVALSC":FBTN "$(realpath "$0") cfi \"$AID\"" \
	--field="$FBUT_GUISET_OTR!$TT_OTR":FBTN "$(realpath "$0") otr \"$AID\"" \
	--field="$FBUT_GUISET_DXHSEL":FBTN "$(realpath "$0") dxh \"$AID\"" \
	--field="$FBUT_GUISET_SHADERREPOS!$TT_SHADERREPOS":FBTN "$(realpath "$0") update shaders repos" \
	--field="$FBUT_GUISET_UPSHADER!$TT_UPSHADER":FBTN "$(realpath "$0") update gameshaders \"$SHADDESTDIR\"" \
	--field="$FBUT_GUISET_FAVSEL!$TT_FAVSEL":FBTN "$(realpath "$0") fav \"$AID\" set"\
	--field="$FBUT_GUISET_BLOCKCAT":FBTN "$(realpath "$0") block" \
	--field="$FBUT_GUISET_SORTCAT!$TT_SORTCAT":FBTN "$(realpath "$0") sort" \
	--field="$FBUT_GUISET_OPURL!$TT_OPENURL":FBTN "$(realpath "$0") hu \"$AID\" X" \
	--field="$FBUT_GUISET_GASCO!$TT_GASCO":FBTN "$(realpath "$0") gs \"$AID\" \"$GN\"" \
	--field="$FBUT_GUISET_VORTEX!$TT_VORTEX":FBTN "$(realpath "$0") $VTX start" \
	--field="$FBUT_GUISET_MO!$TT_MO":FBTN "$(realpath "$0") mo2 start" \
	--field="$FBUT_GUISET_GETSLR!$TT_GETSLR":FBTN "$(realpath "$0") getslrbtn \"$AID\"" \
	--field="$GUI_GAFI!$TT_GAFI":FBTN "$(realpath "$0") gf \"$AID\"" \
	--button="$BUT_EXIT":0 \
	--button="$BUT_GUISET_CATMENUSHORT":4 \
	--button="$BUT_GM":6 \
	--button="$BUT_DGM":8 \
	--button="$BUT_GLM":10 \
	--button="$BUT_FAV":12 \
	--button="$BUT_EDITORMENU":14 \
	--button="$BUT_PLAY":16 \
	"$GEOM"
	case $? in
	0)  {
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_EXIT" "$SETMENU" "Exit"
			GOBACK=0
			closeSTL " ######### STOP EARLY $PROGNAME $PROGVERS #########"
			exit
		}
	;;
	4) 	{
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_GUISET_CATMENUSHORT" "$SETMENU" "Category Menu Selection"
			refreshProtList
			setGuiCategoryMenuSel "$AID" "${FUNCNAME[0]}"
		}
	;;
	6) 	{
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_GM" "$SETMENU" "$GAMMENU"
			refreshProtList
			openGameMenu "$AID" "${FUNCNAME[0]}"
		}
	;;
	8) 	{
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_DGM" "$SETMENU" "Game Default Menu"
			refreshProtList
			openGameDefaultMenu "$AID" "${FUNCNAME[0]}"
		}
	;;
	10) 	{
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_GLM" "$SETMENU" "Global Menu"
			refreshProtList
			openGlobalMenu "$AID" "${FUNCNAME[0]}" "1"
		}
	;;
	12) 	{
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_FAV" "$SETMENU" "Favorites"
			refreshProtList
			favoritesMenu "$AID" "${FUNCNAME[0]}"
		}
	;;
	14) 	{
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_EDITORMENU" "$SETMENU" "EditorDialog"
			EditorDialog "$AID" "${FUNCNAME[0]}"
		}
	;;
	16) 	{
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_PLAY" "$SETMENU" "Game"
			GOBACK=0
			startSteamGame
		}
	;;
	esac

	goBackToPrevFunction "${FUNCNAME[0]}" "$2" "$GOBACK"
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
	createMenu "$ARGSPLIT" "$ARGMENU" "$ARGFUNC" "$ARGPIC" "$UNUSED" "$ARGCOLS" "$ARGTITLE" "$ARGPCMD" "$ARGSPAT"

	source "$ARGMENU"
	writelog "INFO" "${FUNCNAME[0]} - Currently used tempfile is '$MKCFG'"
	"$ARGFUNC" > "$MKCFG"

	case $? in
	0) 	{
			if [ "$ARGPCMD" == "$NON" ]; then
				clickInfo "${FUNCNAME[0]}" "$?" "$QBUT0" "$GAMMENU" "Exit"
				GOBACK=0
				closeSTL " ######### STOP EARLY $PROGNAME $PROGVERS #########"
				exit
			else
				clickInfo "${FUNCNAME[0]}" "$?" "$QBUT0" "$GAMMENU" "$ARGPCMD"
				"$ARGPCMD" "$AID" "${FUNCNAME[0]}"
			fi
		}
	;;
	2)  {
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_MAINMENU" "$FAVOMENU" "$SETMENU"
			MainMenu "$AID" "${FUNCNAME[0]}"
		}
	;;
	4) 	{
			GOBACK=0
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_RELOAD" "$FAVOMENU" "$PARGUI"
			if [ "$SAVESETSIZE" -eq 1 ] ; then	sleep 1;	fi
			"$PARGUI" "$AID" "$ARGPCMD" "$ARGSPLIT"
		}
	;;
	6) 	{
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_SAVERELOAD" "$FAVOMENU" "$PARGUI"
			GOBACK=0
			writelog "INFO" "${FUNCNAME[0]} - Saving config '$ARGLOADCFG' and restart '$PARGUI' GUI"
			saveMenuEntries "$ARGMENU"
			if [ "$SAVESETSIZE" -eq 1 ] ; then	sleep 1;	fi
			"$PARGUI" "$AID" "$ARGPCMD" "$ARGSPLIT"
		}
	;;
	8)  {
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_SAVEPLAY" "$FAVOMENU" "Game Start"
			GOBACK=0
			writelog "INFO" "${FUNCNAME[0]} - Saving config '$ARGLOADCFG' and starting the game"
			saveMenuEntries "$ARGMENU"
			startSteamGame
		}
	;;
	10)	{
			clickInfo "${FUNCNAME[0]}" "$?" "$BUT_PLAY" "$FAVOMENU" "Game Start"
			GOBACK=0
			startSteamGame
		}
	;;
	esac
}

