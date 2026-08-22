#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

#STARTCMDLINE

# Command dispatch. 'commandline' handles top-level verbs and routes grouped
# commands (e.g. 'game files <appid>') to the tgCmd* group functions below.
# Inside a tgCmd* function the sub-verb is consumed first, so $1 is the first
# argument AFTER the sub-verb (one shift level compared to the old flat case).
# The command listing shown by 'help' is generated from data/commands.def.

function commandline {
	case "$1" in
	"-q")
		writelog "INFO" "${FUNCNAME[0]} - Quiet mode enabled with '-q', suppressing notifier for this execution"
		export STLQUIET=1
		USENOTIFIER=0
		shift
		commandline "$@"
		return
	;;

	"help"|"--help"|"-h")
		howto
	;;
	"version"|"--version"|"-v")
		echo "${PROGNAME,,}-${PROGVERS}"
	;;
	"play")
		if [ -z "$2" ]; then
			writelog "INFO" "${FUNCNAME[0]} - need at a valid game name or SteamAppId of an installed game or an absolute path to a game exe as arg2 '$2' or 'gui' for a menu" "E"
		else
			if [ "$2" == "gui" ]; then
				standaloneLaunch
			elif [ "$2" == "ed" ]; then
				standaloneEd "${@:3}"
			elif [ "$2" == "list" ]; then
				standaloneGames l
			else
				initPlay "${@:2}"
			fi
		fi
	;;
	"set")
		if [ -n "$2" ]; then
				if [ "$3" == "global" ]; then
					ENTLIST="$(tgSchemaKeys "global")"
				else
					ENTLIST="$(tgSchemaKeys "default_template")"
				fi

				if ! grep "$2" <<< "$ENTLIST" >/dev/null; then
					writelog "INFO" "${FUNCNAME[0]} - '$2' is no valid entry - valid are:" "E"
					writelog "INFO" "${FUNCNAME[0]} ------------------------" "E"
					writelog "INFO" "${FUNCNAME[0]} - $ENTLIST" "E"
					writelog "INFO" "${FUNCNAME[0]} ------------------------" "E"
					exit
				fi
			if [ -n "$3" ]; then
				if [ -z "$4" ]; then
					writelog "INFO" "${FUNCNAME[0]} - argument 4 is missing - exit" "E"
					exit
				else
					if [ "$3" == "all" ]; then
						writelog "INFO" "${FUNCNAME[0]} - arg3 is all - updating all config files in '$STLGAMEDIRID':" "E"
						while read -r file; do
							writelog "INFO" "${FUNCNAME[0]} - updating entry '$2' to value '$4' in config $file" "E"
							touch "$FUPDATE"
							updateConfigEntry "$2" "$4" "$file"
						done <<< "$(find "$STLGAMEDIRID" -name "*.conf")"
					else
						if [ -f "$STLGAMEDIRID/$3.conf" ]; then
							writelog "INFO" "${FUNCNAME[0]} - updating entry '$2' to value '$4' in config '$STLGAMEDIRID/$3.conf'" "E"
							touch "$FUPDATE"
							updateConfigEntry "$2" "$4" "$STLGAMEDIRID/$3.conf"
						elif [ "$3" == "global" ] && [ -f "$STLDEFGLOBALCFG" ]; then
							writelog "INFO" "${FUNCNAME[0]} - update global config entry '$2' to value '$4' in global config file '$STLDEFGLOBALCFG'" "E"
							touch "$FUPDATE"
							updateConfigEntry "$2" "$4" "$STLDEFGLOBALCFG"
						else
							writelog "INFO" "${FUNCNAME[0]} - config file '$STLGAMEDIRID/$3.conf' does not exist - nothing to do - exit" "E"
							exit
						fi
					fi
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - arg3 is missing, you need to provide either the SteamAppId of the game or 'all' to batch update all game configs with the chosen entry!" "E"
				exit
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - arg2 is missing, you need to provide a valid config entry which should be updated!" "E"
			exit
		fi
	;;
	"settings")
		startSettings "$2"
	;;
	"search")
		startSearchSettings "$2"
	;;
	"editor")
		FUSEID "$2"
		EditorDialog "$USEID"
	;;
	"noty")
		if [ -n "$2" ]; then
			NTEXT="$2"
		else
			NTEXT="notifier test"
		fi
		notiShow "$NTEXT"
	;;
	"wiki")
		OpenWikiPage "$2"
	;;
	"list")
		if [ -z "$2" ]; then
			echo "invalid usage - must pass one additional argument to 'list' command, either 'owned' or 'installed'"
		else
			listSteamGames "$2" "$3" # 3rd parameter is optional
		fi
	;;
	"compat")
		if [ -n "$2" ]; then
			if [ "$2" == "add" ] || [ "$2" == "del" ] || [ "$2" == "get" ]; then
				CompatTool "$2"
			else
				howto
			fi
		else
			CompatTool "get"
		fi
	;;
	"issue")
		writelog "INFO" "${FUNCNAME[0]} - Opening issue tracker in user's default browser"
		"$XDGO" "$PROJECTPAGE/issues/new/choose"
	;;
	"game")
		tgCmdGame "${@:2}"
	;;
	"config")
		tgCmdConfig "${@:2}"
	;;
	"steam")
		tgCmdSteam "${@:2}"
	;;
	"proton")
		tgCmdProton "${@:2}"
	;;
	"wine")
		tgCmdWine "${@:2}"
	;;
	"mods")
		tgCmdMods "${@:2}"
	;;
	"artwork")
		tgCmdArtwork "${@:2}"
	;;
	"get")
		tgCmdGet "${@:2}"
	;;
	"update")
		tgCmdUpdate "${@:2}"
	;;
	"meta")
		tgCmdMeta "${@:2}"
	;;
	*)
		if ! grep -q "lang=\|run" <<< "$@"; then
			writelog "INFO" "${FUNCNAME[0]} ------------------------"
			writelog "INFO" "${FUNCNAME[0]} - arg1 '$1' is no valid command"
			howto
		fi
	;;
	esac
}

