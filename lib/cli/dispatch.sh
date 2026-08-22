#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

#STARTCMDLINE
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

	"addcustomproton"|"acp")
		addCustomProton "$2" "$3"
	;;
	"addnonsteamgame"|"ansg")
		if [ -z "$2" ]; then
			addNonSteamGameGui "$NON"
		else
			if grep -q "ep=\|--exepath=" <<< "$*"; then
				if grep -q "gui" <<< "$*"; then
					addNonSteamGameGui "$@"
				else
					addNonSteamGame "$@"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - Command line parameters insufficent - starting the Gui"
				addNonSteamGameGui "$NON"
			fi
		fi
	;;
	"backup")
		if [ "$2" == "all" ]; then
			backupSteamUserGate "$2"
		else
			FUSEID "$2"
			backupSteamUserGate "$USEID"
		fi
	;;
	"block")
		FUSEID "$2"
		setGuiBlockSelection "$USEID"
	;;
	"cleardeckdeps")
		# We check this in clearDeckDeps too, but thsis is just insurance
		if [ "$ONSTEAMDECK" -eq 1 ]; then
			clearDeckDeps
		else
			writelog "SKIP" "${FUNCNAME[0]} - Not on Steam Deck, nothing to do."
			echo "Not on Steam Deck, nothing to do."
		fi
	;;
	"sort")
		setGuiSortOrder
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
	"conty")
		if [ -n "$2" ]; then
			if [ "$2" == "up" ] || [ "$2" == "update" ]; then
				updateConty
			fi
		fi
	;;
	"createcompatdata"|"ccd")
		FUSEID "$2"
		writelog "INFO" "${FUNCNAME[0]} - Starting Install via command: reCreateCompatdata \"$1\" \"$USEID\" \"$3\""
		reCreateCompatdata "$1" "$USEID" "$3"
	;;
	"createdesktopicon"|"cdi")
		if [ "$2" == "all" ]; then
			if [ "$(listInstalledGameIDs | wc -l)" -eq 0 ]; then
				writelog "SKIP" "${FUNCNAME[0]} - No installed games found!" "E"
			else
				while read -r CATAID; do
					createDesktopIconFile "$CATAID" "$3"
				done <<< "$(listInstalledGameIDs)"
			fi
		else
			FUSEID "$2"
			createDesktopIconFile "$USEID" "$3"
		fi
	;;
	"createappinfo"|"cai")
		if [ "$2" == "installed" ] || [ "$2" == "i" ]; then
			if [ "$(listInstalledGameIDs | wc -l)" -eq 0 ]; then
				writelog "SKIP" "${FUNCNAME[0]} - No installed games found!" "E"
			else
				while read -r CATAID; do
					getRawAppIDInfo "$CATAID" "$3"
				done <<< "$(listInstalledGameIDs)"
			fi
		elif [ "$2" == "owned" ] || [ "$2" == "o" ]; then
			while read -r CATAID; do
				getRawAppIDInfo "$CATAID" "$3"
			done <<< "$(getOwnedAids)"
		else
			FUSEID "$2"
			getRawAppIDInfo "$USEID" "$3"
		fi
	;;
	"createappinfometa"|"caim")
		if [ -n "$2" ]; then
			if [ "$2" == "installed" ] || [ "$2" == "i" ]; then
				if [ "$(listInstalledGameIDs | wc -l)" -eq 0 ]; then
					writelog "SKIP" "${FUNCNAME[0]} - No installed games found!" "E"
				else
					while read -r CATAID; do
						writeAllAIMeta "$CATAID" "$3"
					done <<< "$(listInstalledGameIDs)"
				fi
			elif [ "$2" == "owned" ] || [ "$2" == "o" ]; then
				while read -r CATAID; do
					writeAllAIMeta "$CATAID" "$3"
				done <<< "$(getOwnedAids)"
			else
				if [ "$2" -eq "$2" ]; then
					FUSEID "$2"
					writeAllAIMeta "$USEID" "$3"
				fi
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - need at least 'installed|i' or 'owned|o' or a SteamAppId as arg2" "E"
		fi
	;;
	"createfirstinstall"|"cfi")
		FUSEID "$2"
		CreateCustomEvaluatorScript "$USEID"
	;;
	"configdir")
		"$XDGO" "$STLCFGDIR"
	;;
	"${DPRS,}"|"dprs")
		startDepressurizer
	;;
	"dlcustomproton"|"dcp")
		dlCustomProtonGate "$2"
	;;
	"dlwine"|"dw")
		dlWineGate "$2"
	;;
	"dxvkhud"|"dxh")
		FUSEID "$2"
		DxvkHudPick "$USEID"
	;;
	"listproton"|"lp")
		prettyPrintProtonArr "$2"
	;;
	"dotnet")
		if [ -n "$3" ]; then
			installDotNet "$2" "$3" "$4"
		else
			writelog "INFO" "${FUNCNAME[0]} - need at least a winepfx as arg2 '$2' and a wine binary as arg3" "E"
			#howto
		fi
	;;
	"editor")
		FUSEID "$2"
		EditorDialog "$USEID"
	;;
	"fav")
		FUSEID "$2"
		if [ -n "$3" ] && [ "$3" == "set" ]; then
			setGuiFavoritesSelection "$USEID"
		else
			openTrayIcon
			favoritesMenu "$USEID"
			cleanYadLeftOvers
		fi
	;;
	"gamefiles"|"gf")
		FUSEID "$2"
		GameFilesMenu "$USEID"
	;;
	"gamescope"|"gs")
		FUSEID "$2"
		GameScopeGui "$USEID" "$3"
	;;
	"getexe"|"ge")
		getGameExe "$2" "1"
	;;
	"getid"|"gi"|"gid")
		getIDFromTitle "$2" "1"
	;;
	"gettitle"|"gt")
		getTitleFromID "$2" "1"
	;;
	"getcompatdata"|"gc")
		getCompatData "$2" "1"
	;;
	"getgamedir"|"gg")
		if [ "$3" == "only" ]; then
			getGameDir "$2" "X" "1"
		else
			getGameDir "$2" "" "1"
		fi
	;;
	"help"|"--help"|"-h")
		howto
	;;
	"helpurl"|"hu")
		FUSEID "$2"
		HelpUrlMenu "$USEID"
		if [ -z "$3" ]; then
			rm "$STLSHM/KillBrowser-$AID.txt" 2>/dev/null
		fi
	;;
	"launcher")
		openGameLauncher "$2" "$3"
	;;
	"list")
		if [ -z "$2" ]; then
			echo "invalid usage - must pass one additional argument to 'list' command, either 'owned' or 'installed'"
		else
			listSteamGames "$2" "$3" # 3rd parameter is optional
		fi
	;;
	"meta")
		createMetaData "yes"
	;;
	"getslr")
		if [ "$3" == "native" ]; then
			FETCHNATIVESLR=1
		else
			FETCHNATIVESLR=0
		fi
		commandlineFetchGameSLR "$2" "$FETCHNATIVESLR"
	;;
	"getslrbtn")
		fetchGameSLRGui "$2"
	;;
	"mo2")
		if [ -n "$2" ]; then
			if [ "$2" == "download" ] || [ "$2" == "d" ]; then
				dlLatestMO2
			elif [ "$2" == "install" ] || [ "$2" == "i" ]; then
				# Get path to custom MO2 exe from commandline -- Untested for now
				if [ -n "$3" ]; then
					USEMO2CUSTOMINSTALLER=1
					MO2CUSTOMINSTALLER="$3"
				fi

				StatusWindow "$(strFix "$NOTY_INSTSTART" "$MO")" "installMO2" "InstallMO2Status"
			elif [ "$2" == "start" ] || [ "$2" == "s" ]; then
				startMO2
			elif [ "$2" == "list-supported" ] || [ "$2" == "ls" ]; then
				listMO2Games
			elif [ "$2" == "list-installed" ] || [ "$2" == "li" ]; then
				# Output installed MO2 games in format "Name (AppID) -> /path/to/prefix"
				setMO2Vars
				mapfile -t -O "${#CMDINSTMO2GAMS}" CMDINSTMO2GAMS <<< "$( prepAllMO2Games "li" )"
				for IMO2G in "${CMDINSTMO2GAMS[@]}"; do
					IMO2GAID="$( echo "$IMO2G" | cut -d ";" -f 1 )"
					IMO2GN="$( echo "$IMO2G" | cut -d ";" -f 2 )"
					IMO2GPA="$( echo "$IMO2G" | cut -d ";" -f 3 )"

					printf "%s (%s) -> %s\n" "$IMO2GN" "$IMO2GAID" "$IMO2GPA"
				done
			elif [ "$2" == "create-instance" ] || [ "$2" == "ci" ]; then
				if [ -z "$3" ] || [ "$3" == "all" ]; then
					createAllMO2Instances
				else
					manageMO2GInstance "$3"
				fi
			elif [ "$2" == "url" ] || [ "$2" == "u" ]; then
				if [ -z "$3" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - No URL was passed for ('$3') -- Maybe this is being incorrectly launched from the XDG menu?"
					warnInvalidModToolLaunch "ModOrganizer 2"
				else
					writelog "INFO" "${FUNCNAME[0]} - URL passed is '$3'"
					dlMod2nexurl "$3"
				fi
			elif [ "$2" == "getprefix" ] || [ "$2" == "gp" ]; then
				echo "$MO2COMPDATA/pfx"
			elif [ "$2" == "repairpfx" ]; then
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
			elif [ "$2" == "winecfg" ]; then
				mo2Winecfg
			elif [ "$2" == "winetricks" ] || [ "$2" == "wt" ]; then
				mo2Winetricks
			elif [ "$2" == "resetmime" ]; then
				writelog "INFO" "${FUNCNAME[0]} - (Re)setting MO2 .desktop file entries and MimeType associations"
				echo "(Re)setting MO2 .desktop file entries and MimeType associations"
				setMO2DLMime
			else
				writelog "INFO" "${FUNCNAME[0]} - arg2 '$2' is no valid command"
				howto
			fi
		else
			echo "need arg2"
			howto
		fi
	;;
	"hedgemodmanager"|"hmm")
		if [ -n "$2" ]; then
			if [ -n "$3" ]; then
				CMDHMMDLVER="$3"
			fi

			if [ "$2" == "download" ] || [ "$2" == "d" ]; then
				dlLatestHMM "$CMDHMMDLVER"
			elif [ "$2" == "install" ] || [ "$2" == "i" ]; then
				dlLatestHMM "$CMDHMMDLVER"
				installHMM
			elif [ "$2" == "start" ] || [ "$2" == "s" ]; then
				if [ "$4" == "--force" ] || [ "$4" == "-f" ]; then
					# This will force dotnet48 to be reinstalled for each installed 64bit HMM game if `--force` or `-f` is passed to `tinkergame hmm start`
					startHMM "$CMDHMMDLVER" "X"
				else
					startHMM "$CMDHMMDLVER"
				fi
			elif [ "$2" == "list-supported" ] || [ "$2" == "ls" ]; then
				listSupportedHMMGames
			elif [ "$2" == "list-installed" ] || [ "$2" == "li" ]; then
				listInstalledHMMGames
			elif [ "$2" == "list-owned" ] || [ "$2" == "lo" ]; then
				listOwnedHMMGames
			elif [ "$2" == "desktopfile" ] || [ "$2" == "df" ]; then
				createHMMDesktopFile
			elif [ "$2" == "uninstall" ]; then
				uninstallHMM
			elif [ "$2" == "url" ] || [ "$2" == "u" ]; then
				if [ -z "$3" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - No URL was passed for ('$3') -- Maybe this is being incorrectly launched from the XDG menu?"
					warnInvalidModToolLaunch "Hedge Mod Manager"
				else
					dlHedgeMod "$3"
				fi
			elif [ "$2" == "resetmime" ]; then
				writelog "INFO" "${FUNCNAME[0]} - (Re)setting HMM .desktop file entries and MimeType associations"
				echo "(Re)setting HMM .desktop file entries and MimeType associations"
				createHMMDesktopFile
			else
				echo "Need to input a valid arg2 '$2' to run a HedgeModManager command"
				howto
			fi
		else
			writelog "INFO" "arg2 '$2' is no valid command"
			howto
		fi
	;;
	"opengridfolder"|"ogf")
		openSteamGridDir
	;;
	"setgameart"|"sga")
		if [ -n "$2" ]; then
			if [ -z "$3" ]; then
				setGameArtGui "$2"  # Don't think this function needs to take any arguments
			else
				setGameArt "${@:2}"  # Pass all arguments except the first which is the command name e.g. `setgameart`
			fi
		else
			echo "At least one argument (AppID) must be provided"
		fi
	;;
	"noty")
		if [ -n "$2" ]; then
			NTEXT="$2"
		else
			NTEXT="notifier test"
		fi
		notiShow "$NTEXT"
	;;
	"onetimerun"|"otr")
		FUSEID "$2"
		if [ -z "$2" ]; then
			writelog "WARN" "${FUNCNAME[0]} - No AppID provided for One-Time Run, attempting to start with last known AppID '$USEID'"
			if [ -n "$USEID" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found AppID '$USEID' - Using this for One-Time Run"
				OneTimeRunGui "$USEID"
			else
				writelog "ERROR" "${FUNCNAME[0]} - Could not find last known AppID - Aborting One-Time Run"
			fi
		else
			if [ -z "$3" ]; then
				OneTimeRunGui "$USEID"
			else
				commandlineOneTimeRun "${@:2}"
			fi
		fi
	;;
	"pdb")
		getProtonDBRating "$2"
	;;
	"steamdeckcompat"|"sdc")
		mapfile -d ";" -t -O "${#DECKCOMPATARR[@]}" DECKCOMPATARR <<< "$( getSteamDeckCompatInfo "$( echo "$2" | xargs )" )"
		unset "DECKCOMPATARR[-1]"

		if [ "${#DECKCOMPATARR[@]}" -eq "0" ]; then
			echo "Could not get Steam Deck compatibility information got AppID '$2' - Is this definitely correct?"
			echo "You can check get the AppID for a game by running 'tinkergame getid <name>'"
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
	"pickwin"|"pw")
		pickGameWindowNameMeta "$2" "$3"
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
	"proton"|"p")
		if [ -n "$2" ] && [ "$2" == "list" ]; then
			getAvailableProtonVersions "up" X
		else
			StandaloneProtonGame "$2" "$3"
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
	"src")
			"$STEAM" "${STEAM}://${RECO}"
	;;
	"steamworksshared"|"sws")
		if [ -n "$2" ]; then
			if [ "$2" == "install" ] || [ "$2" == "i" ]; then
				if [ -n "$4" ]; then
				installSteWoShPak "$3" "$4" "$5"
				else
					writelog "INFO" "${FUNCNAME[0]} - Need at least package name as arg 3 and a wineprefix OR a SteamAppID as arg 4" E
					writelog "INFO" "${FUNCNAME[0]} - and optionally an absolute path to to a wine binary as arg 5" E
				fi
			elif [ "$2" == "list" ] || [ "$2" == "l" ]; then
				listSteWoShPaks
			else
				writelog "INFO" "${FUNCNAME[0]} - arg2 '$2' is no valid command"
				howto
			fi
		else
			echo "need arg2"
			howto
		fi
	;;
	"${SPEK,,}")
		if [ -n "$2" ]; then
			if [ "$2" == "download" ] || [ "$2" == "dl" ]; then
				dlSpecialK "$3"
			else
				howto
			fi
		else
			howto
		fi
	;;
	"steamgriddb"|"sgdb")
		# This is the new SteamGridDB commandline usage, we just expose direct function to commandline

		# No arguments passed, skip
		if [ -z "$2" ]; then
			echo "Need to pass arguments to SteamGridDB command, see 'tinkergame help' for usage."
			return
		fi

		if [ -z "$3" ]; then
			# TODO ensure this new path does not break 'commandlineGetSteamGridDBArtwork' usage in any way!
			## Show GUI if only 3rd argument given (assume is AppID), i.e if user just entered "tinkergame sgdb <appid>"
			getSteamGridDBArtworkGUI "$2"
		else
			# TODO if search ID is not provided but the first argument is an integer, assume it is the AppID
			## Will allow for usage like `tinkergame sgdb 730 --apply` which is very clean
			commandlineGetSteamGridDBArtwork "$@"
		fi
	;;
	"getsteamgriddbid"|"sgdbid")
		getSGDBGameIDFromTitle "$2"
	;;
	"update")
		if [ -n "$2" ]; then
			if [ "$2" == "gamedata" ]; then
				if [ -z "$3" ]; then
					getGameDataForInstalledGames
				else
					echo getGameData "$3"
					getGameData "$3"
				fi
			elif [ "$2" == "grid" ]; then
				if [ -z "$3" ]; then
					getGridsForOwnedGames
				elif [ "$3" == "owned" ]; then
					getGridsForOwnedGames
				elif [ "$3" == "installed" ]; then
					getGridsForInstalledGames
				elif [ "$3" == "nonsteam" ] || [ "$3" == "shortcuts" ]; then
					getGridsForNonSteamGames
				fi
			elif [ "$2" == "allgamedata" ]; then
				getDataForAllGamesinSharedConfig
			elif [ "$2" == "shader" ] || [ "$2" == "shaders" ]; then
				if [ -n "$3" ] && { [ "$3" == "repos" ] || [ "$3" == "list" ]; }; then
					dlShaders "$3"
				else
					StatusWindow "$GUI_DLSHADER" "dlShaders $3"  "DownloadShadersStatus"
				fi
			elif [ "$2" == "gameshader" ] || [ "$2" == "gameshaders" ]; then
				if [ -z "$3" ]; then
					writelog "INFO" "${FUNCNAME[0]} - No game directory in argument 3 provided - using last game!"
					GameShaderDialog
				else
					if [ -d "$3" ]; then
						writelog "INFO" "${FUNCNAME[0]} - command line: GameShaderDialog \"$3\""
						GameShaderDialog "$3"
					else
						if [ -n "$4" ]; then
							if [ -d "$4" ]; then
								if [ -n "$5" ] && [ "$5" == "disable" ]; then
									disableThisGameShaderRepo "$3" "$4"
								else
									enableThisGameShaderRepo "$3" "$4"
								fi
							elif [ "$4" == "block" ]; then
								echo "$3" >> "$SHADERREPOBLOCKLIST"
								sort -u "$SHADERREPOBLOCKLIST" -o "$SHADERREPOBLOCKLIST"
								unblockrssub
							elif [ "$4" == "unblock" ]; then
								grep -v "^${3}$" "$SHADERREPOBLOCKLIST" > "$STLSHM/SHADERREPOBLOCKLIST_tmp.txt"
								mv "$STLSHM/SHADERREPOBLOCKLIST_tmp.txt" "$SHADERREPOBLOCKLIST"
							else
								writelog "SKIP" "${FUNCNAME[0]} - Invalid argument '$4' - exit"
							fi
						else
							writelog "SKIP" "${FUNCNAME[0]} - Game directory '$3' does not exist - exit"
						fi
					fi
				fi
			elif [ "$2" == "reshade" ]; then
				dlReShade "$3"
			else
				howto
			fi
		else
			howto
		fi
	;;
	"cleargamegrids")
		if [ -z "$2" ]; then
			writelog "ERROR" "${FUNCNAME[0]} - No parameter given, cannot remove artwork, skipping"
			echo "You must provide either a Steam AppID to remove artwork for, or specify 'all' to remove all game artwork"
		else
			removeSteamGrids "$2"
		fi
	;;
	"version"|"--version"|"-v")
		echo "${PROGNAME,,}-${PROGVERS}"
	;;
	"$VTX")
		# TODO Vortex uninstall option?
		# TODO Vortex commandline flag to set no auto update (i.e. --disable-auto-update)

		USEVORTEX=1
		if [ -n "$2" ]; then
			# If we get a third parameter and any passed command should download/install/start Vortex,
			# set the Vortex version to download to the given version (will only be used if Vortex is not already installed)
			#
			# TODO handle passing a custom installer file, probably only for "install" though where we'll force set a different var
			if [[ -n "$3" && ( "$2" == "download" || "$2" == "install" || "$2" == "start" || "$2" == "getset" ) ]]; then
				if [ "$USEVORTEXCUSTOMVER" -eq 0 ]; then
					writelog "WARN" "${FUNCNAME[0]} - Custom Vortex version passed ('$3') but USEVORTEXCUSTOMVER is '$USEVORTEXCUSTOMVER'"
					writelog "WARN" "${FUNCNAME[0]} - Assuming you know what you're doing and using this version anyway..."
				fi

				USEVORTEXCUSTOMVER=1
				VORTEXCUSTOMVER="$3"
			fi

			if [ "$2" == "install" ] || [ "$2" == "i" ]; then
				if [ -n "$3" ] && [ "$3" == "gui" ]; then
					installVortexGui
				else
					StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${VTX^}")" "dlLatestVortex S" "DownloadVortexStatus"
					StatusWindow "$(strFix "$NOTY_INSTSTART" "${VTX^}")" "installVortex" "InstallVortexStatus"
				fi
			elif [ "$2" == "start" ]; then
				startVortex "noask" "$3"
			elif [ "$2" == "url" ] || [ "$2" == "u" ]; then
				if [ -z "$3" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - No URL was passed for ('$3') -- Maybe this is being incorrectly launched from the XDG menu?"
					warnInvalidModToolLaunch "Vortex"
				else
					startVortex "noask" "url" "$3"
				fi
			elif [ "$2" == "getset" ]; then
				startVortex "noask" "$2"
			elif [ "$2" == "gui" ]; then
				VortexOptions
			elif [ "$2" == "reset" ]; then
				resetVortexSettings
			elif [ "$2" == "stage" ]; then
				addVortexStage "$3"
			elif [ "$2" == "list-supported" ] || [ "$2" == "ls" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Games With ${VTX^} Support found in the ${VTX^} installation:" "E"
				getVortexSupportedNames
			elif [ "$2" == "list-online" ] || [ "$2" == "lo" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Games With ${VTX^} Support listed online:" "E"
				dlVortexSupportedList
			elif [ "$2" == "list-owned" ] || [ "$2" == "low" ]; then
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
			elif [ "$2" == "list-installed" ] || [ "$2" == "li" ]; then
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
			elif [ "$2" == "games" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Opening Gui for en/disabling ${VTX^} for installed and supported games"
				VortexGamesDialog
			elif [ "$2" == "symlinks" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Opening Gui showing Symlinks in the ${VTX^} WINEPREFIX"
				VortexSymDialog
			elif [ "$2" == "download" ] || [ "$2" == "d" ]; then
				StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${VTX^}")" "dlLatestVortex S" "DownloadVortexStatus"
			elif [ "$2" == "activate" ] && { [ -n "$3" ]  && [ "$3" -eq "$3" ] 2>/dev/null;}; then
				startVortex "activate" "$3"
			elif [ "$2" == "getprefix" ] || [ "$2" == "gp" ]; then
				echo "$VORTEXCOMPDATA/pfx"
			elif [ "$2" == "winecfg" ]; then
				vtxWinecfg
			elif [ "$2" == "winetricks" ] || [ "$2" == "wt" ]; then
				vtxWinetricks
			elif [ "$2" == "resetmime" ]; then
				writelog "INFO" "${FUNCNAME[0]} - (Re)setting ${VTX^} .desktop file entries and MimeType associations"
				echo "(Re)setting ${VTX^} .desktop file entries and MimeType associations"
				setVortexDLMime
			else
				writelog "INFO" "${FUNCNAME[0]} - arg2 '$2' is no valid command"
				howto
			fi
		else
			echo "need arg2"
			howto
		fi
	;;
	"vr")
		if [ -n "$3" ]; then
			GAMEWINDOW="$2"
			AID="$3"
			setAIDCfgs
			if [ -n "$4" ] && [ "$4" == "s" ]; then
				storeGameWindowNameMeta "$(getGameWinNameFromXid "$2")"
			fi
			checkSBSVRLaunch "$2"
		else
			howto
		fi
	;;
	"waitrequester"|"wr")
		if [ -n "$2" ] && { [ "$2" == "e" ] || [ "$2" == "s" ] || [ "$2" == "u" ];}; then
			if [ "$2" == "e" ]; then
				writelog "INFO" "${FUNCNAME[0]} - enabling the Wait Requester for the next launched game"
				touch "$EWRF"
			elif [ "$2" == "s" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Skipping the Wait Requester temporarily for the next launched games"
				touch "$SWRF"
			elif [ "$2" == "u" ]; then
				if [ -f "$SWRF" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Disabling the temporary Wait Requester skipping"
					touch "$UWRF"
				else
					writelog "SKIP" "${FUNCNAME[0]} - The temporary Wait Requester skipping is not enabled, nothing to do"
				fi
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} ------------------------"
			writelog "INFO" "${FUNCNAME[0]} - need either e,s or u as arg2"
			howto
		fi
	;;
	"wiki")
		OpenWikiPage "$2"
	;;
	"winetricks"|"wt")
		FUSEID "$2"
		chooseWinetricksPrefix "$USEID"
	;;
	"runwinecfg"|"onetimewinecfg"|"otwcfg")
		# Assumes that if `runwinecfg` is called without any arguments that it's an internal call
		# Otherwise we assume if *any* arguments are passed that we're a user calling it from the command-line
		if [ -n "$2" ]; then
			# Always assume second argument is the AppID
			#
			# Could be improved in future by trying to find a matching game based on an entered game name
			# In the case of multiple matches we could just take the first match
			#
			# (Maybe AppID should be checked for first, on the off-chance that a game's names is the same as an AppID?
			writelog "INFO" "${FUNCNAME[0]} - Looks like we're a user calling this from the command line -- User passed '$2'"
			oneTimeWinecfg "$2"
		else
			writelog "INFO" "${FUNCNAME[0]} - Looks like we're getting an internal One-Time Winecfg call"
			oneTimeWinecfg
		fi
	;;
	"runwinetricks"|"onetimewinetricks"|"otwt")
		# All of the above comments about Winecfg apply to this Winetricks logic as well
		if [ -n "$2" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Looks like we're a user calling this from the command line -- User passed '$2'"
			oneTimeWinetricks "$2"
		else
			writelog "INFO" "${FUNCNAME[0]} - Looks like we're getting an internal One-Time Winetricks call"
			oneTimeWinetricks
		fi
	;;
	"winedebugchannel"|"wdc")
		FUSEID "$2"
		SetWineDebugChannels "$USEID"
	;;
	"yad")
		if [ -n "$2" ]; then
			setYadBin "$2" "$3"
		else
			writelog "INFO" "${FUNCNAME[0]} ------------------------"
			writelog "INFO" "${FUNCNAME[0]} - arg2 '$2' needs to be a valid yad parameter"
			howto
		fi
	;;
	"openissue"|"oi")
		writelog "INFO" "${FUNCNAME[0]} - Opening issue tracker in user's default browser"
		"$XDGO" "$PROJECTPAGE/issues/new/choose"
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
#ENDCMDLINE


### COMMAND LINE END ###

