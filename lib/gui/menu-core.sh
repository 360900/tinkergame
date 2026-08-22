#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function saveMenuEntries {
	SAVMENUCAT="$1"
	writelog "INFO" "${FUNCNAME[0]} - Saving changed Settings"
	writelog "INFO" "${FUNCNAME[0]} - Clearing Results array with '${#Results[@]}' elements"
	writelog "INFO" "${FUNCNAME[0]} - Pulling values from tempfile '$MKCFG'"
	unset Results
	mapfile -t -O "${#Results[@]}" Results < "$MKCFG"

	for i in "${!Results[@]}"; do
		ONUM="$((i +1))"
		VAL="${Results[$i]}"

		RAWENT="$(sed "${ONUM}q;d" "${SAVMENUCAT}-${TMPL}")"
		VAR="$(grep -oP "\('\K[^\')]+" <<< "$RAWENT")"

		if [ -n "$VAL" ]; then
			if grep -q "MENU_GAME" <<< "$RAWENT"; then
				if [ "$SAVMENUCAT" == "$GAMETEMPMENU" ]; then
					SAVECFG="$STLDEFGAMECFG"
				else
					SAVECFG="$STLGAMECFG"
				fi
			elif grep -q "MENU_URL" <<< "$RAWENT"; then
				SAVECFG="$STLURLCFG"
			elif grep -q "MENU_GLOBAL" <<< "$RAWENT"; then
				SAVECFG="$STLDEFGLOBALCFG"
			else
				writelog "SKIP" "${FUNCNAME[0]} - No valid configfile determined for VAR='$VAR' WRITEVAL='$WRITEVAL' - this is an error!"
			fi
			VALUNQ="${VAL//\'/}"
			WRITEVAL="${VALUNQ/# -/-}"

			if [ -n "$VAR" ] && [ -z "$WRITEVAL" ] && [ -n "$SAVECFG" ]; then
				WRITEVAL="$NON"
				writelog "INFO" "${FUNCNAME[0]} - Value for '$VAR' is empty - automatically setting '$NON'"
			fi

			if [ -n "$VAR" ] && [ -n "$WRITEVAL" ] && [ -n "$SAVECFG" ]; then
				updateConfigEntry "$VAR" "$WRITEVAL" "$SAVECFG"
			fi
		fi
	done
	writelog "INFO" "${FUNCNAME[0]} - Done with Saving changed Settings"
}

function saveNewRes {
	if [ "$SAVESETSIZE" -eq 1 ] && [ -n "$3" ]; then
		SNEWW="$1"
		SNEWH="$2"
		CFG="$3"
		touch "$CFG"
		updateConfigEntry "WINX" "$SNEWW" "$CFG"
		updateConfigEntry "WINY" "$SNEWH" "$CFG"
		writelog "INFO" "${FUNCNAME[0]} - Saved new resolution '${SNEWW}x${SNEWH}' in '$CFG'" "$WINRESLOG"
	fi
}

function updateThisWinTemplate {
	if [ -f "$UPWINTMPL" ] && [ -f "$2" ]; then
		cp "$2" "$STLGUIDIR/$SCREENRES/${TEMPL}/${1}.conf"
		rm "$UPWINTMPL"
		writelog "INFO" "${FUNCNAME[0]} - Updated Window Template '$STLGUIDIR/$SCREENRES/${TEMPL}/${1}.conf' with '$2'" "$WINRESLOG"
		notiShow "$(strFix "$NOTY_TEMPLUP" "$1")"
	fi
}