function tgCmdGame {
	local TG_SUB="$1"
	shift
	case "$TG_SUB" in
	"files")
		FUSEID "$1"
		GameFilesMenu "$USEID"
	;;
	"gamescope")
		FUSEID "$1"
		GameScopeGui "$USEID" "$2"
	;;
	"onetimerun")
		FUSEID "$1"
		if [ -z "$1" ]; then
			writelog "WARN" "${FUNCNAME[0]} - No AppID provided for One-Time Run, attempting to start with last known AppID '$USEID'"
			if [ -n "$USEID" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found AppID '$USEID' - Using this for One-Time Run"
				OneTimeRunGui "$USEID"
			else
				writelog "ERROR" "${FUNCNAME[0]} - Could not find last known AppID - Aborting One-Time Run"
			fi
		else
			if [ -z "$2" ]; then
				OneTimeRunGui "$USEID"
			else
				commandlineOneTimeRun "$@"
			fi
		fi
	;;
	"backup")
		if [ "$1" == "all" ]; then
			backupSteamUserGate "$1"
		else
			FUSEID "$1"
			backupSteamUserGate "$USEID"
		fi
	;;
	"desktop-icon")
		if [ "$1" == "all" ]; then
			if [ "$(listInstalledGameIDs | wc -l)" -eq 0 ]; then
				writelog "SKIP" "${FUNCNAME[0]} - No installed games found!" "E"
			else
				while read -r CATAID; do
					createDesktopIconFile "$CATAID" "$2"
				done <<< "$(listInstalledGameIDs)"
			fi
		else
			FUSEID "$1"
			createDesktopIconFile "$USEID" "$2"
		fi
	;;
	"dxvk-hud")
		FUSEID "$1"
		DxvkHudPick "$USEID"
	;;
	"helpurl")
		FUSEID "$1"
		HelpUrlMenu "$USEID"
		if [ -z "$2" ]; then
			rm "$STLSHM/KillBrowser-$AID.txt" 2>/dev/null
		fi
	;;
	"vr")
		if [ -n "$2" ]; then
			GAMEWINDOW="$1"
			AID="$2"
			setAIDCfgs
			if [ -n "$3" ] && [ "$3" == "s" ]; then
				storeGameWindowNameMeta "$(getGameWinNameFromXid "$1")"
			fi
			checkSBSVRLaunch "$1"
		else
			howto
		fi
	;;
	"pickwin")
		pickGameWindowNameMeta "$1" "$2"
	;;
	"protondb")
		getProtonDBRating "$1"
	;;
	"deckcompat")
		mapfile -d ";" -t -O "${#DECKCOMPATARR[@]}" DECKCOMPATARR <<< "$( getSteamDeckCompatInfo "$( echo "$1" | xargs )" )"
		unset "DECKCOMPATARR[-1]"

		if [ "${#DECKCOMPATARR[@]}" -eq "0" ]; then
			echo "Could not get Steam Deck compatibility information got AppID '$1' - Is this definitely correct?"
			echo "You can check get the AppID for a game by running 'tinkergame get id <name>'"
		else
			echo "Valve's testing indicates that this game is ${DECKCOMPATARR[0]} on Steam Deck"
			if ! [ "${#DECKCOMPATARR[@]}" -eq "1" ]; then  # Only take a newline if there is compatibility information to show
				echo ""
				for COMPATSTR in "${DECKCOMPATARR[@]:1}"; do
					echo "$COMPATSTR"
				done
			fi
		fi
	;;
	"waitrequester")
		if [ -n "$1" ] && { [ "$1" == "e" ] || [ "$1" == "s" ] || [ "$1" == "u" ];}; then
			if [ "$1" == "e" ]; then
				writelog "INFO" "${FUNCNAME[0]} - enabling the Wait Requester for the next launched game"
				touch "$EWRF"
			elif [ "$1" == "s" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Skipping the Wait Requester temporarily for the next launched games"
				touch "$SWRF"
			elif [ "$1" == "u" ]; then
				if [ -f "$SWRF" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Disabling the temporary Wait Requester skipping"
					touch "$UWRF"
				else
					writelog "SKIP" "${FUNCNAME[0]} - The temporary Wait Requester skipping is not enabled, nothing to do"
				fi
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} ------------------------"
			writelog "INFO" "${FUNCNAME[0]} - need either e,s or u as the sub-command"
			howto
		fi
	;;
	"compatdata")
		FUSEID "$1"
		writelog "INFO" "${FUNCNAME[0]} - Starting Install via command: reCreateCompatdata \"createcompatdata\" \"$USEID\" \"$2\""
		reCreateCompatdata "createcompatdata" "$USEID" "$2"
	;;
	"first-install")
		FUSEID "$1"
		CreateCustomEvaluatorScript "$USEID"
	;;
	"launcher")
		openGameLauncher "$1" "$2"
	;;
	*)
		writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
		howto
	;;
	esac
}

