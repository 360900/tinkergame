#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function findNonSteamGameIcon {
	find "${STUIDPATH}/config/grid/" -name "${NOSTAIDGRID}_icon.*" | head -n1 2>/dev/null
}

function addNonSteamGame {
	if [ -z "$SUSDA" ] || [ -z "$STUIDPATH" ]; then
		setSteamPaths
	fi
	SCPATH="$STUIDPATH/config/$SCVDF"

	function checkValidVDFBoolean {
		[ "$1" -eq 1 ] || [ "$1" -eq 0 ] && echo "$1"
	}

	function getCRC {
		echo -n "$1" | gzip -c | tail -c 8 | od -An -N 4 -tx4
	}

	function hex2dec {
		printf "%d\n" "0x${1#0x}"
	}

	## How Non-Steam AppIDs work, because it took me almost a year to figure this out
	## ----------------------
	## Steam stores shortcuts in a binary 'shortcuts.vdf', at SROOT/userdata/<id>/config
	##
	## Non-Steam AppIDs are 32bit little-endian (reverse byte order) signed integers, stored as hexidecimal
	## This is probably generated using a crc32 generated from AppName + Exe, but it can actually be anything
	## Steam likely does this to ensure "uniqueness" among entries, tools like Steam-ROM-Manager do the same thing likely for similar reasons
	##
	## For simplicity we generate a random 32bit signed integer using an md5, which we'll then convert to hex to store in the AppID file
	## Though we can write any AppID we want, Steam will reject invalid ones (i.e. big endian hex) it will overwrite our AppID
	## We can also convert this to an unsigned 32bit integer to get the AppID used for grids and other things, the unsigned int is just what Steam stores
	##
	## We can later re-use these functions to do several things:
	## - Check for and remove stray STL configs for no longer stored Non-Steam Game AppIDs (if we had Non-Steam Games we previously used with STL that we no longer use, we can remove these configs in case there is a conflict in future)

	### BEGIN MAGIC APPID FUNCTIONS
	## ----------
	# Generate random signed 32bit integer which can be converted into hex, using the first argument (AppName and Exe fields) as seed (in an attempt to reduce the chances of the same AppID being generated twice)
	function generateShortcutVDFAppId {
		seed="$( echo -n "$1" | md5sum | cut -c1-8 )"
		echo "-$(( 16#${seed} % 1000000000 ))"
	}

	function dec2hex {
		printf '%x\n' "$1" | cut -c 9-  # cut removes the 'ffffffff' from the string (represents the sign) and starts from the 9th character
	}

	# Takes big-endian ("normal") hexidecimal number and converts to little-endian
	function bigToLittleEndian {
		echo -n "$1" | tac -rs .. | tr -d '\n'
	}

	# Takes an signed 32bit integer and converts it to a 4byte little-endian hex number
	function generateShortcutVDFHexAppId {
		bigToLittleEndian "$( dec2hex "$1" )"
	}

	## ----------
	### END MAGIC APPID FUNCTIONS

	function splitTags {
		mapfile -d "," -t -O "${#TAGARR[@]}" TAGARR < <(printf '%s' "$1")
		for i in "${!TAGARR[@]}"; do
			if grep -q "${TAGARR[$i]}" <<< "$(getActiveSteamCollections)"; then
				printf '\x01%s\x00%s\x00' "$i" "${TAGARR[i]}"
			fi
		done
	}

	## Return first image file matching passed name (i.e "hero") in game EXE dir - Used to find named artwork files in the game EXE folder for Non-Steam Games as a fallback if no artwork is provided
	function findGameArtInExeDir {
		NOSTSEARCHDIR="$1"
		NOSTARTFILENAME="${2%%.*}"  # e.x. "hero", "logo"
		NOSTORGFILENAME="${3}"  # Used to return in case no artwork is found, so the original name is used as a fallback

		NOSTFOUNDARTWORK="$( realpath "$( find "$NOSTSEARCHDIR" -name "$NOSTARTFILENAME.*" | head -n1 )" 2>/dev/null )"
		if grep -q "image data" <<< "$( file "$NOSTFOUNDARTWORK" )"; then
			echo "$NOSTFOUNDARTWORK"
		else
			echo "$NOSTORGFILENAME"
		fi
	}

	NOSTHIDE=0  # Set in localconfig.vdf along with tags and overlay settings
	NOSTADC=1
	NOSTAO=1
	NOSTVR=0
	NOSTSTLLO=0
	NOSTAUTOARTWORK=0
	NOSTUSESGDB=0
	for i in "$@"; do
		case $i in
			## General Non-Steam Game properties
			-an=*|--appname=*)
				NOSTAPPNAME="${i#*=}"
				shift ;;
			-ep=*|--exepath=*)
				QEP="${i#*=}";
				if [ -n "$QEP" ]; then
					NOSTEXEPATH="\"$QEP\""
				fi
				shift ;;
			-sd=*|--startdir=*)
				QSD="${i#*=}"
				if [ -n "$QSD" ] && [ -d "$QSD" ]; then
					NOSTSTDIR="\"$QSD\""
				fi
				shift ;;
			-ip=*|--iconpath=*)
				NOSTICONPATH="${i#*=}"
				shift ;;
			-lo=*|--launchoptions=*)
				NOSTLAOP="${i#*=}"
				shift ;;
			-hd=*|--hide=*)
				NOSTHIDE="$( checkValidVDFBoolean "${i#*=}" )"
				shift ;;
			-adc=*|--allowdesktopconf=*)
				NOSTADC="$( checkValidVDFBoolean "${i#*=}" )"
				shift ;;
			-ao=*|--allowoverlay=*)
				NOSTAO="$( checkValidVDFBoolean "${i#*=}" )"
				shift ;;
			-vr=*|--openvr=*)
				NOSTVR="$( checkValidVDFBoolean "${i#*=}" )"
				shift ;;
			-t=*|--tags=*)
				NOSTTAGS="${i#*=}"
				shift ;;
			-stllo=*|--stllaunchoption=*)
				NOSTSTLLO="${i#*=}"
				shift ;;
			-ct=*|--compatibilitytool=*)
				## Get path based on passed name from ProtonCSV, then build argument needed for getProtonInternalName
				NOSTCOMPATTOOL=""
				NOSTCOMPATTOOLNAME="${i#*=}"
				if [ -n "$NOSTCOMPATTOOLNAME" ]; then
					if [[ "$NOSTCOMPATTOOLNAME" == "default" ]]; then  # Default fetches the global Steam compat tool
						GLOBALSTEAMCOMPATTOOL="$( getGlobalSteamCompatToolInternalName )"
						if [ -n "$GLOBALSTEAMCOMPATTOOL" ]; then
							NOSTCOMPATTOOL="$GLOBALSTEAMCOMPATTOOL"
						else
							writelog "INFO" "${FUNCNAME[0]} - Selected 'default' compatibility tool but could not find one in '$CFGVDF' -- Not writing compatibility tool for Non-Steam Game"
						fi
					else
						NOSTCOMPATTOOLPATH="$( getProtPathFromCSV "$NOSTCOMPATTOOLNAME" )"

						if [ -n "$NOSTCOMPATTOOLPATH" ]; then
							NOSTCOMPATTOOL="$( getProtonInternalName "${NOSTCOMPATTOOLNAME};${NOSTCOMPATTOOLPATH}" )"
						else  # i.e. if 'luxtorpeda' was passed, we don't have a path for this, so simply trust the user
							writelog "SKIP" "${FUNCNAME[0]} - Could not get Proton path for given Compatibility Tool '$NOSTCOMPATTOOLNAME' from ProtonCSV -- Simply assuming this internal name is valid and not known to TinkerGame"
							NOSTCOMPATTOOL="$NOSTCOMPATTOOLNAME"
						fi
					fi
				else
					writelog "SKIP" "${FUNCNAME[0]} - Compatibility Tool name argument was passed, but was empty '$NOSTCOMPATTOOLNAME' -- Skipping"
				fi

				shift ;;
			-hr=*|--hero=*)
				NOSTGHERO="${i#*=}"  # <appid>_hero.png -- Banner used on game screen, logo goes on top of this
				shift ;;
			-lg=*|--logo=*)
				NOSTGLOGO="${i#*=}"  # <appid>_logo.png -- Logo used e.g. on game screen
				shift ;;
			-ba=*|--boxart=*)
				NOSTGBOXART="${i#*=}"  # <appid>p.png -- Used in library
				shift ;;
			-tf=*|--tenfoot=*)
				NOSTGTENFOOT="${i#*=}"  # <appid>.png -- Used as small boxart for e.g. most recently played banner
				shift ;;
			--auto-artwork)
				NOSTAUTOARTWORK=1  # Look for artwork with matching names from game EXE folder (hero/logo/boxart/tenfoot.png/jpg/jpeg/gif)
				shift ;;
			## SteamGridDB artwork options
			--use-steamgriddb)
				NOSTUSESGDB=1  # Commandline usage option so a user can tell us to search SteamGridDB using 'NOSTAPPNAME' -- If they pass any other values this will be enabled anyway
				shift ;;
			--steamgriddb-game-id=*|-sgid=*)
				NOSTSGDBGAMEID="${i#*=}"  # SteamGridDB Game ID to search for grids on (optional)
				shift ;;
			--steamgriddb-steam-appid=*|-sgai=*)
				NOSTSGDBSTAID="${i#*=}"  # Steam Game AppID to search for grids on (optional)
				shift ;;
			--steamgriddb-game-name=*|-sgnm=*)
				NOSTSGDBNAM="${i#*=}"  # Game Name to Search SteamGridDB on (will look for name on SteamGridDB, return the SteamGridDB Game ID, aand search on that) (optional)
				shift ;;
			## Used to pass to setGameArt to define how we want to set game artwork (essentially giving a Non-Steam Game UI the functionality of setGameArt since we call it here anyway)
			--copy)
				SGACOPYMETHOD="--copy"  # Copy file to grid folder -- Default
				shift ;;
			--link)
				SGACOPYMETHOD="--link"  # Symlink file to grid folder
				shift ;;
			--move)
				SGACOPYMETHOD="--move"  # Move file to grid folder
				shift ;;
			*) ;;
		esac
	done

	# Ensure we stop without valid EXE -- EXE is the only *required* field, all others can be inferred from it
	# We check against the string with quotes removed for the -z check even though the case above should match it - We have to do this to have a valid path for '-f' check
	NOSTEXEPATHNOQUOTE="$( sed -e 's/^"//' -e 's/"$//' <<< "${NOSTEXEPATH}" )"
	if [ -z "${NOSTEXEPATHNOQUOTE}" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - NOSTEXEPATH was blank, could not add Non-Steam Game -- Aborting!"
		notiShow "${NOTY_NOSTEXEBLANK}"
		echo "Error: Could not add Non-Steam Game -- Executable path was not provided"
		return 1
	elif [ ! -f "${NOSTEXEPATHNOQUOTE}" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - NOSTEXEPATH is not a valid file, could not add Non-Steam Game -- Aborting!"
		notiShow "${NOTY_NOSTEXENOTFOUND}"
		echo "Error: Could not add Non-Steam Game -- Executable is not a valid file!"
		return 1
	fi

	NOSTAPPNAME="${NOSTAPPNAME:-${QEP##*/}}"

	if [ -z "${NOSTSTDIR}" ] || [ ! -d "${NOSTSTDIR}" ]; then
		QSD="$(dirname "$QEP")"; NOSTSTDIR="\"$QSD\""
	fi

	if [ "$NOSTSTLLO" -eq 1 ]; then NOSTGICONPATH="$STLICON"; fi

	# This is formatted as a flag because we can pass "$SGACOPYMETHOD" as an argument to setGameArt, and it will be interpreted as --copy
	SGACOPYMETHOD="${SGACOPYMETHOD:---copy}"

	# off by default but always passed from addNonSteamGame, so if we actually get a value for any of these fields, enable it
	# NOSTUSESGDB=1 flag is for user commandline usage, when they search SteamGridDB for artwork using game name, but don't want to pass other values
	if [ -n "$NOSTSGDBSTAID" ] || [ -n "$NOSTSGDBGAMEID" ] || [ -n "$NOSTSGDBNAM" ]; then NOSTUSESGDB=1; fi

	## These AppIDs are not necessarily guaranteed to be unique, i.e. if the user tries to add the same game twice or something
	## In future we could do a stricter check by attempting to parse the shortcuts.vdf file and re-generating the AppID if it already exists - could be expensive though
	NOSTAIDVDF="$( generateShortcutVDFAppId "${NOSTAPPNAME}${NOSTEXEPATH}" )"  # signed integer AppID, stored in the VDF as hexidecimal - ex: -598031679
	NOSTAIDVDFHEX="$( generateShortcutVDFHexAppId "$NOSTAIDVDF" )"  # 4byte little-endian hexidecimal of above 32bit signed integer, which we write out to the binary VDF - ex: c1c25adc
	NOSTAIDVDFHEXFMT="\x$(awk '{$1=$1}1' FPAT='.{2}' OFS="\\\x" <<< "$NOSTAIDVDFHEX")"  # binary-formatted string hex of the above which we actually write out - ex: \xc1\xc2\x5a\xdc
	NOSTAIDGRID="$( generateSteamShortID "$NOSTAIDVDF" )"  # unsigned 32bit ingeger version of "$NOSTAIDVDF", which is used as the AppID for Steam artwork ("grids"), as well as for our shortcuts

	writelog "INFO" "${FUNCNAME[0]} - === Adding new $NSGA ==="
	writelog "INFO" "${FUNCNAME[0]} - Signed Integer Shortcut AppID: '${NOSTAIDVDF}'"
	writelog "INFO" "${FUNCNAME[0]} - 4byte Little-Endian Hex AppID: '${NOSTAIDVDFHEX}'"
	writelog "INFO" "${FUNCNAME[0]} - Binary-formatted 4byte Little-Endian AppID: '${NOSTAIDVDFHEXFMT}'"
	writelog "INFO" "${FUNCNAME[0]} - Unsigned Integer Shortcut AppID (used for artwork): '${NOSTAIDGRID}'"
	writelog "INFO" "${FUNCNAME[0]} - App Name: '${NOSTAPPNAME}'"
	writelog "INFO" "${FUNCNAME[0]} - Exe Path: '${NOSTEXEPATH}'"
	writelog "INFO" "${FUNCNAME[0]} - Start Dir: '${NOSTSTDIR}'"
	writelog "INFO" "${FUNCNAME[0]} - Icon Path: '${NOSTICONPATH}'"
	writelog "INFO" "${FUNCNAME[0]} - Launch options: '${NOSTLAOP}'"
	writelog "INFO" "${FUNCNAME[0]} - Is Hidden: '${NOSTHIDE}'"
	writelog "INFO" "${FUNCNAME[0]} - Allow Desktop Config: '${NOSTADC}'"
	writelog "INFO" "${FUNCNAME[0]} - Allow Overlay: '${NOSTAO}'"
	writelog "INFO" "${FUNCNAME[0]} - OpenVR: '${NOSTVR}'"
	writelog "INFO" "${FUNCNAME[0]} - Tags: '${NOSTTAGS}'"
	writelog "INFO" "${FUNCNAME[0]} - Compatibility Tool: '${NOSTCOMPATTOOL}'"
	## Artwork logging -- These will be blank if no artwork is passed, that's OK
	writelog "INFO" "${FUNCNAME[0]} - Hero Artwork: '${NOSTGHERO}'"
	writelog "INFO" "${FUNCNAME[0]} - Logo Artwork: '${NOSTGLOGO}'"
	writelog "INFO" "${FUNCNAME[0]} - Boxart Artwork: '${NOSTGBOXART}'"
	writelog "INFO" "${FUNCNAME[0]} - Tenfoot Artwork: '${NOSTGTENFOOT}'"
	writelog "INFO" "${FUNCNAME[0]} - Copy Method for Artwork: '${SGACOPYMETHOD}'"
	writelog "INFO" "${FUNCNAME[0]} - EXE Dir Fallback Artwork: '${NOSTGEXEARTWORKFALLBACK}'"
	## SteamGridDB logging -- Also might be blank and that's fine
	writelog "INFO" "${FUNCNAME[0]} - Use SteamGridDB: '${NOSTUSESGDB}'"
	writelog "INFO" "${FUNCNAME[0]} - SteamGridDB Game ID: '${NOSTSGDBGAMEID}'"
	writelog "INFO" "${FUNCNAME[0]} - SteamGridDB Steam AppID: '${NOSTSGDBAID}'"
	writelog "INFO" "${FUNCNAME[0]} - SteamGridDB Search Name: '${NOSTSGDBNAM}'"

	if [ -f "$SCPATH" ]; then
		writelog "INFO" "${FUNCNAME[0]} - The file '$SCPATH' already exists, creating a backup, then removing the 2 closing backslashes at the end"
		cp "$SCPATH" "${SCPATH//.vdf}_${PROGNAME}_backup.vdf" 2>/dev/null
		truncate -s-2 "$SCPATH"
		OLDSET="$(grep -aPo '\x00[0-9]\x00\x02appid' "$SCPATH" | tail -n1 | tr -dc '0-9')"
		NEWSET=$((OLDSET + 1))
		writelog "INFO" "${FUNCNAME[0]} - Last set in file has ID '$OLDSET', so continuing with '$OLDSET'"
	else
		writelog "INFO" "${FUNCNAME[0]} - Creating new $SCPATH"
		printf '\x00%s\x00' "shortcuts" > "$SCPATH"
		NEWSET=0
	fi

	## Match any image file in same folder as EXE name hero, logo, boxart, tenfoot -- Matches will override selected options
	# If not found, fall back to actual file path provided meaning only artwork that exists will be used
	if [ "$NOSTAUTOARTWORK" -eq 1 ]; then
		NOSTEXEBASEDIR="$( dirname "$NOSTEXEPATH" | cut -d '"' -f2 )"

		NOSTGHERO="$( findGameArtInExeDir "$NOSTEXEBASEDIR" "hero" "$NOSTGHERO" )"
		NOSTGLOGO="$( findGameArtInExeDir "$NOSTEXEBASEDIR" "logo" "$NOSTGLOGO" )"
		NOSTGBOXART="$( findGameArtInExeDir "$NOSTEXEBASEDIR" "boxart" "$NOSTGBOXART" )"
		NOSTGTENFOOT="$( findGameArtInExeDir "$NOSTEXEBASEDIR" "tenfoot" "$NOSTGTENFOOT" )"
		NOSTICONPATH="$( findGameArtInExeDir "$NOSTEXEBASEDIR" "icon" "$NOSTICONPATH" )"
	fi

	## Fetch artwork from SteamGridDB
	if [ "$NOSTUSESGDB" -eq 1 ]; then
		# Regular artwork
		notiShow "$NOTY_SGDBDL"

		# The entered search name is prioritised over actual game EXE name, only one will be used and we will always prefer custom name
		# Ex: user names Non-Steam Game "The Elder Scrolls IV: Oblivion" but they enter a custom search name because they want artwork for "The Elder Scrolls IV: Oblivion Game of the Year Edition"
		# In case art is not found for the custom name, users should enter either the Steam AppID or the SteamGridDB Game ID to use as a fallback (Steam AppID will always be preferred because it will always be exact)
		#
		# Therefore, the order of priority for artwork searching is:
		# 1. Name search (only ONE of the below will be used)
		#     a. If the user enters a custom search name with --steamgriddb-game-name, search on that
		#     b. Otherwise, use the Non-Steam Game name
		# 2. Fallback to ID search if no SteamGridDB ID is found on the name search
		#    a. If the user enters a Steam AppID with --steamgriddb-steam-appid, search on that
		#    b. Otherwise, fall back to searching on an entered SteamGridDB Game ID
		# In short, search on ONE of the names, and if a Game ID is not found on either of these, fall back to searching on ONE of the passed IDs
		# If no IDs are found after all of this, we can't get artwork. We will not fall back to EXE name if no ID is found on custom name, and we will not fall back to SteamGridDB Game ID if no art is found for Steam AppID
		# If no values are provided we will simply search on Non-Steam Game name
		NOSTSEARCHNAME=""  # Name to search for SteamGridDB Game ID on (either custom name or app name)
		NOSTSEARCHID=""  # ID to search for the SteamGridDB artwork on (either Steam AppID or SteamGridDB Game ID)
		NOSTSEARCHFLAG="--nonsteam"  # Whether to search using a Steam AppID or SteamGridDB Game ID (will be set to --steam if we get an AppID)
		if [ -n "$NOSTSGDBSTAID" ]; then
			NOSTSEARCHID="$NOSTSGDBSTAID"
			NOSTSEARCHFLAG="--steam"  # If a match is found on game name above, commandlineGetSteamGridDBArtwork will manage falling back to searching with SteamGridDB Game ID, so this is safe
		elif [ -n "$NOSTSGDBGAMEID" ]; then
			NOSTSEARCHID="$NOSTSGDBGAMEID"
		fi

		# Only add NOSTAPPNAME as fallback if we don't have an ID to search on, because commandlineGetSteamGridDBArtwork will prefer name over ID, so if we have to fall back to Non-Steam Name (i.e. no entered custom name) then only do so if we don't have an ID given
		if [ -n "$NOSTSGDBNAM" ]; then
			NOSTSEARCHNAME="$NOSTSGDBNAM"
		elif [ -n "$NOSTAPPNAME" ] && [ -z "$NOSTSEARCHID" ]; then
			NOSTSEARCHNAME="$NOSTAPPNAME"
		fi

		# Store the ID we searched with, so getSteamGridDBNonSteamIcon doesn't have to hit the endpoint again and we save an API call
		commandlineGetSteamGridDBArtwork --search-name="$NOSTSEARCHNAME" --search-id="$NOSTSEARCHID" --filename-appid="$NOSTAIDGRID" "$NOSTSEARCHFLAG" --apply --replace-existing

		# Get ID that commandlineGetSteamGridDBArtwork searched on above and use that to search for the icon
		NOSTSGDBAPIGAMEID="$( cat "$NOSTSGDBIDSHMFILE" )"

		# Icon -- Only set if we successfully download an icon from SteamGridDB
		getSteamGridDBNonSteamIcon "$NOSTAIDGRID" "$NOSTSGDBAPIGAMEID"
		NOSTSGDBICON="$( findNonSteamGameIcon )"
		if [ -f "$NOSTSGDBICON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found SteamGridDB icon path to '$NOSTSGDBICON' -- Using this as Non-Steam Game Icon"
			NOSTICONPATH="$NOSTSGDBICON"
		else
			writelog "INFO" "${FUNCNAME[0]} - Icon path does not exist at '$NOSTSGDBICON' - Maybe download failed?"
		fi

		notiShow "$NOTY_SGDBDLDONE"
	fi

	writelog "INFO" "${FUNCNAME[0]} - Adding new set '$NEWSET'"
	{
		printf '\x00%s\x00' "$NEWSET"
		printf '\x02%s\x00%b' "appid" "$NOSTAIDVDFHEXFMT"
		printf '\x01%s\x00%s\x00' "AppName" "$NOSTAPPNAME"
		printf '\x01%s\x00%s\x00' "Exe" "$NOSTEXEPATH"
		printf '\x01%s\x00%s\x00' "StartDir" "$NOSTSTDIR"
		printf '\x01%s\x00%s\x00' "icon" "$NOSTICONPATH"
		printf '\x01%s\x00%s\x00' "ShortcutPath" ""
		printf '\x01%s\x00%s\x00' "LaunchOptions" "$NOSTLAOP"

		printf '\x02%s\x00%b\x00\x00\x00' "IsHidden" "\x0${NOSTHIDE:-0}"
		printf '\x02%s\x00%b\x00\x00\x00' "AllowDesktopConfig" "\x0${NOSTADC:-0}"

		# These values are now stored in localconfig.vdf under the "Apps" section,
		# under a block using the Non-Steam Game Signed 32bit AppID. (i.e., -223056321)
		# This is handled by `updateLocalConfigAppsValue` below
		#
		# Unsure if required, but still write these to the shortcuts.vdf file for consistency
		printf '\x02%s\x00%b\x00\x00\x00' "AllowOverlay" "\x0${NOSTAO:-0}"
		printf '\x02%s\x00%b\x00\x00\x00' "OpenVR" "\x0${NOSTVR:-0}"

		printf '\x02%s\x00\x00\x00\x00\x00' "Devkit"
		printf '\x01%s\x00\x00' "DevkitGameID"
		printf '\x02%s\x00\x00\x00\x00\x00' "DevkitOverrideAppID"
		printf '\x02%s\x00\x00\x00\x00\x00' "LastPlayTime"
		printf '\x01%s\x00\x00' "FlatpakAppID"
		printf '\x00%s\x00' "tags"
		splitTags "$NOSTTAGS"  # TODO tags are now stored in localconfig.vdf (see #949) but we still write them here anyway
		printf '\x08\x08\x08\x08'
	} >> "$SCPATH"

	writelog "INFO" "${FUNCNAME[0]} - Finished writing out new Non-Steam Game Shortcut"
	writelog "INFO" "${FUNCNAME[0]} - Adding any chosen Non-Steam game artwork"

	setGameArt "$NOSTAIDGRID" --hero="$NOSTGHERO" --logo="$NOSTGLOGO" --boxart="$NOSTGBOXART" --tenfoot="$NOSTGTENFOOT" "$SGACOPYMETHOD"

	if [ -n "$NOSTCOMPATTOOL" ]; then
		if [ ! -f "$CFGVDF" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - No Config VDF found at '$CFGVDF' -- Unable to set compatibility tool for Non-Steam Game, skipping"
		else
			writelog "INFO" "${FUNCNAME[0]} - Adding selected compatibility tool '$NOSTCOMPATTOOL' for Non-Steam Game"
			NSGVDFVALS=( "name!${NOSTCOMPATTOOL}" "config!" "priority!250" )
			createVdfEntry "$CFGVDF" "CompatToolMapping" "$NOSTAIDGRID" "" "" "" "${NSGVDFVALS[@]}"
			writelog "INFO" "${FUNCNAME[0]} - Finished adding Non-Steam Game compatibility tool to '$CFGVDF'"
		fi
	fi

	# Update "Apps" section in localconfig.vdf to create the section for the new Non-Steam Game and set AllowOverlay and OpenVR accordingly
	# In future if more options are stored here we can also set them in the same way
	writelog "INFO" "${FUNCNAME[0]} - Updating 'localconfig.vdf' to set OpenVR and AllowOverlay values, using Signed 32bit AppID '$NOSTAIDVDF'"
	updateLocalConfigAppsValue "$NOSTAIDVDF" "OverlayAppEnable" "$NOSTAO"
	updateLocalConfigAppsValue "$NOSTAIDVDF" "DisableLaunchInVR" "$(( 1-NOSTVR ))"  # localconfig.vdf tracks where OpenVR is DISabled rather than ENabled, so flip the boolean

	writelog "INFO" "${FUNCNAME[0]} - Finished adding new $NSGA"
	SGACOPYMETHOD=""  # Unset doesn't work for some reason with '--flag'
}

