#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function setflatpak {
	if [ -n "$FLATPAK_ID" ] && [ "$FLATPAK_ID" == "com.valvesoftware.Steam" ]; then
		writelog "INFO" "${FUNCNAME[0]} - seems like flatpak is used, because variable 'FLATPAK_ID' exists and points to 'com.valvesoftware.Steam'"
		INFLATPAK=1
	else
		writelog "INFO" "${FUNCNAME[0]} - started $PROGNAME from ${0}"
	fi
}

# GDK_BACKEND can be either x11 or wayland -- User may want, in some instances, to force X11 over defaulting to Wayland for compatibility
# Option to force Yad to use XWayland is on Global Menu
function setGDKBackend {
	if [ "$XDG_SESSION_TYPE" == "wayland" ] || [ -z "$XDG_SESSION_TYPE" ]; then
		if [ "$YADFORCEXWAYLAND" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - XDG_SESSION_TYPE is either Wayland or undefined ('$XDG_SESSION_TYPE'), and the user chose to force XWayland, so setting GDK_BACKEND=x11"
			export GDK_BACKEND=x11  # May affect other programs launched with STL but we'll see, we may need a way to store the OG value and default it back somehow if this causes problems i.e. when Wine gets Wayland support, or for native games that may use this
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - XDG_SESSION_TYPE is defined and is not Wayland, it is '$XDG_SESSION_TYPE' - No need to set GDK_BACKEND=x11 as it will already default to X11"
	fi
}

# This has the side effect of being called everytime on a local install run, but since the scriptdir of a local install can change, It Has To Be This Way
function setLocalInstall {
	SCRIPTDIR="$( realpath "$0" )"
	SCRIPTDIR="${SCRIPTDIR%/*}"
	# If not on Steam Deck or Flatpak, and we don't have a system config directory, assume we have a non-root local install and set/update config folder structure to match
	if [ "$ONSTEAMDECK" -eq 0 ] && [ ! -d "$SYSTEMSTLCFGDIR" ] && [ "$INFLATPAK" -eq 0 ]; then  # Check if "$SYSTEMSTLCFGDIR" doesn't exist because the user could be running the script for testing but have a global install
		writelog "INFO" "${FUNCNAME[0]} - Looks like we have a non-root local install here - Updating paths..."
		# If no "$SYSTEMSTLCFGDIR" directory, assume it was looking in `/usr/something` for configs (where they would be on a root install) - but since that folder doesn't exist, set it to the scriptdir
		SYSTEMSTLCFGDIR="$SCRIPTDIR"
	else
		writelog "INFO" "${FUNCNAME[0]} - Looks like we don't have a local non-root install"
	fi

	# Only update if we have an existing config file, don't call `updateConfigEntry` on non-existent file
	# Running this block here means we can update existing configs if the user installs system-wide again later or switches between
	if [ -f "$STLDEFGLOBALCFG" ]; then
		touch "$FUPDATE"
		updateConfigEntry "GLOBALCOLLECTIONDIR" "$SYSTEMSTLCFGDIR/collections" "$STLDEFGLOBALCFG"
		updateConfigEntry "GLOBALMISCDIR" "$SYSTEMSTLCFGDIR/misc" "$STLDEFGLOBALCFG"
		updateConfigEntry "GLOBALSBSTWEAKS" "$SYSTEMSTLCFGDIR/sbstweaks" "$STLDEFGLOBALCFG"
		updateConfigEntry "GLOBALTWEAKS" "$SYSTEMSTLCFGDIR/tweaks" "$STLDEFGLOBALCFG"
		updateConfigEntry "GLOBALEVALDIR" "$SYSTEMSTLCFGDIR/eval" "$STLDEFGLOBALCFG"
		updateConfigEntry "GLOBALSTLLANGDIR" "$SYSTEMSTLCFGDIR/lang" "$STLDEFGLOBALCFG"
		updateConfigEntry "GLOBALSTLGUIDIR" "$SYSTEMSTLCFGDIR/guicfgs" "$STLDEFGLOBALCFG"
	fi
}

function removeEmptyFiles {
	REFCHECKDIR="$1"
	writelog "INFO" "${FUNCNAME[0]} - Removing empty files from '$REFCHECKDIR'"
	for STLFILE in "$REFCHECKDIR/"*; do
		if ! [ -s "$STLFILE" ]; then
			rm "$STLFILE" &>/dev/null
		fi
	done
}

# Determine if we have a Non-Steam Game based on some observed behaviour:
# - All Steam applications pass a SteamAppId and SteamOverlayGameId environment variable
# - These two values are equal for Steam games/apps (Native+Proton)
#   - There is also SteamGameId, which is the same for Steam games/apps (SteamAppId == SteamGameId == SteamOverlayGameId)
# - For Non-Steam Games, SteamAppId and SteamGameId are equal, but SteamOverlayGameId is different and a very long number compared to regular Non-Steam AppIds
#   - This option is still passed even if the Steam Overlay is disabled
# - Therefore if SteamAppId and SteamOverlayGameId don't match, we can assume we have a Non-Steam Game
#   - There is a chance these values could match if a user somehow manages to accidentally (or purposefully) set the values to be the same, but in 99% of cases this should be sufficient
# - When launching games with TinkerGame from the commandline, SteamOverlayGameId probably won't be set
function haveNonSteamGame {
	# shellcheck disable=SC2154		# SteamOverlayGameId comes from Steam
	if [ -z "$SteamOverlayGameId" ]; then
		return 1  # No SteamOverlayGameId, prevents false-positive when running from commandline
	elif [ "$SteamAppId" != "$SteamOverlayGameId" ]; then
		return 0
	else
		return 1
	fi
}

##################

function main {

	initShmStl
	restoreGtkCss
	rm "$TEMPLOG" "$WINRESLOG" "$PRELOG" "$APPMALOG" "$GGDLOG" 2>/dev/null
	touch "$PRELOG"
	mkProjDir "$LOGDIRID"
	setflatpak

	USS="${PREFIX}/share/steam"
	if [ "$INFLATPAK" -eq 1 ]; then
		USS="/app/share/steam"
	fi
	SYSSTEAMCOMPATOOLS="$USS/$CTD"

	SCRIPTDIR="$( realpath "$0" )"
	SCRIPTDIR="${SCRIPTDIR%/*}"

	initAID "$@"
	setAIDCfgs

	# Empty LD_PRELOAD before the fork-heavy logging below (loadLanguage and the rest
	# of main). When STL runs as a compatibility tool with the Steam overlay enabled,
	# Steam preloads gameoverlayrenderer.so into this shell via LD_PRELOAD. Its atfork
	# handler deadlocks the short-lived subprocesses writelog spawns, so STL hangs here
	# and never launches the game (Steam sits at "running"). saveOrgVars/emptyVars
	# already clear LD_PRELOAD, but not until after getCurrentCommandline further down,
	# which is too late. Save the original now so restoreOrgVars still gives the overlay
	# back to the game at launch.
	ORG_LD_PRELOAD="${ORG_LD_PRELOAD-${LD_PRELOAD-}}"
	LD_PRELOAD=""

	writelog "INFO" "${FUNCNAME[0]} - Current TinkerGame working directory is '$( pwd )'"

	# Respect language choice asap in running (uses correct language during Steam Deck install)
	# Try and load either from langfile directory or `lang=` argument (prioritising lang arguments) - Default if we don't get a valid `$STLLANG`
	loadLanguage "$@"
	if [ -z "$STLLANG" ]; then
		loadLangFile "$STLDEFLANG"
	fi

	# Check quiet mode to hide notifier
	STLQUIET=0
	if echo "$@" | grep -qow '\-q'; then
		writelog "INFO" "${FUNCNAME[0]} - Quiet mode enabled with '-q', suppressing notifier for this execution"
		export STLQUIET=1
		USENOTIFIER=0
	fi

	steamdedeckt
	setLocalInstall
	getCurrentCommandline "$@"  # Maybe pass args with removed '-q' flag in the above if block
	saveOrgVars
	emptyVars "O"

	if haveNonSteamGame && [ -n "$SteamAppId" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Looks like we have a Non-Steam Game but we have SteamAppId defined -- This has been observed to cause crashes, please remove it from your game folder!"
	elif haveNonSteamGame ; then
		writelog "INFO" "${FUNCNAME[0]} - Looks like we have a Non-Steam Game here, no extra steps but if this is NOT a Non-Steam Game, please report this incorrect detection as a bug"
	fi

    # Notify success on Steam Deck
	if [ "$ONSTEAMDECK" -eq 1 ] && [ "$STEAMDECKSTEAMRUN" -eq 0 ]; then
		printf '\n'
		if [ "$STEAMDECKDIDINSTALL" -eq 1 ]; then
			INSTALLEDPROGVERS="$( grep -i "^PROGVERS=.*." "$PREFIX/tinkergame" | cut -d '"' -f 2 )"
			if [ "$STEAMDECKWASUPDATE" -eq 1 ]; then
				strFix "$NOTY_STEAMDECK_UPDATE_SUCCESS!" "$INSTALLEDPROGVERS"  # Update success w/ version
				notiShow "$(strFix "$NOTY_STEAMDECK_UPDATE_SUCCESS" "$INSTALLEDPROGVERS")" "X"
			else
				strFix "$NOTY_STEAMDECK_INSTALL_SUCCESS!" "$INSTALLEDPROGVERS"  # Install success w/ version
				notiShow "$(strFix "$NOTY_STEAMDECK_INSTALL_SUCCESS" "$INSTALLEDPROGVERS")" "X"
			fi
		else
			# Show install finished if no STL install files were modified (currently only for offline installs where existing install == install files)
			echo "$NOTY_STEAMDECK_INSTALL_FINISH!"
			notiShow "$NOTY_STEAMDECK_INSTALL_FINISH" "X"
		fi
	fi

	writelog "START" "######### Initializing Game Launch $AID using $PROGNAME $PROGVERS #########" "P"

	if [ -f "$STLDEFGLOBALCFG" ] && grep -q "^RESETLOG=\"1\"" "$STLDEFGLOBALCFG"; then
		if [ -f "$PRELOG" ]; then
			mv "$PRELOG" "$LOGFILE"
		else
			rmOldLog
			rm "$PRELOG" 2>/dev/null
		fi
		writelog "INFO" "${FUNCNAME[0]} - Starting with a clean log"  # from here the '$LOGFILE' is written directly
	fi

	writelog "INFO" "${FUNCNAME[0]} - Start creating default configs"
	createDefaultCfgs "$@"

	listSteamLibraries
	setSteamLibraryPaths

	writelog "INFO" "${FUNCNAME[0]} - Checking internal dependencies:"
	checkIntDeps "$@"

	writelog "INFO" "${FUNCNAME[0]} - Initializing first Proton:"
	initFirstProton

	writelog "INFO" "${FUNCNAME[0]} - Initializing default window resolution"
	setInitWinXY

	GREETING="$( getSeasonalGreeting )"
	writelog "INFO" "${FUNCNAME[0]} - ${GREETING:-Welcome to TinkerGame}"

	removeEmptyFiles "$STLAPPINFOIDDIR"  # Remove appinfo files that are 0 bytes (i.e. Non-Steam Games)
	removeEmptyFiles "$STLGHEADD"  # Remove appinfo files that are 0 bytes (i.e. Non-Steam Games)

	setGDKBackend

	if [ -z "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - No arguments provided. See '$PROGCMD --help' for possible command line parameters" "E"
	else
		writelog "INFO" "${FUNCNAME[0]} - Checking command line: incoming arguments '${*}'"
		writelog "INFO" "${FUNCNAME[0]} - Checking command line: first argument '${1}'"

		if [ -n "$SteamAppId" ] && [ "$SteamAppId" -eq "0" ]; then
			if grep -q "\"$1\"" <<< "$(sed -n "/^#STARTCMDLINE/,/^#ENDCMDLINE/p;/^#ENDCMDLINE/q" "$TGSRC_CMDLINE" | grep if)"; then
				writelog "INFO" "${FUNCNAME[0]} - Seems like a '$PROGCMD'-internal command was started - checking the command line"
				commandline "$@"
			else
				setCustomGameVars "$@"
				if [ -n "$ISGAME" ]; then
					if [ "$ISGAME" -eq 2 ] || [ "$ISGAME" -eq 3 ]; then
						prepareLaunch
					fi
				else
					writelog "ERROR" "${FUNCNAME[0]} - Unknown command '$*'" "E"
				fi
			fi
		elif grep -q "$SAC" <<< "$@" || grep -q "$L2EA" <<< "$@"; then
			# We check if incoming commands contain 'steamapps/common' to interpret them as game launch commands
			# But if $1 is a known command in this list, explicitly pass it to 'commandline' as we know it is NOT a game command
			# This prevents commands which contain 'steamapps/common' ANYWHERE in their command (including as paths as parameters to other flags) from being interpreted as a game launch
			#
			# If $1 is a known tinkergame command (with 'tinkergame otr', $1 would be 'otr') then intervene and force this to the 'commandline' function as it is a known tinkergame command
			STLINCOMINGSKIPCOMMANDS="otr|onetimerun"

			if grep -q "update" <<< "$@" || grep -q "^play" <<< "$@" ; then
				commandline "$@"
			# HACK: Since we check for steamapps/common ($SAC), commands which contain this (such as a one-time run path) will incorrectly get triggered as a game launch
			#       As a workaround, skip interpreting a hardcoded set of commands as start parameters and pass directly to commandline (i.e. if we have 'otr' as our first option, pass down to commandline function and run otr)
			#
			#       We also check to make sure the first argument doesn't contain any slashes (i.e. game start commands' first argument could be a path, so it would contain a slash)
			#       This allows us to distinguish between '/home/otr' which could be a game launch command, and the 'tinkergame otr' command (where $1 is 'otr')
			elif grep -qwE "${STLINCOMINGSKIPCOMMANDS}" <<< "${1}" && [[ "${1}" != *"/"* ]]; then
				commandline "$@"
			else
				# If we get here, this should be an actual game start command!
				setGameVars "$@"
				if [ "$ISGAME" -eq 2 ] || [ "$ISGAME" -eq 3 ]; then
					prepareLaunch
				else
					writelog "INFO" "${FUNCNAME[0]} - Unknown parameter '${ORGGCMD[*]}'" "E"
				fi
			fi
		else
			commandline "$@"
		fi
	fi

	restoreGtkCss
}