function tgCmdConfig {
	local TG_SUB="$1"
	shift
	case "$TG_SUB" in
	"dir")
		"$XDGO" "$STLCFGDIR"
	;;
	"favorites")
		FUSEID "$1"
		if [ -n "$2" ] && [ "$2" == "set" ]; then
			setGuiFavoritesSelection "$USEID"
		else
			openTrayIcon
			favoritesMenu "$USEID"
			cleanYadLeftOvers
		fi
	;;
	"block")
		FUSEID "$1"
		setGuiBlockSelection "$USEID"
	;;
	"sort")
		setGuiSortOrder
	;;
	"yad")
		if [ -n "$1" ]; then
			setYadBin "$1" "$2"
		else
			writelog "INFO" "${FUNCNAME[0]} ------------------------"
			writelog "INFO" "${FUNCNAME[0]} - '$1' needs to be a valid yad parameter"
			howto
		fi
	;;
	*)
		writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
		howto
	;;
	esac
}

function tgCmdSteam {
	local TG_SUB="$1"
	shift
	case "$TG_SUB" in
	"add-game")
		if [ -z "$1" ]; then
			addNonSteamGameGui "$NON"
		else
			if grep -q "ep=\|--exepath=" <<< "$*"; then
				# prepend the legacy verb word so addNonSteamGame(Gui) sees the
				# same argv shape it got from the old flat 'ansg' command
				if grep -q "gui" <<< "$*"; then
					addNonSteamGameGui "ansg" "$@"
				else
					addNonSteamGame "ansg" "$@"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - Command line parameters insufficent - starting the Gui"
				addNonSteamGameGui "$NON"
			fi
		fi
	;;
	"clear-deck-deps")
		# We check this in clearDeckDeps too, but this is just insurance
		if [ "$ONSTEAMDECK" -eq 1 ]; then
			clearDeckDeps
		else
			writelog "SKIP" "${FUNCNAME[0]} - Not on Steam Deck, nothing to do."
			echo "Not on Steam Deck, nothing to do."
		fi
	;;
	"shared")
		local TG_SUBSUB="$1"
		shift
		if [ -n "$TG_SUBSUB" ]; then
			if [ "$TG_SUBSUB" == "install" ] || [ "$TG_SUBSUB" == "i" ]; then
				if [ -n "$2" ]; then
					installSteWoShPak "$1" "$2" "$3"
				else
					writelog "INFO" "${FUNCNAME[0]} - Need at least package name as arg 2 and a wineprefix OR a SteamAppID as arg 3" E
					writelog "INFO" "${FUNCNAME[0]} - and optionally an absolute path to to a wine binary as arg 4" E
				fi
			elif [ "$TG_SUBSUB" == "list" ] || [ "$TG_SUBSUB" == "l" ]; then
				listSteWoShPaks
			else
				writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUBSUB' is no valid command"
				howto
			fi
		else
			echo "need a sub-command"
			howto
		fi
	;;
	"depressurizer")
		startDepressurizer
	;;
	"src")
			"$STEAM" "${STEAM}://${RECO}"
	;;
	*)
		writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
		howto
	;;
	esac
}

