#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function resetAID {
	if [ -n "$1" ]; then
		if [ -n "${1##*[!0-9]*}" ]; then
			AID="$1"
		else
			if [ "$1" == "last" ]; then
				if [ -f "$LASTRUN" ]; then
					PREVAID="$(grep "^PREVAID" "$LASTRUN" | cut -d '=' -f2)"
					if [ -n "$PREVAID" ]; then
						AID="${PREVAID//\"}"
						PREVGAME="$(grep "^PREVGAME" "$LASTRUN" | cut -d '=' -f2)"
						if [ -n "$PREVGAME" ]; then
							GN="${PREVGAME//\"}"
						fi
					fi
				else
					AID="$PLACEHOLDERAID"
				fi
			fi
		fi
	fi
	# should not happen, but just in case it is still empty, set the placeholders
	if [ -z "$AID" ]; then
		AID="$PLACEHOLDERAID"
	fi

	if [ "$AID" == "$PLACEHOLDERAID" ]; then
		GN="$PLACEHOLDERGN"
	fi
	setAIDCfgs
}

function setGN {
	if [ -z "$GN" ]; then
		getGameName "$1"
		GN="$GAMENAME"
	fi
}

function createSymLink {
	if [ ! -L "$3" ] && [ -e "$2" ]; then
		ln -s "$2" "$3"
		writelog "INFO" "$1 - Set symlink from '$2' to '$3'"
	else
		if [ -L "$3" ] && [ -z "$4" ]; then
			writelog "INFO" "$1 - Symlink '$3' already exists"
		fi

		if [ ! -e "$2" ]; then
			writelog "INFO" "$1 - '$2' does not exists"
		fi
	fi
}

function linkLog {
	if [ -z "$GN" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Skipping symlinking logfile - no valid game name found"
	else
		createSymLink "${FUNCNAME[0]}" "$LOGFILE" "$LOGDIRTI/$GN.log"
	fi
}

function setGlobalAIDCfgs {
	GLOBALSBSTWEAKCFG="$GLOBALSBSTWEAKS/$AID.conf"
	GLOBALTWEAKCFG="$GLOBALTWEAKS/$AID.conf"
}

function setCompatDataTitle {
	if [ "$STORECOMPDATTITLE" -eq 1 ] && [ -n "$OSCDP" ]; then
		mkProjDir "$STLCOMPDAT"
		COMPDATTITLE="$STLCOMPDAT/$GN"
		if readlink "$COMPDATTITLE" >/dev/null ; then
			writelog "INFO" "${FUNCNAME[0]} - Symlink $COMPDATTITLE already exists"
			if [ "$(readlink "$COMPDATTITLE")" == "$OSCDP" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Symlink '$COMPDATTITLE' already points to the correct directory '$OSCDP'"
			else
				writelog "INFO" "${FUNCNAME[0]} - Symlink '$COMPDATTITLE' points to '$(readlink "$COMPDATTITLE")' which is not the correct directory '$OSCDP' - renewing!"
				rm "$COMPDATTITLE"
				createSymLink "${FUNCNAME[0]}" "$OSCDP" "$COMPDATTITLE"
			fi
		else
			createSymLink "${FUNCNAME[0]}" "$OSCDP" "$COMPDATTITLE"
		fi
	fi
}

function setGameVars {
	getGameOS "$@"
	# common
	if [ -n "$STEAM_COMPAT_INSTALL_PATH" ]; then
		EFD="$STEAM_COMPAT_INSTALL_PATH"
	else
		EFD="$(dirname "$GP")"
	fi

	GFD="$(awk -F 'common' '{print $1}' <<< "$EFD")common/$(awk -F 'common' '{print $NF}' <<< "$EFD" | cut -d'/' -f2)" # f.e. used for vortex symlinks
	GN="$(grep -oE 'common/[^\/]+' <<< "$EFD" | awk -F 'common/' '{print $NF}')"				# THIS is hopefully the proper game name

	if [ -z "$STEAM_COMPAT_TOOL_PATHS" ] || [ "$STEAM_COMPAT_TOOL_PATHS" == "" ]; then
		HAVESCTP=0
	else
		HAVESCTP=1
		ORG_STEAM_COMPAT_TOOL_PATHS="$STEAM_COMPAT_TOOL_PATHS"
	fi

	if [ -n "$STEAM_COMPAT_INSTALL_PATH" ]; then
		STECOSHAPA="$STEAM_COMPAT_SHADER_PATH"
	fi

	# maybe loop through all paths possibly in STEAM_COMPAT_LIBRARY_PATHS?
	if [ -d "$STEAM_COMPAT_LIBRARY_PATHS" ]; then
		APPMAFE="${STEAM_COMPAT_LIBRARY_PATHS}/appmanifest_${AID}.acf"
	else
		APPMAFE="$(listAppManifests | grep -m1 "${1}.acf")"  # this should cover it though as well already
	fi

	REAPSESTR="reaper SteamLaunch"
	if grep -q "$REAPSESTR" <<< "$@"; then
		HAVEREAP=1
	else
		HAVEREAP=0
	fi

	if grep -q "$SLR" <<< "$@"; then
		writelog "INFO" "${FUNCNAME[0]} - Found SLR is launch option"
		HAVESLR=1
	else
		writelog "INFO" "${FUNCNAME[0]} - No SLR is in launch option"
		HAVESLR=0
	fi

	INSTLSTR="${PROGNAME}/${PROGCMD}"
	if grep -q "$INSTLSTR" <<< "$@"; then
		HAVEINSTL=1
	else
		HAVEINSTL=0
	fi

	# first put the initial command line into an array - who knows if we need it again
	while read -r INGARG; do
		mapfile -t -O "${#INGCMD[@]}" INGCMD <<< "$INGARG"
	done <<< "$(printf "%s\n" "$@")"

	# then put the reaper command into an array, as it is the first command in the line
	if [ "$HAVEREAP" -eq 1 ]; then
		FOUNDREAP=0
		while read -r INGARG; do
			if [ "$FOUNDREAP" -eq 0 ]; then
				mapfile -t -O "${#REAPCMD[@]}" REAPCMD <<< "$INGARG"
				if [ "$INGARG" == "--" ]; then
					FOUNDREAP=1
				fi
			else
				mapfile -t -O "${#WIPAGCMD[@]}" WIPAGCMD <<< "$INGARG"
			fi
		done <<< "$(printf "%s\n" "${INGCMD[@]}")"
	else
		while read -r INGARG; do
			mapfile -t -O "${#WIPAGCMD[@]}" WIPAGCMD <<< "$INGARG"
		done <<< "$(printf "%s\n" "${INGCMD[@]}")"
	fi
	THISREAP="${REAPCMD[*]}"
	THISREAP="${THISREAP% SteamLaunch*}"
	if [ -z "$LASTREAP" ] || { [ -n "$LASTREAP" ] && [ "$LASTREAP" != "$THISREAP" ];}; then
		updateConfigEntry "LASTREAP" "$THISREAP" "$STLDEFGLOBALCFG"
	fi

	# if the SLR is called from command line put it into an array as well
	if [ "$HAVESLR" -eq 1 ]; then
		FOUNDSLR=0
		while read -r ORGARG; do
			if [ "$FOUNDSLR" -eq 0 ]; then
				mapfile -t -O "${#RUNSLR[@]}" RUNSLR <<< "$ORGARG"
				if [ "$ORGARG" == "--" ]; then
					FOUNDSLR=1
				fi
			else
				mapfile -t -O "${#WIPBGCMD[@]}" WIPBGCMD <<< "$ORGARG"
			fi
		done <<< "$(printf "%s\n" "${WIPAGCMD[@]}")"
	else
		while read -r ORGARG; do
			mapfile -t -O "${#WIPBGCMD[@]}" WIPBGCMD <<< "$ORGARG"
		done <<< "$(printf "%s\n" "${WIPAGCMD[@]}")"
	fi

	if [ -z "$LASTSLR" ] || { [ -n "$LASTSLR" ] && [ "$LASTSLR" != "${RUNSLR[*]}" ];}; then
		updateConfigEntry "LASTSLR" "${RUNSLR[*]}" "$STLDEFGLOBALCFG"
	fi

	# put the proton path into an array as well if provided from command line
	if [ "$HAVEINPROTON" -eq 1 ]; then
		FOUNDIPRO=0
		while read -r ORGARG; do
			if [ "$FOUNDIPRO" -eq 0 ]; then
				mapfile -t -O "${#INPROTCMD[@]}" INPROTCMD <<< "$ORGARG"
				if [ "$ORGARG" == "$WFEAR" ]; then
					FOUNDIPRO=1
				fi
			else
				mapfile -t -O "${#WIPCGCMD[@]}" WIPCGCMD <<< "$ORGARG"
			fi
		done <<< "$(printf "%s\n" "${WIPBGCMD[@]}")"

		if [ "${INPROTCMD[-1]}" == "$WFEAR" ]; then
			unset "INPROTCMD[-1]"  # removing last INPROTCMD element as it is '$WFEAR'
		fi

		INPROTV="$(setProtonPathVersion "${INPROTCMD[*]}")"
	else
		while read -r ORGARG; do
			mapfile -t -O "${#WIPCGCMD[@]}" WIPCGCMD <<< "$ORGARG"
		done <<< "$(printf "%s\n" "${WIPBGCMD[@]}")"
	fi

	# put the own $PROGCMD command into an array if provided from command line
	if [ "$HAVEINSTL" -eq 1 ]; then
		FOUNDINSTL=0
		while read -r ORGARG; do
			if [ "$FOUNDINSTL" -eq 0 ]; then
				mapfile -t -O "${#INSTLCMD[@]}" INSTLCMD <<< "$ORGARG"
				if [[ "$ORGARG" =~ $INSTLSTR ]]; then
					FOUNDINSTL=1
				fi
			else
				mapfile -t -O "${#WIPDGCMD[@]}" WIPDGCMD <<< "$ORGARG"
			fi
		done <<< "$(printf "%s\n" "${WIPCGCMD[@]}")"
	else
		while read -r ORGARG; do
			mapfile -t -O "${#WIPDGCMD[@]}" WIPDGCMD <<< "$ORGARG"
		done <<< "$(printf "%s\n" "${WIPCGCMD[@]}")"
	fi

	# SLRCT = Steam Linux Runtime from Compatibility Tool
	# Refers to instances where the SLR comes in the launch command for a game
	# This can happen if you launch a game with SLR 1.0 or 3.0 selected as a compatibility tool, as Steam
	# will give the launch command wrapped with the SLR.
	#
	# See setSLRReap for implementation on how we use this
	if grep -q "$SLR" <<< "${WIPDGCMD[@]}"; then
		HAVESLRCT=1
	else
		HAVESLRCT=0
	fi

	if [ "$HAVESLRCT" -eq 1 ]; then
		FOUNDSLR=0
		while read -r ORGARG; do
			if [ "$FOUNDSLR" -eq 0 ]; then
				mapfile -t -O "${#RUNSLRCT[@]}" RUNSLRCT <<< "$ORGARG"
				if [ "$ORGARG" == "--" ]; then
					FOUNDSLR=1
				fi
			else
				mapfile -t -O "${#ORGFGCMD[@]}" ORGFGCMD <<< "$ORGARG"
			fi
		done <<< "$(printf "%s\n" "${WIPDGCMD[@]}")"
	else
		while read -r ORGARG; do
			mapfile -t -O "${#ORGFGCMD[@]}" ORGFGCMD <<< "$ORGARG"
		done <<< "$(printf "%s\n" "${WIPDGCMD[@]}")"
	fi

	# what is left now is the game executable and its command line arguments - splitting

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
	done <<< "$(printf "%s\n" "${ORGFGCMD[@]}")"

	if [ "${ORGGCMD[0]}" == "$WFEAR" ]; then
		# removing first ORGGCMD element as it is '$WFEAR'
		unset "ORGGCMD[0]"
	fi

	if [ -z "$GAMEEXE" ]; then
		GAMEEXE="${ORGGCMD[*]}"
		GAMEEXE="${GAMEEXE##*/}"
	fi
}

function getGameOS {
	function setLin {
		if [ -f "$OSCHECKGAMEEXE" ]; then
			GP="$OSCHECKGAMEEXE"
		else
			GPRAW="$(printf "%s\n" "$@" | grep -m1 "$SAC")"
			if grep -q "/./" <<< "$GPRAW"; then
				GP="${GPRAW//\/.\//\/}"
			else
				GP="$GPRAW"
			fi
		fi
		ABSGAMEEXEPATH="$GP"
		GE="${GP##*/}"																			# the game executable
		ISGAME=3																				# no STEAM_COMPAT_DATA_PATH, so it is no windows game
	}

	function setWin {
		if [ -f "$OSCHECKGAMEEXE" ]; then
			GP="$OSCHECKGAMEEXE"
		else
			GP="$(printf "%s\n" "$@" | grep -v "proton\|$SLR" | grep -m1 "$SAC")"				# the absolute game path of the windows game exe
		fi
		ABSGAMEEXEPATH="$GP"
		GPFX="$STEAM_COMPAT_DATA_PATH/pfx"														# currently used WINEPREFIX
		GE="$(awk -F '.exe' '{print $1}' <<< "${GP##*/}")"										# just the windows game exe name
		writelog "INFO" "${FUNCNAME[0]} - '$GE' determined to be a Windows Game"
		ISGAME=2
	}
	if [ "$STLPLAY" -eq 0 ]; then
		if [ "$ABSGAMEEXEPATH" == "$NON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Starting game OS detection"

			while read -r INGARG; do
				if grep -q "$STEAM_COMPAT_INSTALL_PATH" <<< "$INGARG"; then
					OSCHECKGAMEEXE="$INGARG"
				fi
				mapfile -t -O "${#OSCHECKINGCMD[@]}" OSCHECKINGCMD <<< "$INGARG"
			done <<< "$(printf "%s\n" "$@")"

			if [ -n "$STEAM_COMPAT_DATA_PATH" ]; then
				if grep -q "$L2EA" <<< "$@"; then
					ISORIGIN=1
				fi

				if [ "$ISORIGIN" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - Found '$L2EA' in the command line, so this is a Windows game!"
					setWin "$@"
				elif [ -f "$OSCHECKGAMEEXE" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Making some checks on '$OSCHECKGAMEEXE' to determine the OS version of the game"
					if grep -q "shell script" <<< "$(file "$(realpath "$OSCHECKGAMEEXE")")" || grep -q "ELF.*.LSB" <<< "$(file "$(realpath "$OSCHECKGAMEEXE")")" ; then
						writelog "INFO" "${FUNCNAME[0]} - Looks like this is a Linux game!"
						setLin "$@"
					elif grep -q "PE32" <<< "$(file "$OSCHECKGAMEEXE")"; then
						writelog "INFO" "${FUNCNAME[0]} - Looks like this is a Windows game!"
						setWin "$@"
					else
						writelog "WARN" "${FUNCNAME[0]} - Could not determine OS version of '$OSCHECKGAMEEXE' (add check?), so assuming this is a Windows game"
						setWin "$@"
					fi
				else
					writelog "WARN" "${FUNCNAME[0]} - Could not extract the full game binary path from the incoming game launch command, so assuming this is a Windows game!"
					setWin "$@"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - STEAM_COMPAT_DATA_PATH is not defined, so this is either a Linux Game or no game was started at all"
				setLin "$@"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - ISGAME is already set to '$ISGAME' - nothing to determine"
		fi
	fi
}

function setCustomGameVars {
	# there doesn't seem to be a possibility to distinguish game platform based on given variables, so using at least a basic arch check on the exe:
	GP="$(printf "%s\n" "$@" | grep -v "$WFEAR" | head -n1)"

	getGameOS "$@"

	GE="$(awk -F '.exe' '{print $1}' <<< "${GP##*/}")"
	EFD="$(dirname "$GP")"
	# need to just guess here, because of missing fix strings
	GFD="$EFD"
	GN="$GE"

	# Allows custom programs to use SLR and force it from the toolmanifest
	USESLR=1
	HAVESLR=0

	while read -r ORGARG; do
		mapfile -t -O "${#ORGGCMD[@]}" ORGGCMD <<< "$ORGARG"
	done <<< "$(printf "%s\n" "$@")"
	if [ "${ORGGCMD[0]}" == "$WFEAR" ]; then
		unset "ORGGCMD[0]"  # removing first ORGGCMD element as it is '$WFEAR'
	fi
}