function updateWinRes {
	if [ -z "$SAVESETSIZE" ] || [ "$ONSTEAMDECK" -eq 1 ]; then
		SAVESETSIZE=0
	fi

	if [ "$SAVESETSIZE" -eq 1 ]; then
		WNAM="$1"
		CFG="$2"
		TEMPLGUICFG="$3"

		writelog "INFO" "${FUNCNAME[0]} - Starting resolution-poll for '$GAMEGUICFG' with incoming '${WINX}x${WINY}'" "$WINRESLOG"

		ORGW="${WINX}"
		ORGH="${WINY}"
		NEWW="${WINX}"
		NEWH="${WINY}"

		MAXWAIT=3
		COUNTER=0

		while ! "$XWININFO" -name "$WNAM" -stats >/dev/null 2>/dev/null; do
			if [ -f "$CLOSETMP" ]; then
				writelog "WAIT" "${FUNCNAME[0]} - ${PROGNAME,,} is just closing - leaving loop" "$WINRESLOG"
				break
			fi
			if [[ "$COUNTER" -ge "$MAXWAIT" ]]; then
				writelog "SKIP" "${FUNCNAME[0]} - Timeout waiting for Window '$WNAM'" "$WINRESLOG"
				return
			fi

			writelog "INFO" "${FUNCNAME[0]} - Waiting for Window '$WNAM'" "$WINRESLOG"
			COUNTER=$((COUNTER+1))
			sleep 1
		done

		writelog "INFO" "${FUNCNAME[0]} - Window '$WNAM' is running - polling the resolution" "$WINRESLOG"

		while true; do
			SRES="$("$XWININFO" -name "$WNAM" -stats 2>/dev/null | awk '$1=="-geometry" {print $2}' | cut -d '+' -f1)"
			if grep -q "x" <<< "$SRES"; then
				PREVW="$NEWW"
				PREVH="$NEWH"

				TNEWW1="${SRES%x*}"
				TNEWW="${TNEWW1%%-*}"

				TNEWH1="${SRES#*x}"
				TNEWH="${TNEWH1%%-*}"

				if [ "$TNEWW" -ne "$ORGW" ] || [ "$TNEWH" -ne "$ORGH" ]; then
					if [ "$TNEWW" != "$PREVW" ] || [ "$TNEWH" != "$PREVH" ]; then
						if [ -n "${TNEWW##*[!0-9]*}" ] && [ -n "${TNEWH##*[!0-9]*}" ]; then
							NEWW="$TNEWW"
							NEWH="$TNEWH"
							writelog "INFO" "${FUNCNAME[0]} - Found new Window Resolution '${NEWW}x${NEWH}' for Window '$WNAM'" "$WINRESLOG"
						else
							writelog "SKIP" "${FUNCNAME[0]} - Skipping found false-positive size '${NEWW}x${NEWH}'"	"$WINRESLOG"
						fi
					fi
				fi
				sleep 1
			else
				if [ "$NEWW" -ne "$ORGW" ] || [ "$NEWH" -ne "$ORGH" ]; then
					writelog "INFO" "${FUNCNAME[0]} - The Window '$WNAM' was closed - saving the last seen resolution '${NEWW}x${NEWH}' into config '$CFG'" "$WINRESLOG"
					saveNewRes "$NEWW" "$NEWH" "$CFG"
					if [ ! -f "$TEMPLGUICFG" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Creating template '$TEMPLGUICFG' with the same resolution '${NEWW}x${NEWH}'" "$WINRESLOG"
						cp "$CFG" "$TEMPLGUICFG"
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - The Window '$WNAM' was closed - the resolution didn't change - nothing to do" "$WINRESLOG"
				fi

				updateThisWinTemplate "$TITLE" "$CFG"

				return
			fi
		done
	fi
}

function updateEditor {
	CFG="$1"

	loadCfg "$CFG" X
	if grep -q "$XDGO" <<< "$STLEDITOR" || [ ! -f "$STLEDITOR" ] ; then
		writelog "WARN" "${FUNCNAME[0]} - '$XDGO' selected as editor or configured editor not found - trying to find an installed editor installed"
		if [ -x "$(command -v "$XDGMIME" 2>/dev/null)" ]; then
			XDGED="$(command -v "$("$XDGMIME" query default text/plain | cut -d '.' -f1)" 2>/dev/null)"
			if [ -x "$XDGED" ]; then
				writelog "INFO" "${FUNCNAME[0]} - $XDGMIME points to '$XDGED', which also exists"
				FOUNDEDITOR="$XDGED"
			fi
		fi

		if [ -z "$FOUNDEDITOR" ]; then
			if [ -x "$(command -v "geany")" ]; then
				FOUNDEDITOR="$(command -v "geany")"
			elif [ -x "$(command -v "gedit")" ]; then
				FOUNDEDITOR="$(command -v "gedit")"
			elif [ -x "$(command -v "leafpad")" ]; then
				FOUNDEDITOR="$(command -v "leafpad")"
			elif [ -x "$(command -v "kwrite")" ]; then
				FOUNDEDITOR="$(command -v "kwrite")"
			fi
		fi

		if [ -n "$FOUNDEDITOR" ]; then
			writelog "INFO" "${FUNCNAME[0]} - changing STLEDITOR to '$FOUNDEDITOR' in '$CFG'"
			updateConfigEntry "STLEDITOR" "$FOUNDEDITOR" "$CFG"
			loadCfg "$CFG"
		else
			writelog "INFO" "${FUNCNAME[0]} - No valid editor found - will fall back to '$XDGO'."
		fi
	fi
}

function setGPfxFromAppMa {
	if [ -n "$2" ] && [ -f "$2" ]; then
		echo "${2%/*}/$CODA/$1/pfx"
	else
		if [ -z "$GPFX" ]; then
			APPMAFE="$(listAppManifests | grep -m1 "${1}.acf")"
			if [ -n "$APPMAFE" ]; then
				if [ ! -d "$APPMAFE" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - '$APPMAFE' is no valid directory - probably function 'listAppManifests' requires a fix here!"
				else
					AMF="${APPMAFE##*/}"
					GPFX="${APPMAFE%/*}/$CODA/$1/pfx"
					writelog "INFO" "${FUNCNAME[0]} - Found WINEPREFIX '$GPFX' in '$AMF'"
				fi
			fi
		fi
	fi
	if [ -z "$GPFX" ] && [ -n "$AMF" ] && [ -z "$2" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Could not retrieve WINEPREFIX from '$AMF'"
	fi
}

function getGameTextFiles {
	setGPfxFromAppMa "$AID"
	unset GameTxtFiles

	if [ -d "$GPFX/$DRCU/$STUS" ]; then
		# an option to parse user-contributed per game config lists with the actual config files instead of searching for any textfile would be easy
		EXID="$HIDEDIR/hide-${AID}.txt"
		touch "$EXID"
		SKIPGTF=0

		if [ -n "$1" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Searching for at least one editable textfile in '$GPFX/$DRCU/$STUS'"
			find "$GPFX/$DRCU/$STUS" -type f -exec grep -Iq . {} \; -print -quit >/dev/null
		else
			while read -r gtxtfile; do
				while read -r skip; do
					if grep -q "$skip" <<< "$gtxtfile"; then
						SKIPGTF=1
					fi
				done < "$EXID"

				if [ "$SKIPGTF" -eq 0 ]; then
					GameTxtFiles+=("$gtxtfile")
				else
					SKIPGTF=0
				fi
			done <<< "$(find "$GPFX/$DRCU/$STUS" -type f -exec grep -Iq . {} \; -print)"
		fi
	fi
}

function getAvailableCfgs {
	unset CfgFiles
	while read -r cfgfile; do
		if [ -f "${!cfgfile}" ]; then
			CfgFiles+=("${!cfgfile}")
		fi
	done <<< "$(sed -n "/^#STARTEDITORCFGLIST/,/^#ENDEDITORCFGLIST/p;/^#ENDEDITORCFGLIST/q" "$TGSRC_PATHS" | grep -v "^#" | grep -v "LOGFILE" | grep "=" | cut -d '=' -f1)"

	getGameTextFiles "X"
}

function confirmReq {
	QUESTION="$2"
	TITLE="${PROGNAME}-$1"
	pollWinRes "$TITLE"
	setShowPic

	"$YAD" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center --on-top "${WINDECO[@]}" --title="$TITLE" --text="$(spanFont "$QUESTION" "H")" "$GEOM"
	echo "$?"
}

function EditorDialog {
	writelog "INFO" "${FUNCNAME[0]} - Opening Editor Dialog"

	resetAID "$1"
	loadCfg "$STLGAMECFG" X
	getAvailableCfgs

	if [ "$BACKUPSTEAMUSER" -eq 1 ]; then
		EXID="$BACKEX/exclude-${AID}.txt"
		if [ -f "$EXID" ]; then
			CfgFiles+=("$EXID")
		fi
	fi

	HIDEID="$HIDEDIR/hide-${AID}.txt"
	if [ -f "$HIDEID" ]; then
		CfgFiles+=("$HIDEID")
	fi

	if [ -f "$MAHUTMPL" ]; then
		CfgFiles+=("$MAHUTMPL")
	fi

	MHIC="$MAHUCID/${AID}.conf"
	if [ -f "$MHIC" ]; then
		CfgFiles+=("$MHIC")
	fi

	getGameTextFiles
	CfgFiles+=("${GameTxtFiles[@]}")

	if [ -f "$LOGFILE" ]; then
		CfgFiles+=("$LOGFILE")
	fi

	REVALSC="$EVMETAID/${EVALSC}_${AID}.vdf"
	CEVALSC="$EVMETACUSTOMID/${EVALSC}_${AID}.vdf"
	AEVALSC="$EVMETAADDONID/${EVALSC}_${AID}.vdf"

	if [ -f "$REVALSC" ]; then
		CfgFiles+=("$REVALSC")
	fi

	if [ -f "$CEVALSC" ]; then
		CfgFiles+=("$CEVALSC")
	fi

	if [ "$UUUSEIGCS" -eq 1 ] || [ "$USEIGCS" -eq 1 ]; then
		IGCSINI="$EFD/${IGCS}.ini"
		if	 [ -f "$IGCSINI" ]; then
			CfgFiles+=("$IGCSINI")
		fi
	fi

	if [ "$UUUSEPATCH" -eq 1 ] || [ "$UUUSEVR" -eq 1 ]; then
		UUUPATCHFILE="$(find "$MEGAMEDIR" -name "$UUUPATCH")"
		if	[ -f "$UUUPATCHFILE" ]; then
			CfgFiles+=("$UUUPATCHFILE")
		fi
	fi

	if [ "$USERESHADE" -eq 1 ] || [ "$USESPECIALK" -eq 1 ]; then
		setFullGameExePath "FGEP"
		while read -r inifile; do
			if [ -f "$inifile" ]; then
				CfgFiles+=("$inifile")
			fi
		done <<< "$(find "$FGEP" -mindepth 1 -maxdepth 1 -type f -name "*.ini")"
	fi

	if [ "$USEOPENVRFSR" -eq 1 ]; then
		OVRFP="$EFD/${OVFS}-${SHOSTL}-enabled.txt"
		if [ -f "$OVRFP" ]; then
			OVRMODF="$EFD/$(grep "$OVRMOD" "$OVRFP")"
			if [ -f "$OVRMODF" ]; then
				CfgFiles+=("$OVRMODF")
			fi
		fi
	fi

	if [ -f "$AEVALSC" ]; then
		CfgFiles+=("$AEVALSC")
	fi

	if [ -f "$STLPROTONIDLOGDIR/steam-${AID}.log" ]; then
		CfgFiles+=("$STLPROTONIDLOGDIR/steam-${AID}.log")
	fi

	if [ -f "$STLDXVKLOGDIR/${GE}_d3d11.log" ]; then
		CfgFiles+=("$STLDXVKLOGDIR/${GE}_d3d11.log")
	fi

	if [ -f "$STLDXVKLOGDIR/${GE}_dxgi.log" ]; then
		CfgFiles+=("$STLDXVKLOGDIR/${GE}_dxgi.log")
	fi

	writelog "INFO" "${FUNCNAME[0]} - Found ${#CfgFiles[@]} available Config Files - opening Checklist"
	export CURWIKI="$PPW/Editor-Menu"
	TITLE="${PROGNAME}-Editor"
	pollWinRes "$TITLE"

	setShowPic

	EDFILES="$(while read -r f; do	echo "FALSE"; echo "$f"; done <<< "$(printf "%s\n" "${CfgFiles[@]}" | sort -u)" | \
	"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist --column=Edit --column=ConfigFile --separator="\n" --print-column="2" \
	--text="$(spanFont "$(strFix "$GUI_EDITORDIALOG" "$SGNAID")" "H")" --title="$TITLE" --button="$BUT_EDIT":0 --button="$BUT_HIDE":2 --button="$BUT_OD":4 --button="$BUT_DEL":6 --button="$BUT_CAN":8 "$GEOM")"
	case $? in
		0)  {
				if [ -n "$EDFILES" ]; then
					if [ -n "$HELPURL" ] && [ "$HELPURL" != "$NON" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Opening the url '$HELPURL' in the browser"
						checkHelpUrl "$HELPURL"
					fi

					if [ -z "$STLEDITOR" ] || [ "$STLEDITOR" = "$NON" ]; then
						writelog "INFO" "${FUNCNAME[0]} - No editor found or selected. Falling back to '$XDGO'"
						writelog "WARN" "${FUNCNAME[0]} - If you find games fail to close try setting an editor manually"
						STLEDITOR=$XDGO
					fi

					writelog "INFO" "${FUNCNAME[0]} - Opening Editor '$STLEDITOR' with selected Config Files"
					mapfile -t -O "${#EdArr[@]}" EdArr <<< "$EDFILES"
					"$STLEDITOR" "${EdArr[@]}"
					unset EdArr
					# kill browser if it was opened with the editor:
					if [ -n "$KILLBROWSER" ]; then
						if [ "$KILLBROWSER" -eq 1 ]; then
							"$PKILL" -f "$BROWSER"
						fi
					fi
				fi
			}
		;;
		2)  {
		writelog "INFO" "${FUNCNAME[0]} - Selected HIDE 1"
				if [ -n "$EDFILES" ]; then
					HIDELIST="$HIDEDIR/hide-${AID}.txt"
					writelog "INFO" "${FUNCNAME[0]} - Selected HIDE - Hiding all selected files from the EditorList by adding them to the Exclude list '$HIDELIST'"
					echo "$EDFILES"	 >> "$HIDELIST"
					sort -u"$HIDELIST" -o "$HIDELIST"
					sed "/^ *$/d" -i "$HIDELIST"
				fi
			}
		;;
		4)
			if [ -x "$(command -v "$XDGO" 2>/dev/null)" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Selected Open Directory - Opening the directory containing the first selected file using '$XDGO'"
				mapfile -t -O "${#EdArr[@]}" EdArr <<< "$EDFILES"
				"$XDGO" "$(dirname "${EdArr[0]}")"
				unset EdArr
			else
				writelog "SKIP" "${FUNCNAME[0]} - '$XDGO' not found - can't open the directory"
			fi
		;;
		6)  writelog "INFO" "${FUNCNAME[0]} - Selected Delete"
			RSEL="$(confirmReq "Ask_Delete_Selected_Files" "$GUI_DELSEL")"
			if [ "$RSEL" -eq 0 ]; then
			{
				writelog "INFO" "${FUNCNAME[0]} - Confirmed deletion of all selected files"
				mapfile -t -O "${#EdArr[@]}" EdArr <<< "$EDFILES"
				rm "${EdArr[@]}" 2>/dev/null
				unset EdArr
			}
			else
				writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL - Not deleting the files"
			fi
		;;
		8)  writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL"
		;;
	esac

	goBackToPrevFunction "${FUNCNAME[0]}" "$2"
}