function tgCmdProton {
	local TG_SUB="$1"
	shift
	case "$TG_SUB" in
	"list")
		prettyPrintProtonArr "$1"
	;;
	"refresh")
		getAvailableProtonVersions "up" X
	;;
	"download")
		dlCustomProtonGate "$1"
	;;
	"add")
		addCustomProton "$1" "$2"
	;;
	"getslr")
		if [ "$2" == "native" ]; then
			FETCHNATIVESLR=1
		else
			FETCHNATIVESLR=0
		fi
		commandlineFetchGameSLR "$1" "$FETCHNATIVESLR"
	;;
	"getslr-gui")
		fetchGameSLRGui "$1"
	;;
	"start")
		StandaloneProtonGame "$1" "$2"
	;;
	*)
		writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
		howto
	;;
	esac
}

function tgCmdWine {
	local TG_SUB="$1"
	shift
	case "$TG_SUB" in
	"download")
		dlWineGate "$1"
	;;
	"winecfg")
		# Assumes that if called without any arguments that it's an internal call
		# Otherwise we assume if *any* arguments are passed that we're a user calling it from the command-line
		if [ -n "$1" ]; then
			# Always assume first remaining argument is the AppID
			writelog "INFO" "${FUNCNAME[0]} - Looks like we're a user calling this from the command line -- User passed '$1'"
			oneTimeWinecfg "$1"
		else
			writelog "INFO" "${FUNCNAME[0]} - Looks like we're getting an internal One-Time Winecfg call"
			oneTimeWinecfg
		fi
	;;
	"winetricks")
		FUSEID "$1"
		chooseWinetricksPrefix "$USEID"
	;;
	"onetime-winetricks")
		# Same internal-vs-user logic as winecfg above
		if [ -n "$1" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Looks like we're a user calling this from the command line -- User passed '$1'"
			oneTimeWinetricks "$1"
		else
			writelog "INFO" "${FUNCNAME[0]} - Looks like we're getting an internal One-Time Winetricks call"
			oneTimeWinetricks
		fi
	;;
	"debug-channels")
		FUSEID "$1"
		SetWineDebugChannels "$USEID"
	;;
	"dotnet")
		if [ -n "$2" ]; then
			installDotNet "$1" "$2" "$3"
		else
			writelog "INFO" "${FUNCNAME[0]} - need at least a winepfx as arg1 '$1' and a wine binary as arg2" "E"
		fi
	;;
	*)
		writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
		howto
	;;
	esac
}

function tgCmdMods {
	local TG_SUB="$1"
	shift
	case "$TG_SUB" in
	"mo2")
		tgCmdMO2 "$@"
	;;
	"vortex")
		tgCmdVortex "$@"
	;;
	"hedge")
		tgCmdHMM "$@"
	;;
	*)
		writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
		howto
	;;
	esac
}

function tgCmdMO2 {
	local TG_SUB="$1"
	shift
	if [ -n "$TG_SUB" ]; then
		if [ "$TG_SUB" == "download" ] || [ "$TG_SUB" == "d" ]; then
			dlLatestMO2
		elif [ "$TG_SUB" == "install" ] || [ "$TG_SUB" == "i" ]; then
			# Get path to custom MO2 exe from commandline -- Untested for now
			if [ -n "$1" ]; then
				USEMO2CUSTOMINSTALLER=1
				MO2CUSTOMINSTALLER="$1"
			fi

			StatusWindow "$(strFix "$NOTY_INSTSTART" "$MO")" "installMO2" "InstallMO2Status"
		elif [ "$TG_SUB" == "start" ] || [ "$TG_SUB" == "s" ]; then
			startMO2
		elif [ "$TG_SUB" == "list-supported" ] || [ "$TG_SUB" == "ls" ]; then
			listMO2Games
		elif [ "$TG_SUB" == "list-installed" ] || [ "$TG_SUB" == "li" ]; then
			# Output installed MO2 games in format "Name (AppID) -> /path/to/prefix"
			setMO2Vars
			mapfile -t -O "${#CMDINSTMO2GAMS}" CMDINSTMO2GAMS <<< "$( prepAllMO2Games "li" )"
			for IMO2G in "${CMDINSTMO2GAMS[@]}"; do
				IMO2GAID="$( echo "$IMO2G" | cut -d ";" -f 1 )"
				IMO2GN="$( echo "$IMO2G" | cut -d ";" -f 2 )"
				IMO2GPA="$( echo "$IMO2G" | cut -d ";" -f 3 )"

				printf "%s (%s) -> %s\n" "$IMO2GN" "$IMO2GAID" "$IMO2GPA"
			done
		elif [ "$TG_SUB" == "create-instance" ] || [ "$TG_SUB" == "ci" ]; then
			if [ -z "$1" ] || [ "$1" == "all" ]; then
				createAllMO2Instances
			else
				manageMO2GInstance "$1"
			fi
		elif [ "$TG_SUB" == "url" ] || [ "$TG_SUB" == "u" ]; then
			if [ -z "$1" ]; then
				writelog "ERROR" "${FUNCNAME[0]} - No URL was passed for ('$1') -- Maybe this is being incorrectly launched from the XDG menu?"
				warnInvalidModToolLaunch "ModOrganizer 2"
			else
				writelog "INFO" "${FUNCNAME[0]} - URL passed is '$1'"
				dlMod2nexurl "$1"
			fi
		elif [ "$TG_SUB" == "getprefix" ] || [ "$TG_SUB" == "gp" ]; then
			echo "$MO2COMPDATA/pfx"
		elif [ "$TG_SUB" == "repairpfx" ]; then
			setMO2Vars

			# EXPERIMENTAL REPAIR OPTION
			writelog "INFO" "${FUNCNAME[0]} - Attempting to repair ModOrganizer 2 prefix using experimental repair option"
			writelog "INFO" "${FUNCNAME[0]} - This runs a basic Proton command in the game prefix in an attempt to repair/update corrupted/outdated files in the prefix"
			writelog "INFO" "${FUNCNAME[0]} - Attempting to repair ModOrganizer 2 prefix with 'STEAM_COMPAT_DATA_PATH=\"$MO2COMPDATA\" \"$MO2RUNPROT\" run wine'"

			echo "WARNING: This option is experimental and intended for use to fix kernel32.dll-related errors, here be dragons!"
			echo "Attempting to repair ModOrganizer 2 prefix with 'STEAM_COMPAT_DATA_PATH=\"$MO2COMPDATA\" \"$MO2RUNPROT\" run wine'"
			STEAM_COMPAT_DATA_PATH="$MO2COMPDATA" "$MO2RUNPROT" run wine
			writelog "INFO" "${FUNCNAME[0]} - Finished attempting to repair ModOrganizer 2 prefix"
			echo "Done. If there are any errors above, repair probably didn't succeed. If there are no errors and the prefix is still broken, try running something with Proton in the prefix using something similar to the command above."
		elif [ "$TG_SUB" == "winecfg" ]; then
			mo2Winecfg
		elif [ "$TG_SUB" == "winetricks" ] || [ "$TG_SUB" == "wt" ]; then
			mo2Winetricks
		elif [ "$TG_SUB" == "resetmime" ]; then
			writelog "INFO" "${FUNCNAME[0]} - (Re)setting MO2 .desktop file entries and MimeType associations"
			echo "(Re)setting MO2 .desktop file entries and MimeType associations"
			setMO2DLMime
		else
			writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
			howto
		fi
	else
		echo "need a sub-command"
		howto
	fi
}

