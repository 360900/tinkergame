#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function getLatestMO2Ver {
	# Temporarily hardcode to MO2 v2.4.4 until a Proton version with this patch is available: https://gitlab.winehq.org/wine/wine/-/merge_requests/3931
	writelog "INFO" "${FUNCNAME[0]} - Temporarily hardcoding ModOrganizer 2 version to v2.4.4 until v2.5.0 works under Proton"
	writelog "INFO" "${FUNCNAME[0]} - Please open an issue if this Wine patch is available in a Proton version and MO2 works under Proton again: https://gitlab.winehq.org/wine/wine/-/merge_requests/3931"
	MO2SETUP="Mod.Organizer-2.4.4.exe"

	MO2SET="Mod.Organizer"

	# writelog "INFO" "${FUNCNAME[0]} - Search for latest '$MO2SET' Release under '$MO2PROJURL'"
	# MO2SETUP="$(getLatestGitHubExeVer "$MO2SET" "$MO2PROJURL" "1")"
	# if [ -n "$MO2SETUP" ]; then
	# 	writelog "INFO" "${FUNCNAME[0]} - Found '$MO2SETUP'"
	# else
	# 	writelog "ERROR" "${FUNCNAME[0]} - Could not find any '$MO2SET' Release"
	# fi
}

function dlLatestMO2 {
	# Custom executable
	# Only download MO2 if MO2CUSTOMINSTALLER is disabled, AND if a custom installer is not valid (if undefined, or $NON, or doesn't exist)
	if [ "$USEMO2CUSTOMINSTALLER" -eq 1 ] && checkCustomModToolInstaller "ModOrganizer 2" "$MO2CUSTOMINSTALLER"; then
		writelog "INFO" "${FUNCNAME[0]} - Valid ModOrganizer 2 custom installer executable found ('$MO2CUSTOMINSTALLER') -- Using this to install MO2 instead of downloading from GitHub"
		MO2SPATH="$( realpath "$MO2CUSTOMINSTALLER" )"  # Use custom exe
		return
	fi

	# Regular download from GitHub
	getLatestMO2Ver
	if [ -n "$MO2SETUP" ]; then
		mkProjDir "$MO2DLDIR"
		MO2SPATH="$MO2DLDIR/$MO2SETUP"
		if [ ! -f "$MO2SPATH" ]; then
			MO2VRAW="$(grep -oP "${MO2SET}-\K[^X]+" <<< "$MO2SETUP")"
			MO2VERSION="${MO2VRAW%.exe}"
			DLURL="$MO2PROJURL/releases/download/v$MO2VERSION/$MO2SETUP"
			writelog "INFO" "${FUNCNAME[0]} - Downloading $MO2SETUP to $MO2DLDIR from '$DLURL'"

			if [ -n "$1" ]; then
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$MO2SETUP")" "S"
				dlCheck "$DLURL" "$MO2SPATH" "X" "Downloading '$MO2SETUP'"
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$MO2SETUP")" "S"
			else
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$MO2SETUP")"
				dlCheck "$DLURL" "$MO2SPATH" "X" "Downloading '$MO2SETUP'"
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$MO2SETUP")"
			fi
			if [ -f "$MO2SPATH" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Download succeeded - continuing installation"
			else
				writelog "ERROR" "${FUNCNAME[0]} - Download failed!"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - No MO2SETUP defined - nothing to download - skipping"
	fi
}

function setMO2Vars {
	if [ -z "$MOINST" ]; then
		MOINST="$NON"
	fi

	if [ "$MOINST" == "$NON" ]; then
		if [ -n "$GPFX" ]; then
			MOINST="portable"
			writelog "INFO" "${FUNCNAME[0]} - Found the variable for the game wineprefix '$GPFX', so using a $MOINST instance of '$MO2'"
			MO2PFX="$GPFX"
			MO2CODA="${GPFX//\/pfx}"
		else
			MOINST="global"
			writelog "INFO" "${FUNCNAME[0]} - No game wineprefix found in env, so using a $MOINST instance of '$MO2'"
			MO2CODA="$MO2COMPDATA"
			MO2PFX="${MO2COMPDATA//\"/}/pfx"
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - The '$MO2' instance was already set to '$MOINST' during this run"
	fi

	if [ -z "$MO2EXE" ]; then
		MO2EXE="$MO2PFX/$MOERPATH"
		NXMG="nxmhandler"
		NMXHLOG="$MO2PFX/$DRCU/$STUS/$ADLO/$MO/${NXMG}.log"
	fi
	MO2GAMES="$GLOBALMISCDIR/mo2games.txt"
	writelog "INFO" "${FUNCNAME[0]} - The $MO2 helper-file is set to '$MO2GAMES'"

	if [ -z "$MO2WINE" ] || [ ! -f "$MO2WINE" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Preparing Proton variables for a $MOINST $MO2 instance"

		if [ "$MOINST" == "portable" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using proton version '$USEPROTON', which is currently configured for the game $GAMENAME"
			SETMO2PROT="$USEPROTON"
		else
			if [ "$USEMO2PROTON" == "$NON" ]; then
				if [ ! -f "$PROTONCSV" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Looking for available Proton versions"
					getAvailableProtonVersions "up" X
				fi

				if ! grep -q "^GE" "$PROTONCSV"; then
					autoBumpGE "X"
				fi

				SETMO2PROT="$(grep "^GE" "$PROTONCSV" | sort -V | tail -n1)"
				SETMO2PROT="${SETMO2PROT%%;*}"
				USEMO2PROTON="$SETMO2PROT"
				touch "$FUPDATE"
				updateConfigEntry "USEMO2PROTON" "$USEMO2PROTON" "$STLDEFGLOBALCFG"
				writelog "INFO" "${FUNCNAME[0]} - USEMO2PROTON is '$NON', so using latest Proton-GE '$SETMO2PROT' automatically" "E"
			else
				SETMO2PROT="$USEMO2PROTON"
			fi
		fi

		writelog "INFO" "${FUNCNAME[0]} - Using $SETMO2PROT for $MO"
		setModWine "SETMO2PROT" "MO2RUNPROT" "MO2WINE"
	fi
}

# Helper to check if custom exe for mod tool is valid
# $1 = name of tool (for display purpses), $2 = path to custom executable
# Intended for commandline primarily, not installMO2/etc directly - Could probably be re-used for Vortex
function checkCustomModToolInstaller {
	if [ -z "$1" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Did not pass tool name"
	fi

	if [ -n "$2" ] && [ "$2" != "$NON" ]; then  # Ensure file is given
		if [ -f "$2" ] && [ -s "$2" ]; then  # Ensure file is file and is > 0bytes
			writelog "INFO" "${FUNCNAME[0]} - Got valid $1 executable '$2' is a valid file -- Will use this to install $1"
			echo "Got valid $1 executable '$2' is a valid file -- Will use this to install $1"
			return 0
		else
			writelog "INFO" "${FUNCNAME[0]} - Custom $1 executable '$2' is not a valid file -- Skipping"
			echo "Custom $1 executable '$2' is not a valid file -- Skipping"
			return 1
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - Custom executable ('$2') is not defined -- Skipping"
		echo "Custom executable ('$2') is not defined -- Skipping"
		return 1
	fi
}

function installMO2 {
	dlLatestMO2 "S"

	if [ -f "$MO2SPATH" ]; then
		setMO2Vars
		if [ -f "$MO2EXE" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - '$MO2EXE' does already exists - nothing to install - skipping"
		elif [ -f "$MO2INSTFAIL" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - '$MO2INSTFAIL' found - seems like installation failed previously - skipping further attempts to avoid loops"
		else
			if [ -f "$MO2RUNPROT" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Using '$MO2RUNPROT' for installation" "E"
				mkProjDir "$MO2CODA"
				touch "${MO2COMPDATA}/tracked_files"
				STEAM_COMPAT_CLIENT_INSTALL_PATH="$SROOT" STEAM_COMPAT_DATA_PATH="$MO2CODA" "$MO2RUNPROT" "run" 2> "$STLSHM/${FUNCNAME[0]}_protonrun.log"
				writelog "INFO" "${FUNCNAME[0]} - Installing '$MO2SPATH' into '$MO2PFX'"
				notiShow "$(strFix "$NOTY_INSTSTART" "${MO2SPATH##*/}")"
				# the '$MO2SPATH' installer at least fails on the Steam Deck, so using $INNOEXTRACT for the installation if available
				MININNO=1.9
				WIMOINST=1

				if [ -f "$(command -v "$INNOEXTRACT")" ]; then
					INNOVER="$("$INNOEXTRACT" --version | head -n1 | cut -d ' ' -f2)"
					if [ "$(printf '%s\n' "$MININNO" "$INNOVER" | sort -V | head -n1)" != "$MININNO" ] || grep -qi "[A-Z]" <<< "$INNOVER" ; then
						writelog "ERROR" "${FUNCNAME[0]} - Version for '$INNOEXTRACT' is invalid. You need to at least version '$MININNO'"
						writelog "ERROR" "${FUNCNAME[0]} - Starting $MO2EXE using wine/proton instead"
						WIMOINST=1
					else
						WIMOINST=0
					fi

					if [ "$WIMOINST" -eq 0 ]; then
						writelog "INFO" "${FUNCNAME[0]} - Using $INNOEXTRACT binary found in path: '$(command -v "$INNOEXTRACT")'"
						MO2DST="$MO2PFX/$MORDIR"
						mkProjDir "$MO2DST"
						"$INNOEXTRACT" -m -s -d "$MO2DST" "$MO2SPATH"
						if [ -d "$MO2DST/app" ]; then
							mv "$MO2DST/app" "$MO2DST/${MO2^^}"
							writelog "INFO" "${FUNCNAME[0]} - Installed '$MO' into '$MO2DST/${MO2^^}' using '$INNOEXTRACT'"
						else
							writelog "WARN" "${FUNCNAME[0]} - Extraction of '$MO' into '$MO2DST/${MO2^^}' using $INNOEXTRACT failed or the output directory is called differently"
						fi
					fi
				fi

				if [ "$WIMOINST" -eq 1 ]; then
					if [ "$ONSTEAMDECK" -eq 1 ]; then
						writelog "WARN" "${FUNCNAME[0]} - Unfortunately '$INNOEXTRACT' is required to install $MO on the Steam Deck, but it wasn't found"
					else
						writelog "INFO" "${FUNCNAME[0]} - '$INNOEXTRACT' not found, trying to use the installer '$MO2SPATH' regularly"
						sleep 3
						WINEDEBUG="-all" WINEPREFIX="$MO2PFX" "$MO2WINE" "$MO2SPATH" "/VERYSILENT"
					fi
				fi

				if [ ! -f "$MO2EXE" ]; then
					writelog "WARN" "${FUNCNAME[0]} - '$MO2EXE' not found after installation, creating '$MO2INSTFAIL' to avoid further attempts"
					date > "$MO2INSTFAIL"
				fi
				notiShow "$(strFix "$NOTY_INSTSTOP" "${MO2SPATH##*/}")" "S"
				writelog "INFO" "${FUNCNAME[0]} - Base ${MO} installation finished"
				setMO2DLMime
				notiShow "$GUI_DONE" "S"
			else
				writelog "SKIP" "${FUNCNAME[0]} - MO2RUNPROT '$MO2RUNPROT' not found, can't continue with $MO installion"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$MO2SETUP' not found - nothing to install - skipping"
	fi
}

function checkInstalledMO2Games {
	if [ -f "$MO2INSTFAIL" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - '$MO2INSTFAIL' found - seems like installation failed previously - skipping ${FUNCNAME[0]}"
	elif [ ! -d "$SRCPFX" ]; then
		if [ -n "$1" ]; then
			SYMODE="$1"
		else
			SYMODE="set"
		fi

		while read -r line; do
			MGID="$(cut -d ';' -f2 <<< "$line")"
			MGID="${MGID//\"}"

			while read -r sl; do
				CHKAPMA="$sl/$SA/appmanifest_${MGID}.acf"
				if [ -f "$CHKAPMA" ]; then
					MGNA1="$(cut -d ';' -f1 <<< "$line")"
					MGNA="${MGNA1//\"}"
					MGPFX="$(dirname "$CHKAPMA")/$CODA/${MGID}/pfx"
					setModGameSyms "$SYMODE" "$MGPFX" "$MGNA" "$MGID" "$MO2PFX" "$CHKAPMA"
				fi
			done <<< "$(printf "%s\n" "${SLARR[@]}")"
		done < "$MO2GAMES"
		setModGameReg "$MO2PFX" "$MO2WINE"
	fi
}

function prepAllMO2Games {
	MO2STDIR="$MO2PFX/$DRC/$PFX86S"
	MO2SADIR="$MO2STDIR/$SA"
	mkProjDir "$MO2SADIR"

	rm "$MO2SADIR/$LIFOVDF" 2>/dev/null
	{
		echo "\"LibraryFolders\""
		echo "{"
		listWinSteamLibraries
		echo "}"
	} >> "$MO2SADIR/$LIFOVDF"

	checkInstalledMO2Games "$1"
}

# Output supported MO2 games in format "Name (AppID)"
function listMO2Games {
	MO2GAMES="$GLOBALMISCDIR/mo2games.txt"
	while read -r MO2GAM; do
		MO2GAMNAM="$( echo "$MO2GAM" | cut -d ";" -f 1 | cut -d '"' -f 2 )"
		MO2GAMAID="$( echo "$MO2GAM" | cut -d ";" -f 2 | cut -d '"' -f 2 )"

		printf "%s (%s)\n" "$MO2GAMNAM" "$MO2GAMAID"
	done <"$MO2GAMES"
}

function manageMO2GInstance {
	setMO2Vars
	if [ ! -f "$MO2EXE" ]; then
		StatusWindow "$(strFix "$NOTY_INSTSTART" "$MO")" "installMO2" "InstallMO2Status"
	fi

	if [ -f "$MO2INSTFAIL" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - '$MO2INSTFAIL' found - seems like installation failed previously - skipping ${FUNCNAME[0]}"
	else
		if [ -z "$1" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - argument 1 '$1' is invalid"
		else
			writelog "INFO" "${FUNCNAME[0]} - Looking for '$1' in '$MO2GAMES'"
			if grep -q "$1" "$MO2GAMES"; then
				MO2AID="$1"
				MO2GA1="$(grep -m1 "\"$MO2AID\"" "$MO2GAMES" | cut -d ';' -f1)"
				MO2GAM="${MO2GA1//\"}"

				MO2GAMIN1="$(grep -m1 "\"$MO2AID\"" "$MO2GAMES" | cut -d ';' -f3)"
				MO2GAMINI="${MO2GAMIN1//\"}"

				if [ -n "$MO2GAM" ]; then
					if [ -n "$2" ] && [ "$2" == "portable" ]; then
						MOIN="$MO2PFX/$MOERDIR"
						writelog "INFO" "${FUNCNAME[0]} - preparing '$2' instance in '$MOIN' for '$1'"
						GLOBMOIN="${MO2COMPDATA//\"/}/pfx/$DRCU/$STUS/$ADLO/$MO/$MO2GAM"
					else
						MOIN="$MO2PFX/$DRCU/$STUS/$ADLO/$MO/$MO2GAM"
						GLOBMOIN="$MOIN"
					fi

					MODPRDE="$MOIN/profiles/Default"
					MODLIST="$MODPRDE/modlist.txt"
					MOININI="$MOIN/${MO}.ini"
					MOINEW=0

					GLOBZMOIN="Z:${GLOBMOIN//\//\\\\}"

					if [ ! -f "$MOININI" ]; then
						MO2GADI="$(getGameDirFromAID "$MO2AID")"

						writelog "INFO" "${FUNCNAME[0]} - Creating an initial '$MOININI'"

						if [ -d "$MO2GADI" ]; then
							MO2GAZDI="Z:${MO2GADI//\//\\\\}"
							mkProjDir "$MOIN"
							writelog "INFO" "${FUNCNAME[0]} - GLOBZMOIN is '$GLOBZMOIN'"
							touch "$MOININI"
							# This used to use `echo` but was changed because of ShellCheck SC2028
							# The behaviour was different too, echo was returning '\\\\' but printf was returning '\\'
							# Based on the rest of the paths, I think printf's '\\' is actually correct, but if this breaks anything,
							# we can re-evaluate.
							{
							echo "[General]"
							echo "gameName=$MO2GAMINI"
							echo "selected_profile=@ByteArray(Default)"
							echo "gamePath=@ByteArray($MO2GAZDI)"
							echo "[Settings]"
							printf "download_directory=%s\\\\\\\\downloads\r\n" "${GLOBZMOIN}"
							printf "cache_directory=%s\\\\\\\\webcache\r\n" "${GLOBZMOIN}"
							printf "mod_directory=%s\\\\\\\\mods\r\n" "${GLOBZMOIN}"
							printf "overwrite_directory=%s\\\\\\\\overwrite\r\n" "${GLOBZMOIN}"
							printf "profiles_directory=%s\\\\\\\\profiles\r\n" "${GLOBZMOIN}"
							} >> "$MOININI"
							MOINEW=1
						else
							writelog "SKIP" "${FUNCNAME[0]} - '$MO2AID' is a supported Id, but the game installation could not be found"
						fi
					else
						writelog "INFO" "${FUNCNAME[0]} - '$MOININI' does already exist"
						if grep -q "${GLOBZMOIN}" "$MOININI"; then
							writelog "INFO" "${FUNCNAME[0]} - and it uses $PROGNAME paths"
						else
							# XXXXXXXXXXXX maybe TODO optionally add above paths if missing
							writelog "INFO" "${FUNCNAME[0]} - the file was created by the user, leaving it unmodified"
						fi
					fi
					if [ -d "$MOIN" ]; then
						if [ -n "$2" ]; then
							if [ "$2" == "portable" ]; then
								writelog "INFO" "${FUNCNAME[0]} - Using $2 instance"
								MO2INST="$2"
							else
								writelog "INFO" "${FUNCNAME[0]} - Using $MO instance '$MO2GAM'"
								MO2INST="$MO2GAM"
							fi
						else
							if [ "$MOINEW" -eq 1 ]; then
								writelog "INFO" "${FUNCNAME[0]} - Created initial $MO instance '$MO2GAM'"
							else
								writelog "SKIP" "${FUNCNAME[0]} - $MO instance '$MO2GAM' already exists"
							fi
						fi
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - Could not find game name for '$MO2AID' - starting regularly with default instance"
				fi
			else
				STAMO2=0
				writelog "SKIP" "${FUNCNAME[0]} - '$1' is no supported $MO game"
				listMO2Games
			fi
		fi
	fi
}

function createAllMO2Instances {
	setMO2Vars
	while read -r line; do
		manageMO2GInstance "$line"
	done <<< "$(prepAllMO2Games "li" | cut -d ';' -f1)"
}

function prepareMO2 {
	setMO2Vars
	STAMO2=1
	if [ -n "$1" ] && [ "$1" != "$NON" ]; then
		if [ "$1" -eq "$1" ] 2>/dev/null; then
			if [ -n "$MOINST" ] && [ "$MOINST" == "portable" ]; then
				manageMO2GInstance "$1" "$MOINST"
			else
				manageMO2GInstance "$1"
			fi

			if [ "$2" == "disabled" ]; then
				STAMO2=0
			fi
		else
			if grep -q "^\"$1\"" "$MO2GAMES"; then
				writelog "INFO" "${FUNCNAME[0]} - Using $MO instance '$1'"
				MO2INST="$1"
			fi
		fi
	else
		if [ ! -f "$MO2EXE" ]; then
			StatusWindow "$(strFix "$NOTY_INSTSTART" "$MO")" "installMO2" "InstallMO2Status"
		fi

		if [ -f "$MO2INSTFAIL" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - '$MO2INSTFAIL' found - seems like installation failed previously - skipping ${FUNCNAME[0]}"
		else
			if [ "$MOINST" == "global" ]; then
				updateMO2GlobConf
				writelog "INFO" "${FUNCNAME[0]} - Updating/creating $MO instances for $MOINST instance"
				createAllMO2Instances
				STAMO2=1
			else
				writelog "SKIP" "${FUNCNAME[0]} - $MOINST instance running - nothing to prepare"
			fi
		fi
	fi

	if [ "$STAMO2" -eq 1 ] && [ "$2" != "disabled" ]; then
		if [ ! -f "$MO2EXE" ]; then
			StatusWindow "$(strFix "$NOTY_INSTSTART" "$MO")" "installMO2" "InstallMO2Status"
		fi

		if [ "$MOINST" == "global" ]; then
			writelog "INFO" "${FUNCNAME[0]} - preparing all games for $MOINST instance"
			prepAllMO2Games "set"
		fi

		if [ -f "$MO2EXE" ]; then
			if [ "$MOINST" == "global" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Checking for instance to be launched as $MOINST instance"
				if [ -z "$MO2INST" ]; then
					if [ -f "$NMXHLOG" ]; then
						writelog "INFO" "${FUNCNAME[0]} - No $MO instance provided - searching last one found in '$NMXHLOG'"
						RINST1="$(tac "$NMXHLOG" | grep -m1 \"reg\")"
						RINST2="${RINST1##*\"reg\" }"
						RINST="$(cut -d '"' -f2 <<< "$RINST2")"
						if [ -n "$RINST" ]; then
							MO2INST1="$(grep -m1 "\"$RINST\"" "$MO2GAMES" | cut -d ';' -f1)"
							MO2INST="${MO2INST1//\"}"
							writelog "INFO" "${FUNCNAME[0]} - Found '$RINST' as last used game in '$NMXHLOG', so using instance '$MO2INST'"
							MO2AID="$(grep -m1 "\"$RINST\"" "$MO2GAMES" | cut -d ';' -f2)"
							manageMO2GInstance "${MO2AID//\"}" "X"
							if [ -z "$EFD" ]; then
								if [ -z "$APPMAFE" ]; then
									APPMAFE="$(listAppManifests | grep -m1 "${MO2AID//\"}.acf")"
								fi
								EFD="$(getGameDirFromAM "$APPMAFE")"
							fi
						fi
					else
						writelog "INFO" "${FUNCNAME[0]} - No log '$NMXHLOG' found, so the last used instance can't be determined - using last supported instance installed instead"
						LAINST="$(checkInstalledMO2Games "li" | tail -n1)"
						MO2INST="$(cut -d ';' -f2 <<< "$LAINST")"
						MO2AID="$(cut -d ';' -f1 <<< "$LAINST")"
					fi
				fi
			fi

			if [ -n "$MO2INST" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Using $MO instance '$MO2INST'"
			else
				writelog "INFO" "${FUNCNAME[0]} - No $MO instance provided"
			fi

			setMO2DLMime
		else
			writelog "ERROR" "${FUNCNAME[0]} - No '$MO2EXE' found - can't continue"
		fi
	fi
}

function createMO2SilentModeExeProfilesList {
	# Get all of the ModOrganizer 2 executables launch configurations in the instance's INI
	# The user can use this to override which 'moshortcut://' is launched in Silent Mode
	MO2SILENTMODEEXEPROFILES="$NON"
	MO2GAMES="$GLOBALMISCDIR/mo2games.txt"

	# Taken from manageMO2GInstance
	MO2GA1="$(grep -m1 "\"$AID\"" "$MO2GAMES" | cut -d ';' -f1)"
	MO2GAM="${MO2GA1//\"}"
	if [ -z "$MO2GAM" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Does not appear that '$AID' is a ModOrganizer 2 game, nothing to do"
		return
	fi

	# MO2COMPDATA taken from setMO2Vars
	MOIN="${MO2COMPDATA//\"/}/pfx/$DRCU/$STUS/$ADLO/$MO/${MO2GAM}/${MO}.ini"
	writelog "INFO" "${FUNCNAME[0]} - MOIN is '${MOIN}'"
	if [ ! -f "$MOIN" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Nothing to do, ModOrganizer 2 instance INI for '$MO2GAM ($AID)' doesn't exist at '$MOIN' -- Perhaps this game has never been managed with MO2 before?"
		return
	fi

	# Executables are stored in INI in format '1\title=Executable Name', where '1' is its position in the MO2 executable profile list
	while read -r MO2EXEPROF; do
		# Remove \r with Windows line encoding in INI (\n should already be removed)
		MO2SILENTMODEEXEPROFILES="${MO2SILENTMODEEXEPROFILES}!${MO2EXEPROF//$'\r'/}"
	done <<< "$( sed -n 's/^[0-9]\\title=//p' "$MOIN" )"

	writelog "INFO" "${FUNCNAME[0]} - MO2SILENTMODEEXEPROFILES list is '${MO2SILENTMODEEXEPROFILES}'"
}

function startMO2 {
	prepareMO2 "$NON" "gui"
	if [ -d "${MO2EXE%/*}" ] ; then
		writelog "INFO" "${FUNCNAME[0]} - Starting '$MO2EXE'" E
		PFXSUTEMP="$GPFX/$DRCU/$STUS/Temp"
		mkProjDir "$PFXSUTEMP"
		cd "${MO2EXE%/*}" >/dev/null || return

		if [ -n "$MOINST" ] && [ "$MOINST" == "portable" ]; then
			updateMO2PortConf
		else
			updateMO2GlobConf
		fi

		if [ -n "$MO2INST" ]; then
			writelog "INFO" "${FUNCNAME[0]} - WINEDEBUG=\"-all\" WINEPREFIX=\"$MO2PFX\" \"$MO2WINE\" \"$MO2EXE\" -i \"$MO2INST\"" E
			WINEDEBUG="-all" WINEPREFIX="$MO2PFX" "$MO2WINE" "$MO2EXE" -i "$MO2INST" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}_${IFILE##*/}.log"
		else
			writelog "INFO" "${FUNCNAME[0]} - WINEDEBUG=\"-all\" WINEPREFIX=\"$MO2PFX\" \"$MO2WINE\" \"$MO2EXE\"" E
			WINEDEBUG="-all" WINEPREFIX="$MO2PFX" "$MO2WINE" "$MO2EXE" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}_${IFILE##*/}.log"
		fi
		cd - >/dev/null || return
		mkProjDir "$PFXSUTEMP"
	elif [ -f "$MO2INSTFAIL" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - '$MO2INSTFAIL' found - seems like installation failed previously - can't start '$MO'"
	else
		writelog "SKIP" "${FUNCNAME[0]} - Could not find '$MO2EXE' - can't start $MO - this should not happen" E
	fi
}

function dlMod2nexurl {
	setMO2Vars

	MONGUR1="${1//nxm:\/\/}"
	MONGURL="${MONGUR1%%/*}"
	MYPORTDLDAT="${STLMO2DLDATDIR}/${MONGURL}.conf"

	function dlMod2globnexurl {
		MYGLOBDLDAT="${STLMO2DLDATDIR}/global.conf"

		if [ -f "$MYGLOBDLDAT" ]; then
			source "$MYGLOBDLDAT"
			if [ -d "${GMO2EXE%/*}" ] && [ -f "$RUNPROTON" ] && [ -n "$STEAM_COMPAT_CLIENT_INSTALL_PATH" ] && [ -n "$STEAM_COMPAT_DATA_PATH" ]; then
				MYINST="$(grep -m1 "\"${MONGURL}\"" "$MO2GAMES" | cut -d ';' -f1)"
				MYINST="${MYINST//\"/}"
				if [ -n "$MYINST" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Starting global '$RUNPROTON run ${MO}.exe -i $MYINST $1'"
					STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_COMPAT_CLIENT_INSTALL_PATH" STEAM_COMPAT_DATA_PATH="$STEAM_COMPAT_DATA_PATH" "$RUNPROTON" "run" "${MO}.exe" -i "$MYINST" "$1" 2>&1 | tee /tmp/RUNMO2DL.log
				else
					writelog "ERROR" "${FUNCNAME[0]} - Could not find a valid $MO instance for '${MONGURL}' - giving up"
				fi
			elif [ -d "${GMO2EXE%/*}" ] && [ -n "$MO2PFX" ] && [ -n "$MO2WINE" ]; then
				MYINST="$(grep -m1 "\"${MONGURL}\"" "$MO2GAMES" | cut -d ';' -f1)"
				MYINST="${MYINST//\"/}"
				if [ -n "$MYINST" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Starting global MO2 in prefix '$MO2PFX' using '$MO2WINE' on $MYINST"
					WINEDEBUG="-all" WINEPREFIX="$MO2PFX" "$MO2WINE" "$GMO2EXE" -i "$MYINST" "$1" 2>&1 | tee /tmp/RUNMO2DL.log
				else
					writelog "ERROR" "${FUNCNAME[0]} - Could not find a valid global MO2 instance"
				fi
			else
				writelog "ERROR" "${FUNCNAME[0]} - Attempted to download Url '$1' for game '$MONGURL', but seems like global '$MYGLOBDLDAT' has incomplete data - giving up" "E"
			fi
		else
			writelog "ERROR" "${FUNCNAME[0]} - Attempted to download Url '$1' for game '$MONGURL', but the source script '$MYGLOBDLDAT' for global $MO is missing - giving up" "E"
		fi
	}

	if [ -f "$LAMOINST" ] && grep -q "global" "$LAMOINST"; then
		writelog "INFO" "${FUNCNAME[0]} - The last used $MO2 instance was global', so using the global $MO installation for the download" "E"
		dlMod2globnexurl "$1"
	elif [ -f "$MYPORTDLDAT" ]; then
		source "$MYPORTDLDAT"
		if [ -d "${GMO2EXE%/*}" ] && [ -f "$RUNPROTON" ] && [ -n "$STEAM_COMPAT_CLIENT_INSTALL_PATH" ] && [ -n "$STEAM_COMPAT_DATA_PATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Download Url '$1' for game '$MONGURL' using data from portable '$MYPORTDLDAT'"
			cd "${GMO2EXE%/*}" >/dev/null || return
			writelog "INFO" "${FUNCNAME[0]} - Starting portable '$RUNPROTON run ${MO}.exe $1'"
			STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_COMPAT_CLIENT_INSTALL_PATH" STEAM_COMPAT_DATA_PATH="$STEAM_COMPAT_DATA_PATH" "$RUNPROTON" run "${MO}.exe" "$1" 2>&1 | tee /tmp/RUNMO2DL.log
			cd - >/dev/null || return
		elif [ -d "${GMO2EXE%/*}" ] && [ -n "$MO2PFX" ] && [ -n "$MO2WINE" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Download Url '$1' for game '$MONGURL' using data from portable '$MYPORTDLDAT'"
			cd "${GMO2EXE%/*}" >/dev/null || return
			writelog "INFO" "${FUNCNAME[0]} - Starting portable MO2 in prefix '$MO2PFX' using '$MO2WINE'"
			if [ -n "$MO2INST" ]; then
				WINEDEBUG="-all" WINEPREFIX="$MO2PFX" "$MO2WINE" "$GMO2EXE" -i "$MO2INST" "$1" 2>&1 | tee /tmp/RUNMO2DL.log
			else
				WINEDEBUG="-all" WINEPREFIX="$MO2PFX" "$MO2WINE" "$GMO2EXE" "$1" 2>&1 | tee /tmp/RUNMO2DL.log
			fi
			cd - >/dev/null || return
		else
			writelog "ERROR" "${FUNCNAME[0]} - Attempted to download Url '$1' for game '$MONGURL', but seems like portable '$MYPORTDLDAT' has incomplete data - trying global $MO" "E"
			dlMod2globnexurl "$1"
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - Attempted to download Url '$1' for game '$MONGURL', but the source script '$MYPORTDLDAT' for portable $MO2 is missing - trying to start a global $MO" "E"
		dlMod2globnexurl "$1"
	fi
}

function setMO2DLMime {
	setMO2Vars

	MO2D="$MO-${PROGNAME,,}-dl.desktop"
	FMO2D="$HOME/.local/share/applications/$MO2D"

	if [ ! -f "$FMO2D" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating new desktop file $MO2D"
		{
		echo "[Desktop Entry]"
		echo "Type=Application"
		echo "Categories=Utilities;"
		echo "Name=$MO ($PROGNAME - ${PROGNAME,,})"
		echo "Comment=Link Handler - For internal use only"
		echo "Icon=$STLICON"
		echo "MimeType=x-scheme-handler/nxm;x-scheme-handler/nxm-protocol"
		echo "Terminal=false"
		echo "X-KeepTerminal=false"
		echo "Path=$(dirname "$MO2EXE")"
		if [ "$INFLATPAK" -eq 1 ]; then
			echo "Exec=/usr/bin/flatpak run --command=tinkergame $FLATPAK_ID mods mo2 url %u"
		else
			echo "Exec=$(realpath "$0") mods mo2 url %u"
		fi
		echo "NoDisplay=true"
		echo "Hidden=false"
		} >> "$FMO2D"

		VD="$VTX-${PROGNAME,,}-dl.desktop"
		FVD="$HOME/.local/share/applications/$VD"
		if [ -f "$FVD" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Renaming desktopfile ${FVD} to ${FVD}-off, because '$MO2D' was created"
			mv "$FVD" "$FVD-off"
		fi
	else
		if grep -q "$MO2PFX" "$FMO2D"; then
			writelog "INFO" "${FUNCNAME[0]} - Desktopfile '$FMO2D' looks to be up2date"
			# Do NOT return here: re-(re)apply the xdg-mime default association
			# every run so a stale mimeapps.list cannot silently break nxm:// handling.
		else
			writelog "INFO" "${FUNCNAME[0]} - Renaming desktopfile '$FMO2D' and creating a new one for ${PROGNAME,,}"
			mv "$FMO2D" "$FMO2D-old"
			setMO2DLMime
		fi
	fi

	# setting mime types for nxm

	if [ -x "$(command -v "$XDGMIME" 2>/dev/null)" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Setting download defaults for nexusmod protocol via $XDGMIME pointing at $MO2D"
		"$XDGMIME" default "$MO2D" x-scheme-handler/nxm
		"$XDGMIME" default "$MO2D" x-scheme-handler/nxm-protocol
	else
		writelog "SKIP" "${FUNCNAME[0]} - $XDGMIME not found - couldn't set download defaults for nexusmod protocol - skipping"
	fi
}

function checkMO2 {
	# migrateCfgOption should mean this never happens, but can never be too careful -- Has begun happening since 12/01/2024 for a small number of Steam Deck users
	if [ "$MO2MODE" == "$NON" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - MO2MODE is '$NON' -- This should not happen but has been observed in the wild, so explicitly returning here"
		return
	fi

	# MO2 disabled means don't use MO2 at all
	if [ "$MO2MODE" == "disabled" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - MO2MODE is 'disabled' -- Skipping checkMO2!"
		return
	fi

	# MO2 Wait Requester logic to choose between GUI, Silent, Cancel, or default MO2 mode if the Wait Requester times out
	writelog "INFO" "${FUNCNAME[0]} - MO2MODE is '$MO2MODE' - starting MO2"
	if [ "$WAITMO2" -gt 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Opening $MO Requester with timeout '$WAITMO2'"
		fixShowGnAid
		export CURWIKI="$PPW/Mod-Organizer-2"
		TITLE="${PROGNAME}-Open-Mod-Organizer2"
		pollWinRes "$TITLE"

		setShowPic
		"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--title="$TITLE" \
		--text="$(spanFont "$SGNAID - $GUI_ASKMO2" "H")" \
		--button="$BUT_MO2_GUI":0 \
		--button="$BUT_MO2_SIL":4 \
		--button="$BUT_MO2_SKIP":6 \
		--timeout="$WAITMO2" \
		--timeout-indicator=top \
		"$GEOM"

		case $? in
			0)  {
					writelog "INFO" "${FUNCNAME[0]} - Selected to start $MO with gui"
					MO2MODE="gui"
				}
			;;
			4)  {
					writelog "INFO" "${FUNCNAME[0]} - Selected to start $MO with mods silently"
					MO2MODE="silent"
				}
			;;
			6)  {
					writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL - Not starting $MO at all"
					MO2MODE="disabled"
				}
			;;
			70) {
					writelog "INFO" "${FUNCNAME[0]} - TIMEOUT - Starting $MO2 with default ModOrganizer 2 mode" # with mods silently"
				}
			;;
		esac
	else
		writelog "INFO" "${FUNCNAME[0]} - $MO Requester was skipped because WAITMO2 is '$WAITMO2' - not changing MO2MODE '$MO2MODE'"
	fi

	prepareMO2 "$AID" "$MO2MODE"
	if [ "$MO2MODE" != "disabled" ] && [ "$USECUSTOMCMD" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Disabling custom command, because $MO2 is enabled"
		USECUSTOMCMD=0
	fi
}

function mo2Winecfg {
	setMO2Vars
	fallbackIfNoRunProton "$USEMO2PROTON"
	getWinecfgExecutable
	if [ -d "$MO2PFX" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Running Winecfg for MO2"
		writelog "INFO" "${FUNCNAME[0]} - WINEDEBUG=\"-all\" WINEPREFIX=\"$MO2PFX\" \"$MO2WINE\" \"$OTWINECFGEXE\""
		WINEDEBUG="-all" WINEPREFIX="$MO2PFX" "$MO2WINE" "$OTWINECFGEXE"
	else
		writelog "ERROR" "${FUNCNAME[0]} - ModOrganizer 2 is not installed or prefix is missing, cannot run Winecfg for MO2"
		echo "ModOrganizer 2 is not installed or prefix is missing, cannot run Winecfg for ModOrganizer 2"
	fi
}

function mo2Winetricks {
	setMO2Vars
	chooseWinetricks
	if [ -d "$MO2PFX" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Running Winetricks for MO2"
		writelog "INFO" "${FUNCNAME[0]} - WINEDEBUG=\"-all\" WINEPREFIX=\"$MO2PFX\" WINE=\"$MO2WINE\" \"$WINETRICKS\""
		WINEDEBUG="-all" WINEPREFIX="$MO2PFX" WINE="$MO2WINE" "$WINETRICKS"
	else
		writelog "ERROR" "${FUNCNAME[0]} - ModOrganizer 2 is not installed or prefix is missing, cannot run Winetricks for MO2"
		echo "ModOrganizer 2 is not installed or prefix is missing, cannot run Winetricks for ModOrganizer 2"
	fi
}

#### MO2 MOD ORGANIZER STOP ####

# dprs:
