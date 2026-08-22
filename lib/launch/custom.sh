#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function StandaloneProtonGame {
	function SapRun {
		if [ "$SAPRUN" == "TRUE" ]; then
			RUNSAPPROTON="$(getProtPathFromCSV "$SAPPROTON")"
			if [ ! -f "$RUNSAPPROTON" ]; then
				RUNSAPPROTON="$(fixProtonVersionMismatch "SAPPROTON" "$STLGAMECFG" X)"
			fi

			if [ ! -f "$RUNSAPPROTON" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - No executable for selected Proton '$SAPPROTON' found"
			elif [ ! -f "$SAPEXE" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - No executable found"
			elif [ ! -d "$SAP_COMPAT_DATA_PATH" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - No $CODA dir found"
			else
				if [ -z "$SAPARGS" ]; then
					RUNSAPARGS=""
				else
					mapfile -d " " -t -O "${#RUNSAPARGS[@]}" RUNSAPARGS < <(printf '%s' "$SAPARGS")
				fi

				writelog "INFO" "${FUNCNAME[0]} - Starting '$SAPEXE' with '$SAPPROTON' with STEAM_COMPAT_DATA_PATH '$SAP_COMPAT_DATA_PATH'"
				STEAM_COMPAT_DATA_PATH="$SAP_COMPAT_DATA_PATH" "$RUNSAPPROTON" run "$SAPEXE" "${RUNSAPARGS[@]}"
			fi
		fi
	}

	function SapGui {
		export CURWIKI="$PPW/Standalone-Proton"
		TITLE="${PROGNAME}-StandaloneProtonGame"
		pollWinRes "$TITLE"

		SAPGAMELIST="$(find "$STLGSAPD" -type f -exec basename {} .conf \; | tr '\n' '!')"

		if [ -z "$SAP_COMPAT_DATA_PATH" ]; then
			SAP_COMPAT_DATA_PATH="$STLGSACD/${PROGNAME,,}-$((10000 + RANDOM % 10000))"
			mkProjDir "$SAP_COMPAT_DATA_PATH"
			IN_SAP_COMPAT_DATA_PATH="$SAP_COMPAT_DATA_PATH"
		fi

		PROTPARTS="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--title="$TITLE" \
		--text="$(spanFont "$GUI_SAPTEXT" "H")" \
		--field=" ":LBL " " --separator="|" \
		--field="$GUI_SAPGAME!$DESC_SAPGAME":CBE "$(cleanDropDown "${SAPGAME}" "$SAPGAMELIST")" \
		--field="$GUI_SAPPROTON!$DESC_SAPPROTON":CB "$(cleanDropDown "${SAPPROTON//\"}" "$PROTYADLIST")" \
		--field="$GUI_SAP_COMPAT_DATA_PATH!$DESC_SAP_COMPAT_DATA_PATH":DIR "${SAP_COMPAT_DATA_PATH//\"}" \
		--field="$GUI_SAPEXE!$DESC_SAPEXE":FL "${SAPEXE//\"}" \
		--field="$GUI_SAPARGS!$DESC_SAPARGS" "${SAPARGS//\"}"\
		--field="$GUI_SAPRUN!$DESC_SAPRUN":CHK "$SAPRUN" \
		--button="$BUT_CAN:0" --button="$BUT_LOAD:2" --button="$BUT_RUN:4" "$GEOM"
		)"
		case $? in
			0)	{
					writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN' - Exiting"
					if [ -d "$IN_SAP_COMPAT_DATA_PATH" ]; then
						rmdir "$IN_SAP_COMPAT_DATA_PATH"
					fi
				}
			;;
			2)	{
					writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_LOAD'"
					mapfile -d "|" -t -O "${#SAPARR[@]}" SAPARR < <(printf '%s' "$PROTPARTS")
					SAPGAME="${SAPARR[1]}"
					writelog "INFO" "Loading '${STLGSAPD}/${SAPGAME}.conf' and starting the gui ${FUNCNAME[0]}"
					loadCfg "${STLGSAPD}/${SAPGAME}.conf"

					if [ "$IN_SAP_COMPAT_DATA_PATH" != "$SAP_COMPAT_DATA_PATH" ]; then
						if [ -d "$IN_SAP_COMPAT_DATA_PATH" ]; then
							writelog "INFO" "${FUNCNAME[0]} - User chose an own COMPAT_DATA_PATH, removing autocreated '$IN_SAP_COMPAT_DATA_PATH'"
							rmdir "$IN_SAP_COMPAT_DATA_PATH"
						fi
					fi

					"${FUNCNAME[0]}"
				}
			;;
			4)	{
					writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_RUN' - Exiting"
					unset SAPARR
					mapfile -d "|" -t -O "${#SAPARR[@]}" SAPARR < <(printf '%s' "$PROTPARTS")
					SAPGAME="${SAPARR[1]}"
					SAPPROTON="${SAPARR[2]}"
					SAP_COMPAT_DATA_PATH="${SAPARR[3]}"
					SAPEXE="${SAPARR[4]}"
					SAPARGS="${SAPARR[5]}"
					SAPRUN="${SAPARR[6]}"

					if [ "$IN_SAP_COMPAT_DATA_PATH" != "$SAP_COMPAT_DATA_PATH" ]; then
						if [ -d "$IN_SAP_COMPAT_DATA_PATH" ]; then
							writelog "INFO" "${FUNCNAME[0]} - User chose an own COMPAT_DATA_PATH, removing autocreated '$IN_SAP_COMPAT_DATA_PATH'"
							rmdir "$IN_SAP_COMPAT_DATA_PATH"
						fi
					fi

					if [ -n "$SAPGAME" ];then
						SAPCFG="${STLGSAPD}/${SAPGAME}.conf"

						touch "$FUPDATE" "$SAPCFG"
						updateConfigEntry "SAPGAME" "$SAPGAME" "$SAPCFG"
						if [ -n "$SAPPROTON" ];then
							touch "$FUPDATE"
							updateConfigEntry "SAPPROTON" "$SAPPROTON" "$SAPCFG"
						fi
						if [ -n "$SAP_COMPAT_DATA_PATH" ];then
							touch "$FUPDATE"
							updateConfigEntry "SAP_COMPAT_DATA_PATH" "$SAP_COMPAT_DATA_PATH" "$SAPCFG"
						fi
						if [ -n "$SAPEXE" ];then
							touch "$FUPDATE"
							updateConfigEntry "SAPEXE" "$SAPEXE" "$SAPCFG"
						fi
						if [ -n "$SAPARGS" ];then
							touch "$FUPDATE"
							updateConfigEntry "SAPARGS" "$SAPARGS" "$SAPCFG"
						fi
						if [ -n "$SAPRUN" ];then
							touch "$FUPDATE"
							updateConfigEntry "SAPRUN" "$SAPRUN" "$SAPCFG"
						fi
					fi
					SapRun
				}
			;;
		esac
	}

	createProtonList X

	mkProjDir "$STLGSAPD"
	SAPGUI=1
	SAPRUN="TRUE"

	if [ -n "$1" ] && [ -z "$2" ] && [ -f "${STLGSAPD}/${1}.conf" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Loading '${STLGSAPD}/${1}.conf' silently"
		loadCfg "${STLGSAPD}/${1}.conf"
		SAPGUI=0
		SapRun
	elif [ -n "$1" ] && [ ! -f "${STLGSAPD}/${1}.conf" ]; then
		if [ "$1" == "list" ]; then
			find "$STLGSAPD" -type f -exec basename {} .conf \;
			SAPGUI=0
			SAPRUN="FALSE"
		else
			writelog "INFO" "${FUNCNAME[0]} - Using '$1' as game title"
			SAPGAME="$1"
		fi
	elif [ -n "$1" ] && [ -n "$2" ] && [ -f "${STLGSAPD}/${1}.conf" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Loading '${STLGSAPD}/${1}.conf' and starting the gui"
		loadCfg "${STLGSAPD}/${1}.conf"
		SAPGUI=1
	elif [ -z "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Only starting plain gui"
	fi

	if [ "$SAPGUI" -eq 1 ]; then
		SapGui
	fi
}

function getWinecfgExecutable {
	# Check if we have a systemwide Winecfg
	if [ -x "$(command -v "$WINECFG")" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using Winecfg found at '$WINECFG'"
		OTWINECFGEXE="$WINECFG"
	else
		# Try to use winecfg with Proton executable
		writelog "INFO" "${FUNCNAME[0]} - Trying to use Winetrickks with game Proton version"
		if [ -z "$RUNPROTON" ]; then
			writelog "WARN" "${FUNCNAME[0]} - RUNPROTON is empty - '$RUNPROTON' - Maybe this is not a Proton game?"
		else
			WINECFGBASEPATH="$(dirname "$RUNPROTON")"

			writelog "INFO" "${FUNCNAME[0]} - RUNPROTON is '$RUNPROTON'"
			writelog "INFO" "${FUNCNAME[0]} - WINECFGBASEPATH is '$WINECFGBASEPATH'"

			if [ -d "$WINECFGBASEPATH" ]; then
				OTWINECFGEXE="$( find "$WINECFGBASEPATH" -name "winecfg.exe" | head -n1 )"
				writelog "INFO" "${FUNCNAME[0]} - Using Winecfg found at '$OTWINECFGEXE'"
			else
				writelog "WARN" "${FUNCNAME[0]} - Could not find directory name for Proton version '$RUNPROTON' - This probably shouldn't happen! - Could not get Winecfg executable to run"
			fi
		fi
	fi
}

# Extracted from part of setModWine
# Does not handle Proton version mismatches but this should hopefully be handled before game launch -- a PR would be welcome for this until I get around to it :-)
function getWineBinFromProtPath {
	INPROTON="$1"

	CHECKDNWINED="$(dirname "$INPROTON")/$DBW"  # Valve Proton structure
	CHECKDNWINEF="$(dirname "$INPROTON")/$FBW"  # GE-Proton structure

	FWINEVAR=""
	if [ -f "$CHECKDNWINED" ]; then
		writelog "INFO" "${FUNCNAME[0]} - CHECKDNWINED is a file -- '${CHECKDNWINED}' -- Looks like we have a Valve Proton here"
		FWINEVAR="$CHECKDNWINED"
	elif [ -f "$CHECKDNWINEF" ]; then
		FWINEVAR="$CHECKDNWINEF"
		writelog "INFO" "${FUNCNAME[0]} - CHECKDNWINEF is a file -- '${CHECKDNWINEF}' -- Looks like we have a GE-Proton here"
	else
		writelog "ERROR" "${FUNCNAME[0]} - Could not find Wine binary for Proton '$INPROTON' - can't continue"
	fi

	echo "$FWINEVAR"
}

# These functions will always use the game Proton version instead of the Proton version in the dropdown
# I don't think there's a way for us to get the Proton version in this dropdown to use with the game
#
# Having these as primary menu buttons would mean the dialog would close and the user would have to re-open the one-time run menu to run their game
# The tradeoff for now is having them set the Proton version by changing the game version before going to the one-time menu, and then they can run Winetricks
#
# I think this is a better tradeoff than having the menu close, as the amount of users who would change the Proton version are probably minimal
# compared to the users who would be annoyed by the dialog closing



# These two winecfg and winetricks functions need to be updated to accomodate a passed in AppID from the command line
# - needs to be able to get game config / proton versions
# - handle cases where a Proton version is not set for a game that has never been launched with STL
# - abort for native games (may need to check executable for this?)
function oneTimeWinecfg {
	OTPROT="$( getProtPathFromCSV "$USEPROTON" )"
	OTWINE="$( getWineBinFromProtPath "$OTPROT" )"

	if [ -z "$GPFX" ]; then
		getGameFiles "$AID"  # Potentially fix GPFX not being set in some situations
	fi

	writelog "INFO" "${FUNCNAME[0]} - Running OneTime Winecfg with Wine '$RUNWINE'"

	if [ -z "$RUNPROTON" ]; then
		RUNPROTON="$OTPROT"  # Makes getWinecfgExecutable happy
	fi

	getWinecfgExecutable
	WINEDEBUG="-all" WINEPREFIX="$GPFX" "$OTWINE" "$OTWINECFGEXE" # GPFX is not defined on Steam Deck for some reason? Need to fix, then this should work
}

# Needs updated to accomodate a passed in AppID from the command line
function oneTimeWinetricks {
	writelog "INFO" "${FUNCNAME[0]} - Getting Winetricks binary"
	chooseWinetricks
	if [ ! -x "$(command -v "$WINETRICKS")" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Could not run one-time Winetricks because Winetricks is not installed - Skipping"
	else
		OTPROT="$( getProtPathFromCSV "$USEPROTON" )"
		OTWINE="$( getWineBinFromProtPath "$OTPROT" )"

		if [ -z "$GPFX" ]; then
			getGameFiles "$AID"  # Potentially fix GPFX not being set in some situations
		fi

		writelog "INFO" "${FUNCNAME[0]} - Running OneTime Winetricks for prefix '$GPFX'"

		WINE="$OTWINE" WINEPREFIX="$GPFX" "$WINETRICKS"  # GPFX is not defined on Steam Deck for some reason? Need to fix, then this should work
	fi
}

# Does the shared setup for one-time run commandline and GUI functions
function setOneTimeRunVars {
	if [ -n "$1" ]; then
		AID="$1"
		setAIDCfgs
	fi
	loadCfg "$STLGAMECFG"

	if [ -z "$STEAM_COMPAT_DATA_PATH" ]; then
		METCFG="$CUMETA/${AID}.conf"
		if [ -f "$METCFG" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Loading Metadata '$METCFG'"
			fixCustomMeta "$METCFG" # will be removed again later
			loadCfg "$METCFG"
		fi

		if [ -n "$WINEPREFIX" ] && [ -d "$WINEPREFIX" ]; then
			STEAM_COMPAT_DATA_PATH="${WINEPREFIX%/*}"
			writelog "INFO" "${FUNCNAME[0]} - Found STEAM_COMPAT_DATA_PATH '$STEAM_COMPAT_DATA_PATH'"
		fi
	fi

	# Since we can use OTR with native Linux games, we just warn when there is no STEAM_COMPAT_DATA_PATH
	if [ -z "$STEAM_COMPAT_DATA_PATH" ]; then
		writelog "WARN" "${FUNCNAME[0]} - STEAM_COMPAT_DATA_PATH could not be determined - This may mean we're running a native Linux game here, in which case this can be safely ignored."
		writelog "WARN" "${FUNCNAME[0]} - If you need to use a Windows executable you'll have to use One-Time Run with a Windows game, or the Windows release of this game."
	fi
}

function OneTimeRunReset {
	# Reset all One-Time Run variables with the dummy value (easier than removing them, which should be unnecessary)
	writelog "INFO" "${FUNCNAME[0]} - Restoring defaults for One Time Run variables"

	# Remove config file entries -- Blank entries will act as "(none)" for files/paths, "false" for checkboxes, and the
	# Proton version is handled already with a mismatch check
	touch "$FUPDATE"
	updateConfigEntry "OTPROTON" "DUMMY" "$STLGAMECFG"
	touch "$FUPDATE"
	updateConfigEntry "OTEXE" "DUMMY" "$STLGAMECFG"
	touch "$FUPDATE"
	updateConfigEntry "OTARGS" "DUMMY" "$STLGAMECFG"
	touch "$FUPDATE"
	updateConfigEntry "OTUSEEXEDIR" "DUMMY" "$STLGAMECFG"
	touch "$FUPDATE"
	updateConfigEntry "OTFORCEPROTON" "DUMMY" "$STLGAMECFG"
	touch "$FUPDATE"
	updateConfigEntry "OTSLR" "DUMMY" "$STLGAMECFG"

	# Unset variables to ensure values are cleared on the UI
	unset "$OTPROTON"
	unset "$OTEXE"
	unset "$OTARGS"
	unset "$OTUSEEXEDIR"
	unset "$OTFORCEPROTON"
	unset "$OTSLR"
}

# Called when a user passes arguments for onetimerun
# TODO a way to use default game Proton version, either if '--proton' is not supplied or if '--proton="default"'?
# TODO add a way to use PROTON_LOG with custom command?
function commandlineOneTimeRun {
	setOneTimeRunVars "$1"
	# Get incoming arguments
	OTRUNDIR="$( pwd )"  # Default to current script directory
	USEEXEDIR=0
	OTFORCEPROTON=0
	OTSLR=0
	OTRESET=0
	for i in "$@"; do
		case $i in
			--exe=*)
				OTEXE="$( realpath "${i#*=}" )"
				shift ;;
			--proton=*)
				# Needed for saving to work, since RUNOTPROTON gets overridden with Proton path from CSV
				RUNOTPROTON="${i#*=}"
				OTPROTON="$RUNOTPROTON"
				shift ;;
			--workingdir=*)
				PASSEDRUNDIR="${i#*=}"
				if [ -n "$PASSEDRUNDIR" ] && [ -d "$PASSEDRUNDIR" ]; then  # Ensure working directory exists
					OTRUNDIR="$PASSEDRUNDIR"
				fi
				shift ;;
			--useexedir)
				USEEXEDIR=1
				shift ;;
			--args=*)
				OTARGS="${i#*=}"
				shift ;;
			--forceproton)
				OTFORCEPROTON=1
				shift ;;
			--useslr)
				OTSLR=1
				shift ;;
			--save)
				OTSAVE="TRUE"
				shift ;;
			--default)
				OneTimeRunReset
				OTRESET=1
				shift ;;
		esac
	done

	# When default is passed, all other options are ignored, as it should be used standalone
	# (and priamrily internally for the defaults button)
	if [ "$OTRESET" -eq 1 ]; then
		return
	fi

	# Ensure EXE is given and that directory to run the exe in is valid, and also ensure we have a valid Proton version to run the exe with
	# TODO refactor to flatten
	if [ -n "$OTEXE" ] && [ -f "$OTEXE" ]; then  # Valid executable required (Windows executable or Linux executable/file/etc, not really an EXE for Linux but oh well - Naming is hard!)
		if [ "$USEEXEDIR" -eq 1 ]; then  # Use EXE dir as working dir
			OTRUNDIR="$( dirname "$OTEXE" )"
			writelog "INFO" "${FUNCNAME[0]} - Using executable directory '$OTRUNDIR' as working directory"
		fi

		if [ -d "$OTRUNDIR" ]; then  # Working directory needs to be valid
			# Don't check executable type if OTFORCEPROTON
			if [ "$OTFORCEPROTON" -eq 1 ]; then
				ISWINDOWSEXE=1
			else
				ISWINDOWSEXE="$(file "$OTEXE" | grep -c "PE32")"  # TODO how do things like .bat scripts work here?
			fi

			if [ "$ISWINDOWSEXE" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Looks like we've got a Windows executable here or the user forced Proton"
				# Ensure we have STEAM_COMPAT_DATA_PATH before we try to run a Windows executable
				if [ -z "$STEAM_COMPAT_DATA_PATH" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - Cannot run Windows executable without a STEAM_COMPAT_DATA_PATH -- Maybe you're using One-Time Run with a native Linux game?"
					echo "Cannot run Windows executable without a STEAM_COMPAT_DATA_PATH -- Maybe you're using One-Time Run with a native Linux game?"
					return
				fi
				writelog "INFO" "${FUNCNAME[0]} - Trying to find Proton version to launch executable with from given Proton name '$RUNOTPROTON'"

				# If user did not pass '--proton', then use the game's Proton version
				if [ -z "$RUNOTPROTON" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Did not get RUNOTPROTON from '--proton' option (perhaps this option was omitted?), so using per-game Proton version (USEPROTON) '$USEPROTON'"
					RUNOTPROTON="$USEPROTON"
					OTPROTON="$USEPROTON"
				fi

				RUNOTPROTON="$(getProtPathFromCSV "$RUNOTPROTON")"
				if [ ! -f "$RUNOTPROTON" ]; then
					writelog "INFO" "${FUNCNAME[0]} - RUNOTPROTON '$RUNOTPROTON' could not be found in ProtonCSV -- Attempting to resolve mismatch"
					# "1" forces fixProtonVersionMismatch to run even though ISGAME != 2 (ISGAME -eq 2 means Proton game, but ISGAME may not be 2 for One-Time Run, so we force Proton version resolution)
					if [ -n "$RUNOTPROTON" ]; then
						RUNOTPROTON="$(fixProtonVersionMismatch "RUNOTPROTON" "$STLGAMECFG" "1" X)"
					else
						writelog "INFO" "${FUNCNAME[0]} - Attemptiing to resolve Proton version mismatch for blank RUNOTPROTON '$RUNOTPROTON' by instead trying to resolve based on USEPROTON '$USEPROTON' which should hopefully not be blank"
						RUNOTPROTON="$(fixProtonVersionMismatch "USEPROTON" "$STLGAMECFG" "1" X)"
					fi

					# Update OTPROTON to make sure it matches any Proton version mismatch fixes / to have a value if One-Time Run was called without '--proton' (i.e use the Game Proton version)
					OTPROTON="$( getProtNameFromPath "$RUNOTPROTON" )"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - Given executable detected as native Linux binary, this is usually correct but if this was detected incorrectly you should force Proton!"
			fi

			if [ -f "$RUNOTPROTON" ] || [ "$ISWINDOWSEXE" -eq 0 ]; then
				if [ -f "$RUNOTPROTON" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Found Proton version '$RUNOTPROTON'"
				else
					writelog "INFO" "${FUNCNAME[0]} - Executable is native Linux, no Proton version required."
				fi

				if [ -z "$OTARGS" ]; then  # Set the custom arguments for executable
					RUNOTARGS=""
				else
					mapfile -d " " -t -O "${#RUNOTARGS[@]}" RUNOTARGS < <(printf '%s' "$OTARGS")
					writelog "INFO" "${FUNCNAME[0]} - Passing arguments to One-Time Run executable '${OTRUNARGS[*]}'"
				fi

				# NOTE: Having save here means values won't save unless a launch is successful -- This is probably ok, but just a note for future reference
				if [ "$OTSAVE" == "TRUE" ];then  # Save one-time settings to game config file -- Really only useful for OneTimeRunGUI
					writelog "INFO" "${FUNCNAME[0]} - Saving One time run settings into '$STLGAMECFG'"

					# Only save Proton version if we're using a Windows executable, otherwise we don't set a Proton version!
					if [ "$ISWINDOWSEXE" -eq 1 ]; then
						touch "$FUPDATE"
						updateConfigEntry "OTPROTON" "$OTPROTON" "$STLGAMECFG"
					fi
					touch "$FUPDATE"
					updateConfigEntry "OTEXE" "$OTEXE" "$STLGAMECFG"
					touch "$FUPDATE"
					updateConfigEntry "OTARGS" "$OTARGS" "$STLGAMECFG"
					touch "$FUPDATE"
					updateConfigEntry "OTUSEEXEDIR" "$USEEXEDIR" "$STLGAMECFG"
					touch "$FUPDATE"
					updateConfigEntry "OTFORCEPROTON" "$OTFORCEPROTON" "$STLGAMECFG"
					touch "$FUPDATE"
					updateConfigEntry "OTSLR" "$OTSLR" "$STLGAMECFG"

					# Only write out OTRUNDIR if the path, and is not the current script working directory (default path already) AND if USEEXEXIR is false (USEEXEDIR overrides OTRUNDIR)
					CFGOTRUNDIR="DUMMY"
					if [ "$USEEXEDIR" -eq 0 ] && [ -d "$OTRUNDIR" ] && [ "$OTRUNDIR" != "$( pwd )" ]; then
						CFGOTRUNDIR="$OTRUNDIR"
					fi
					touch "$FUPDATE"
					updateConfigEntry "OTRUNDIR" "$CFGOTRUNDIR" "$STLGAMECFG"
				fi

				# Run in subshell to avoid messing with current script paths
				if [ "$ISWINDOWSEXE" -eq 1 ]; then
					if [ "$OTSLR" -eq 1 ]; then
						# Get SLR for given OTR Proton
						OTSLRPROT="$( getProtNameFromPath "$RUNOTPROTON" )"
						setNonGameSLRReap "1" "$OTSLRPROT"
					fi

					NOTYPROTNAME="$( basename "$( dirname "$RUNOTPROTON" )" )"  # NOTE: This will need updated if we allow Wine as the path will be different!

					if [ -n "${SLRCMD[*]}" ] && [ "$OTSLR" -eq 1 ]; then  # Use SLR
						writelog "INFO" "${FUNCNAME[0]} - Starting '$OTEXE' with '$RUNOTPROTON' with STEAM_COMPAT_DATA_PATH '$STEAM_COMPAT_DATA_PATH' and using working directory '$OTRUNDIR' and using the Steam Linux Runtime"
						writelog "INFO" "${FUNCNAME[0]} - cd \"$OTRUNDIR\" && STEAM_COMPAT_CLIENT_INSTALL_PATH=\"${SROOT}\" STEAM_COMPAT_DATA_PATH=\"$STEAM_COMPAT_DATA_PATH\" \"${SLRCMD[*]}\" \"$RUNOTPROTON\" run \"$OTEXE\" \"${RUNOTARGS[*]}\""

						notiShow "$( strFix "$NOTY_OTRSTARTSLR" "$( basename "$OTEXE" )" "$NOTYPROTNAME" )"

						(cd "$OTRUNDIR" && STEAM_COMPAT_CLIENT_INSTALL_PATH="$SROOT" STEAM_COMPAT_DATA_PATH="$STEAM_COMPAT_DATA_PATH" "${SLRCMD[@]}" "$RUNOTPROTON" run "$OTEXE" "${RUNOTARGS[@]}")
					else  # No SLR
						writelog "INFO" "${FUNCNAME[0]} - Starting '$OTEXE' with '$RUNOTPROTON' with STEAM_COMPAT_DATA_PATH '$STEAM_COMPAT_DATA_PATH' and using working directory '$OTRUNDIR'"
						writelog "INFO" "${FUNCNAME[0]} - cd \"$OTRUNDIR\" && STEAM_COMPAT_CLIENT_INSTALL_PATH=\"${SROOT}\" STEAM_COMPAT_DATA_PATH=\"$STEAM_COMPAT_DATA_PATH\" \"$RUNOTPROTON\" run \"$OTEXE\" \"${RUNOTARGS[*]}\""

						notiShow "$( strFix "$NOTY_OTRSTART" "$( basename "$OTEXE" )" "$NOTYPROTNAME" )"

						(cd "$OTRUNDIR" && STEAM_COMPAT_CLIENT_INSTALL_PATH="$SROOT" STEAM_COMPAT_DATA_PATH="$STEAM_COMPAT_DATA_PATH" "$RUNOTPROTON" run "$OTEXE" "${RUNOTARGS[@]}")
					fi
				else  # Native Linux
					if [ "$OTSLR" -eq 1 ]; then
						setNonGameSLRReap
					fi

					if [ -n "${SLRCMD[*]}" ] && [ "$OTSLR" -eq 1 ]; then  # Use SLR
						writelog "INFO" "${FUNCNAME[0]} - Starting Native Linux program '$OTEXE' using working directory '$OTRUNDIR' and the Steam Linux Runtime"
						writelog "INFO" "${FUNCNAME[0]} - cd \"$OTRUNDIR\" && \"${SLRCMD[*]}\" \"$OTEXE\" \"${RUNOTARGS[*]}\""

						notiShow "$( strFix "$NOTY_OTRSTARTNATIVESLR" "$( basename "$OTEXE" )" )"

						(cd "$OTRUNDIR" && "${SLRCMD[@]}" "$OTEXE" "${RUNOTARGS[@]}")
					else  # No SLR
						writelog "INFO" "${FUNCNAME[0]} - Starting Native Linux program '$OTEXE' using working directory '$OTRUNDIR'"
						writelog "INFO" "${FUNCNAME[0]} - cd \"$OTRUNDIR\" && \"$OTEXE\" \"${RUNOTARGS[*]}\""

						notiShow "$( strFix "$NOTY_OTRSTARTNATIVE" "$( basename "$OTEXE" )" )"

						(cd "$OTRUNDIR" && "$OTEXE" "${RUNOTARGS[@]}")
					fi
				fi
			else
				writelog "ERROR" "${FUNCNAME[0]} - Could not find valid Proton to launch custom executable with"
				notiShow "$( strFix "$NOTY_OTRPROTINVALID" "$OTPROTON" )"
				echo "Could not find valid Proton to launch custom executable with ('$OTPROTON') -- Is it definitely installed?"
			fi
		else
			writelog "WARN" "${FUNCNAME[0]} - Working directory '$OTRUNDIR' is no valid directory -- Cannot continue"
			notiShow "$( strFix "$NOTY_OTRRUNDIRINVALID" "$OTRUNDIR" )"
			echo "Working directory '$OTRUNDIR' doesn't appear to be valid -- Does it definitely exist and have correct permissions?"

		fi
	else
		writelog "ERROR" "${FUNCNAME[0]} - One-Time Run command '$OTEXE' is not valid -- Cannot continue"
		if [ -z "$OTEXE" ]; then
			notiShow "$NOTY_OTREXEBLANK" "X"
			echo "Selected One-Time Run executable appears to be blank: '$OTEXE'"
		else
			notiShow "$( strFix "$NOTY_OTREXEINVALID" "$OTEXE" )"
			echo "Selected One-Time Run executable '$OTEXE' doesn't appear to be valid."
		fi
	fi
}


function OneTimeRunGui {
	setOneTimeRunVars "$1"
	createProtonList X
	export CURWIKI="$PPW/One-Time-Run"
	TITLE="${PROGNAME}-${FUNCNAME[0]}"
	pollWinRes "$TITLE"
	setShowPic
	if [ -z "$OTPROTON" ]; then
		OTPROTON="$USEPROTON"
	fi

	# TODO GUI looks weird because of uneven number of checkboxes, but this will be fixed once we add a checkbox for Steam Linux Runtime as well
	OTCMDS="$("$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--title="$TITLE" --separator="|" \
		--columns="2" \
		--text="$(spanFont "$GUI_ONETIMERUN" "H")" \
		--field="$GUI_OTPROTON!$DESC_OTPROTON":CB "$(cleanDropDown "${OTPROTON//\"}" "$PROTYADLIST")" \
		--field="$GUI_OTEXE!$DESC_OTEXE":FL "${OTEXE//\"}" \
		--field="$GUI_OTARGS!$DESC_OTARGS" "${OTARGS//\"}" \
		--field="$GUI_OTRFORCEPROTON!$DESC_OTRFORCEPROTON":CHK "$OTFORCEPROTON" \
		--field="$BUT_RUNWINECFG!$DESC_RUNWINECFG":FBTN "$( realpath "$0" ) wine winecfg" \
		--field="$GUI_OTRCUSTWORKINGDIR!$DESC_OTRCUSTWORKINGDIR":DIR "$OTRUNDIR" \
		--field="$GUI_OTRUSEEXEDIR!$DESC_OTRUSEEXEDIR":CHK "$OTUSEEXEDIR" \
		--field="$GUI_OTSAVE!$DESC_OTSAVE":CHK "FALSE" \
		--field="$GUI_OTRSLR!$DESC_OTRSLR":CHK "$OTSLR" \
		--field="$BUT_RUNWINETRICKS!$DESC_RUNWINETRICKS":FBTN "$( realpath "$0" ) wine onetime-winetricks" \
		--button="$BUT_CAN:0" \
		--button="$BUT_DGM:2" \
		--button="$BUT_RUNONETIMECMD:4" \
		"$GEOM"
	)"
	case $? in
		# Selected Cancel
		0)	{
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN' - Exiting"
			}
		;;
		2) {
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_DGM' - Resetting One-Time Run values"
				OneTimeRunReset
				OneTimeRunGui
		   }
		;;
		# Selected Run
		4)	{
				mapfile -d "|" -t -O "${#OTARR[@]}" OTARR < <(printf '%s' "$OTCMDS")

				OTPROTON="${OTARR[0]}"
				OTEXE="${OTARR[1]}"
				OTARGS="${OTARR[2]}"
				OTFORCEPROTON="${OTARR[3]}"
				# OTARR[4] and OTARR[9] are the WINECFG and WINETRICKS buttons
				OTCUSTWORKDIR="${OTARR[5]}"
				OTUSEEXEDIR="${OTARR[6]}"
				OTSAVE="${OTARR[7]}"
				OTSLR="${OTARR[8]}"

				writelog "INFO" "${FUNCNAME[0]} - OTPROTON is '$OTPROTON'"
				writelog "INFO" "${FUNCNAME[0]} - OTEXE is '$OTEXE'"
				writelog "INFO" "${FUNCNAME[0]} - OTARGS is '$OTARGS'"
				writelog "INFO" "${FUNCNAME[0]} - OTFORCEPROTON is '$OTFORCEPROTON'"
				writelog "INFO" "${FUNCNAME[0]} - OTCUSTWORKDIR is '$OTCUSTWORKDIR'"
				writelog "INFO" "${FUNCNAME[0]} - OTUSEEXEDIR is '$OTUSEEXEDIR'"
				writelog "INFO" "${FUNCNAME[0]} - OTSAVE is '$OTSAVE'"
				writelog "INFO" "${FUNCNAME[0]} - OTSLR is '$OTSLR'"

				OTR_FLAGARGS=( --exe="$OTEXE" --proton="$OTPROTON" --args="$OTARGS" )  # Default arguments that we'll always pass (Proton will be ignored if not Windows executable, commandlineOneTimeRun figures that bit out)

				# USEEXEDIR will take priority over custom working dir, cannot use both at the same time either
				# Default is script working directory i.e. pwd
				if [ "$OTUSEEXEDIR" == "TRUE" ]; then
					OTR_FLAGARGS+=( --useexedir )
				elif [ -n "$OTCUSTWORKDIR" ]; then
					OTR_FLAGARGS+=( --workingdir="$OTCUSTWORKDIR" )
				fi

				if [ "$OTFORCEPROTON" == "TRUE" ]; then
					OTR_FLAGARGS+=( --forceproton )
				fi

				if [ "$OTSLR" == "TRUE" ]; then
					OTR_FLAGARGS+=( --useslr )
				fi

				if [ "$OTSAVE" == "TRUE" ]; then
					OTR_FLAGARGS+=( --save )
				fi

				commandlineOneTimeRun "$1" "${OTR_FLAGARGS[@]}"
			}
		;;
	esac
}