function tgCmdVortex {
	# TODO Vortex uninstall option?
	# TODO Vortex commandline flag to set no auto update (i.e. --disable-auto-update)

	local TG_SUB="$1"
	shift

	USEVORTEX=1
	if [ -n "$TG_SUB" ]; then
		# If we get an additional parameter and any passed command should download/install/start Vortex,
		# set the Vortex version to download to the given version (will only be used if Vortex is not already installed)
		#
		# TODO handle passing a custom installer file, probably only for "install" though where we'll force set a different var
		if [[ -n "$1" && ( "$TG_SUB" == "download" || "$TG_SUB" == "install" || "$TG_SUB" == "start" || "$TG_SUB" == "getset" ) ]]; then
			if [ "$USEVORTEXCUSTOMVER" -eq 0 ]; then
				writelog "WARN" "${FUNCNAME[0]} - Custom Vortex version passed ('$1') but USEVORTEXCUSTOMVER is '$USEVORTEXCUSTOMVER'"
				writelog "WARN" "${FUNCNAME[0]} - Assuming you know what you're doing and using this version anyway..."
			fi

			USEVORTEXCUSTOMVER=1
			VORTEXCUSTOMVER="$1"
		fi

		if [ "$TG_SUB" == "install" ] || [ "$TG_SUB" == "i" ]; then
			if [ -n "$1" ] && [ "$1" == "gui" ]; then
				installVortexGui
			else
				StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${VTX^}")" "dlLatestVortex S" "DownloadVortexStatus"
				StatusWindow "$(strFix "$NOTY_INSTSTART" "${VTX^}")" "installVortex" "InstallVortexStatus"
			fi
		elif [ "$TG_SUB" == "start" ]; then
			startVortex "noask" "$1"
		elif [ "$TG_SUB" == "url" ] || [ "$TG_SUB" == "u" ]; then
			if [ -z "$1" ]; then
				writelog "ERROR" "${FUNCNAME[0]} - No URL was passed for ('$1') -- Maybe this is being incorrectly launched from the XDG menu?"
				warnInvalidModToolLaunch "Vortex"
			else
				startVortex "noask" "url" "$1"
			fi
		elif [ "$TG_SUB" == "getset" ]; then
			startVortex "noask" "getset"
		elif [ "$TG_SUB" == "gui" ]; then
			VortexOptions
		elif [ "$TG_SUB" == "reset" ]; then
			resetVortexSettings
		elif [ "$TG_SUB" == "stage" ]; then
			addVortexStage "$1"
		elif [ "$TG_SUB" == "list-supported" ] || [ "$TG_SUB" == "ls" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Games With ${VTX^} Support found in the ${VTX^} installation:" "E"
			getVortexSupportedNames
		elif [ "$TG_SUB" == "list-online" ] || [ "$TG_SUB" == "lo" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Games With ${VTX^} Support listed online:" "E"
			dlVortexSupportedList
		elif [ "$TG_SUB" == "list-owned" ] || [ "$TG_SUB" == "low" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Games owned with ${VTX^} Support:" "E"
			VORTEXGAMES="$GLOBALMISCDIR/$VOGAT"
			while read -r line; do
				# TODO speed this up somehow?
				OWNEDVTXGAMELINE="$( grep "\"$line\"" "$VORTEXGAMES" )"
				OWNEDVTXGAMENAME="$( echo "$OWNEDVTXGAMELINE" | cut -d ";" -f2 | cut -d '"' -f 2 )"
				OWNEDVTXGAMEAID="$( echo "$OWNEDVTXGAMELINE" | cut -d ";" -f3 | cut -d '"' -f 2 )"

				if [ -n "$OWNEDVTXGAMENAME" ] && [ -n "$OWNEDVTXGAMEAID" ]; then
					printf "%s (%s)\n" "$OWNEDVTXGAMENAME" "$OWNEDVTXGAMEAID"
				fi
			done <<< "$(getOwnedAids)"
		elif [ "$TG_SUB" == "list-installed" ] || [ "$TG_SUB" == "li" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Installed Games With ${VTX^} Support"
			setVortexVars
			VORTEXGAMES="$GLOBALMISCDIR/$VOGAT"
			while read -r INSTALLEDVTXAID; do
				if [ -z "$INSTALLEDVTXAID" ]; then
					continue
				fi

				INSTALLEDVTXNAME="$( grep "$INSTALLEDVTXAID" "$VORTEXGAMES" | cut -d ";" -f 2 | cut -d '"' -f 2 )"

				# Bit hacky but fixes an instance where two games (on newlines) are returned but only one AppID is returned
				# Get rid of the newlines and replace with a semicolon, then cut and get the second game name which should be the matching AppID
				INSTALLEDVTXNAME="$( echo "${INSTALLEDVTXNAME//$'\n'/;}" | cut -d ";" -f 2 )"
				printf "%s (%s)\n" "$INSTALLEDVTXNAME" "$INSTALLEDVTXAID"
			done <<< "$(getInstalledGamesWithVortexSupport X)"
		elif [ "$TG_SUB" == "games" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Opening Gui for en/disabling ${VTX^} for installed and supported games"
			VortexGamesDialog
		elif [ "$TG_SUB" == "symlinks" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Opening Gui showing Symlinks in the ${VTX^} WINEPREFIX"
			VortexSymDialog
		elif [ "$TG_SUB" == "download" ] || [ "$TG_SUB" == "d" ]; then
			StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${VTX^}")" "dlLatestVortex S" "DownloadVortexStatus"
		elif [ "$TG_SUB" == "activate" ] && { [ -n "$1" ]  && [ "$1" -eq "$1" ] 2>/dev/null;}; then
			startVortex "activate" "$1"
		elif [ "$TG_SUB" == "getprefix" ] || [ "$TG_SUB" == "gp" ]; then
			echo "$VORTEXCOMPDATA/pfx"
		elif [ "$TG_SUB" == "winecfg" ]; then
			vtxWinecfg
		elif [ "$TG_SUB" == "winetricks" ] || [ "$TG_SUB" == "wt" ]; then
			vtxWinetricks
		elif [ "$TG_SUB" == "resetmime" ]; then
			writelog "INFO" "${FUNCNAME[0]} - (Re)setting ${VTX^} .desktop file entries and MimeType associations"
			echo "(Re)setting ${VTX^} .desktop file entries and MimeType associations"
			setVortexDLMime
		else
			writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
			howto
		fi
	else
		echo "need a sub-command"
		howto
	fi
}

function tgCmdHMM {
	local TG_SUB="$1"
	shift
	if [ -n "$TG_SUB" ]; then
		if [ -n "$1" ]; then
			CMDHMMDLVER="$1"
		fi

		if [ "$TG_SUB" == "download" ] || [ "$TG_SUB" == "d" ]; then
			dlLatestHMM "$CMDHMMDLVER"
		elif [ "$TG_SUB" == "install" ] || [ "$TG_SUB" == "i" ]; then
			dlLatestHMM "$CMDHMMDLVER"
			installHMM
		elif [ "$TG_SUB" == "start" ] || [ "$TG_SUB" == "s" ]; then
			if [ "$2" == "--force" ] || [ "$2" == "-f" ]; then
				# This will force dotnet48 to be reinstalled for each installed 64bit HMM game if `--force` or `-f` is passed to the HMM start command
				startHMM "$CMDHMMDLVER" "X"
			else
				startHMM "$CMDHMMDLVER"
			fi
		elif [ "$TG_SUB" == "list-supported" ] || [ "$TG_SUB" == "ls" ]; then
			listSupportedHMMGames
		elif [ "$TG_SUB" == "list-installed" ] || [ "$TG_SUB" == "li" ]; then
			listInstalledHMMGames
		elif [ "$TG_SUB" == "list-owned" ] || [ "$TG_SUB" == "lo" ]; then
			listOwnedHMMGames
		elif [ "$TG_SUB" == "desktopfile" ] || [ "$TG_SUB" == "df" ]; then
			createHMMDesktopFile
		elif [ "$TG_SUB" == "uninstall" ]; then
			uninstallHMM
		elif [ "$TG_SUB" == "url" ] || [ "$TG_SUB" == "u" ]; then
			if [ -z "$1" ]; then
				writelog "ERROR" "${FUNCNAME[0]} - No URL was passed for ('$1') -- Maybe this is being incorrectly launched from the XDG menu?"
				warnInvalidModToolLaunch "Hedge Mod Manager"
			else
				dlHedgeMod "$1"
			fi
		elif [ "$TG_SUB" == "resetmime" ]; then
			writelog "INFO" "${FUNCNAME[0]} - (Re)setting HMM .desktop file entries and MimeType associations"
			echo "(Re)setting HMM .desktop file entries and MimeType associations"
			createHMMDesktopFile
		else
			echo "Need to input a valid sub-command '$TG_SUB' to run a HedgeModManager command"
			howto
		fi
	else
		writelog "INFO" "a sub-command is required"
		howto
	fi
}

function tgCmdArtwork {
	local TG_SUB="$1"
	shift
	case "$TG_SUB" in
	"download")
		# This is the SteamGridDB commandline usage, we just expose the direct function on the command line

		# No arguments passed, skip
		if [ -z "$1" ]; then
			echo "Need to pass arguments to the SteamGridDB command, see 'tinkergame help' for usage."
			return
		fi

		if [ -z "$2" ]; then
			# Show GUI if only one argument is given (assume it is an AppID), i.e if user just entered "tinkergame artwork download <appid>"
			getSteamGridDBArtworkGUI "$1"
		else
			# commandlineGetSteamGridDBArtwork parses named flags only
			# (--search-id= etc.) - bare positional args are ignored
			commandlineGetSteamGridDBArtwork "$@"
		fi
	;;
	"set")
		if [ -n "$1" ]; then
			if [ -z "$2" ]; then
				setGameArtGui "$1"  # Don't think this function needs to take any arguments
			else
				setGameArt "$@"  # Pass all remaining arguments (AppID + artwork options)
			fi
		else
			echo "At least one argument (AppID) must be provided"
		fi
	;;
	"clear")
		if [ -z "$1" ]; then
			writelog "ERROR" "${FUNCNAME[0]} - No parameter given, cannot remove artwork, skipping"
			echo "You must provide either a Steam AppID to remove artwork for, or specify 'all' to remove all game artwork"
		else
			removeSteamGrids "$1"
		fi
	;;
	"open")
		openSteamGridDir
	;;
	"gameid")
		getSGDBGameIDFromTitle "$1"
	;;
	*)
		writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
		howto
	;;
	esac
}

