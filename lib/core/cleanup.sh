#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function setCloseVars {
# yes, ugly... ¯\_(ツ)_/¯
	if [ ! -f "$CLOSEVARS" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Storing all variables used in closeSTL into '$CLOSEVARS'"
		{
		echo BROWSER
		echo LOGLEVEL
		echo MO2MODE
		echo ONLY_CUSTOMCMD
		echo RUN_NYRNA
		echo RUN_REPLAY
		echo RUNSBSVR
		echo TOGSTEAMWEBHELPER
		echo USECUSTOMCMD
		echo USEMANGOAPP
		echo USENETMON
		echo USEPROTON
		echo USEWINE
		echo WAITFORTHISPID
		} >> "$CLOSEVARS"
		# should be sorted above already, but better safe
		sort "$CLOSEVARS" -o "$CLOSEVARS"
	fi
}

#STARTCLOSESTL ###
function closeSTL {
	writelog "INFO" "${FUNCNAME[0]} - closing STL"

	updateConfigEntry "CUSTOMCMD" "$DUMMYBIN" "$STLDEFGAMECFG"

	# dummy file which could be used to stop possible while loops
	writelog "INFO" "${FUNCNAME[0]} - Creating '$CLOSETMP'"
	touch "$CLOSETMP"

	setPrevRes
	customUserScriptStop	# USERSTOP

	rmFileIfExists "$MO2INSTFAIL" 2>/dev/null

	if [ "$USEMANGOAPP" -eq 1 ] && "$PGREP" -f "$MANGOAPP" >/dev/null; then
		writelog "INFO" "${FUNCNAME[0]} - Killing '$MANGOAPP'"
		"$PKILL" -f "$MANGOAPP"
	fi

	checkPlayTime "$duration"

	steamdeckClose

	if [ -f "$STLSHM/KillBrowser-$AID.txt" ]; then
		writelog "INFO" "${FUNCNAME[0]} - '$BROWSER' instance was created, so closing it now, to exit the game session"
		if [ -n "$BROWSER" ] && [ "$BROWSER" != "$XDGO" ]; then
			"$PKILL" -f "$BROWSER"
		fi
		rm "$STLSHM/KillBrowser-$AID.txt"
	fi

	cleanSUTemp
	backupSteamUser "$AID"

	if [ "$SGDBAUTODL" == "after_game" ] ; then
		writelog "INFO" "${FUNCNAME[0]} - Automatic Grid Update Check '$SGDBAUTODL'"
		# getGrids "$AID"
		commandlineGetSteamGridDBArtwork --search-id="$AID" --steam
	fi

	if [ "$ISGAME" -eq 2 ] && [ "$PROTON_LOG" -eq 1 ]; then
		createSymLink "${FUNCNAME[0]}" "$STLPROTONIDLOGDIR/steam-${AID}.log" "$STLPROTONTILOGDIR//steam-${GN}.log"
	fi

	writelog "INFO" "${FUNCNAME[0]} - Game '$SGNAID' exited - cleaning up custom processes if necessary"

# all variables in closeSTL are blocked from being unset before gamestart - dirty list with variables to keep which are not used here:
#DXVK_HUD DXVK_LOG_LEVEL ENABLE_VKBASALT LOGDIR LOGLEVEL MANGOHUD NETOPTS PROTON_DEBUG_DIR PROTON_DUMP_DEBUG_COMMANDS PROTON_FORCE_LARGE_ADDRESS_AWARE
#PROTON_LOG PROTON_LOG_DIR PROTON_NO_D3D10 PROTON_NO_D3D11 PROTON_NO_ESYNC PROTON_NO_FSYNC PROTON_ENABLE_NVAPI PROTON_HIDE_NVIDIA_GPU PROTON_USE_WINED3D
#USESLR WINEDLLOVERRIDES WINE_FULLSCREEN_INTEGER_SCALING WINE_FULLSCREEN_FSR WINE_FULLSCREEN_FSR_STRENGTH WINE_FULLSCREEN_FSR_MODE WINE_FULLSCREEN_FSR_CUSTOM_MODE

	# kill $VRVIDEOPLAYER in case it wasn't closed before
	if [ -n "$RUNSBSVR" ]; then
		if [ "$RUNSBSVR" -eq 1 ]; then
			if "$PGREP" -f "$VRVIDEOPLAYER" >/dev/null; then
				"$PKILL" -f "$VRVIDEOPLAYER"
				writelog "INFO" "${FUNCNAME[0]} - $VRVIDEOPLAYER killed"
			fi
		fi
	fi

	# kill $NYRNA if running
	if [ -n "$RUN_NYRNA" ]; then
		if [ "$RUN_NYRNA" -eq 1 ]; then
			if "$PGREP" -f "$NYRNA" >/dev/null; then
				"$PKILL" -f "$NYRNA"
				# also remove systray created in /tmp/ ("systray_" with 6 random chars should be save enough)
				find /tmp -maxdepth 1 -type f -regextype posix-extended -regex '^.*systray_[A-Z,a-z,0-9]{6}' -exec rm {} \;
				writelog "INFO" "${FUNCNAME[0]} - $NYRNA killed"
			fi
		fi
	fi

	# kill $REPLAY if running
	if [ -n "$RUN_REPLAY" ]; then
		if [ "$RUN_REPLAY" -eq 1 ]; then
			if "$PGREP" -f "$REPLAY" >/dev/null; then
				"$PKILL" -f "$REPLAY"
				writelog "INFO" "${FUNCNAME[0]} - $REPLAY killed"
			fi
		fi
	fi

	# stop network monitor if running
	if [ "$USENETMON" -eq 1 ]; then
		if "$PGREP" "$NETMON" >/dev/null; then
			"$PKILL" -f "$NETMON"
			writelog "INFO" "${FUNCNAME[0]} - $NETMON killed"
			rmDupLines "$NETMONDIR/$AID-$NETMON.log"  # remove duplicate lines to make reading easier
		fi
	fi

	togWindows windowraise	# TOGGLEWINDOWS
	getHexAidForAid "$AID" X
	cleanYadLeftOvers
	notiShow "$(strFix "$NOTY_STLSTOP" "$GN" "$AID" "$PROGNAME")"

	sleep 1 # so any while loop still running gets the chance to see it
	writelog "INFO" "${FUNCNAME[0]} - Removing '$CLOSETMP'"
	rm "$CLOSETMP" 2>/dev/null
	writelog "STOP" "######### ${FUNCNAME[0]} $PROGNAME $PROGVERS #########"
	rm "$UPWINTMPL" 2>/dev/null
	rm "$KILLSWITCH" 2>/dev/null
	rm "$GWXTEMP" 2>/dev/null
	rm "$STLSHM"/lola-*.txt 2>/dev/null

	# only useful for win games or games started outside steam:
	if [ "$STLPLAY" -eq 1 ] || [ "$ISGAME" -eq 2 ] || { [ "$ISGAME" -eq 3 ] && [ "$USEWINE" -eq 0 ]; }; then
		writeLastRun
		storeMetaData "$AID" "$GN" "$GPFX" "$EFD"
	fi

	delMenuTemps
	delWinetricksTemps
	if [ "$AID" != "$PLACEHOLDERAID" ]; then
		echo "log can be found under: '$TEMPLOG' and '$LOGFILE'"
	else
		echo "log can be found under: '$TEMPLOG'"
	fi
}
#ENDCLOSESTL ###