function setOPCustPath {
	if [ -z "$CUSTOMCMD" ] || [[ "$CUSTOMCMD" =~ ${DUMMYBIN}$ ]]; then
		OPCUSTPATH="$GP"
	fi

	if [ -z "$OPCUSTPATH" ]; then
		OPCUSTPATH="$CUSTOMCMD"
	fi

	if [ -n "$OPCUSTPATH" ]; then
		export OPCUSTPATH="$OPCUSTPATH"
		writelog "INFO" "${FUNCNAME[0]} - Default path for custom exe file requester is '$OPCUSTPATH'"
	fi
}

# Build a string like 'export ENABLE_VKBASALT=1' and evaluate that string as code
# Allows us to more flexibly enable vkBasalt forks in future like vkShade
function setVulkanPostProcessor {
	if [ ! "$VULKANPOSTPROCESSOR" = "$NON" ]; then
		VULKANPOSTPROCESSOREXPORTVAR="ENABLE_${VULKANPOSTPROCESSOR^^}"

		writelog "INFO" "${FUNCNAME[0]} - Enabling Vulkan Post-Processor '$VULKANPOSTPROCESSOR' with environment with '$VULKANPOSTPROCESSOREXPORTVAR'"
		eval "export ${VULKANPOSTPROCESSOREXPORTVAR}=1"
	fi
}

