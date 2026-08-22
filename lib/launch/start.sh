#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function startGame {
	loadCfg "$GEMETA/$AID.conf"

	if [ "$STLPLAY" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Getting the Game Window name:"
		getGameWindowName &
	fi

	touch "$PIDLOCK"
	startSBSVR &
	gameFix
	checkConty

	if [ "$BLOCKINTERNET" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Starting game with blocked internet access"
		BLOCKCMD="unshare"
		BLOCKARGS="-n -r"
		unset BLOCKARGSARR
		mapfile -d " " -t -O "${#BLOCKARGSARR[@]}" BLOCKARGSARR < <(printf '%s' "$BLOCKARGS")
		RUNCMD=("$BLOCKCMD" "${BLOCKARGSARR[@]}" "${@}")
	else
		RUNCMD=("${@}")
	fi

	writelog "INFO" "${FUNCNAME[0]} - Full start command is '${*}'"

	prepMO2 "$@"

	if [ "$HAVESCTP" -eq 1 ] && [ "$ISGAME" -eq 2 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Rebuilding STEAM_COMPAT_TOOL_PATHS variable:"
		writelog "INFO" "${FUNCNAME[0]} - Adding RUNPROTON '${RUNPROTON%/*}'"
		STEAM_COMPAT_TOOL_PATHS="${RUNPROTON%/*}"
		if [ "$HAVESCTP" -eq 1 ] && [ "$USESLR" -eq 1 ]; then
			RUNSLA="${RUNSLR[0]}"
			writelog "INFO" "${FUNCNAME[0]} - Adding '${RUNSLA%/*}' because USESLR is enabled"
			STEAM_COMPAT_TOOL_PATHS="$STEAM_COMPAT_TOOL_PATHS:${RUNSLA%/*}"
		fi
		writelog "INFO" "${FUNCNAME[0]} - Result: Set STEAM_COMPAT_TOOL_PATHS from '$ORG_STEAM_COMPAT_TOOL_PATHS' to '$STEAM_COMPAT_TOOL_PATHS'"
	elif [ "$RUNFORCESLR" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Rebuilding STEAM_COMPAT_TOOL_PATHS variable, because SLR was forced"
		writelog "INFO" "${FUNCNAME[0]} - Adding RUNPROTON '${RUNPROTON%/*}'"
		STEAM_COMPAT_TOOL_PATHS="${RUNPROTON%/*}"
		LASTSLRPATH="${LASTSLR% --verb*}"
		STEAM_COMPAT_TOOL_PATHS="$STEAM_COMPAT_TOOL_PATHS:${LASTSLRPATH%/*}"
		writelog "INFO" "${FUNCNAME[0]} - Result: Updated STEAM_COMPAT_TOOL_PATHS to '$STEAM_COMPAT_TOOL_PATHS'"
	fi

	SECONDS=0

	if [ "$MO2MODE" != "disabled" ] && [ -n "$GMO2EXE" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Changing pwd to '${GMO2EXE%/*}' for $MO launch"
		cd "${GMO2EXE%/*}" >/dev/null || return
	fi

	if ! command -v "$GAMESCOPE" >/dev/null && [ "$USEMANGOAPP" -eq 1 ]; then
		writelog "WARN" "${FUNCNAME[0]} - Disabling USEMANGOAPP because '$GAMESCOPE' wasn't found"
		USEMANGOAPP=0
	fi

	if [ -x "$RUNCONTY" ] && [ "$RUNCONTY" != "$NON" ]; then
		writelog "INFO" "${FUNCNAME[0]} - ## Starting game using Conty executable '$RUNCONTY'"
		"$RUNCONTY" "${RUNCMD[@]}"
	else
		writelog "INFO" "${FUNCNAME[0]} - ## ORIGINAL INCOMING LAUNCH COMMAND: '${INGCMD[*]}'"
		writelog "INFO" "${FUNCNAME[0]} - ## STL LAUNCH COMMAND: '${RUNCMD[*]}'"
		writelog "INFO" "${FUNCNAME[0]} - ## GAMESTART HERE ###"

		restoreOrgVars

		GRUNLOG="$STLGLLOGDIRID/${AID}.log"
		if [ "$ISORIGIN" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - ## ${L2EA}  LAUNCH COMMAND: '${RUNCMD[*]}'"

			function runEA {
				"${RUNCMD[@]}" 2>&1 | tee "$GRUNLOG"
			}

			unsetSTLvars
			runEA &
		elif [ "$USEMANGOAPP" -eq 1 ]; then
			# mangoapp gamestart - COMMENTDEBUG:
			writelog "INFO" "${FUNCNAME[0]} - Using $MANGOAPP"
			MRSH="$STLSHM/maprun.sh"
			printf "\"%s\" " "${RUNCMD[@]}" > "$MRSH"
			sed -i "s/\\\/\\\\\\\/" "$STLSHM/maprun.sh"
			chmod +x "$MRSH"
			gameScopeArgs "$GAMESCOPE_ARGS"

			function runMA {
				function mappRun {
					"$MRSH" & "$MANGOAPP"
				}
				export MANGOAPP
				export MRSH
				export -f mappRun
				if [ -n "${GAMESCOPEARGSARR[0]}" ]; then
					writelog "INFO" "${FUNCNAME[0]} - ## ${MANGOAPP^^} GAMESCOPE LAUNCH COMMAND: '$(command -v "$GAMESCOPE") ${GAMESCOPEARGSARR[*]}'"
					"$(command -v "$GAMESCOPE")" "${GAMESCOPEARGSARR[@]}" bash -c mappRun 2>&1 | tee "$GRUNLOG"
				else
					"$(command -v "$GAMESCOPE")" -- bash -c mappRun 2>&1 | tee "$GRUNLOG"
				fi
			}
			runMA &
		else
			# regular gamestart - COMMENTDEBUG:
			"${RUNCMD[@]}" 2>&1 | tee "$GRUNLOG"
		fi
	fi

	if [ "$MO2MODE" != "disabled" ]; then
		cd - >/dev/null || return
	fi

	emptyVars "O" "X" # clear original variables again (mostly for a continous log (date))
	createSymLink "${FUNCNAME[0]}" "$GRUNLOG" "${STLGLLOGDIRTI}/${GN}.log"

# this is broken - maybe later:
#	if [ "$ISGAME" -eq 2 ] && [ "$USEWINE" -eq 0 ] && { grep -qi "GE-" <<< "$USEPROTON" || grep -qi "\-TKG" <<< "$USEPROTON" || [ "$ISORIGIN" -eq 1 ];}; then
	if [ "$ISGAME" -eq 2 ] && [ "$USEWINE" -eq 0 ]; then
		if [ "$ISORIGIN" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Waiting for $L2EA process to finish"
			# TODO maybe add waitForOriginPid - the sleep is not too nice (but at least non blocking)
			sleep 20
			OE="EADesktop.exe"
			WSPID="$("$PGREP" -a "" | grep "$OE" | grep -v grep | cut -d ' ' -f1 | tail -n1)"
			writelog "INFO" "${FUNCNAME[0]} - $L2EA game launch pid is $WSPID"
		elif [ "$USEMANGOAPP" -eq 1 ]; then
			# could be used generally, but undecided yet if waitForGamePid should be used always by default
			waitForGamePid
			RLRUNWINESERVER="$(readlink -f "$RUNWINESERVER")"
			WSPID="$("$PGREP" -a "" | grep "$RLRUNWINESERVER" | grep -v grep | cut -d ' ' -f1 | tail -n1)"
			writelog "INFO" "${FUNCNAME[0]} - $MANGOAPP game launch pid is $WSPID"
		elif [ "$USECUSTOMCMD" -eq 1 ] && [ "$FORK_CUSTOMCMD" -eq 1 ] && [ "$ONLY_CUSTOMCMD" -eq 0 ] && [ "$WAITFORCUSTOMCMD" -ge 1 ] && [ -n "$(CUCOPID)" ];then
			WSPID="$(CUCOPID)"
			writelog "INFO" "${FUNCNAME[0]} - Custom program pid is $WSPID"
		else
			RLRUNWINESERVER="$(readlink -f "$RUNWINESERVER")"
			WSPID="$("$PGREP" -a "" | grep "$RLRUNWINESERVER" | grep -v grep | cut -d ' ' -f1 | tail -n1)"
		fi
		if [ -n "$WSPID" ] && [ "$WSPID" -eq "$WSPID" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Waiting for the process '$WSPID' to finish"
			tail --pid="$WSPID" -f /dev/null

			if [ "$USEMANGOAPP" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - $MANGOAPP game launch finished - closing"
				"$PKILL" -f "$MANGOAPP"
			else
				writelog "INFO" "${FUNCNAME[0]} - Process '$WSPID' finished - closing"
			fi
		else
			writelog "ERROR" "${FUNCNAME[0]} - Could not determine pid of '$RLRUNWINESERVER'"
		fi
	else
		writelog "WARN" "${FUNCNAME[0]} - Skipping Wait for any PID - ISGAME:'$ISGAME';USEWINE:'$USEWINE' - possible missing function!"
	fi

	duration=$SECONDS
	logPlayTime "$duration"
	writelog "INFO" "${FUNCNAME[0]} - ## GAMESTOP after '$duration' seconds playtime"

	# Continue steamwebhelper if requested
	StateSteamWebHelper cont
}

# Shellcheck doesn't like the sed commands here and wants parameter expansion, but I'm not sure that these sed actions are possible with it.
# The Shellcheck wiki says more complex sed examples can be ignored, so we ignore it
function gameScopeArgs {  # This implementation could be VASTLY improved!
	ARGSTRING="$1"
	unset GAMESCOPEARGSARR

	# Even if no args are given we always have to end GameScope commands with '--'
	# $1 == NON when we save with no arguments, doing this visually preserves the GameScope "none" text while still gracefully handling blank args by forcing '--'
	if [ "$1" == "$NON" ] || [ -z "$( trimWhitespaces "$1" )" ]; then  # trimWhitespaces accounts for strings that are just whitespaces, i.e. '     '
		writelog "INFO" "${FUNCNAME[0]} - No gamescope arguments given, but we need to end with '--', so forcing GAMESCOPEARGSARR to '--' and returning"
		GAMESCOPEARGSARR=("--")
		return
	fi

	# This removes paths from the GameScope args array as spaces in paths can cause issues, then builds the array, and then re-inserts the paths where it finds empty single-quotes which we wrap paths with in GameScopeGui.
	# When saving from the main menu, single quotes seem to get cleared, so we need to ensure paths are wrapped with them

	# Store paths from GameScope array string
	IFS_backup=$IFS
	IFS=$'\n'
	mapfile -t GAMESCOPE_ARGPATHS < <( echo "$ARGSTRING" | grep -oP "'/(.+?)'" )
	writelog "INFO" "${FUNCNAME[0]} - GameScope incoming args are '${ARGSTRING[*]}'"
	# If the above is empty, try and surround any existing paths with quotes and then grep for the file paths from the quotes - This means paths cannot contain quotes, but oh well. Compromise!
	if [ -z "${GAMESCOPE_ARGPATHS[*]}" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Could not find any paths from incoming GameScope arguments, checking if we need to surround any paths in quotes..."
		unset GAMESCOPE_ARGPATHS

		# shellcheck disable=SC2001
		ARGSTRING="$(echo "${ARGSTRING}" | sed "s:\(/\S* \S*\):'\1':g" )"  # Finds paths and surrounds them in single quotes so the below grep works!
		mapfile -t GAMESCOPE_ARGPATHS < <( echo "$ARGSTRING" | grep -oP "'/(.+?)'" )
		if [ -n "${GAMESCOPE_ARGPATHS[*]}" ]; then
			writelog "INFO" "${FUNCNAME[0]} - We found some paths we need to update - Updated GameScope args string is '$ARGSTRING'"
		else
			writelog "INFO" "${FUNCNAME[0]} - Still could not find any paths from incoming GameScope arguments, assuming we don't have any paths in our arguments"
		fi
	fi
	IFS=$IFS_backup

	# Remove all text between single quotes -- We assume all text between single quotes in this context will be a GameScope path arg
	writelog "INFO" "${FUNCNAME[0]} - GameScope arg paths are '${GAMESCOPE_ARGPATHS[*]}'"
	# shellcheck disable=SC2001
	ARGSTRING="$( echo "$ARGSTRING" | sed "s:'[^']*':'':g" )"
	mapfile -d " " -t -O "${#GAMESCOPEARGSARR[@]}" GAMESCOPEARGSARR < <(printf '%s' "$ARGSTRING")

	INSERTARG=$((0))  # Which path arg to insert from the `GAMESCOPE_ARGPATHS` array
	GAMESCOPEARGSARR_COPY=("${GAMESCOPEARGSARR[@]}")
	for i in "${!GAMESCOPEARGSARR_COPY[@]}"; do
		if [[ "${GAMESCOPEARGSARR_COPY[i]}" == *"'"* ]]; then
			GAMESCOPEARGSARR_COPY[i]="${GAMESCOPE_ARGPATHS[${INSERTARG}]}"
			INSERTARG=$((INSERTARG + 1))
		fi
	done

	unset GAMESCOPEARGSARR  # Reset array and re-assign it to copied array with updated argument values
	GAMESCOPEARGSARR=("${GAMESCOPEARGSARR_COPY[@]}")

	# Ensure GameScope args always end with "--", otherwise GameScope will try to use everyting following it as a GameScope command and fail
	# With the GameScope GUI we add "--" to the end, but if the user manually updates their launch options, this will help prevent them from getting into a failed state
	if [ "${GAMESCOPEARGSARR[-1]}" != "--" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Last Gamescope argument is not '--' so manually appending this to the end of GAMESCOPESARGSARR"
		writelog "WARN" "${FUNCNAME[0]} - This is invalid syntax but manually fixing it"
		GAMESCOPEARGSARR+=("--")
	fi

	if [ "${#GAMESCOPEARGSARR[@]}" -ge 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using following gamescope arguments: '${GAMESCOPEARGSARR[*]}'"
	else
		writelog "INFO" "${FUNCNAME[0]} - gamescope doesn't have any command line arguments"
	fi
}


function gameArgs {
	ARGSTRING="$1"
	unset GAMEARGSARR

	if [ "$1" == "$GAMEARGS" ]; then
		if [ "$SORTGARGS" -eq 1 ]; then
			# add (originally "hardcoded", but now possibly modified) command line arguments coming directly from Steam/the game
			if [ "$HARDARGS" != "$NOPE" ] && [ "$HARDARGS" != "$NON" ]; then
				mapfile -d " " -t -O "${#GAMEARGSARR[@]}" GAMEARGSARR < <(printf '%s' "$HARDARGS")
			fi

			# now append those command line arguments coming from $SLO
			if [ "$SLOARGS" != "$NON" ]; then
				mapfile -d " " -t -O "${#GAMEARGSARR[@]}" GAMEARGSARR < <(printf '%s' "$SLOARGS")
			fi
		else
			if [ "${#ORGCMDARGS[@]}" -ge 1 ]; then
				GAMEARGSARR=("${ORGCMDARGS[@]}")
			fi
		fi
	fi

	# finally add the own custom command line arguments
	if [ "$1" != "$NON" ]; then
		mapfile -d " " -t -O "${#GAMEARGSARR[@]}" GAMEARGSARR < <(printf '%s' "$ARGSTRING")
	fi

	if [ "${#GAMEARGSARR[@]}" -ge 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Combined final game command line arguments: '${GAMEARGSARR[*]}'"
	else
		writelog "INFO" "${FUNCNAME[0]} - Game doesn't use any command line arguments"
	fi
}

function fixCustomMeta {
	if [ -f "$1" ] && grep -q "^GAMEDIR=" "$1"; then
		writelog "INFO" "${FUNCNAME[0]} - Renaming variable 'GAMEDIR' to 'MEGAMEDIR' in '$1', because 'GAMEDIR' also exists in the generic metadata, coming from steam" "E"
		sed "s:^GAMEDIR=:MEGAMEDIR=:" -i "$1"
	fi
}

function initPlay {
	# HAVESLR=0  # Previously enabled to force disable SLR from launch command, but now we can handle SLR from launch command and safely ignore it if not present
	## TODO: Are any of these other values still needed?
	HAVESLRCT=0
	HAVEREAP=0
	HAVESCTP=0
	INCOPATH=0
	STLPLAY=1

	function setHaveConfs {
		if [ -n "$HAVID" ]; then
			if [ -z "$HAVCUME" ]; then
				HAVCUME="$CUMETA/$HAVID.conf"
			fi

			if [ -z "$HAVGEME" ]; then
				HAVGEME="$GEMETA/$HAVID.conf"
			fi

			if [ -z "$HAVGACO" ]; then
				HAVGACO="$STLGAMEDIRID/$HAVID.conf"
			fi
		fi
	}

	function loadHaveConfs {
		if [ -f "$HAVGEME" ] && [ -z "$LOADEDHAVGEME" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Loading generic metadata found under '$HAVGEME'" "E"
			loadCfg "$HAVGEME"
			LOADEDHAVGEME=1
		fi

		if [ -f "$HAVCUME" ] && [ -z "$LOADEDHAVCUME" ]; then
			fixCustomMeta "$HAVCUME"
			writelog "INFO" "${FUNCNAME[0]} - Loading custom metadata found under '$HAVCUME'" "E"
			loadCfg "$HAVCUME"
			LOADEDHAVCUME=1
		fi

		if [ -f "$HAVGACO" ] && [ -z "$LOADEDHAVGACO" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Loading game config '$HAVGACO'" "E"
			loadCfg "$HAVGACO"
			LOADEDHAVGACO=1
		fi
	}

	function saveHaveCuMe {
		if [ -n "$HAVCUME" ] && [ ! -f "$HAVCUME" ]; then
			touch "$HAVCUME"
		fi

		if [ -n "$MEGAMEDIR" ]; then
			touch "$FUPDATE"
			updateConfigEntry "MEGAMEDIR" "$MEGAMEDIR" "$HAVCUME"
		fi
	}

	function saveHaveGeMe {
		if [ -n "$HAVGEME" ] && [ ! -f "$HAVGEME" ]; then
			touch "$HAVGEME"
		fi

		if [ -n "$HAVID" ]; then
			touch "$FUPDATE"
			updateConfigEntry "GAMEID" "$HAVID" "$HAVGEME"
		elif [ -n "$AID" ] && [ "$AID" != "$PLACEHOLDERAID" ]; then
			touch "$FUPDATE"
			updateConfigEntry "GAMEID" "$AID" "$HAVGEME"
		fi

		if [ -n "$EXECUTABLE" ]; then
			touch "$FUPDATE"
			updateConfigEntry "EXECUTABLE" "$EXECUTABLE" "$HAVGEME"
			if [ -z "$GAMEEXE" ]; then
				GAMEEXE="${EXECUTABLE//.exe}"
			fi
		fi

		if [ -n "$GE" ] && [ -z "$GAMEEXE" ]; then
			GAMEEXE="$GE"
		fi

		if [ -n "$GAMEEXE" ]; then
			touch "$FUPDATE"
			updateConfigEntry "GAMEEXE" "$GAMEEXE" "$HAVGEME"
		fi

		if [ -z "$GAMENAME" ]; then
			GAMENAME="${EXECUTABLE//.exe}"
		fi

		if [ -n "$GAMENAME" ]; then
			touch "$FUPDATE"
			updateConfigEntry "GAMENAME" "$GAMENAME" "$HAVGEME"
		fi

		if [ -z "$KEEPGAMENAME" ]; then
			KEEPGAMENAME=1
			touch "$FUPDATE"
			updateConfigEntry "KEEPGAMENAME" "$KEEPGAMENAME" "$HAVGEME"
		fi
	}

	if [ "$1" -eq "$1" ] 2>/dev/null; then
		writelog "INFO" "${FUNCNAME[0]} - Assuming incoming argument '$1' is a SteamAppId" "E"
		HAVID="$1"
	elif [ -f "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Assuming incoming argument '$1' is an absolute path to a game exe" "E"
		HAVPA="$1"
		INCOPATH=1
	else
		writelog "INFO" "${FUNCNAME[0]} - Assuming incoming argument '$1' is a game title" "E"
		HAVTI="$1"
	fi

	if [ -n "$HAVTI" ] || [ -n "$HAVID" ] && { [ -n "$2" ] && [ -f "$2" ];}; then
		HAVPA="$2"
	fi

	if [ -n "$HAVTI" ]; then
		CKHAVGEME="$(find "$TIGEMETA" -iname "$HAVTI.conf")"
		if [ -f "$CKHAVGEME" ]; then
			HAVGEME="$CKHAVGEME"
		fi

		CKHAVCUME="$(find "$TICUMETA" -iname "$HAVTI.conf")"
		if [ -f "$CKHAVCUME" ]; then
			HAVCUME="$CKHAVCUME"
		fi

		if [ -z "$HAVGEME" ]; then
			HAVGEMECFG="$(grep -Ri "NAME=\"$HAVTI" "$GEMETA/" | head -n1 | cut -d ':' -f1)"
			CKHAVGEME="$GEMETA/$HAVGEMECFG"
			if [ -f "$CKHAVGEME" ]; then
				HAVGEME="$CKHAVGEME"
			fi

			CKHAVCUME="$(find "$CUMETA" -iname "$HAVGEMECFG")"
			if [ -f "$CKHAVCUME" ]; then
				HAVCUME="$CKHAVCUME"
			fi
		fi
	fi

	setHaveConfs
	loadHaveConfs

	if [ -n "$GAMEID" ] && [ -z "$HAVID" ]; then
		HAVID="$GAMEID"
		writelog "INFO" "${FUNCNAME[0]} - Found SteamAppId '$HAVID'" "E"
	fi

	setHaveConfs
	loadHaveConfs

	if [ -z "$EXECUTABLE" ] && [ -f "$HAVPA" ]; then
		EXECUTABLE="${HAVPA##*/}"
	fi

	if [ -z "$EXECUTABLE" ] && [ -n "$GAMENAME" ]; then
		EXECUTABLE="$GAMENAME"
	fi

	if [ -z "$HAVPA" ] && [ -n "$MEGAMEDIR" ] && [ -n "$EXECUTABLE" ]; then
		CHKHAVPA="$MEGAMEDIR/$EXECUTABLE"
		if [ -f "$CHKHAVPA" ]; then
			HAVPA="$CHKHAVPA"
		fi
	fi

	if [ -n "$EXECUTABLE" ] && [ -n "$HAVPA" ] && [ "$EXECUTABLE" != "${HAVPA##*/}" ]; then
		EXECUTABLE="${HAVPA##*/}"
	fi

	if [ -n "$MEGAMEDIR" ]; then
		GFD="$MEGAMEDIR"
	fi

	if [ -z "$HAVID" ] &&  [ -z "$GAMEID" ] && [ -n "$HAVPA" ]; then
		HAVID="$(setGNID "${HAVPA##*/}")"
		if [ -z "$GFD" ]; then
			GFD="${HAVPA%/*}"
		fi
		if [ -z "$EFD" ]; then
			EFD="${HAVPA%/*}"
		fi
	fi

	if [ -n "$MEGAMEDIR" ] && [ -n "$HAVPA" ] && [ "$MEGAMEDIR" != "${HAVPA%/*}" ]; then
		MEGAMEDIR="${HAVPA%/*}"
	fi

	if [ -n "${HAVPA%/*}" ] && [ -z "$EFD" ]; then EFD="${HAVPA%/*}"; fi
	if [ -n "${HAVPA%/*}" ] && [ -z "$GFD" ]; then GFD="${HAVPA%/*}"; fi

	setHaveConfs
	loadHaveConfs

	if [ -n "$HAVID" ] &&  [ -z "$GAMEID" ] && { [ -z "$AID" ] || [ "$AID" == "$PLACEHOLDERAID" ];}; then
		writelog "INFO" "${FUNCNAME[0]} - Setting AID to '$HAVID'" "E"
		export AID="$HAVID"
	fi

	if [ -n "$GAMEID" ] && { [ -z "$AID" ] || [ "$AID" == "$PLACEHOLDERAID" ];}; then
		writelog "INFO" "${FUNCNAME[0]} - Setting AID to '$GAMEID'" "E"
		export AID="$GAMEID"
	fi
	saveHaveCuMe
	saveHaveGeMe
    # from here all required vars should be ready to launch
	if [ -n "$AID" ] && [ "$AID" != "$PLACEHOLDERAID" ]; then
		if [ -z "$HAVGACO" ]; then
			HAVGACO="$STLGAMEDIRID/$AID.conf"
		fi

		loadHaveConfs

		if [ -n "$GAMENAME" ] && [ "$GAMENAME" != "$NON" ]; then
			ICGN="$GAMENAME"
		elif [ -n "$GAMEEXE" ] && [ "$GAMEEXE" != "$NON" ]; then
			ICGN="$GAMEEXE"
		elif [ -n "$EXECUTABLE" ] && [ "$EXECUTABLE" != "$NON" ]; then
			ICGN="$GAMEEXE"
		else
			ICGN="$NON"
		fi

		createDesktopIconFile "$AID" "0" "$ICGN" "$HAVPA"

		if [ -f "$HAVPA" ]; then
			if [ -z "$GP" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Set 'GP' to '$HAVPA'" "E"
				GP="$HAVPA"
			else
				writelog "INFO" "${FUNCNAME[0]} - Already have 'GP' '$GP'" "E"
			fi

			if [ "$INCOPATH" -eq 1 ]; then
				while read -r INGARG; do
					mapfile -t -O "${#INGCMD[@]}" INGCMD <<< "$INGARG"
				done <<< "$(printf "%s\n" "$@")"

				FOUNDORGGCMD=0
				while read -r ORGARG; do
					if [ "$FOUNDORGGCMD" -eq 0 ]; then
						mapfile -t -O "${#ORGGCMD[@]}" ORGGCMD <<< "$ORGARG"
						if [[ "$ORGARG" =~ $GP ]]; then
							FOUNDORGGCMD=1
						fi
					else
						mapfile -t -O "${#ORGCMDARGS[@]}" ORGCMDARGS <<< "$ORGARG"
					fi
				done <<< "$(printf "%s\n" "${INGCMD[@]}")"
			else
				ORGGCMD=( "$HAVPA" )
			fi

			if [ -z "$GE" ] && [ -n "$HAVPA" ]; then
				GE="${HAVPA##*/}"
			fi

			if [ -z "$GP" ] && [ -n "$HAVPA" ]; then
				GP="$HAVPA"
			fi

			if [ -z "$GN" ] && [ -n "$HAVPA" ]; then
				GN="${HAVPA##*/}"
			fi

			writelog "INFO" "${FUNCNAME[0]} - Game executable used is '$HAVPA'" "E"

			if grep -q "shell script" <<< "$(file "$(realpath "$HAVPA")")" || grep -q "ELF.*.LSB" <<< "$(file "$(realpath "$HAVPA")")" ; then
				writelog "INFO" "${FUNCNAME[0]} - Assuming this is a linux binary" "E"
				ISGAME=3
				GPFX="$NON"
				cd "$MEGAMEDIR" || return
				prepareLaunch
				cd - || return
			else
				writelog "INFO" "${FUNCNAME[0]} - Assuming this is a windows binary" "E"

				if [ -z "$STEAM_COMPAT_INSTALL_PATH" ]; then
					if [ -n "$MEGAMEDIR" ]; then
						export STEAM_COMPAT_INSTALL_PATH="$MEGAMEDIR"
					elif [ -n "$EFD" ]; then
						export STEAM_COMPAT_INSTALL_PATH="$EFD"
					else
						writelog "INFO" "${FUNCNAME[0]} - STEAM_COMPAT_INSTALL_PATH (game dir) is unknown - setting it at least to '${STLDLDIR}'"
						export STEAM_COMPAT_INSTALL_PATH="$STLDLDIR"
					fi
				fi

				if [ -z "$STL_COMPAT_DATA_PATH" ]; then
					STL_COMPAT_DATA_PATH="$STLCOMPDAT/$AID"
				fi

				if [ -n "$STL_COMPAT_DATA_PATH" ]; then
					mkProjDir "$STL_COMPAT_DATA_PATH"
					writelog "INFO" "${FUNCNAME[0]} - Using '$STL_COMPAT_DATA_PATH' as STEAM_COMPAT_DATA_PATH" "E"
					export STEAM_COMPAT_DATA_PATH="$STL_COMPAT_DATA_PATH"
					export GPFX="${STL_COMPAT_DATA_PATH}/pfx"
					ISGAME=2
					cd "$STEAM_COMPAT_INSTALL_PATH" || return
					prepareLaunch
					cd - || return
				else
					writelog "ERROR" "${FUNCNAME[0]} - STEAM_COMPAT_DATA_PATH was not defined"
				fi
			fi
		fi
	else
		writelog "ERROR" "${FUNCNAME[0]} - Could not determine an AppID - can't continue" "E"
	fi
}

function standaloneGames {
	if [ -d "$GEMETA" ]; then
		while read -r line; do
			if [ -n "$1" ] && [ "$1" == "l" ]; then
				SAG="$(grep "^GAMENAME=" "$line" | cut -d '=' -f2)"
				if [ -n "$SAG" ]; then
					echo "${SAG//\"/}"
				fi
			elif [ -n "$1" ] && [ "$1" == "g" ]; then
				unset GAMENAME EXECUTABLE GAMEID
				loadCfg "$line"
				if [ -n "$GAMEID" ] && [ -n "$EXECUTABLE" ]; then
					echo "FALSE"

					if [ -n "$GAMENAME" ]; then
						echo "$GAMENAME"
					else
						echo "$EXECUTABLE"
					fi

					echo "$EXECUTABLE"
					echo "$GAMEID"
				else
					writelog "SKIP" "${FUNCNAME[0]} - Skipping config '$line', because at least one of GAMEID:'$GAMEID' EXECUTABLE:'$EXECUTABLE', GAMENAME:'$GAMENAME' is empty"
				fi
			else
				echo "$line"
			fi
		done <<< "$(find "$GEMETA" -name "${GETSTAID}.conf")"
	else
		writelog "ERROR" "${FUNCNAME[0]} - Directory GEMETA '$GEMETA' could not be found" "E"
 	fi
}

function standaloneDefGameIcon {
	if [ -x "$(command -v "$CONVERT" 2>/dev/null)" ]; then
		"$CONVERT" "$STLICON" -resize "128x128!" "$WANTGPNG"
	else
		cp "$STLICON" "$WANTGPNG"
	fi
}

function standaloneGameIcon {
	WANTGPNG="$1"
	AID="$2"
	GAMENAME="$3"
	HAVEPA="$4"
	if [ -f "$WANTGPNG" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Already have an icon: '$WANTGPNG'"
	else
		writelog "SKIP" "${FUNCNAME[0]} - Trying to find an icon for '$GAMENAME'"
		if grep -q "shell script" <<< "$(file "$(realpath "$HAVPA")")" || grep -q "ELF.*.LSB" <<< "$(file "$(realpath "$HAVPA")")" ; then
			# yes, quick&dirty!
			SYSICN="$(cut -d '=' -f2 <<< "$(grep "^Icon=" "$(find "/usr/share/applications/" -name "${HAVPA##*/}*.desktop" | head -n1)")")"
			if [ -n "$SYSICN" ]; then
				SYSICF="$(find "/usr/share/icons/" -name "${SYSICN}.png" | sort -nr | head -n1)"
				if [ -f "$SYSICF" ]; then
					if [ -x "$(command -v "$CONVERT" 2>/dev/null)" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Creating a '$SYSICF' copy with fix size 128x128 at '$WANTGPNG'"
						"$CONVERT" "$SYSICF" -resize "128x128!" "$WANTGPNG"
					else
						writelog "INFO" "${FUNCNAME[0]} - Copying '$SYSICF' to '$WANTGPNG'"
						cp "$SYSICF" "$WANTGPNG"
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - Did not find a default icon for '$GAMENAME' using '$STLICON' as default for '$WANTGPNG'"
					standaloneDefGameIcon
				fi
			fi
		else
			PEVDSTI="$STLGPEVKD/$PERES/id/$AID"

			if [ -x "$(command -v "$PERES")" ] && { [ ! -d "$PEVDSTI" ] || [ "$(find "$PEVDSTI" -type f | wc -l)" -eq 0 ];}; then
				mkProjDir "$PEVDSTI"
				writelog "INFO" "${FUNCNAME[0]} - extracting data from '${HAVEPA##*/}' using '$PERES' to '$PEVDSTI'"
				cd "$PEVDSTI" >/dev/null || return
				notiShow "$(strFix "$NOTY_ANALYZE" "$HAVEPA" "$PERES")"
				"$PERES" -x "$HAVEPA" &
				cd - >/dev/null || return
			fi

			PRI="$PEVDSTI/resources/icons"
			if [ ! -d "$PRI" ]; then
				writelog "INFO" "${FUNCNAME[0]} - directory for alternative icon location not found - using '$STLICON' as default for '$WANTGPNG'"
				standaloneDefGameIcon
			else
				FIRSTICO="$(find "$PRI" -type f -name "*.ico" -printf "%s %p\n" | sort -nr | head -n1 | cut -d ' ' -f2)"
				if [ -f "$FIRSTICO" ]; then
					if [ -x "$(command -v "$CONVERT" 2>/dev/null)" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Converting '$FIRSTICO', extracted from '${HAVEPA##*/}' to '$WANTGPNG'"
						"$CONVERT" "$FIRSTICO" -resize "128x128!" "$WANTGPNG"
					else
						writelog "INFO" "${FUNCNAME[0]} - Could not convert '$FIRSTICO', because '$CONVERT' was not found - using '$STLICON' as default for '$WANTGPNG'"
						cp "$STLICON" "$WANTGPNG"
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - Could not extract icon from '${HAVEPA##*/}' - using '$STLICON' as default for '$WANTGPNG'"
					standaloneDefGameIcon
				fi
			fi
		fi
	fi
}

function standaloneDesktopFile {
	INTDTFILE="$1"
	WANTGPNG="$2"
	AID="$3"
	GAMENAME="$4"

	if [ -f "$INTDTFILE" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - $INTDTFILE already exists"
	else
		if [ -n "$GAMENAME" ] && [ "$GAMENAME" != "$NON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Creating '$INTDTFILE' for '$GAMENAME'"
			{
				echo "[Desktop Entry]"
				echo "Name=${GAMENAME//\"/}"
				echo "Comment=$(strFix "$DF_SLCOMMENT" "${GAMENAME//\"/}" "$PROGNAME")"
				if [ "$INFLATPAK" -eq 1 ]; then
					echo "Exec=/usr/bin/flatpak run --command=tinkergame $FLATPAK_ID play $AID"
				else
					echo "Exec=$(realpath "$0") play $AID"
				fi
				echo "Icon=$WANTGPNG"
				echo "Terminal=false"
				echo "Type=Application"
				echo "Categories=Game;"
			} >> "$INTDTFILE"
		fi
	fi
}

function standaloneLaunch {
	setShowPic
	STLA="Standalone-Launcher"
	export CURWIKI="$PPW/$STLA"
	TITLE="${PROGNAME}-$STLA"
	pollWinRes "$TITLE"
	if [ -d "$STLISLDFD" ] && [ "$(find "$STLISLDFD" -name "*.desktop" | wc -l)" -ge 1 ]; then
		"$YAD" --f1-action="$F1ACTION" --icons --window-icon="$STLICON" --read-dir="$STLISLDFD" "${WINDECO[@]}" --title="$TITLE" --single-click --keep-icon-size --center --compact --sort-by-name "$GEOM"
	else
		writelog "SKIP" "${FUNCNAME[0]} - No games found in '$STLISLDFD' or directory itself not found"
	fi
}

function standaloneEd {
	if [ -z "$1" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Need a valid AppID or title for an installed standalone program" "E"
	else
		if [ "$1" -eq "$1" ] 2>/dev/null; then
			AID="$1"
			HAVID="$AID"
		else
			if [ -d "$STLISLDFD" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Looking for AppID for title '$1'" "E"
				TSTAID="$(grep "^Name=$1$" -h -A5 -R "$STLISLDFD" | grep -m1 "Exec=" | grep -o "$GETSTAID")"
				if [ -n "$TSTAID" ] && [ "$TSTAID" -eq "$TSTAID" ] 2>/dev/null; then
					AID="$TSTAID"
					HAVID="$AID"
				fi
			else
				writelog "ERROR" "${FUNCNAME[0]} - directory '$STLISLDFD' missing - can't search for '$1'" "E"
			fi
		fi

		if [ -n "$AID" ] && [ "$AID" != "$PLACEHOLDERAID" ]; then

			unset MEGAMEDIR GAMENAME KEEPGAMENAME STL_COMPAT_DATA_PATH
			writelog "INFO" "${FUNCNAME[0]} - Looking for configs for AppID '$AID'" "E"
			HAVGEME="$GEMETA/${AID}.conf"
			if [ -f "$HAVGEME" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Loading found config '$HAVGEME'" "E"
				loadCfg "$HAVGEME"
			fi

			HAVCUME="$CUMETA/${AID}.conf"
			if [ -f "$HAVCUME" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Loading found config '$HAVCUME'" "E"
				loadCfg "$HAVCUME"
			fi

			WANTGPNG="$STLGPNG/${AID}.png"
			CPICKPROG="$MEGAMEDIR/$EXECUTABLE"

			STED="Standalone-Editor"
			STLA="Standalone-Launcher"
			export CURWIKI="$PPW/$STLA"
			TITLE="${PROGNAME}-$STED"
			pollWinRes "$TITLE"

			NEWSTDAT="$("$YAD" --f1-action="$F1ACTION" --image "$WANTGPNG" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
			--title="$TITLE" --separator="|" \
			--text="$STED" \
			--field=" ":LBL " " \
			--field="     $GUI_PICKPROG!$DESC_PICKPROG":FL "$CPICKPROG" \
			--field="     $GUI_GAMENAME!$DESC_GAMENAME" "${GAMENAME/#-/ -}" \
			--field="     $GUI_KEEPGAMENAME!$DESC_KEEPGAMENAME":CHK "${KEEPGAMENAME/#-/ -}" \
			--field="     $GUI_STL_COMPAT_DATA_PATH!$DESC_STL_COMPAT_DATA_PATH":DIR "${STL_COMPAT_DATA_PATH/#-/ -}" \
			--field="     $GUI_PICKICON!$DESC_PICKICON":FL "${WANTGPNG/#-/ -}" \
			--button="$BUT_DONE":0 --button="$BUT_CAN":2  "$GEOM")"
			case $? in
			0)  {
					writelog "INFO" "${FUNCNAME[0]} - Selected $BUT_DONE"
					unset NSTARR
					mapfile -d "|" -t -O "${#NSTARR[@]}" NSTARR < <(printf '%s' "$NEWSTDAT")
					NPICKPROG="${NSTARR[1]}"
					NGAMENAME="${NSTARR[2]}"
					NKEEPGAMENAME="${NSTARR[3]}"
					NSTL_COMPAT_DATA_PATH="${NSTARR[4]}"
					NPICKICON="${NSTARR[5]}"

					NEWIC=0

					if [ "$NPICKPROG" != "$CPICKPROG" ]; then
						NMEGAMEDIR="${NPICKPROG%/*}"
						NEXECUTABLE="${NPICKPROG##*/}"

						if [ "$NMEGAMEDIR" != "$MEGAMEDIR" ]; then
							touch "$FUPDATE"
							updateConfigEntry "MEGAMEDIR" "$NMEGAMEDIR" "$HAVCUME"
							NEWIC=1
						fi
						if [ "$NEXECUTABLE" != "$EXECUTABLE" ]; then
							touch "$FUPDATE"
							updateConfigEntry "EXECUTABLE" "$NEXECUTABLE" "$HAVGEME"
							NEWIC=1
						fi
					fi

					if [ "$NGAMENAME" != "$GAMENAME" ]; then
						touch "$FUPDATE"
						updateConfigEntry "GAMENAME" "$NGAMENAME" "$HAVGEME"
						NEWIC=1
					fi

					updateConfigEntry "KEEPGAMENAME" "$NKEEPGAMENAME" "$HAVGEME"

					if [ "$NSTL_COMPAT_DATA_PATH" != "$STL_COMPAT_DATA_PATH" ]; then
						touch "$FUPDATE"
						updateConfigEntry "STL_COMPAT_DATA_PATH" "$NSTL_COMPAT_DATA_PATH" "$HAVGEME"
						NEWIC=1
					fi

					if [ "$NPICKICON" != "$WANTGPNG" ]; then
						if [ -x "$(command -v "$CONVERT" 2>/dev/null)" ]; then
							"$CONVERT" "$NPICKICON" -resize "128x128!" "$WANTGPNG"
						else
							cp "$NPICKICON" "$WANTGPNG"
						fi
						NEWIC=1
					fi

					if [ "$NEWIC" -eq 1 ]; then
						loadCfg "$HAVGEME"
						loadCfg "$HAVCUME"
						WANTGPNG="$STLGPNG/${AID}.png"
						HAVEPA="$MEGAMEDIR/$EXECUTABLE"
						INTDTFILE="$STLISLDFD/$AID.desktop"
						rm "$INTDTFILE"
						standaloneDesktopFile "$INTDTFILE" "$WANTGPNG" "$AID" "$GAMENAME" "$HAVEPA"
					fi
				}
			;;
			2) 	{
					writelog "INFO" "${FUNCNAME[0]} - Selected $BUT_CAN"

				}
			;;
			esac
		else
			writelog "ERROR" "${FUNCNAME[0]} - No data found for '$1'" "E"
		fi
	fi
}

function createDLWineList {
	writelog "INFO" "${FUNCNAME[0]} - Generating list of online available Wine archives"
	WINEDLLIST="$STLSHM/WineDL.txt"
	MAXAGE=360

	if [ ! -f "$WINEDLLIST" ] || test "$(find "$WINEDLLIST" -mmin +"$MAXAGE")"; then
		rm "$WINEDLLIST" 2>/dev/null
		while read -r CWURL; do
		if grep -q "$GHURL" <<< "${!CWURL}"; then
			SRCURL="${!CWURL}"
			SRCURL="${SRCURL//\/releases}"
			SRCURL="${SRCURL//$GHURL/$AGHURL\/repos}"
			SRCURL="${SRCURL}/releases"
			"$WGET" -q "$SRCURL" -O - | "$JQ" -r '.[].assets[].browser_download_url' | grep "tar.gz\|tar.xz" >>  "$WINEDLLIST"
		fi
		done <<< "$(grep "^CW_" "$STLURLCFG" | cut -d '=' -f1)"
	fi

	unset WineDLList
	unset WineDLDispList
	while read -r CWVERS; do
		mapfile -t -O "${#WineDLList[@]}" WineDLList <<< "$CWVERS"
		mapfile -t -O "${#WineDLDispList[@]}" WineDLDispList <<< "${CWVERS##*/}"
	done < "$WINEDLLIST"
}

function dlWineGUI {
	createDLWineList

	writelog "INFO" "${FUNCNAME[0]} - Opening dialog to choose a download"

	DLWINELIST="$(printf "!%s\n" "${WineDLDispList[@]//\"/}" | tr -d '\n' | sed "s:^!::" | sed "s:!$::")"
	export CURWIKI="$PPW/Download-Custom-Wine"
	TITLE="${PROGNAME}-DownloadWine"
	pollWinRes "$TITLE"

	if [ -z "$DLWINE" ]; then
		DLWINE="${WineDLDispList[0]}"
	fi

	if [ -z "$DLWINELIST" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Empty download list - is '$JQ' installed and are we online?"
		notiShow "$GUI_EMPTYDLIST" "X"
	fi

	DLDISPWINE="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
	--title="$TITLE" \
	--text="$(spanFont "$GUI_DLWINETEXT" "H")" \
	--field=" ":LBL " " \
	--field="$GUI_DLWINETEXT2!$GUI_DLWINETEXT":CBE "$(cleanDropDown "${DLWINE/#-/ -}" "$DLWINELIST")" \
	"$GEOM")"

	if [ -n "${DLDISPWINE//|/\"}" ]; then
		if grep -q "^http" <<< "${DLDISPWINE//|/\"}"; then  #"
			DLURL="${DLDISPWINE//|/\"}"
			writelog "INFO" "${FUNCNAME[0]} - The URL '$DLURL' was entered manually - downloading directly"
		else
			DLWINEVERSION="${DLDISPWINE//|/}"
			DLURL="$(printf "%s\n" "${WineDLList[@]}" | grep -m1 "${DLDISPWINE//|}")"
			writelog "INFO" "${FUNCNAME[0]} - '${DLDISPWINE//|}' was selected - downloading '$DLURL'"
		fi
		StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "Wine")" "dlWine ${DLURL//|/\"}" "DownloadWineStatus"
	fi
}

# TODO currently unused:
function PickSpecificWine {
	export CURWIKI="$PPW/Download-Custom-Wine"
	TITLE="${PROGNAME}-${FUNCNAME[0]}"
	pollWinRes "$TITLE"

	SPECWINE="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
	--title="$TITLE" --separator="|" \
	--text="$(spanFont "$GUI_DLSPECWINE" "H")" \
	--field=" ":LBL " " \
	--field="Vanilla":CHK "TRUE" \
	--field="Staging":CHK "TRUE" \
	--field="Proton":CHK "TRUE" \
	--field="TkG":CHK "TRUE" \
	--field=" ":LBL " " \
	--field="x86":CHK "TRUE" \
	--field="amd64":CHK "TRUE" \
	"$GEOM")"

	unset SWINSEL
	mapfile -d "|" -t -O "${#SWINSEL[@]}" SWINSEL < <(printf '%s' "$SPECWINE")
	WANTVAN="${SWINSEL[1]}"
	WANTSTA="${SWINSEL[2]}"
	WANTPRO="${SWINSEL[3]}"
	WANTTKG="${SWINSEL[4]}"
	WANTX86="${SWINSEL[6]}"
	WANTA64="${SWINSEL[7]}"

	if [ "$WANTVAN" == "TRUE" ]; then
		GWI="[0-9]-[x,a]"
		GWO="$NON"
	else
		GWO="[0-9]-[x,a]"
		GWI="releases"
	fi

	if [ "$WANTSTA" == "TRUE" ]; then
		GWI="${GWI}\|staging"
	else
		GWO="${GWO}\|staging"
	fi

	if [ "$WANTPRO" == "TRUE" ]; then
		GWI="${GWI}\|proton"
	else
		GWO="${GWO}\|proton"
	fi

	if [ "$WANTTKG" == "TRUE" ]; then
		GWI="${GWI}\|tkg"
	else
		GWO="${GWO}\|tkg"
	fi

	if [ "$WANTX86" == "TRUE" ]; then
		GWI="${GWI}\|x86"
	else
		GWO="${GWO}\|x86"
	fi

	if [ "$WANTA64" == "TRUE" ]; then
		GWI="${GWI}\|amd64"
	else
		GWO="${GWO}\|amd64"
	fi
}

function dlWine {
	WURL="${1//\"/}"
	WURLFILE="${WURL##*/}"
	DSTDL="$WINEDLDIR/$WURLFILE"
	if [ ! -f "$DSTDL" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Downloading '$WURL' to '$WINEDLDIR'"
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$WURL")" "S"
		dlCheck "$WURL" "$DSTDL" "X" "Downloading '$WURLFILE'"
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$WURL")" "S"
	else
		writelog "INFO" "${FUNCNAME[0]} - File '$DSTDL' already exists - nothing to download"
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON4" "${WURL##*/}")" "S"
	fi
	extractWine "$DSTDL"
}

function dlWineGate {
	if [ -z "$1" ]; then
		dlWineGUI
	else
		if grep -q "^http" <<< "$1"; then
			writelog "INFO" "${FUNCNAME[0]} - '$1' is an URL - sending directly to dlWine"
			StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "Wine")" "dlWine $*" "DownloadWineStatus"
		elif [ "$1" == "latest" ] || [ "$1" == "l" ]; then
			createDLWineList
			writelog "INFO" "${FUNCNAME[0]} - Downloading latest custom Wine ${WineDLList[0]//\"/}" "E"
			StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "Wine")" "dlWine ${WineDLList[0]//\"/}" "DownloadWineStatus"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Don't know what to do with argument '$1'"
		fi
	fi
}

function extractWine {
	if [ -f "$1" ]; then
		WURLFILE="${1##*/}"
		WDIRRAW="${WURLFILE//wine-/}"
		WDIR="${WDIRRAW//.tar.xz}"

		if [ -d "$WINEEXTDIR/$WDIR" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Directory '$WINEEXTDIR/$WDIR' already exists - nothing to extract"
		else
			writelog "INFO" "${FUNCNAME[0]} - Extracting archive '$WURLFILE' to '$WINEEXTDIR'"
			notiShow "$(strFix "$NOTY_DLCUSTOMPROTON3" "$1")" "S"
			"$TAR" xf "$1" -C "$WINEEXTDIR" 2>/dev/null
			notiShow "$GUI_DONE" "S"
		fi
	fi
}

function WineSelection {
	setShowPic
	export CURWIKI="$PPW/Wine-Support"
	TITLE="${PROGNAME}-ChooseWine"
	pollWinRes "$TITLE"

	writelog "INFO" "${FUNCNAME[0]} - Opening Wine Selection"

	 "$YAD" --image "$SHOWPIC" "${YADIMGTOP[@]}" --center --window-icon="$STLICON" --form "${WINDECO[@]}" \
	--title="$TITLE" \
	--text="$(spanFont "$GUI_SELWINE" "H")" \
	--button="$BUT_DLDWINE":0 \
	--button="$BUT_SELWINE":2 \
	"$GEOM"

	case $? in
	0)  {
			writelog "INFO" "${FUNCNAME[0]} - Selected Wine Download"
			dlWineGUI
			if [ "$DLWINEVERSION" != "$NON" ]; then
				WINEVERSION="${DLWINEVERSION//|/}"
				writelog "INFO" "${FUNCNAME[0]} - Chose downloaded '$WINEVERSION'"
			fi
		}
	;;
	2) 	{
			writelog "INFO" "${FUNCNAME[0]} - Selected Ready Wine"
			createWineList
			export CURWIKI="$PPW/Wine-Support"
			TITLE="${PROGNAME}-SelectedWine"
			pollWinRes "$TITLE"
			WINSEL="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
			--title="$TITLE" \
			--text="$(spanFont "$GUI_SELIWINE" "H")" \
			--field=" ":LBL " " \
			--field="     $GUI_WINEVERSION!$DESC_WINEVERSION ('WINEVERSION')":CBE "$(cleanDropDown "${WINEVERSION/#-/ -}" "$WINEYADLIST")" \
			"$GEOM")"
			WINEVERSION="${WINSEL//|/}"
			writelog "INFO" "${FUNCNAME[0]} - Chose available '$WINEVERSION'"
		}
	;;
	esac

	writelog "INFO" "${FUNCNAME[0]} - Saving selected wine version '$WINEVERSION' into $STLGAMECFG"
	touch "$FUPDATE"
	updateConfigEntry "WINEVERSION" "$WINEVERSION" "$STLGAMECFG"

	if [ -n "$2" ]; then
		setWineVersion "$AID" "${FUNCNAME[0]}"
	fi
}

function setWineVersion {
	if [ "$USEWINE" -eq 1 ] && [ "$ISGAME" -eq 2 ]; then
		if [[ "$WINEVERSION" =~ ${DUMMYBIN}$ ]] || [ "$WINEVERSION" == "$NON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - No current wine version configured yet"
			if [[ ! "$WINEDEFAULT" =~ ${DUMMYBIN}$ ]] && [ "$WINEDEFAULT" != "$NON" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Default wine version set to '$WINEDEFAULT' - using that as current wine"
				WINEVERSION="$WINEDEFAULT"
			else
				writelog "INFO" "${FUNCNAME[0]} - No current wine version configured and no default one set, so opening a requester"
				WineSelection "$AID" "${FUNCNAME[0]}"
				writelog "INFO" "${FUNCNAME[0]} - Chose '$WINEVERSION' via requester"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Using current wine version '$WINEVERSION'"
		fi

		WINEVERSION="${WINEVERSION%%.tar*}"

		if [ ! -d "$WINEEXTDIR/${WINEVERSION}" ]; then

			if ! grep -q "$WINEVERSION" "$WINEDLLIST"; then
				writelog "ERROR" "${FUNCNAME[0]} - Failed to set wineversion to something usable: '$WINEVERSION' - giving up"
				closeSTL " ######### STOP EARLY '$PROGNAME $PROGVERS' #########"
				exit
			else
				writelog "INFO" "${FUNCNAME[0]} - Configured wine version '$WINEVERSION' is not installed yet, but was found detected as downloadable - trying to install it automatically"
				DLURL="$(grep "$WINEVERSION" "$WINEDLLIST" | head -n1)"
				writelog "INFO" "${FUNCNAME[0]} - Downloading '$WINEVERSION' from '$DLURL'"
				StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "Wine")" "dlWine ${DLURL//|/\"}" "DownloadWineStatus"
				if [ -d "$WINEEXTDIR/$WINEVERSION" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Downloading and extracting '$WINEVERSION' was successful"
				else
					writelog "ERROR" "${FUNCNAME[0]} - Downloading and extracting '$WINEVERSION' failed - giving up"
					closeSTL " ######### STOP EARLY '$PROGNAME $PROGVERS' #########"
					exit
				fi
			fi
		fi
	fi
	RUNWINEVERSION="$WINEVERSION"
	writelog "INFO" "${FUNCNAME[0]} - Selected wine version is '$RUNWINEVERSION'"
}

function createWineList {
	writelog "INFO" "${FUNCNAME[0]} - Updating the Wine Dropdown List"
	WINEYADLIST="$(printf "!%s\n" "$(find "$WINEEXTDIR" -mindepth 1 -maxdepth 1 -type d -printf '%P!')" | tr -d '\n' | sed "s:^!::" | sed "s:!$::")"
}

function setWineVars {
	WINEVERSION="${WINEVERSION%%.tar*}"

	if [ "$USEWINE" -eq 1 ] && [ "$ISGAME" -eq 2 ] && { [ -z "$RUNWINEVERSION" ] || [ "$RUNWINEVERSION" != "$WINEVERSION" ];}; then
		writelog "INFO" "${FUNCNAME[0]} - USEWINE is enabled. Creating some wine related variables"

		if [ -n "$RUNWINEVERSION" ] && [[ "$WINEVERSION" =~ ${DUMMYBIN}$ ]]; then
			WINEVERSION="$RUNWINEVERSION"
		else
			createDLWineList
		fi

		setWineVersion

		USEWINEBIN="$WINEEXTDIR/${WINEVERSION}/bin"
		writelog "INFO" "${FUNCNAME[0]} - Setting wine bin dir to '$USEWINEBIN'"

		RUNWINE="$USEWINEBIN/wine"
		writelog "INFO" "${FUNCNAME[0]} - Setting wine binary to '$RUNWINE'"

		RUNWINECFG="$USEWINEBIN/$WINECFG"
		writelog "INFO" "${FUNCNAME[0]} - Setting $WINECFG binary to '$RUNWINECFG'"

		RUNREGEDIT="$USEWINEBIN/regedit"
		writelog "INFO" "${FUNCNAME[0]} - Setting regedit binary to '$RUNREGEDIT'"

		RUNWICO="$USEWINEBIN/$WICO"
		writelog "INFO" "${FUNCNAME[0]} - Setting $WICO binary to '$RUNWICO'"

		if [ -n "$ARCHALTEXE" ] && [[ ! "$ARCHALTEXE" =~ ${DUMMYBIN}$ ]]; then
			CHARCH="$ARCHALTEXE"
		else
			CHARCH="$GP"
		fi

		if [ "$(getArch "$CHARCH")" == "32" ]; then
			RUNWINEARCH=win32
		else
			RUNWINEARCH=win64
		fi

		writelog "INFO" "${FUNCNAME[0]} - Game binary '${CHARCH##*/}' is $(getArch "$CHARCH")-bit so creating '$RUNWINEARCH' WINEPREFIX"
		GWFX="${GPFX//pfx/wfx}"
		writelog "INFO" "${FUNCNAME[0]} - Using WINEPREFIX '$GWFX'"
	fi
}

# Get path to 'require_tool_appid' specified in toolmanifest.vdf
function getRequireToolAppidPath {
	COMPATTOOLPATH="$1"

	if [ -d "$COMPATTOOLPATH" ]; then
		TOMAPATH="${COMPATTOOLPATH}/$TOMA"
		if [ -f "$TOMAPATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found tool manifest at '$TOMAPATH', attempting to get 'require_tool_appid' value..."

			REQUIRETOOLAID="$( getValueFromAppManifest "require_tool_appid" "$TOMAPATH" )"  # toolmanifest.vdf and some other files have identical structures to AppManifest files, so this works :-)
			if [ -n "$REQUIRETOOLAID" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Got 'require_tool_appid' from '$TOMAPATH' ('$REQUIRETOOLAID') - Returning path to tool"

				getGameDir "$REQUIRETOOLAID" "X"
			else
				writelog "INFO" "${FUNCNAME[0]} - Could not get 'require_tool_appid' from existing file '$TOMAPATH' - Assuming the key was not present"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Could not get Steam Linux Runtime, could not find tool manifest at '$TOMAPATH'"
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - Could not find directory for specified compat tool '$COMPATTOOLPATH'"
	fi
}

# Function to get SLR to append to game/program launch
# Primarily used to set SLRCMD so it can be appended, but also sets the reaper command
# TODO: refactor to use early returns and less indentation where possible
function setSLRReap {
	# This function has gotten a bit messy with all the override options, but these are used to allow setSLRReap to be re-used outside of regular game launches such as for Vortex.

	# These variables are only passed for Non-Game SLR launches i.e. Vortex, they are ignored for game launches and use fallback values
	OVERRIDESLR="$1"  # Always get SLR, ignoring other vars that specify otherwise
	SLRFORCETYPE="${2:-0}"  # Force fetch the Proton SLR (1), or native SLR (2), ignoring value of ISGAME
	SLRPROTONVER="$3"  # Proton version to fetch the SLR version from (where to find the toolmanifest.vdf from) -- Optional, will fall back to RUNPROTON set by game

	# Allow overriding USESLR/HAVESLR and forcing to fetch the SLR anyway (used for times when SLR is needed outside of regular game launch e.g. Vortex)
	if [ -n "$OVERRIDESLR" ]; then
		writelog "INFO" "${FUNCNAME[0]} - OVERRIDESLR is enabled, ignoring user settings and fetching SLR anyway"
	fi

	# Set the Proton path to look for the toolmanifest.vdf file in for game launches we want RUNPROTON, but for non-game SLR cases we want to set a custom Proton path without overriding RUNPROTON which could interfere with subsequent game launches)
	if [ -z "$SLRPROTONVER" ]; then
		writelog "INFO" "${FUNCNAME[0]} - SLRPROTONVER is not defined, this is fine as regular game launches don't pass this"

		writelog "INFO" "${FUNCNAME[0]} - Falling back to RUNPROTON which is '$RUNPROTON'"
		SLRPROTONVER="${RUNPROTON}"
	fi

	# USESLR tells whether the user has chosen to get the SLR, HAVESLR refers to the legacy check for the SLR passed from the compat tool/Steam launch command
	if [[ ( -n "$USESLR" && -n "$HAVESLR" ) || -n "$OVERRIDESLR" ]]; then
		# SLR fetching from Steam start command
		# --------------
		# Sometimes the SLR comes from the compatibility tool (hence SLRCT, SLR Compat Tool) -- This only happens with Proton <= 4.11, and more critically, with games that are using
		# a Steam Linux Runtime compatibility tool. Some games, like CS2, have an SLR forced by Valve Testing and this cannot be disabled by the user
		#
		# In this case, we want to take the SLR given to us by the compatibility tool and use that
		# HAVESLRCT=1 will only be true if the SLR is coming from the compatibility tool
		if [ "$HAVESLRCT" -eq 1 ] && [ "$USESLR" -eq 1 ] && [ "$IGNORECOMPATSLR" -eq 0 ]; then
			writelog "INFO" "${FUNCNAME[0]} - ## SLR is enabled via USESLR=$USESLR - prepending SLR from Compatibility Tool to the current launch command"
			writelog "INFO" "${FUNCNAME[0]} - ## This can happen if a game is running with a Steam Linux Runtime compatibility tool enabled"
			SLRCMD=("${RUNSLRCT[@]}")
			writelog "INFO" "${FUNCNAME[0]} - RUNSLRCT is '${RUNSLRCT[*]}'"
		# This is very, very legacy and will likely never happen again
		# While the above case covers games that get their SLR from the compatibility tool (only old Proton versions, and any native game using SLR 1.0 or 3.0),
		# this case covers *regular native games* that pass the SLR in their start command, which should not happen anymore
		#
		# The reason we use an 'elif' is because games should only meet one of these conditions:
		# - SLR comes from the selected compatibility tool (e.g. if a user selects SLR 1.0 for a native game, or if one is selected for them)
		# - SLR comes from the game start command even if no compat tool is used (should not happen anymore, legacy Steam behaviour)
		# - SLR is not given to us *at all*, so we use the SLR fetching below
		elif [ "$HAVESLR" -eq 1 ] && [ "$USESLR" -eq 1 ] && [ "$IGNORECOMPATSLR" -eq 0 ]; then
			writelog "INFO" "${FUNCNAME[0]} - ## SLR is enabled via USESLR=$USESLR - prepending SLR from command line to the current launch command"
			writelog "INFO" "${FUNCNAME[0]} - RUNSLR is '${RUNSLR[*]}'"
			SLRCMD=("${RUNSLR[@]}")
		# If the user enables "IGNORECOMPATSLR", disable HAVESLR so that the below logic for Pressure Vessel Funtime will kick in and fetch the SLR manually
		# HAVESLR controls whether we Have an SLR coming from the incoming command line options, which is nowadays only really the case for native titles with a Compat Tool forced/selected by Valve Testing
		elif [ "$HAVESLRCT" -eq 1 ] && [ "$USESLR" -eq 1 ] && [ "$IGNORECOMPATSLR" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - ## SLR was found in incoming Start Command, likely from a compatibility tool, but 'IGNORECOMPATSLR' is '${IGNORECOMPATSLR}'"
			writelog "INFO" "${FUNCNAME[0]} - ## Ignoring this incoming SLR from the selected Steam Linux Runtime Compatibility Tool and instead letting TinkerGame find the Steam Linux Runtime instead"
			writelog "WARN" "${FUNCNAME[0]} - ## Note that some games require a specific Steam Linux Runtime version, and if a given Steam Linux Runtime version that TinkerGame looks for is not found, or if the version found does not match what a game might require, launching may fail"

			HAVESLR=0
		fi

		# Legacy case to ignore SLR gotten from commandline
		if [ "$HAVESLR" -eq 1 ] && [ "$USESLR" -eq 0 ] ; then
			writelog "SKIP" "${FUNCNAME[0]} - USESLR is disabled, so skipping '$SLR' found in the commandline: '${RUNSLR[*]}'"
		fi
		# --------------

		# SLR fetching (from toolmanifest.vdf / native Linux SLR AppID)
		# ---------------
		# TODO This could probably be refactored to have less indentation and return early...
		RUNFORCESLR=0
		if [[ ( "$HAVESLR" -eq 0 && "$USESLR" -eq 1 ) || -n "$OVERRIDESLR" ]]; then
			if [ -n "$LASTSLR" ] && [ -f "${LASTSLR% --verb*}" ] && [ "$FORCESLR" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - ## No SLR provided from command line, but FORCESLR is $FORCESLR, so prepending LASTSLR '$LASTSLR' to the current launch command"
				mapfile -d " " -t -O "${#LASTSLRARR[@]}" LASTSLRARR < <(printf '%s' "$LASTSLR")
				SLRCMD=("${LASTSLRARR[@]}")
				RUNFORCESLR=1
			else
				# Steam usually does not pass the SLR in the start command anymore, and gets it from the `toolmanifest.vdf` with the `"require_tool_appid": "<app_id>"` for Proton games
				# For native games, on Steam Deck it seems Valve enforce the regular Steam Linux Runtime, so we have separate logic for fetching that
				writelog "INFO" "${FUNCNAME[0]} - No SLR provided from command line, attempting to fetch required SLR from current compatibility tool's '$TOMA'"

				SLR_PATH=""
				SLRENTRYPOINT=""
				SLRVERB=""
				PROTON_SLRCMD=("")
				NATIVE_SLRCMD=("")

				# Pressure Vessel Funtime 2nd Edition Ver. 2.31
				writelog "INFO" "${FUNCNAME[0]} - Now executing Pressure Vessel Funtime 2nd Edition Ver. 2.31"
				# Get SLR Paths
				# Use native SLR: if ( ( game is native AND NOT forcing Proton ) OR forcing native )
				if [[ ( "$ISGAME" -eq 3 && "$SLRFORCETYPE" -eq 0 ) || "$SLRFORCETYPE" -eq 2 ]]; then
					# Native games already have a hardcoded initial native SLR AppID, so we can get the path from this hardcoded AppID
					# However they need to get the required "nested" SLR from the toolmanifest from the hardcoded native SLR - This is the SLR that the regular native SLR runs inside of
					# This nested AppID is stored in the hardcoded SLR's toolmanifest
					writelog "INFO" "${FUNCNAME[0]} - Looks like we have a native Linux game here - Checking for plain SLR (AppID '$SLRAID')"
					REQUIRED_APPID="$SLRAID"  # AppID of native SLR

					NATIVE_SLR_PATH="$( getGameDir "$REQUIRED_APPID" "X" )"  # Native SLR
					if [ -d "$NATIVE_SLR_PATH" ]; then
						SLR_PATH="$( getRequireToolAppidPath "$NATIVE_SLR_PATH" )"  # Nested SLR path for native SLR to run inside of
						writelog "INFO" "${FUNCNAME[0]} - Nested Steam Linux Runtime for native game seems to be '$SLR_PATH'"
						NATIVE_SLR_ENTRYPOINT="${NATIVE_SLR_PATH}/scout-on-soldier-entry-point-v2"
						NATIVE_SLRCMD=("$NATIVE_SLR_ENTRYPOINT" "--")  # Extra part to pass for native CMD which needs to be appended to regular SLRCMD
					else
						writelog "WARN" "${FUNCNAME[0]} - Could not find Steam Linux Runtime with AppID '$SLRAID' for native Linux game - This will need to be installed manually!"
					fi
				else
					SLR_PATH="$( getRequireToolAppidPath "$( dirname "$SLRPROTONVER" )" )"  # Path to SLR based on AppID in Proton's `toolmanifest.vdf`
				fi

				# Build SLRCMD
				if [ -d "$SLR_PATH" ]; then
					writelog "INFO" "${FUNCNAME[0]} - '$SLR_PATH' exists - Path gotten from specified AppID looks valid"
					SLRENTRYPOINT="${SLR_PATH}/_v2-entry-point"
					SLRVERB="--verb=$WFEAR"
					PROTON_SLRCMD=("$SLRENTRYPOINT" "$SLRVERB" "--")
				else
					writelog "WARN" "${FUNCNAME[0]} - Could not get path to Steam Linux Runtime - This will need to be installed manually!"
					writelog "WARN" "${FUNCNAME[0]} - Ignoring USESLR option since valid Steam Linux Runtime could not be found"
				fi

				# Passing even a blank `NATIVE_SLRCMD[@]` prevents games from launching, so we need this check
				if [ -n "${NATIVE_SLRCMD[*]}" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Building Steam Linux Runtime command for native game"
					SLRCMD=("${PROTON_SLRCMD[@]}" "${NATIVE_SLRCMD[@]}")  # Not really "Proton" for native games, but naming is hard
				elif [ -n "${PROTON_SLRCMD[*]}" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Building Steam Linux Runtime command for Proton game"
					SLRCMD=("${PROTON_SLRCMD[@]}")
				else
					if [ "${REQUIRED_APPID}" = "${SLRAID}" ]; then  # Assume native when REQUIRED_APPID is set to the native Linux SLRAID
						writelog "WARN" "${FUNCNAME[0]} - No native linux Steam Linux Runtime found, game will not use Steam Linux Runtime"
					else  # If not native, can only be Proton
						writelog "WARN" "${FUNCNAME[0]} - No Proton Steam Linux Runtime found, game will not use Steam Linux Runtime"
					fi
				fi
			fi
		fi
		# ---------------

		# Set Reaper command (currently no way to toggle this if we call setSLRReap for non-game launches, doesn't seem to have any negative impact though?)
		# ---------------
		if [ "$HAVEREAP" -eq 1 ] && [ "$USEREAP" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - ## reaper command is enabled via USEREAP=$USEREAP - prepending to the current launch command"
			SLRCMD=("${REAPCMD[@]}" "${SLRCMD[@]}")
		elif [ "$HAVEREAP" -eq 0 ] && [ "$USEREAP" -eq 1 ] && [ -n "$LASTREAP" ] && [ -f "$LASTREAP" ] && [ "$FORCEREAP" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - ## No reaper command provided from command line, but FORCEREAP is $FORCEREAP, so prepending LASTREAP '$LASTREAP' to the current launch command"
			SLRCMD=("$LASTREAP" "SteamLaunch" "AppId=$AID" "--" "${SLRCMD[@]}")
		fi
		# ---------------

		# Reaper is started *by Steam now for Proton games* after a game launch (i.e. after %command% but *not* before) so if reaper is disabled we have to check for and kill it
		# Doesn't apply to native games because we use 'tinkergame %command%', and reaper is started as part of '%command%'.
		if [ "$USEREAP" -eq 0 ]; then
			if "$PGREP" -x "reaper"; then
				writelog "INFO" "${FUNCNAME[0]} - USEREAP is '$USEREAP' and found reaper process, killing it!"
				"$PKILL" -9 "reaper"
			fi
		fi

		if [ -n "${SLRCMD[*]}" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Adding SLR '${SLRCMD[*]}' to the launch command"
		else
			if [ "$USESLR" -eq 1 ]; then
				notiShow "$NOTY_SLRMISSING" "X"
			else
				writelog "INFO" "${FUNCNAME[0]} - SLRCMD is not defined, but USESLR is disabled, so this should be safe to ignore"
			fi
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - USESLR and HAVESLR not defined -- Probably shouldn't happen?"
	fi
}

function fetchGameSLRGui {
	if [ "$ISGAME" -eq 3 ]; then
		commandlineFetchGameSLR "$1" "1" "1"  # Native Linux SLR
	else
		commandlineFetchGameSLR "$1" "0" "1"  # Proton SLR
	fi
}

## Fetch the AppID required by a game's selected Proton version, and prompt Steam to install it with steam://install/<appid>
function commandlineFetchGameSLR {
	FUSEID "$1"
	USENATIVE="$2"  # We could pass this from the UI if we know we have a native game (ISGAME -eq 3)
	SLRDISPLAYNOTIFIER="${3:-0}"

	if [ "$USENATIVE" -eq 1 ]; then  # Get native Linux SLR
		# Check if SLR is already installed
		EXISTINGSLRPATH="$( getGameDir "$SLRAID" "only" )"
		if [ -d "$EXISTINGSLRPATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Required Steam Linux Runtime ('$SLRAID') is already installed at '$EXISTINGSLRPATH' -- Nothing to do."
			echo "Required Steam Linux Runtime ('$SLRAID') is already installed at '$EXISTINGSLRPATH' -- Nothing to do."
			if [ "$SLRDISPLAYNOTIFIER" -eq 1 ]; then
				notiShow "$NOTY_INSTALLSLR_ALREADYEXISTS"
			fi

			return
		fi

		SLRINSTALLCMD="steam steam://install/$SLRAID"
		writelog "INFO" "${FUNCNAME[0]} - Installing Steam Linux Runtime for Native Linux games"
		echo "Installing Steam Linux Runtime for Native Linux games"

		eval "$SLRINSTALLCMD"
		echo "Continue installation of tool from Steam install dialog."

		if [ "$SLRDISPLAYNOTIFIER" -eq 1 ]; then
			notiShow "$NOTY_INSTALLSLR_DONE"
		fi
	elif [ -f "$STLGAMECFG" ] && [ -n "$USEPROTON" ]; then  # If this is a game launched before with STL, get the Steam Linux Runtime for it
		PROTPATH="$( dirname "$( getProtPathFromCSV "$USEPROTON" )" )"

		# Very similar to logic in getRequireToolAppidPath
		TOMAPATH="${PROTPATH}/$TOMA"
		if [ -f "$TOMAPATH" ]; then
			SLRID="$( getValueFromAppManifest "require_tool_appid" "$TOMAPATH" )"
			if [ -n "$SLRID" ]; then
				# Check if SLR is already installed
				EXISTINGSLRPATH="$( getGameDir "$SLRID" "only" )"
				if [ -d "$EXISTINGSLRPATH" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Required Steam Linux Runtime ('$SLRID') is already installed at '$EXISTINGSLRPATH' -- Nothing to do."
					echo "Required Steam Linux Runtime ('$SLRID') is already installed at '$EXISTINGSLRPATH' -- Nothing to do."

					if [ "$SLRDISPLAYNOTIFIER" -eq 1 ]; then
						notiShow "$NOTY_INSTALLSLR_ALREADYEXISTS"
					fi

					return
				fi

				SLRINSTALLCMD="steam steam://install/$SLRID"
				writelog "INFO" "${FUNCNAME[0]} - Game Proton version '$USEPROTON' expects Steam Linux Runtime with AppID '$SLRID' - Requesting it from Steam..."
				echo "Game Proton version '$USEPROTON' expects Steam Linux Runtime with AppID '$SLRID' - Requesting it from Steam..."

				eval "$SLRINSTALLCMD"
				echo "Continue installation of tool from Steam install dialog."

				if [ "$SLRDISPLAYNOTIFIER" -eq 1 ]; then
					notiShow "$NOTY_INSTALLSLR_DONE"
				fi
			else  # No require_tool_appid set in toolmanifest.vdf
				writelog "ERROR" "${FUNCNAME[0]} - require_tool_appid was not defined ('$SLRID') -- Maybe no Steam Linux Runtime is required for this Proton version?"
				echo "require_tool_appid was not defined ('$SLRID') -- Maybe no Steam Linux Runtime is required for this Proton version?"

				if [ "$SLRDISPLAYNOTIFIER" -eq 1 ]; then
					notiShow "$NOTY_INSTALLSLR_NOREQUIRETOOLAPPID"
				fi
			fi
		else  # No toolmanifest.vdf set at all
			writelog "ERROR" "${FUNCNAME[0]} - Could not find $TOMA for Proton version '$USEPROTON' at path '$PROTPATH'"
			echo "Could not find $TOMA for Proton version '$USEPROTON' at path '$PROTPATH'"

			if [ "$SLRDISPLAYNOTIFIER" -eq 1 ]; then
				notiShow "$NOTY_INSTALLSLR_NOTOOLMANIFEST"
			fi
		fi
	else  # Not a valid game used with STL before
		writelog "ERROR" "${FUNCNAME[0]} - Could not find STLGAMECFG ('$STLGAMECFG') or USEPROTON ('$USEPROTON') for AppID '$AID'"
		echo "Could not find STLGAMECFG ('$STLGAMECFG') or USEPROTON ('$USEPROTON') for AppID '$AID'"

		if [ "$SLRDISPLAYNOTIFIER" -eq 1 ]; then
			notiShow "$NOTY_INSTALLSLR_INVALIDGAME"
		fi
	fi
}

function setBoxtronCmd {
	DOSEXE="$GP"
	if [ -x "$(command -v "$BOXTRONCMD" 2>/dev/null)" ]; then
		notiShow "$(strFix "$NOTY_BOXTRON" "$GN" "$AID")"
		# disable CHANGE_PULSE_LATENCY else audio gets stuck
		CHANGE_PULSE_LATENCY="0"
		EXTSTARTCMD=("$BOXTRONCMD" "$BOXTRONARGS" "$DOSEXE")
		writelog "INFO" "${FUNCNAME[0]} - Starting game '$SGNAID' with boxtron"
	else
		writelog "ERROR" "${FUNCNAME[0]} - boxtron command '$BOXTRONCMD' not found - exit"
		exit
	fi
}

function setRobertaCmd {
	VMEXE="$GP"
	if [ -x "$(command -v "$ROBERTACMD" 2>/dev/null)" ]; then
		EXTSTARTCMD=("$ROBERTACMD" "$ROBERTAARGS" "$VMEXE")
		writelog "INFO" "${FUNCNAME[0]} - Starting game '$AID' with roberta"
		notiShow "$(strFix "$NOTY_ROBERTA" "$GN" "$AID")"
	else
		writelog "ERROR" "${FUNCNAME[0]} - roberta command '$ROBERTACMD' not found - exit"
		exit
	fi
}

function setLuxtorpedaCmd {
	LUXEXE="$GP"
	if [ -x "$(command -v "$LUXTORPEDACMD" 2>/dev/null)" ]; then
		if [ "$USESLR" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using ${LUXTORPEDACMD^} (Runtime)"
			LUMADO="manual-download"
			LUXTORPEDAARGS="runtime_$LUXTORPEDAARGS"
		else
			LUMADO="manual-download"
		fi
		# skip download if engine_choice.txt exists already:
		if [ ! -f "$HOME"/.config/luxtorpeda/"$AID"/engine_choice.txt ]; then
			writelog "INFO" "${FUNCNAME[0]} - Downloading native game data for '$AID' with luxtorpeda: '$LUXTORPEDACMD' '$LUMADO' $AID"
			notiShow "$(strFix "$NOTY_LUXTORPEDA1" "$GN" "$AID")"
			"$LUXTORPEDACMD" "$LUMADO" "$AID"
		fi
		notiShow "$(strFix "$NOTY_LUXTORPEDA2" "$GN" "$AID")"
		EXTSTARTCMD=("$LUXTORPEDACMD" "$LUXTORPEDAARGS" "$LUXEXE")
		writelog "INFO" "${FUNCNAME[0]} - Starting game '$AID' with luxtorpeda"
	else
		writelog "ERROR" "${FUNCNAME[0]} - luxtorpeda command '$LUXTORPEDACMD' not found - exit"
		exit
	fi
}

function setLinuxCmd {
	# maybe limit this to custom linux commands
	if [ "${GAMESTARTCMD[0]}" == "$WFEAR" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Removing '$WFEAR' from '${GAMESTARTCMD[*]}'"
		GAMESTARTCMD=( "${GAMESTARTCMD[@]:1}" )
		writelog "INFO" "${FUNCNAME[0]} - Result is '${GAMESTARTCMD[*]}'"
	fi

	# start with gamemoderun:
	if [ "$USEGAMEMODERUN" -eq 1 ]; then
		if [ "$USEGAMESCOPE" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Starting native game '$SGNAID' with '$GAMEMODERUN' and '$GAMESCOPE'"
			notiShow "$(strFix "$NOTY_STARTNATGAMOSC" "$GN" "$AID")"
			gameScopeArgs "$GAMESCOPE_ARGS"
		else
			writelog "INFO" "${FUNCNAME[0]} - Starting native game '$SGNAID' with '$GAMEMODERUN' - ${GAMESTARTCMD[*]}"
			notiShow "$(strFix "$NOTY_STARTNATGAMO" "$GN" "$AID")"
		fi
	# start with gamescope:
	elif [ "$USEGAMESCOPE" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Starting native game '$SGNAID' with $GAMESCOPE arguments '$GAMESCOPE_ARGS'"
		notiShow "$(strFix "$NOTY_STARTNATGAMSCO" "$GN" "$AID")"
		gameScopeArgs "$GAMESCOPE_ARGS"
	# regular start:
	else
		writelog "INFO" "${FUNCNAME[0]} - Starting native game '$SGNAID'"
		notiShow "$(strFix "$NOTY_STARTNAT" "$GN" "$AID")"
	fi
}

function setWineCmd {
	function startWineGame {
		writelog "INFO" "${FUNCNAME[0]} - Starting game '$GN' ($AID)' using Wine"
		extWine64Run "$@" "$RUNWINE" "${FINGAMECMD[*]}" &> "$WINE_LOG_DIR/${AID}.log"
		WINEPID="$!"
	}

	writelog "INFO" "${FUNCNAME[0]} - Using Wine instead of Proton"
	setWineVars

	RUNGAMECMD="${GAMESTARTCMD[*]}"
	RAWGAMECMD="${RUNGAMECMD#*waitforexitandrun }"
	mapfile -d " " -t -O "${#FINGAMECMD[@]}" FINGAMECMD < <(printf '%s' "$RAWGAMECMD")

	writelog "INFO" "${FUNCNAME[0]} - Starting game $GN with '$("$RUNWINE" --version)' and waiting for its PID to exit"

	# start with gamemoderun:
	if [ "$USEGAMEMODERUN" -eq 1 ]; then
		if [ "$USEGAMESCOPE" -eq 1 ]; then
			gameScopeArgs "$GAMESCOPE_ARGS"
			notiShow "$(strFix "$NOTY_STARTPROTGAMOSC" "$RUNWINEVERSION" "$GN" "$AID")"
			startWineGame "$GMR" "$GSC" "${GAMESCOPEARGSARR[@]}"
			writelog "INFO" "${FUNCNAME[0]} - Started game $GN via wine using '$GAMEMODERUN' and '$GAMESCOPE' with PID '$WINEPID'"
		else
			notiShow "$(strFix "$NOTY_STARTPROTGAMO" "$RUNWINEVERSION" "$GN" "$AID")"
			startWineGame "$GMR"
			writelog "INFO" "${FUNCNAME[0]} - Started game $GN via wine using '$GAMEMODERUN' with PID '$WINEPID'"
		fi
	# start with gamescope:
	elif [ "$USEGAMESCOPE" -eq 1 ]; then
		gameScopeArgs "$GAMESCOPE_ARGS"
		notiShow "$(strFix "$NOTY_STARTPROTGAMSCO" "$RUNWINEVERSION" "$GN" "$AID")"
		startWineGame "$GSC" "${GAMESCOPEARGSARR[@]}"
		writelog "INFO" "${FUNCNAME[0]} - Started game $GN via wine using '$GAMESCOPE' with PID '$WINEPID'"
	# regular start:
	else
		notiShow "$(strFix "$NOTY_STARTPROT" "$RUNWINEVERSION" "$GN" "$AID")"
		startWineGame
		writelog "INFO" "${FUNCNAME[0]} - Started game $GN via wine with PID '$WINEPID'"
	fi

	wait "$WINEPID"
	writelog "INFO" "${FUNCNAME[0]} - game PID '$WINEPID' exited..."
}

function setProtonCmd {
	# proton variants start here:
	if [ "$RUN_GDB" -eq 1 ]; then
		GDBGAMESTARTCMD=("${ORGGCMD[@]}" "${GAMEARGSARR[@]}")
	elif [ "$HAVEINPROTON" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Not overriding Proton and using Proton provided by steam commandline '${INPROTCMD[*]}'"
		PROTSTARTCMD=("${INPROTCMD[@]}" "$WFEAR")
	else
		writelog "INFO" "${FUNCNAME[0]} - Proton override enabled, so checking if it needs updated"

		if [ -z "$USEPROTON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - No current Proton found"
			if [ "$AUTOLASTPROTON" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Automatically selecting newest official one"
				setNOP
			fi
		fi


		setRunProtonFromUseProton # the last chance to set the Proton version before starting the game
		delPrefix # remove prefix if requested
		fixSymlinks # fixing outdated symlinks if requested
		unSymlink  # and/or unsymlink any proton symlink found

		if [ "$HAVEINPROTON" -eq 1 ] && [ "${INPROTCMD[*]}" == "$RUNPROTON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Command line proton '${INPROTCMD[*]}' is identical to RUNPROTON '$RUNPROTON' - nothing to change"
			PROTSTARTCMD=("${INPROTCMD[@]}" "$WFEAR")
		else
			if [ ! -f "${RUNPROTON//\"/}" ]; then
				writelog "WARN" "${FUNCNAME[0]} - '$USEPROTON' seems outdated as the executable ${RUNPROTON//\"/} wasn't found"
				fixProtonVersionMismatch "USEPROTON" "$STLGAMECFG"
			fi

			if [ "${GAMESTARTCMD[0]}" == "$WFEAR" ]; then
				unset "GAMESTARTCMD[0]"  # removing first ORGGCMD element as it is '$WFEAR'
			fi

			if [ -f "${RUNPROTON//\"/}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Prepending Proton '$USEPROTON' (='${RUNPROTON//\"/}') to the command line '${GAMESTARTCMD[*]}'"
				PROTSTARTCMD=("${RUNPROTON//\"/}" "$WFEAR")
			else
				writelog "INFO" "${FUNCNAME[0]} - Still don't have a usable proton executable in RUNPROTON '{RUNPROTON//\"/}')"
				if [ "$HAVEINPROTON" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - Overriding Proton provided by steam commandline '${INPROTCMD[*]}' from command line with '$USEPROTON' (='${RUNPROTON//\"/}')"
					PROTSTARTCMD=("${INPROTCMD[@]}" "$WFEAR")
				else
					writelog "ERROR" "${FUNCNAME[0]} - Could not find any usable proton version - this will likely crash - please open an issue on '$PROJECTPAGE' with this log"
				fi
			fi
			writelog "INFO" "${FUNCNAME[0]} - UPDATED game start command is: ${GAMESTARTCMD[*]}"
		fi

		if [ "$USERAYTRACING" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Raytracing is enabled with the variable 'USERAYTRACING' - exporting 'VKD3D_CONFIG=dxr11' and appending '-dx12' to the game command line parameters"
			export VKD3D_CONFIG=dxr11
			GAMEARGSARR=("${GAMEARGSARR[@]}" "-dx12")
		fi
	fi

	# set the definitive used versions, which are also stored into writeLastRun
	PROTONVERSION="$(setProtonPathVersion "$RUNPROTON")"

	# start with x64dbg:
	if [ "$RUN_X64DBG" -eq 1 ]; then
		checkX64dbgLaunch "${GAMESTARTCMD[@]}"
	elif [ "$RUN_GDB" -eq 1 ]; then
		if [ -f "$(command -v "$USETERM")" ]; then
			prepareGdb
			injectGdb &
			writelog "INFO" "${FUNCNAME[0]} - Starting '$SGNAID' using '$GDBGAMERUN' and attaching gdb to the running process"
			writelog "WARN" "${FUNCNAME[0]} - This function might not always work as expected - not sure yet if it is worth to maintain"
			notiShow "$(strFix "$NOTY_STARTPROTGDB" "$PROTONVERSION" "$GN" "$AID")"
			"$GDBGAMERUN"
		else
			writelog "ERROR" "${FUNCNAME[0]} - '$GDB' was enabled, but configured terminal '$USETERM' was not found"
		fi
	elif [ "$RUN_DEPS" -eq 1 ]; then
		checkDepsLaunch "${GAMESTARTCMD[@]}"
	# start with gamemoderun:
	elif [ "$USEGAMEMODERUN" -eq 1 ]; then
		if [ "$USEGAMESCOPE" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Starting '$SGNAID' with Proton: '$PROTONVERSION' with '$GAMEMODERUN' and '$GAMESCOPE'"
			gameScopeArgs "$GAMESCOPE_ARGS"
			notiShow "$(strFix "$NOTY_STARTPROTGAMOSC" "$PROTONVERSION" "$GN" "$AID")"
		else
			writelog "INFO" "${FUNCNAME[0]} - Starting '$SGNAID' with Proton: '$PROTONVERSION' with '$GAMEMODERUN'"
			notiShow "$(strFix "$NOTY_STARTPROTGAMO" "$PROTONVERSION" "$GN" "$AID")"
		fi
	# start with gamescope:
	elif [ "$USEGAMESCOPE" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Starting '$SGNAID' with Proton: '$PROTONVERSION' with $GAMESCOPE arguments '$GAMESCOPE_ARGS'"
		notiShow "$(strFix "$NOTY_STARTPROTGAMSCO" "$PROTONVERSION" "$GN" "$AID")"
		gameScopeArgs "$GAMESCOPE_ARGS"
	# regular start:
	else
		writelog "INFO" "${FUNCNAME[0]} - Starting '$SGNAID' with Proton: '$PROTONVERSION'"
		notiShow "$(strFix "$NOTY_STARTPROT" "$PROTONVERSION" "$GN" "$AID")"
	fi
}

function launchSteamGame {
	steamdeckBeforeGame

	setCommandLaunchVars  # Re-usable function for Steam games and custom program launches

	writelog "INFO" "${FUNCNAME[0]} - Initial game command is '${INGCMD[*]}'"

	# Refetch SLR, in case we set it for custom command as well
	# i.e. custom command could use native SLR, but we might want to use Proton SLR for the game, or vice versa
	unset "${SLRCMD[@]}"
	setSLRReap

	if [ "$USEBOXTRON" -eq 1 ] || [ "$USEROBERTA" -eq 1 ] || [ "$USELUXTORPEDA" -eq 1 ]; then
		ISGAME=3
	fi

	# game start command for both proton and linux native games:
	if [ "$USEBOXTRON" -eq 0 ] && [ "$USEROBERTA" -eq 0 ] && [ "$USELUXTORPEDA" -eq 0 ]; then
		# the actual game launch:
		gameArgs "$GAMEARGS"
		GAMESTARTCMD=("${ORGGCMD[@]}")
	fi

	# first start with non-proton games here:
	if [ "$ISGAME" -eq 3 ]; then
		if [ "$USEBOXTRON" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Preparing boxtron command"
			setBoxtronCmd
		elif [ "$USEROBERTA" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Preparing roberta command"
			setRobertaCmd
		elif [ "$USELUXTORPEDA" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Preparing luxtorpeda command"
			setLuxtorpedaCmd
		else
			writelog "INFO" "${FUNCNAME[0]} - Preparing linux native game command"
			setLinuxCmd
		fi

	# now games using proton or wine:
	elif [ "$ISGAME" -eq 2 ]; then
		if [ "$USEWINE" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Preparing wine command"
			setWineCmd
		else
			writelog "INFO" "${FUNCNAME[0]} - Preparing proton command"
			setProtonCmd
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - With ISGAME '$ISGAME' the game failed to start"
	fi

	# X64DBG_ATTACHONSTARTUP controls launching the game if x64dbg and this are enabled together, similar to ONLY_CUSTOMCMD, so don't do Steam game launch and exit function
	if [ "$RUN_X64DBG" -eq 1 ] && [ "$X64DBG_ATTACHONSTARTUP" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - RUN_X64DBG and X64DBG_ATTACHONSTARTUP were both enabled, this means x64dbg managed running the game process, so we don't have to -- Aborting Steam game launch"
		return
	fi

	if [ "$USEWINE" -eq 0 ]; then
		# concatenate final game start command

		buildCustomCmdLaunch

		FINALSTARTCMD=( "${FINALOUTCMD[@]}" )  # Use FINALOUTCMD from buildCustomCmdLaunch

		if [ -n "${SLRCMD[0]}" ]; then
			if [ -n "${FINALSTARTCMD[0]}" ]; then
				FINALSTARTCMD=("${FINALSTARTCMD[@]}" "${SLRCMD[@]}")
			else
				FINALSTARTCMD=("${SLRCMD[@]}")
			fi
		fi

		if [ -n "${EXTSTARTCMD[0]}" ]; then
			if [ -n "${FINALSTARTCMD[0]}" ]; then
				FINALSTARTCMD=("${FINALSTARTCMD[@]}" "${EXTSTARTCMD[@]}")
			else
				FINALSTARTCMD=("${EXTSTARTCMD[@]}")
			fi
		else
			if [ -n "${PROTSTARTCMD[0]}" ]; then
				if [ -n "${FINALSTARTCMD[0]}" ]; then
					FINALSTARTCMD=("${FINALSTARTCMD[@]}" "${PROTSTARTCMD[@]}")
				else
					FINALSTARTCMD=("${PROTSTARTCMD[@]}")
				fi
			fi

			if [ -n "${GAMESTARTCMD[0]}" ]; then
				if [ -n "${FINALSTARTCMD[0]}" ]; then
					FINALSTARTCMD=("${FINALSTARTCMD[@]}" "${GAMESTARTCMD[@]}")
				else
					FINALSTARTCMD=("${GAMESTARTCMD[@]}")
				fi
			fi

			if [ -n "${GAMEARGSARR[0]}" ]; then
				if [ -n "${FINALSTARTCMD[0]}" ]; then
					FINALSTARTCMD=("${FINALSTARTCMD[@]}" "${GAMEARGSARR[@]}")
				else
					FINALSTARTCMD=("${GAMEARGSARR[@]}")
				fi
			fi
		fi

		if [ "$STARTDEBUG" -eq 1 ]; then
			{
				echo "$(date) - $GN ($AID) - ======================"
				echo "GMR $GMR"
				echo "GSC $GSC"
				echo "SLRCMD '${SLRCMD[*]}'"
				echo "PROTSTARTCMD '${PROTSTARTCMD[*]}'"
				echo "GAMESTARTCMD '${GAMESTARTCMD[*]}'"
				echo "GAMEARGSARR '${GAMEARGSARR[*]}'"
				echo "-----------"
				echo "I '${INGCMD[*]}'"
				echo "X '${FINALSTARTCMD[*]}'"
				echo "$(date) - $GN ($AID) - ======================"
				if [ "$HAVESCTP" -eq 0 ] && [ "$HAVEREAP" -eq 0 ]; then
					echo "$(date) - $GN ($AID) - HAVESCTP='$HAVESCTP', and HAVEREAP='$HAVEREAP' - assuming ${PROGNAME,,} is used as compat tool - using regular base game command to continue"
				elif [ "$HAVESCTP" -eq 0 ] && [ "$HAVEREAP" -eq 1 ]; then
					echo "$(date) - $GN ($AID) - HAVESCTP='$HAVESCTP', but also HAVEREAP='$HAVEREAP' - assuming ${PROGNAME,,} is set to both command and compat tool (or compat tool is empty) - steam doesn't provide STEAM_COMPAT_TOOL_PATHS, so have to cut out the reaper line to continue; HAVESLR='$HAVESLR'"
				elif [ "$HAVESCTP" -eq 1 ] && [ "$HAVEREAP" -eq 1 ]; then
					echo "$(date) - $GN ($AID) - HAVESCTP='$HAVESCTP', and HAVEREAP='$HAVEREAP' - assuming $PROGCMD is used as command line tool - switching proton version is disabled"
				elif [ "$HAVESCTP" -eq 1 ] && [ "$HAVEREAP" -eq 0 ]; then
					echo "$(date) - $GN ($AID) - HAVESCTP='$HAVESCTP', but also HAVEREAP='$HAVEREAP' - something went wrong - never seen this in the wild"
				fi
				echo "$(date) - $GN ($AID) - ======================"
				echo "$(date) - $GN ($AID) - INITIAL LAUNCH COMAND '${INGCMD[*]}'"
				echo "$(date) - $GN ($AID) - HAVESCTP='$HAVESCTP';HAVEREAP='$HAVEREAP';HAVESLR='$HAVESLR';HAVESLRCT='$HAVESLRCT';HAVEINPROTON='$HAVEINPROTON'"
				echo "$(date) - $GN ($AID) - REAPCMD '${REAPCMD[*]}'"
				echo "$(date) - $GN ($AID) - RUNSLR '${RUNSLR[*]}'"
				echo "$(date) - $GN ($AID) - RUNSLRCT '${RUNSLRCT[*]}'"
				echo "$(date) - $GN ($AID) - ISGAME '$ISGAME'"
				echo "$(date) - $GN ($AID) - INPROTCMD '${INPROTCMD[*]}'"
				echo "$(date) - $GN ($AID) - INSTLCMD '${INSTLCMD[*]}'"
				echo "$(date) - $GN ($AID) - ORGGCMD '${ORGGCMD[*]}'"
				echo "$(date) - $GN ($AID) - ORG_STEAM_COMPAT_TOOL_PATHS '${ORG_STEAM_COMPAT_TOOL_PATHS[*]}'"
				echo "$(date) - $GN ($AID) - USEREAP='$USEREAP'; USESLR=$USESLR'"
				echo "$(date) - $GN ($AID) - FINAL LAUNCH RUNCMD '${RUNCMD[*]}'"
				echo "$(date) - $GN ($AID) - FINALSTARTCMD '${FINALSTARTCMD[*]}'"
				echo "$(date) - $GN ($AID) - ======================"
			} >> "$STLSHM/${PROGNAME,,}-${FUNCNAME[0]}-STARTDEBUG.txt"
		fi

		# might be also useful for starting custom commands generally
		if [ "$USECUSTOMCMD" -eq 1 ] && [ "$FORK_CUSTOMCMD" -eq 1 ] && [ "$ONLY_CUSTOMCMD" -eq 0 ] && [ "$WAITFORCUSTOMCMD" -ge 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - WAITFORCUSTOMCMD is enabled, so replacing $WFEAR with 'run' in'${FINALSTARTCMD[*]}'"
			for i in "${!FINALSTARTCMD[@]}"; do
				if [[ ${FINALSTARTCMD[$i]} == "$WFEAR" ]]; then
					FINALSTARTCMD[i]="run"
				fi
			done
		fi

		writelog "INFO" "${FUNCNAME[0]} - Original incoming start command: '${INGCMD[*]}'"
		writelog "INFO" "${FUNCNAME[0]} - Final outgoing start command: '${FINALSTARTCMD[*]}'"

		startGame "${FINALSTARTCMD[@]}"

		writelog "STOP" "######### $PROGNAME $PROGVERS #########"
	fi
}

### CORE LAUNCH END ###

### COMMAND LINE START ###