function goBackToPrevFunction {
	IAM="$1"
	PREV="$2"

	if [ "$IAM" != "$PREV" ]; then
		if [ -z "$3" ]; then
			MYGOBACK=1
		else
			MYGOBACK="$3"
		fi

		if [ -z "$PREV" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$IAM' closed"
		else
			if [ "$PREV" != "$NON" ] && [ "$MYGOBACK" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - '$IAM' closed - Going back to the '$PREV'"
				"$PREV" "$AID" "$IAM"
			else
				writelog "INFO" "${FUNCNAME[0]} - '$IAM' closed"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Took a wrong road somewhere - '$IAM' and '$PREV' - leaving"
	fi
}

function closeTrayIcon {
	notiShow "$(strFix "$NOTY_CLOSETRAY" "$YADTRAYPID")"
	writelog "INFO" "${FUNCNAME[0]} - Closing TrayIcon '$YADTRAYPID'"
	kill "$YADTRAYPID" 2>/dev/null
}

function cleanYadLeftOvers {
	closeTrayIcon
}

function GETALTEXEPATH {
	if [ -n "$ALTEXEPATH" ] && [ "$ALTEXEPATH" != "/tmp" ]; then
		if [ -d "$ALTEXEPATH" ]; then
			echo "$ALTEXEPATH"
		elif [ -d "$EFD/$ALTEXEPATH" ]; then
			echo "$EFD/$ALTEXEPATH"
		fi
	fi
}

#STARTIEX
function TrayIconExports {
	export XWI="$XWININFO"
	export XDO="$XDO"
	export PROGCMD="$PROGCMD"

	export -f writelog
	export AID="$AID"

	export GPFX="$GPFX"
	export KILLSWITCH="$KILLSWITCH"
	export -f killProtonGame
	export -f PauseGame
	export EFD="$EFD"
	export GAMEWINDOW="$GAMEWINDOW"
	export UPWINTMPL="$UPWINTMPL"
	export TRAYCUSC="$TRAYCUSC"

	if [ -n "$(GETALTEXEPATH)" ]; then
		SHADDESTDIR="$(GETALTEXEPATH)"
	fi

	export SHADDESTDIR="$SHADDESTDIR"

	KPFX="$GPFX"
	if [ "$USEWINE" -eq 1 ]; then
		setWineVars
		KPFX="$GWFX"
	fi

	if [ ! -f "$RUNWINE" ]; then
		setRunWineServer "${FUNCNAME[0]}"
	fi

	export RUNWINESERVER="$RUNWINESERVER"

	if [ -n "$KPFX" ]; then
		echo "WINEPREFIX=\"$KPFX\" \"$RUNWINESERVER\" -k" > "$KILLSWITCH"
		if [ "$USEMANGOAPP" -eq 1 ]; then
			echo "$PKILL -f \"$MANGOAPP\"" >> "$KILLSWITCH"
		fi
		echo "touch $CLOSETMP" >> "$KILLSWITCH"
		chmod +x "$KILLSWITCH"
	fi

	export SHADDESTDIR="$SHADDESTDIR"
	export -f TrayShaderMenu
	export -f TrayVR
	export -f TrayPickWin
	export -f TraySRC
	export -f TrayUWT
	export -f TrayLCS
	export -f TrayGameFiles
	export -f TrayMO2
	export -f TrayProtonList
	export -f TrayOpenIssue
}
#ENDIEX

function openTrayIcon {
	setShadDestDir

	if [ -z "$1" ]; then
		# loading gameconfig here, as some vars might have to be exported
		writelog "INFO" "${FUNCNAME[0]} - LoadCfg: $STLGAMECFG"
		loadCfg "$STLGAMECFG"
	fi

	if [ "$ONSTEAMDECK" -eq 1 ] && [ "$FIXGAMESCOPE" -eq 1 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Skipping TrayIcon on SteamDeck Game Mode" "X"
	else
		if [ -z "$YADTRAYPID" ] && [ "$USETRAYICON" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Opening trayIcon:" "X"

			# variables and functions used by exported functions below

			# functions for the trayIcon Menu
			function killProtonGame {
				"$KILLSWITCH"
			}

			function PauseGame {
				PAUSEPID="$(sleep 5 && "$XDO" getactivewindow getwindowpid)"
				# idea taken with friendly permission from $GHURL/Ilazki:
				GAMESTATE="$(ps -q "$PAUSEPID" -o state --no-headers)"
				GAMESIG="-STOP"

				if [ "$GAMESTATE" = "T" ] ; then
					GAMESIG="-CONT"
				fi

				kill "$GAMESIG" "$PAUSEPID"
			}

			function TrayShaderMenu {
				"$PROGCMD" update gameshaders "$SHADDESTDIR"
			}

			function TrayVR {
				if [ -z "$GAMEWINDOW" ]; then
					GAMEWINDOW="$(sleep 2 && "$XWI" -stats | grep ^"$XWI" | tail -n1 | cut -d '"' -f2)";
				fi

				if [ -n "$GAMEWINDOW" ]; then
					writelog "INFO" "${FUNCNAME[0]} - TrayIcon: picked '$PICKWINDOWNAME'"
					"$PROGCMD" game vr "$PICKWINDOWNAME" "$AID" "s"
				else
					writelog "SKIP" "${FUNCNAME[0]} - TrayIcon: Didn't find a game window name to open in vr"
				fi
			}

			function TrayPickWin {
				writelog "INFO" "${FUNCNAME[0]} - TrayIcon: Executing Window Pick command for game '$GN '$AID'"
				"$PROGCMD" game pickwin "$AID" "$GN"
			}

			function TraySRC {
				writelog "INFO" "${FUNCNAME[0]} - TrayIcon: Executing command '$STEAM ${STEAM}://${RECO}'"
				"$PROGCMD" steam src
			}

			function TrayUWT {
				writelog "INFO" "${FUNCNAME[0]} - TrayIcon: Triggering Window Template Update"
				touch "$UPWINTMPL"
			}

			function TrayLCS {
				writelog "INFO" "${FUNCNAME[0]} - TrayIcon: Triggering Launch custom script"
				"$TRAYCUSC"
			}

			function TrayGameFiles {
				writelog "INFO" "${FUNCNAME[0]} - TrayIcon: Executing Game Files command for game '$GN '$AID'"
				"$PROGCMD" game files "$AID"
			}

			function TrayMO2 {
				writelog "INFO" "${FUNCNAME[0]} - TrayIcon: Starting standalone $MO instance"
				"$PROGCMD" mods mo2 start
			}

			function TrayProtonList {
				writelog "INFO" "${FUNCNAME[0]} - TrayIcon: Updating list of available Proton versions"
				"$PROGCMD" proton refresh
			}

			function TrayOpenIssue {
				writelog "INFO" "${FUNCNAME[0]} - TrayIcon: Open Issue Tracker with User's Default Browser"
				"$PROGCMD" issue
			}

			TrayIconExports

			# actually open the actual trayIcon
			GDK_BACKEND=x11 "$YAD" --image="$STLICON" --notification --item-separator=","\
			--menu="$TRAY_KILLSWITCH,bash -c killProtonGame \
			|$TRAY_PAUSE,bash -c PauseGame \
			|$TRAY_SHADER,bash -c TrayShaderMenu \
			|$TRAY_VR,bash -c TrayVR \
			|$TRAY_PICKWINDOW,bash -c TrayPickWin \
			|$TRAY_SRC,bash -c TraySRC \
			|$TRAY_UWT,bash -c TrayUWT \
			|$TRAY_LCS,bash -c TrayLCS \
			|$GUI_GAFI,bash -c TrayGameFiles \
			|$TRAY_UPL,bash -c TrayProtonList \
			|$FBUT_GUISET_MO,bash -c TrayMO2 \
			|$TRAY_OPENISSUE,bash -c TrayOpenIssue" \
			--text="$TRAY_TOOLTIP" >/dev/null 2>/dev/null &
			YADTRAYPID="$!"
		fi
	fi
}