# main:#################

function saveOrgVars {
	# TODO resolve the unused warnings by dynamically assigning the variables like we do in 'restoreOrgVars'

	writelog "INFO" "${FUNCNAME[0]} - Storing some original variables to restore them later" "P"

	env | grep "=" | sort -o "$VARSIN"

	# shellcheck disable=2034
	# Keep the value main saved before it emptied LD_PRELOAD (see the overlay-deadlock
	# note after setAIDCfgs). Unset-only default so an intentionally-empty saved value
	# is preserved rather than overwritten with the current (already empty) LD_PRELOAD.
	ORG_LD_PRELOAD="${ORG_LD_PRELOAD-${LD_PRELOAD-}}"
	# shellcheck disable=2034
	ORG_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
	# shellcheck disable=2034
	ORG_LC_ALL="$LC_ALL"
	# shellcheck disable=2034
	ORG_PATH="$PATH"
}

function emptyVars {
	# clear "original" variables
	if [ "$1" == "O" ] ; then
		LC_ALL=""
		STLPATH="$(tr ':' '\n' <<< "$PATH" | grep -v "$STERU" | tr '\n' ':')"
		PATH="$STLPATH"

		FPPATH="/app/utils/bin/"
		if [ -d "$FPPATH" ]; then
			PATH="${STLPATH%:}:$FPPATH"
		else
			PATH="$STLPATH"
		fi
		LD_LIBRARY_PATH=""
		LD_PRELOAD=""
		if [ -z "$2" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Emptied some original variables as they slowdown several system calls when started from steam" "P"
			writelog "INFO" "${FUNCNAME[0]} - Set \$PATH to '$PATH'" "P"
		fi
	# empty "some" internal variables created by ${PROGNAME,,} (before starting the game)
	elif [ "$1" == "S" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Clearing some '${PROGNAME,,}' internal variables before the game starts"

		TIEXV="$STLSHM/TrayIconVars.txt"
		TIEXF="$STLSHM/TrayIconFuncs.txt"

		if [ ! -f "$TIEXV" ]; then
			sed -n "/^#STARTIEX/,/^#ENDIEX/p;/^#ENDIEX/q" "$TGSRC_MENUCORE" | grep export | grep -v "export \-f" | cut -d '=' -f1 | awk -F 'export ' '{print $2}' > "$TIEXV"
		fi

		if [ ! -f "$TIEXF" ]; then
			sed -n "/^#STARTIEX/,/^#ENDIEX/p;/^#ENDIEX/q" "$TGSRC_MENUCORE" | grep "export \-f" | awk -F '-f ' '{print $2}' > "$TIEXF"
		fi

		while read -r intvar; do
			if [ -n "$intvar" ]; then
				if [[ "$intvar" =~ "BASH_FUNC" ]]; then
					BAFU1="${intvar#BASH_FUNC_*}"
					BAFU="${BAFU1%%\%}"
					if grep -q "${BAFU%%\%}" "$STLSHM/TIEXF"; then
						writelog "INFO" "${FUNCNAME[0]} - Skipping TrayIcon function '${BAFU%%\%}'"
					else
						if grep -q "function ${BAFU%%\%}" "$TG_LIBDIR"/*/*.sh; then
							writelog "INFO" "${FUNCNAME[0]} - Clearing function '${BAFU%%\%}'"
							unset -f "${BAFU%%\%}"
						else
							writelog "INFO" "${FUNCNAME[0]} - Skipping unknown function '${BAFU%%\%}'"
						fi
					fi
				else
					if grep -q "$intvar" "$STLSHM/TIEXV"; then
						writelog "INFO" "${FUNCNAME[0]} - Skipping TrayIcon variable '$intvar'"
					else
						if ! grep -q "\$${intvar}" "$TG_LIBDIR"/*/*.sh ; then
							writelog "INFO" "${FUNCNAME[0]} - Skipping unknown variable '$intvar'"
						else
							if grep -q "$intvar" <<< "$(sed -n "/^#STARTCLOSESTL/,/^#ENDCLOSESTL/p;/^#ENDCLOSESTL/q" "$TGSRC_CLEANUP")"; then
								writelog "INFO" "${FUNCNAME[0]} - Skipping variable in closeSTL '$intvar'"
							else
								writelog "INFO" "${FUNCNAME[0]} - Clearing variable '$intvar'"
								unset "$intvar"
							fi
						fi
					fi
				fi
			fi
		done <<< "$(comm -32 <(cut -d '=' -f1 < "$STLSHM/${FUNCNAME[0]}-in") <(cut -d '=' -f1 < "$VARSIN"))"
	fi
}

function unsetSTLvars {
	setCloseVars
	writelog "INFO" "${FUNCNAME[0]} - Unsetting $PROGNAME internal variables"
	sort "$STLSETENTRIES" -o "${STLSETENTRIES}s"
	while read -r line; do
		unset "$line"
	done <<< "$(comm -3 "${STLSETENTRIES}s" "$CLOSEVARS")"
}

function restoreOrgVars {
	writelog "INFO" "${FUNCNAME[0]} - Restoring previously cleared environment variables"

	STLRESTOREVARS=( "LD_PRELOAD" "LD_LIBRARY_PATH" "LC_ALL" "PATH" )
	for RESTOREVAR in "${STLRESTOREVARS[@]}"; do

		# e.g. 'ORG_LD_PRELOAD' for 'LD_PRELOAD' on first iteration of the loop
		BUILTORGVARNAME="\$ORG_${RESTOREVAR}"

		# Check if the envvar has been defined in a custom-vars conf file, if so don't restore it and continue
		if grep -q "^${RESTOREVAR}" "$GLOBCUSTVARS" || grep -q "^${RESTOREVAR}" "$GAMECUSTVARS"; then
			writelog "WARN" "${FUNCNAME[0]} - Not restoring '${RESTOREVAR}' to original value as it is defined in a custom-vars conf file. This may potentially cause issues."

			continue
		fi

		eval "${RESTOREVAR}=\"${BUILTORGVARNAME}\""
	done
}

function rmOldLog {
	# restart $LOGFILE only if older than 3 minutes # TODO minutes configurable?
	setAIDCfgs
	if [ -f "$LOGFILE" ]; then
		if test "$(find "$LOGFILE" -mmin -3 2>/dev/null)"; then
			rm "$LOGFILE" 2>/dev/null
		fi
	fi
}