function checkWinesync {
	if [ "$ENABLE_WINESYNC" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Enabling Winesync variables because 'ENABLE_WINESYNC' is '$ENABLE_WINESYNC'"
		export WINEESYNC=0
		export WINEFSYNC=0
		export WINEFSYNC_FUTEX2=0
	fi
}

function checkPrimerun {
	if [ "$USEPRIMERUN" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Enabling Primerun variables because 'USEPRIMERUN' is '$USEPRIMERUN'"
		export __NV_PRIME_RENDER_OFFLOAD=1
		export __VK_LAYER_NV_optimus=NVIDIA_only
		export __GLX_VENDOR_LIBRARY_NAME=nvidia
		export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
	fi
}

function checkZink {
	if [ "$USEZINK" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Enabling Zink variables because 'USEZINK' is '$USEZINK'"
		export __GLX_VENDOR_LIBRARY_NAME=mesa
		export MESA_LOADER_DRIVER_OVERRIDE=zink
		export GALLIUM_DRIVER=zink
	fi
}

function setCommandLaunchVars {
	if [ "$USEGAMEMODERUN" -eq 1 ]; then
		GMR="$(command -v "$GAMEMODERUN")"
	fi

	if [ "$USEOBSCAP" -eq 1 ]; then
		OBSC="$(command -v "$OBSCAP")"
	fi

	if [ "$USEGAMESCOPE" -eq 1 ]; then
		if [ "$USEMANGOAPP" -eq 1 ]; then
			if [ "$ONSTEAMDECK" -eq 1 ]; then
				if [ "$FIXGAMESCOPE" -eq 1 ]; then
					writelog "SKIP" "${FUNCNAME[0]} - Disabling USEMANGOAPP variable in Steam Deck Game Mode, because Steam Deck uses $MANGOAPP already by default"
					USEMANGOAPP=0
				else
					writelog "INFO" "${FUNCNAME[0]} - Allowing USEMANGOAPP variable in Steam Deck Desktop Mode"
					USEMANGOAPP=1
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - Not adding $GAMESCOPE to the game launch command, because $MANGOAPP is enabled, which triggers it automatically"
				USEGAMESCOPE=0
			fi
		else
			# Enable the ENABLE_GAMESCOPE_WSI environment variable if checkbox is enabled on GameScopeGui
			if [ "$USEGAMESCOPEWSI" -eq 1 ]; then
				export ENABLE_GAMESCOPE_WSI=1
			fi

			GSC="$(command -v "$GAMESCOPE")"

			gameScopeArgs "$GAMESCOPE_ARGS"  # Create GameScope args array - Is called twice because we call `setCommandLaunchVars` above and in `buildCustomCmdLaunch` it seems
		fi
	fi

	# NOTE: Primerun and Zink both set ' __GLX_VENDOR_LIBRARY_NAME', so Zink has to go after Primerun as shown to activate correctly
	checkWinesync
	checkPrimerun
	checkZink

	# This could be expanded in future as a general option to force Wayland for games/engines that support it, e.g. '-wayland' flag for unity
	if [ "$SDLUSEWAYLAND" -eq 1 ]; then
		export SDL_VIDEODRIVER=wayland
	fi

	if [ -n "$STLRAD_PFTST" ] && [ "$STLRAD_PFTST" != "none" ]; then
		writelog "INFO" "${FUNCNAME[0]} - STLRADV_PFTST is not empty or none - Exporting RADV_PERFTEST=$STLRAD_PFTST"
		export RADV_PERFTEST=$STLRAD_PFTST
	fi

	setVulkanPostProcessor
	setWineDpiScaling
}

# Used to create the launch command for games and custom commands so they can use various program functions i.e. GameScope
function buildCustomCmdLaunch {
	setCommandLaunchVars  # Checks for things like GameMode, GameScope, etc
	FINALOUTCMD=()

	# Lifted originally from `launchSteamGame`
	if [ -n "$GMR" ]; then
		if [ -n "${FINALOUTCMD[0]}" ]; then
			FINALOUTCMD=("${FINALOUTCMD[@]}" "$GMR")
		else
			FINALOUTCMD=("$GMR")
		fi
	fi

	# GameScope has to be appended before other commands
	if [ -n "$GSC" ]; then
		if [ -n "${FINALOUTCMD[0]}" ]; then
			FINALOUTCMD=("${FINALOUTCMD[@]}" "$GSC")
		else
			FINALOUTCMD=("$GSC")
		fi

		if [ -n "${FINALOUTCMD[0]}" ]; then
			FINALOUTCMD=("${FINALOUTCMD[@]}" "${GAMESCOPEARGSARR[@]}")
		fi
	fi

	# OBS capture has to go after GameScope
	if [ "$USEOBSCAP" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - USEOBSCAP is enabled - preparing $OBSCAP command"
		if [ -n "${FINALOUTCMD[0]}" ]; then
			FINALOUTCMD=("${FINALOUTCMD[@]}" "$OBSC")
		else
			FINALOUTCMD=("$OBSC")
		fi
	fi

	# MangoHud has to go inside GameScope
	if [ "$USEMANGOHUD" -eq 1 ]; then
		if [ "$MAHUARGS" != "$NON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Exporting MANGOHUD_CONFIG with $MAHU arguments '$MAHUARGS'"
			export MANGOHUD_CONFIG="$MAHUARGS"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Not exporting  MANGOHUD_CONFIG '$MAHUARGS'"
		fi

		if [ "$MAHUVAR" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Exporting MANHOGUD variable and skipping all $MAHU binary settings, because MAHUVAR is '$MAHUVAR'"
			export MANGOHUD=1
		else
			if [ -f "$MAHUBIN" ]; then
				writelog "INFO" "${FUNCNAME[0]} - $MAHU is enabled"
				if [ "$LDPMAHU" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - Preloading $MAHU"
					export LD_PRELOAD="$LD_PRELOAD $MAHUBIN"
				else
					if [ -n "${FINALOUTCMD[0]}" ]; then
						FINALOUTCMD=("${FINALOUTCMD[@]}" "$MAHUBIN")
					else
						FINALOUTCMD=("$MAHUBIN")
					fi

					# Append '--dlsym' to mangohud command -- There is also the MANGOHUD_DLSYM=1 env var but this can be set manually, and does not always work
					# i.e. Torchlight II works with '--dlsym' but not 'MANGOHUD_DLSYM=1'
					if [ "$MAHUDLSYM" -eq 1 ]; then
						FINALOUTCMD=("${FINALOUTCMD[@]}" "--dlsym")
					fi
				fi
			else
				writelog "WARN" "${FUNCNAME[0]} - $MAHU binary not found - disabling"
				USEMANGOHUD=0
			fi
		fi
	fi
}

function launchCustomProg {
	if [ -n "$1" ]; then
		CUSTOMCMD="$WICO"
	fi

	if [ -z "$CUSTOMCMD" ] || [[ "$CUSTOMCMD" =~ ${DUMMYBIN}$ ]]; then
		writelog "INFO" "${FUNCNAME[0]} - CUSTOMCMD variable is empty - opening file requester"
		fixShowGnAid

		export CURWIKI="$PPW/Custom-Program"
		TITLE="${PROGNAME}-OpenCustomProgram"
		pollWinRes "$TITLE"

		ZCUST="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--title="$TITLE" \
		--text="$(spanFont "$SGNAID - $GUI_SELECTCUSTOMEXE" "H")" \
		--field=" ":LBL " " \
		--field="$GUI_SELECTEXE":FL "${OPCUSTPATH/#-/ -}" "$GEOM")"

		if [ -n "$ZCUST" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '${ZCUST//|/}' selected for CUSTOMCMD - updating configfile '$STLGAMECFG'"
			updateConfigEntry "CUSTOMCMD" "${ZCUST//|/}" "$STLGAMECFG"

			CUSTOMCMD="${ZCUST//|/}"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Nothing selected for CUSTOMCMD - skipping"
			if [ "$ONLY_CUSTOMCMD" -eq 1 ]; then
				writelog "SKIP" "${FUNCNAME[0]} - ONLY_CUSTOMCMD is enabled - bailing out here"
				closeSTL " ######### STOP EARLY '$PROGNAME $PROGVERS' #########"
				exit
			else
				writelog "SKIP" "${FUNCNAME[0]} - Continuing with the main game"
				return
			fi
		fi
	fi

	if [ -z "$CUSTOMCMD" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - CUSTOMCMD variable is empty - but it shouldn't be empty here!"
	fi

	CHCUSTDIR=0
	if [ -n "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using '$WICO' as custom command"
		LACO="$WICO"
		CUSTCOM="$WICO"
	elif [ -x "$(command -v "$CUSTOMCMD")" ]; then
		writelog "INFO" "${FUNCNAME[0]} - '$CUSTOMCMD' found"
		LACO="$CUSTOMCMD"
		CUSTCOM="$(command -v "$CUSTOMCMD")"
		CHCUSTDIR=1
	else
		writelog "INFO" "${FUNCNAME[0]} - '$CUSTOMCMD' not found - searching in gamedir"

		if [ -f "$EFD/$CUSTOMCMD" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$CUSTOMCMD' was found in gamedir '$EFD'"
			LACO="$EFD/$CUSTOMCMD"
			CUSTCOM="$EFD/$CUSTOMCMD"
		else
			writelog "INFO" "${FUNCNAME[0]} - '$CUSTOMCMD' also not in '$EFD/$CUSTOMCMD' - checking if absolute path was provided"

			if [ -f "$CUSTOMCMD" ]; then
				writelog "INFO" "${FUNCNAME[0]} - '$CUSTOMCMD' is absolute path"
				LACO="$CUSTOMCMD"
				CUSTCOM="$CUSTOMCMD"
				CHCUSTDIR=1
			else
				writelog "INFO" "${FUNCNAME[0]} - CUSTOMCMD file '$CUSTOMCMD' not found - opening file requester"
				fixShowGnAid
				export CURWIKI="$PPW/Custom-Program"
				TITLE="${PROGNAME}-OpenCustomProgram"
				pollWinRes "$TITLE"

				ZCUST="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
				--title="$TITLE" \
				--text="$(spanFont "$SGNAID - $GUI_SELECTCUSTOMEXE" "H")" \
				--field=" ":LBL " " \
				--field="$GUI_SELECTEXE":FL "${OPCUSTPATH/#-/ -}" "$GEOM")"

				if [ -n "$ZCUST" ]; then
					writelog "INFO" "${FUNCNAME[0]} - '${ZCUST//|/}' selected for CUSTOMCMD - updating configfile '$STLGAMECFG'"
					updateConfigEntry "CUSTOMCMD" "${ZCUST//|/}" "$STLGAMECFG"
					LACO="${ZCUST//|/}"
					CUSTCOM="${ZCUST//|/}"
					CUSTOMCMD="${ZCUST//|/}"
					CHCUSTDIR=1
				else
					writelog "SKIP" "${FUNCNAME[0]} - Nothing selected for CUSTOMCMD - skipping"
					if [ "$ONLY_CUSTOMCMD" -eq 1 ]; then
						writelog "SKIP" "${FUNCNAME[0]} - ONLY_CUSTOMCMD is enabled - bailing out here"
						closeSTL " ######### STOP EARLY $PROGNAME $PROGVERS #########"
						exit
					else
						writelog "SKIP" "${FUNCNAME[0]} - Continuing with the main game"
						return
					fi
				fi
			fi
		fi
	fi

	if [ -z "$LACO" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - ERROR - launch command empty- skipping launch"
	else
		startSBSVR &

		if [ "$CHCUSTDIR" -eq 1 ]; then
			CUSTDIR="$(dirname "$CUSTOMCMD")"
			cd "$CUSTDIR" >/dev/null || return
			writelog "INFO" "${FUNCNAME[0]} - Changed pwd into the custom directory '$PWD'"
		fi

		# Putting logic here means we have FINALOUTCMD for Wine/Proton *and* native games
		if [ "$EXTPROGS_CUSTOMCMD" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - EXTPROGS_CUSTOMCMD was set to 1, so checking for custom arguments like MangoHUD and GameScope"
			buildCustomCmdLaunch  # Create FINALOUTCMD
			writelog "INFO" "${FUNCNAME[0]} - Generated arguments for custom command are now '${FINALOUTCMD[*]}'"
		fi

		# Use Wine/Proton with a custom command if it is detected as a Windows executable, a batch script (.bat), a Windows shortcut (.lnk), or if the user forces Proton
		# Cannot always rely on `file` to return `PE32` even for Windows executables -- See #710 (seems to be when exe files are built on Linux they are not PE32)
		if [ "$(file "$CUSTCOM" | grep -c "PE32")" -eq 1 ] || grep -q ".bat" <<< "$CUSTCOM" || grep -q ".lnk" <<< "$CUSTCOM" || [ "$CUSTOMCMDFORCEWIN" -eq 1 ]; then
			if [ "$CUSTOMCMDFORCEWIN" -eq 1 ]; then
				# Force custom command to use Wine/Proton, even if we do not detect it as a valid Windows binary
				writelog "INFO" "${FUNCNAME[0]} - CUSTOMCMDFORCEWIN is '$CUSTOMCMDFORCEWIN' - User wants to force this custom command as a Windows program"
				if [ "$(file "$CUSTCOM" | grep -c "PE32")" -eq 0 ]; then
					writelog "WARN" "${FUNCNAME[0]} - Custom command does not appear to be a Windows program by normal TinkerGame checks, but CUSTOMCMDFORCEWIN was enabled, so using Proton anyway"
				else
					writelog "INFO" "${FUNCNAME[0]} - Custom command seems to be a Windows program anyway even though CUSTOMCMDFORCEWIN was enabled"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - '$CUSTCOM' seems to be a MS Windows program - starting through proton"
			fi

			if [ "$USEWICO" -eq 1 ] && [ "$(file "$CUSTCOM" | grep -c "(console)")" -eq 1 ]; then  # Command line Wine/Proton custom program
				writelog "INFO" "${FUNCNAME[0]} - '$CUSTCOM' seems to be a MS console program - starting using '$WICO'"
				if [ "$FORK_CUSTOMCMD" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - FORK_CUSTOMCMD is set to 1 - forking the custom program in background and continue"
					extProtonRun "FC" "$LACO" "$CUSTOMCMD_ARGS" "" "${CUSTOMCMD_USESLR}"
				elif [ "$ONLY_CUSTOMCMD" -eq 1 ] && [ -n "${FINALOUTCMD[*]}" ]; then
					writelog "INFO" "${FUNCNAME[0]} - ONLY_CUSTOMCMD is set to 1 and we have some arguments in FINALOUTCMD - passing to extProtonRun to build a valid start command"
					extProtonRun "R" "$LACO" "$CUSTOMCMD_ARGS" "$FINALOUTCMD" "${CUSTOMCMD_USESLR}"  # extProtonRun will handle adding the FINALOUTCMD args to
				else
					extProtonRun "RC" "$LACO" "$CUSTOMCMD_ARGS" "" "${CUSTOMCMD_USESLR}"
				fi
			else  # GUI Wine/Proton program
				writelog "INFO" "${FUNCNAME[0]} - '$CUSTCOM' seems to be a MS gui program - starting regularly"

				if [ "$FORK_CUSTOMCMD" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - FORK_CUSTOMCMD is set to 1 - forking the custom program in background and continue"
					extProtonRun "F" "$LACO" "$CUSTOMCMD_ARGS" "" "${CUSTOMCMD_USESLR}"
				elif [ "$ONLY_CUSTOMCMD" -eq 1 ] && [ -n "$FINALOUTCMD" ]; then
					writelog "INFO" "${FUNCNAME[0]} - ONLY_CUSTOMCMD is set to 1 and we have some arguments in FINALOUTCMD - passing to extProtonRun to build a valid start command"
					extProtonRun "R" "$LACO" "$CUSTOMCMD_ARGS" "${FINALOUTCMD[*]}" "${CUSTOMCMD_USESLR}" "${CUSTOMCMD_USESLR}"  # extProtonRun will handle adding the FINALOUTCMD args
				else
					extProtonRun "R" "$LACO" "$CUSTOMCMD_ARGS" "" "${CUSTOMCMD_USESLR}"
				fi
			fi
		else  # Native custom command
			writelog "INFO" "${FUNCNAME[0]} - Seems like we may have a Linux executable here"

			# Arguments to append to executable
			if [ -z "$CUSTOMCMD_ARGS" ] || [ "$CUSTOMCMD_ARGS" == "$NON" ]; then
				RUNCUSTOMCMD_ARGS=""
			else
				writelog "INFO" "${FUNCNAME[0]} - Starting the custom program '$CUSTOMCMD' with args: '$CUSTOMCMD_ARGS'"
				mapfile -d " " -t -O "${#RUNCUSTOMCMD_ARGS[@]}" RUNCUSTOMCMD_ARGS < <(printf '%s' "$CUSTOMCMD_ARGS")
			fi

			# Custom program args to preceed executable (e.g. /usr/bin/gamemode /usr/bin/gamescope -- ./game.sh)
			if [ -z "$FINALOUTCMD" ]; then
				writelog "INFO" "${FUNCNAME[0]} - No external program args here it seems"
				RUNEXTPROGRAMARGS=( "" )  # Initialise to array with empty string so we don't have to do checks in each if block
			else
				writelog "INFO" "${FUNCNAME[0]} - Looks like we got some external program args, '${FINALOUTCMD[*]}'"
				mapfile -d " " -t -O "${#RUNEXTPROGRAMARGS[@]}" RUNEXTPROGRAMARGS < <(printf '%s' "${FINALOUTCMD[*]}")
			fi

			FWAIT=2

			# TODO should respect selected SLR once #1087 is implemented
			if [ "$CUSTOMCMD_USESLR" -eq 1 ]; then
				unset "${SLRCMD[@]}"

				writelog "INFO" "${FUNCNAME[0]} - Steam Linux Runtime enabled, attempting to fetch Steam Linux Runtime for native Custom Command"
				# "2" is the FORCESLRTYPE, meaning we want to force to get the native SLR -- We do this in case we are trying to launch a native custom command with a Proton title
				# In this case, setSLRReap is going to have the Proton SLR vars set from the game launch, so we need to force it here to use the native SLR
				setNonGameSLRReap "2"
			fi

			# TODO this is the exact same logic as in extProtonRun (except the log messages are slightly different), is there any way to share it?
			if [ -n "${SLRCMD[*]}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Gotten Steam Linux Runtime for native launch, using RUNEXTPROGRAMARGS array to contain it and add it to launch command"

				OLDRUNEXTPROGRAMARGS=( "${RUNEXTPROGRAMARGS[@]}" )

				unset "${RUNEXTPROGRAMARGS[@]}"
				RUNEXTPROGRAMARGS=( "${SLRCMD[@]}" )

				# OLDRUNEXTPROGRAMARGS should only contain one item, the passed args for the custom command
				# if the first item here is not empty, assume we have to include the old pass args in the new array
				#
				# if blank, it means OLDRUNEXTPROGRAMARGS was most likely empty (or started with a blank element, which would cause a crash anyway)
				# so we can just create RUNEXTPROGRAMARGS with the SLR as the only element
				if [ -n "${OLDRUNEXTPROGRAMARGS[0]}" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Seems like some arguments were given to the custom command, including them alongside the Steam Linux Runtime arguments"
					RUNEXTPROGRAMARGS+=( "${OLDRUNEXTPROGRAMARGS[@]}" )
				fi
			elif [ -z "${SLRCMD[*]}" ] && [ "$CUSTOMCMD_USESLR" -eq 1 ]; then
				writelog "WARN" "${FUNCNAME[0]} - Attempted to fetch Steam Linux Runtime but failed to find one!"
			fi
			unset "${SLRCMD[@]}"

			# Launch native custom command
			NATIVEPROGNAME="$( basename "$LACO" )"
			if [ -n "$1" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Starting only the '$WICO' with command: '$LACO'"
				"${RUNEXTPROGRAMARGS[@]}" "$LACO"
				writelog "STOP" "######### CLEANUP #########"
				closeSTL "######### DONE - $PROGNAME $PROGVERS #########"
				exit
			else
				writelog "INFO" "${FUNCNAME[0]} - '$CUSTCOM' doesn't seem to be a MS Windows exe - regular start (without further analysing)"
				if [ "$FORK_CUSTOMCMD" -eq 1 ]; then  # Forked native custom program
					writelog "INFO" "${FUNCNAME[0]} - FORK_CUSTOMCMD is set to 1 - forking the custom program in background and continue"
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						writelog "INFO" "${FUNCNAME[0]} - \"${RUNEXTPROGRAMARGS[*]}\" \"${LACO}\" \"${RUNCUSTOMCMD_ARGS[*]}\""
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_NATIVE" "$NATIVEPROGNAME" )"; "${RUNEXTPROGRAMARGS[@]}" "$LACO" "${RUNCUSTOMCMD_ARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					else
						writelog "INFO" "${FUNCNAME[0]} - \"${LACO}\" \"${RUNCUSTOMCMD_ARGS[*]}\""
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_NATIVE" "$NATIVEPROGNAME" )"; "$LACO" "${RUNCUSTOMCMD_ARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					fi
				else  # Regular native executable
					writelog "INFO" "${FUNCNAME[0]} - Starting native custom command regularly"
					notiShow "$( strFix "$NOTY_CUSTPROG_REG_NATIVE" "$NATIVEPROGNAME" )"
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						writelog "INFO" "${FUNCNAME[0]} - \"${RUNEXTPROGRAMARGS[*]}\" \"${LACO}\" \"${RUNCUSTOMCMD_ARGS[*]}\""
						"${RUNEXTPROGRAMARGS[@]}" "$LACO" "${RUNCUSTOMCMD_ARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					else
						writelog "INFO" "${FUNCNAME[0]} - \"${LACO}\" \"${RUNCUSTOMCMD_ARGS[*]}\""
						"$LACO" "${RUNCUSTOMCMD_ARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					fi
				fi
			fi
		fi

		if [ "$CHCUSTDIR" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Changing pwd into previous directory"
			cd - >/dev/null || return
		fi
	fi
}

function getGameFiles {
	AID="$1"

	if [ -z "$APPMAFE" ]; then
		APPMAFE="$(listAppManifests | grep -m1 "${AID}.acf")"
	fi

	if [ -f "$APPMAFE" ]; then
		if [ -z "$GPFX" ]; then
			GPFX="$(dirname "$APPMAFE")/$CODA/$1/pfx"
		fi

		if [ -z "$EFD" ]; then
			EFD="$(getGameDirFromAM "$APPMAFE")"
		fi

		if [ -z "$STECOSHAPA" ]; then
			STECOSHAPA="${APPMAFE%/*}/shadercache/$AID"
		fi
	fi
}

function createCustomCfgs {
	if [ ! -f "$GAMECUSTVARS" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating emtpy game-specific config '$GAMECUSTVARS' for user defined custom variables"
		touch "$GAMECUSTVARS"
	fi

	if [ ! -f "$GLOBCUSTVARS" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating emtpy global config '$GLOBCUSTVARS' for user defined custom variables"
		touch "$GLOBCUSTVARS"
	fi

}

function loadCustomVars {
	if [ -s "$GLOBCUSTVARS" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Loading user defined custom variables from global config '$GLOBCUSTVARS'"
		loadCfg "$GLOBCUSTVARS"
	else
		writelog "INFO" "${FUNCNAME[0]} - Empty global config '$GLOBCUSTVARS' for user defined custom variables not loaded"
	fi

	if [ -s "$GAMECUSTVARS" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Loading user defined custom variables from game-specific config '$GAMECUSTVARS'"
		loadCfg "$GAMECUSTVARS"
	else
		writelog "INFO" "${FUNCNAME[0]} - Empty game-specific config '$GAMECUSTVARS' for user defined custom variables not loaded"
	fi
}

function setGameFilesArray {
	unset GamDesc
	unset GamFiles
	if [ "$EFD" != "." ] && [ -d "$EFD" ]; then
		GamDesc+=("$GUI_GD")
		GamFiles+=("$EFD")
	fi

	if [ -d "$GPFX" ]; then
		GamDesc+=("$GUI_WP")
		GamFiles+=("$GPFX")
	fi

	if [ -f "$APPMAFE" ]; then
		GamDesc+=("$GUI_AM")
		GamFiles+=("$APPMAFE")
	fi

	if [ -d "$STECOSHAPA" ]; then
		GamDesc+=("$GUI_SP")
		GamFiles+=("$STECOSHAPA")
	fi

	if [ -n "$STLDXVKCFG" ]; then
		GamDesc+=("$GUI_DXVKCFG")
		GamFiles+=("$STLDXVKCFG")
	fi

	if [ -f "$MAHUCID/${AID}.conf" ]; then
		GamDesc+=("$GUI_MANGOHUDGAMECFG")
		GamFiles+=("$MAHUCID/${AID}.conf")
	fi

	# Open /dev/shm/tinkergame directory
	if [ -d "$STLSHM" ]; then
		GamDesc+=("$GUI_STLSHMDIR")
		GamFiles+=("$STLSHM")
	fi

	# Open logfile at /dev/shm/tinkergame/tinkergame.log
	if [ -f "$TEMPLOG" ]; then
		GamDesc+=("$GUI_STLSHMLOG")
		GamFiles+=("$TEMPLOG")
	fi

	# Open game logging directory at, by default, STLCFGDIR/logs/tinkergame
	if [ -d "$LOGDIR" ]; then
		GamDesc+=("$GUI_STLPERGAMELOGSDIR")
		GamFiles+=("$LOGDIR")
	fi

	createCustomCfgs

	GamDesc+=("$GUI_STLCVFILE")
	GamFiles+=("$GAMECUSTVARS")

	GamDesc+=("$GUI_STLGLBCVFILE")
	GamFiles+=("$GLOBCUSTVARS")
}

function GameFilesMenu {
	if [ -n "$1" ]; then
		getGameFiles "$1"
	else
		setGameVars
	fi

	fixShowGnAid

	setGameFilesArray

	if [ "${#GamFiles[@]}" -ge 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Found ${#GamFiles[@]} available game files and directories - opening menu"
		export CURWIKI="$PPW/Game-Files"
		TITLE="${PROGNAME}-Game-Files"
		pollWinRes "$TITLE"

		setShowPic
		OPFILES="$(for i in "${!GamFiles[@]}"; do printf "FALSE\n%s\n%s\n" "${GamDesc[$i]}" "${GamFiles[$i]}"; done | \
		"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist --column=Open --column=Description --column=Path --separator="\n" --print-column="3" \
		--text="$(spanFont "$(strFix "$GUI_GAFIDIALOG" "$SGNAID")" "H")" --title="$TITLE" --button="$BUT_CAN:0" --button="$BUT_SELECT:2" "$GEOM")"
		case $? in
			0) writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN' - Cancelling selection"
			;;
			2)
				if [ -x "$(command -v "$XDGO" 2>/dev/null)" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Selected Open - Opening selected files and directories using '$XDGO'"
					mapfile -t -O "${#OpArr[@]}" OpArr <<< "$OPFILES"
					if [ "${#OpArr[@]}" -ge 1 ]; then
						while read -r gafi; do
							if [ -n "$gafi" ]; then
								if [ "$gafi" == "$STLDXVKCFG" ] && [ ! -f "$STLDXVKCFG" ]; then
									writelog "INFO" "${FUNCNAME[0]} - Creating blank game-specific DXVK config in '$STLDXVKCFG' for user-defined DXVK configuration options"
									echo "## $(strFix "$STLDXVKCFG_WARNING" "$DXVKURL")" > "$STLDXVKCFG"
									if [ "$USE_STLDXVKCFG" -eq 0 ]; then
										writelog "INFO" "${FUNCNAME[0]} - Enabling USE_STLDXVKCFG automatically, because the user selected to open the config file '$STLDXVKCFG'"
										USE_STLDXVKCFG=1
										touch "$FUPDATE"
										updateConfigEntry "USE_STLDXVKCFG" "$USE_STLDXVKCFG" "$STLGAMECFG"
									fi
								fi
								"$XDGO" "$gafi"
							fi
						done <<< "$(printf "%s\n" "${OpArr[@]}")"
						unset OpArr
					else
						writelog "SKIP" "${FUNCNAME[0]} - Nothing selected"
					fi
				else
					writelog "SKIP" "${FUNCNAME[0]} - '$XDGO' not found - can't open the directory"
				fi
			;;
		esac
	else
		writelog "SKIP" "${FUNCNAME[0]} - Could not find any game files"
	fi
}

function DxvkHudPick {
	if [ -n "$1" ]; then
		AID="$1"
		setAIDCfgs
	fi

	if [ ! -f "$STLGAMECFG" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Game config '$STLGAMECFG' not found - exiting"
	else
		DXVKHUDLIST="1,devinfo,fps,frametimes,submissions,drawcalls,pipelines,memory,gpuload,version,api,compiler,samplers,full"

		writelog "INFO" "${FUNCNAME[0]} - LoadCfg: $STLGAMECFG"
		loadCfg "$STLGAMECFG"

		unset CURDXH

		if [ "$DXVK_HUD" == "0" ]; then
			declare -a CURDXH
		else
			mapfile -d " " -t -O "${#CURDXH[@]}" CURDXH <<< "$(printf '%s\n' "$DXVK_HUD")"
		fi
		fixShowGnAid
		export CURWIKI="$PPW/Dxvk-Hud-Options"
		TITLE="${PROGNAME}-DXVK-Hud-Options"
		pollWinRes "$TITLE"

		setShowPic

		DXHUDOPTS="$(
		while read -r dxline; do
			if [[ "${CURDXH[*]}" =~ $dxline ]]; then
				echo TRUE
			else
				echo FALSE
			fi
			echo "$dxline"
		done <<< "$(tr ',' '\n' <<< "$DXVKHUDLIST")"	 | \
		"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist --column="$GUI_ADD" --column="$GUI_DXH" --separator="" --print-column="2" \
		--text="$(spanFont "$(strFix "$GUI_DXHDIALOG" "$SGNAID")" "H")" --title="$TITLE" "$GEOM")"

		if [ -n "$DXHUDOPTS" ]; then
			unset DXVK_HUD
			while read -r line; do
				DXVK_HUD="${DXVK_HUD},$line"
			done <<< "$DXHUDOPTS"
			DXVK_HUD="${DXVK_HUD#*[[:blank:]]}"
			DXVK_HUD="${DXVK_HUD#*,}"
			DXVK_HUD="${DXVK_HUD%*[[:blank:]]}"
			touch "$FUPDATE"
			updateConfigEntry "DXVK_HUD" "$DXVK_HUD" "$STLGAMECFG"
		else
			writelog "INFO" "${FUNCNAME[0]} - Nothing selected"
			touch "$FUPDATE"
			DXVK_HUD="0"
			updateConfigEntry "DXVK_HUD" "0" "$STLGAMECFG"
		fi

		if [ -n "$2" ]; then
			"$2" "$AID" "${FUNCNAME[0]}"
		fi
	fi
}