function tgCmdGet {
	local TG_SUB="$1"
	shift
	case "$TG_SUB" in
	"exe")
		getGameExe "$1" "1"
	;;
	"id")
		getIDFromTitle "$1" "1"
	;;
	"title")
		getTitleFromID "$1" "1"
	;;
	"compatdata")
		getCompatData "$1" "1"
	;;
	"gamedir")
		if [ "$2" == "only" ]; then
			getGameDir "$1" "X" "1"
		else
			getGameDir "$1" "" "1"
		fi
	;;
	*)
		writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
		howto
	;;
	esac
}

function tgCmdUpdate {
	local TG_SUB="$1"
	shift
	if [ -n "$TG_SUB" ]; then
		if [ "$TG_SUB" == "gamedata" ]; then
			if [ -z "$1" ]; then
				getGameDataForInstalledGames
			else
				echo getGameData "$1"
				getGameData "$1"
			fi
		elif [ "$TG_SUB" == "grid" ]; then
			if [ -z "$1" ]; then
				getGridsForOwnedGames
			elif [ "$1" == "owned" ]; then
				getGridsForOwnedGames
			elif [ "$1" == "installed" ]; then
				getGridsForInstalledGames
			elif [ "$1" == "nonsteam" ] || [ "$1" == "shortcuts" ]; then
				getGridsForNonSteamGames
			fi
		elif [ "$TG_SUB" == "allgamedata" ]; then
			getDataForAllGamesinSharedConfig
		elif [ "$TG_SUB" == "shader" ] || [ "$TG_SUB" == "shaders" ]; then
			if [ -n "$1" ] && { [ "$1" == "repos" ] || [ "$1" == "list" ]; }; then
				dlShaders "$1"
			else
				StatusWindow "$GUI_DLSHADER" "dlShaders $1"  "DownloadShadersStatus"
			fi
		elif [ "$TG_SUB" == "gameshader" ] || [ "$TG_SUB" == "gameshaders" ]; then
			if [ -z "$1" ]; then
				writelog "INFO" "${FUNCNAME[0]} - No game directory in argument 1 provided - using last game!"
				GameShaderDialog
			else
				if [ -d "$1" ]; then
					writelog "INFO" "${FUNCNAME[0]} - command line: GameShaderDialog \"$1\""
					GameShaderDialog "$1"
				else
					if [ -n "$2" ]; then
						if [ -d "$2" ]; then
							if [ -n "$3" ] && [ "$3" == "disable" ]; then
								disableThisGameShaderRepo "$1" "$2"
							else
								enableThisGameShaderRepo "$1" "$2"
							fi
						elif [ "$2" == "block" ]; then
							echo "$1" >> "$SHADERREPOBLOCKLIST"
							sort -u "$SHADERREPOBLOCKLIST" -o "$SHADERREPOBLOCKLIST"
							unblockrssub
						elif [ "$2" == "unblock" ]; then
							grep -v "^${1}$" "$SHADERREPOBLOCKLIST" > "$STLSHM/SHADERREPOBLOCKLIST_tmp.txt"
							mv "$STLSHM/SHADERREPOBLOCKLIST_tmp.txt" "$SHADERREPOBLOCKLIST"
						else
							writelog "SKIP" "${FUNCNAME[0]} - Invalid argument '$2' - exit"
						fi
					else
						writelog "SKIP" "${FUNCNAME[0]} - Game directory '$1' does not exist - exit"
					fi
				fi
			fi
		elif [ "$TG_SUB" == "reshade" ]; then
			dlReShade "$1"
		elif [ "$TG_SUB" == "specialk" ]; then
			if [ -n "$1" ] && { [ "$1" == "download" ] || [ "$1" == "dl" ]; }; then
				dlSpecialK "$2"
			else
				howto
			fi
		elif [ "$TG_SUB" == "conty" ]; then
			if [ -n "$1" ] && { [ "$1" == "up" ] || [ "$1" == "update" ]; }; then
				updateConty
			fi
		else
			howto
		fi
	else
		howto
	fi
}

function tgCmdMeta {
	local TG_SUB="$1"
	shift
	case "$TG_SUB" in
	"update")
		createMetaData "yes"
	;;
	"raw")
		if [ "$1" == "installed" ] || [ "$1" == "i" ]; then
			if [ "$(listInstalledGameIDs | wc -l)" -eq 0 ]; then
				writelog "SKIP" "${FUNCNAME[0]} - No installed games found!" "E"
			else
				while read -r CATAID; do
					getRawAppIDInfo "$CATAID" "$2"
				done <<< "$(listInstalledGameIDs)"
			fi
		elif [ "$1" == "owned" ] || [ "$1" == "o" ]; then
			while read -r CATAID; do
				getRawAppIDInfo "$CATAID" "$2"
			done <<< "$(getOwnedAids)"
		else
			FUSEID "$1"
			getRawAppIDInfo "$USEID" "$2"
		fi
	;;
	"write")
		if [ -n "$1" ]; then
			if [ "$1" == "installed" ] || [ "$1" == "i" ]; then
				if [ "$(listInstalledGameIDs | wc -l)" -eq 0 ]; then
					writelog "SKIP" "${FUNCNAME[0]} - No installed games found!" "E"
				else
					while read -r CATAID; do
						writeAllAIMeta "$CATAID" "$2"
					done <<< "$(listInstalledGameIDs)"
				fi
			elif [ "$1" == "owned" ] || [ "$1" == "o" ]; then
				while read -r CATAID; do
					writeAllAIMeta "$CATAID" "$2"
				done <<< "$(getOwnedAids)"
			else
				if [ "$1" -eq "$1" ]; then
					FUSEID "$1"
					writeAllAIMeta "$USEID" "$2"
				fi
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - need at least 'installed|i' or 'owned|o' or a SteamAppId as the first argument" "E"
		fi
	;;
	*)
		writelog "INFO" "${FUNCNAME[0]} - sub-command '$TG_SUB' is no valid command"
		howto
	;;
	esac
}
#ENDCMDLINE


### COMMAND LINE END ###
