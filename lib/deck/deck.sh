#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function steamdeckClose {
	if [ "$ONSTEAMDECK" -eq 1 ]; then
		GTKCSSFILE="$HOME/.config/gtk-3.0/gtk.css"
		if [ -f "${GTKCSSFILE}_ORIGNAL" ] ; then
			writelog "INFO" "${FUNCNAME[0]} - recovering original gtk.css from '${GTKCSSFILE}_ORIGNAL'"
			mv "${GTKCSSFILE}_ORIGNAL" "$GTKCSSFILE"
		fi

		if [ -n "$STLCTLID" ] && [ "$STLCTLID" != "$PLACEHOLDERAID" ]; then
			VTAPP="769"
			writelog "INFO" "${FUNCNAME[0]} - Loading controller configuration of ValveTestApp769 '$VTAPP' to map the controller to the default Steam Deck settings via 'steam steam://forceinputappid/$VTAPP'"
			steam steam://forceinputappid/"$VTAPP"
		fi
	fi
}

function steamdeckBeforeGame {
	if [ "$ONSTEAMDECK" -eq 1 ]; then
		if [ "$FIXGAMESCOPE" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Final Deck Check: Looks like we're in Game Mode (FIXGAMESCOPE is '$FIXGAMESCOPE')"
			writelog "INFO" "${FUNCNAME[0]} - Force-enabling DXVK_HDR=1 for Steam Deck Game Mode, allows HDR support for Steam Deck OLED and HDR displays attached to Steam Deck"

			# Override config value without updating the stored value itself, to preserve compatibility with Desktop Mode
			export DXVK_HDR=1
		else
			writelog "INFO" "${FUNCNAME[0]} - Final Deck Check: Looks like we're in Desktop Mode (FIXGAMESCOPE is '$FIXGAMESCOPE')"
		fi

		if [ "$USEGAMESCOPE" -eq 1 ] && [ "$FIXGAMESCOPE" -eq 1 ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Disabling own GameScope on SteamDeck Game Mode" "X"
			USEGAMESCOPE=0
		else
			writelog "INFO" "${FUNCNAME[0]} - Allowing GameScope enabled on SteamDeck in Desktop Mode" "X"
		fi

		if [ "$USEGAMEMODERUN" -eq 1 ] && [ "$FIXGAMESCOPE" -eq 1 ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Disabling own Feral GameMode tool (gamemoderun) on SteamDeck Game Mode" "X"
			USEGAMEMODERUN=0
		else
			writelog "INFO" "${FUNCNAME[0]} - Allowing Feral GameMode tool (gamemoderun) enabled on SteamDeck in Desktop Mode" "X"
		fi

		if [ -n "$STLCTLID" ] && [ "$STLCTLID" != "$PLACEHOLDERAID" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Loading controller configuration for the current game via 'steam steam://forceinputappid/$AID'"
			steam steam://forceinputappid/"$AID"
		fi
	fi
}

function steamdeckControl {
	if [ "$ONSTEAMDECK" -eq 1 ]; then
		setSDCfg
		export STLCTLID="$PLACEHOLDERAID"

		if [ ! -f "$STLSDLCFG" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Creating initial '$STLSDLCFG'"
			touch "$STLSDLCFG"
			echo "STLCTLID=\"$PLACEHOLDERAID\"" > "$STLSDLCFG"
		fi

		if [ -f "$STLSDLCFG" ]; then
			loadCfg "$STLSDLCFG" X
		fi

		if [ "$STLCTLID" != "$PLACEHOLDERAID" ]; then
			writelog "WARN" "${FUNCNAME[0]} - As documented you're on your own if mappings fail and you need to fix it manually via ssh"
			STLCNTRLD="$DEFSTEAMAPPSCOMMON/Steam Controller Configs/${STEAMUSERID}/config/${STLCTLID}"
			STLCNTRLF="$STLCNTRLD/controller_neptune.vdf"

			if [ -f "$STLCNTRLF" ] && ! grep -q "$NICEPROGNAME" "$STLCNTRLF"; then
				writelog "INFO" "${FUNCNAME[0]} - Good - found an original controller config under '$STLCNTRLF' - creating backup under ${STLCNTRLF}_ORG"
				mv "$STLCNTRLF" "${STLCNTRLF}_ORG"
			fi

			if  [ -f "$STLCNTRLF" ] && grep -q "$NICEPROGNAME" "$STLCNTRLF"; then
				if [ "$(grep -m1 "revision" "$SRCCTRLF" | grep -oE "[0-9]")" -gt "$(grep -m1 "revision" "$STLCNTRLF" | grep -oE "[0-9]")" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Updating '$STLCNTRLF'"
					cp "$SRCCTRLF" "$STLCNTRLF"
				else
					writelog "INFO" "${FUNCNAME[0]} - '$STLCNTRLF' is already up-to-date"
				fi
			fi

			if [ -f "${STLCNTRLF}_ORG" ] && [ ! -f "$STLCNTRLF" ]; then
				SRCCTRLF="${PREFIX}/misc/tinkergame-steamdeck-control.vdf"
				mkProjDir "$STLCNTRLD"
				writelog "INFO" "${FUNCNAME[0]} - Copying $NICEPROGNAME '$SRCCTRLF' to '$STLCNTRLF'"
				cp "$SRCCTRLF" "$STLCNTRLF"
				# might not be even required, but the data is ready anyway, so make it as complete as possible
				sed "s:XXXXXX:$STEAMUSERID:g" -i "$STLCNTRLF"
				sed "s:YYYYYY:$STLCTLID:g" -i "$STLCNTRLF"
			fi

			if grep -q "$NICEPROGNAME" "$STLCNTRLF"; then
				writelog "INFO" "${FUNCNAME[0]} - Loading controller configuration of SteamAppId '$STLCTLID' to allow joypad controls in $PROGNAME via 'steam steam://forceinputappid/$STLCTLID'"
				steam steam://forceinputappid/"$STLCTLID" > "$STLSHM/${FUNCNAME[0]}_stdout.txt" 2> "$STLSHM/${FUNCNAME[0]}_stderr.txt"
				writelog "INFO" "${FUNCNAME[0]} - controller settings for '$STLCTLID' loaded "
			else
				writelog "SKIP" "${FUNCNAME[0]} - Found controller config '', but it doesn't contain '$NICEPROGNAME' - not loading"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Skipping loading controller mapping for Steam Deck, because STLCTLID is not configured: '$STLCTLID'"
		fi
	fi
}

# NOTE: More may be added here in future to handle install failure
function steamDeckInstallFail {
	printf "\n%s\n" "$NOTY_STEAMDECK_INSTALLFAIL"
	notiShow "$NOTY_STEAMDECK_INSTALLFAIL" "X"
	exit 1;
}

# Generic function to download dependency from URL (mainly intended for fetching from package repos)
function fetchAndExtractDependency {
	function removeFileExtension {
		local FNAME="$1"
		local LASTFNAME=""
		while ! [ "$FNAME" = "$LASTFNAME" ]; do
			LASTFNAME="$FNAME"
			FNAME="${FNAME%.*}"
		done
		echo "$FNAME"
	}

	# Return dependency name stripped of version, architecture, file extension
	function getPrettyDependencyName {
		removeFileExtension "$( echo "$1" | sed -E 's:(\-[0-9]\.[0-9])+(.+)::g;s:^[^A-Za-z0-9]+::g' )"
	}

	# Takes dependency filename and strips:
	# - any non-letters-or-numbers from start of string
	# - the architecture string and everything after it
	# - any remaining letters or numbers
	# - any remaining non-numbers from the end of the string
	function getDependencyVersion {
		echo "$1" | sed -E 's:^[^A-Za-z0-9]::g;s:x86+(.*)::g;s:[a-zA-Z]::g;s:[^0-9]+$::g' | grep -oE "[0-9]\.[0-9]+(.+)"
	}

	# Variables used to build URL
	local ARCHIVEURL
	local EXTRACTPATH
	local ARCHIVENAME

	ARCHIVEURL="$1"
	EXTRACTPATH="$2"
	ARCHIVENAME="${3:-${1##*/}}"  # If no extract name passed, take filename from end of archive URL

	local CURLCMD
	local EXTRACTCMD
	local EXTRACTCMDFLAGS

	CURLCMD="curl"
	EXTRACTCMD="tar"
	EXTRACTCMDFLAGS="xf"

	local LOCALVERS
	local STLVERS

	# Download dependency
	mkdir -p "$EXTRACTPATH"
	if ! [ -f "$EXTRACTPATH/$ARCHIVENAME" ]; then
		if ! [ "$INTERNETCONNECTION" -eq 0 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Installing '$ARCHIVENAME' from '$ARCHIVEURL' to installation directory '$EXTRACTPATH'"
			echo "Downloading dependency '$ARCHIVENAME'..."
			if "$CURLCMD" -Lq "$ARCHIVEURL" -o "$EXTRACTPATH/$ARCHIVENAME"; then  # Not showing notifier to reduce notifier spam
				writelog "INFO" "${FUNCNAME[0]} - Successfully downloaded dependency '$ARCHIVENAME'"
				echo "Successfully downloaded $ARCHIVENAME!"
			else  # Download failure
				writelog "WARN" "${FUNCNAME[0]} - Failed to download dependency '$ARCHIVENAME', will attempt to continue with installation in case dependency archives already exist at '$EXTRACTPATH'"
				notiShow "$(strFix "$NOTY_STEAMDECK_DEPINSTALLFAIL" "$ARCHIVENAME")" "X"
				strFix "$NOTY_STEAMDECK_DEPINSTALLFAIL" "$ARCHIVENAME"
			fi
		else  # No internet connection
			writelog "WARN" "${FUNCNAME[0]} - No internet connection, can't download dependency '$ARCHIVENAME' - Will check for locally installed dependencies later on (should be located at '$EXTRACTPATH/$ARCHIVENAME')"
			echo "WARNING: No Internet Connection, cannot download dependency '$ARCHIVENAME'. For offline installation, manually place the file in '$EXTRACTPATH'."
			notiShow "$(strFix "$NOTY_STEAMDECK_NOINTERNETDEPSWARN" "$ARCHIVENAME" "$EXTRACTPATH")"
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - Dependency '$ARCHIVENAME' already exists at installation directory '$EXTRACTPATH', skipping redownload..."
		echo "Dependency '$ARCHIVENAME' already exists at installation directory '$EXTRACTPATH', nothing to download"
	fi

	# Extracting dependencies - If we can't find an exact match for the downloaded file, try to find a fuzzy match based on 'real' package name
	if ! [ -f "$EXTRACTPATH/$ARCHIVENAME" ]; then
		# Get list of files and remove version string from it, then check if this name is inside our target archive file
		# This basically tries to find any archives that have the 'actual' package name e.g. 'innoextract' from 'innoextract-1.1-1.pkg.tar.zst', then tries to search if any files in the directory match
		# the archive we passed in to try to download but couldn't and try to extract them. This lets us extract dependencies for a potential archive match if the name is not exact
		local DEPMATCHFOUND=0
		mapfile -t DEPFILES < <( find "$EXTRACTPATH" -maxdepth 1 -type f -iname \*"*.*"\* -exec basename {} \; )
		if ! [[ "${#DEPFILES[@]}" -eq 0 ]]; then
			writelog "INFO" "${FUNCNAME[0]} - Found archive in '$EXTRACTPATH' that is potential match for '$ARCHIVENAME'"
			for file in "${DEPFILES[@]}"; do
				# Removes version number, anything before the first space, and removes anything that isn't a sequence of letters or numbers from the beginning of the filename
				# Attempts to be as generous as possible in matching *any* match for the dependency name
				PRETTYFILENAME="$( getPrettyDependencyName "$file" )"
				PRETTYARCHIVENAME="$( getPrettyDependencyName "$ARCHIVENAME" )"

				if [[ ( "$ARCHIVENAME" =~ $PRETTYFILENAME || "$PRETTYFILENAME" =~ $PRETTYARCHIVENAME ) ]]; then
					writelog "INFO" "${FUNCNAME[0]} - Found potential existing dependency '$file', assuming dependency '$ARCHIVENAME' is already satisfied."
					echo "Found potential matching dependency archive for '$ARCHIVENAME' at '$file'"

					LOCALVERS="$( getDependencyVersion "$file" )"
					STLVERS="$( getDependencyVersion "$ARCHIVENAME" )"
					# Check local archive version vs. what STL asked for
					if [ -z "$LOCALVERS" ]; then
						# Could not get version string from archive
						writelog "WARN" "${FUNCNAME[0]} - Could not get version from archive - This dependency version may not work if is newer than '$STLVERS'"
						echo "Could not get version from archive - This dependency version may not work if is newer than '$STLVERS'!"
					else
						if [ "$LOCALVERS" = "$STLVERS" ]; then  # Version match
							writelog "INFO" "${FUNCNAME[0]} - Archive version appears to be the same version that TinkerGame asked for - Should be ok to install this version"
							echo "Dependency version looks ok"
						else  # Version newer/older (might still work, but warn the user anyway)
							writelog "WARN" "${FUNCNAME[0]} - Archive version '${LOCALVERS}' does not match the version that TinkerGame asked for ('$STLVERS') - This may cause problems with the installation!"
							echo "Dependency version does not match what TinkerGame was looking for - This may cause problems with your installation!"
						fi
					fi

					ARCHIVENAME="$file"
					DEPMATCHFOUND=1
					break
				fi
			done
		fi

		# Abort if we couldn't match a dependency
		if [[ "$DEPMATCHFOUND" -eq 0 ]]; then
			writelog "INFO" "${FUNCNAME[0]} - Could not find any matching dependency archives in '$EXTRACTPATH' for '$ARCHIVENAME' - Assuming this dependency is missing and installation cannot continue"
			echo "Could not find any archive in '$EXTRACTPATH' for '$ARCHIVENAME', aborting install..."
			return 1;
		fi
	fi

	# Extract archive now that we know we should have *something* to extract
	writelog "INFO" "${FUNCNAME[0]} - Extracting dependency '$ARCHIVENAME' at '$EXTRACTPATH/$ARCHIVENAME'"
	echo "Extracting dependency '$ARCHIVENAME'..."
	if "$EXTRACTCMD" "$EXTRACTCMDFLAGS" "$EXTRACTPATH/$ARCHIVENAME" -C "$EXTRACTPATH"; then
		# Succes extraction
		writelog "INFO" "${FUNCNAME[0]} - Successfully extracted dependency to '$EXTRACTPATH/$ARCHIVENAME'"
		echo "Successfully extracted '$ARCHIVENAME' to '$EXTRACTPATH'"
	else
		# Failed extraction
		writelog "ERROR" "${FUNCNAME[0]} - Failed to extract dependency '$ARCHIVENAME' to '$EXTRACTPATH' - Consider checking file/folder permissions"
		notiShow "$(strFix "$NOTY_STEAMDECK_EXTRACTFAIL" "$ARCHIVENAME" "$EXTRACTPATH")" "X"
		strFix "$NOTY_STEAMDECK_EXTRACTFAIL" "$ARCHIVENAME" "$EXTRACTPATH"
		return 1;
	fi
}

function checkSteamDeckDependencies {

	function installDependencyVersionFromURL {
		local DEPCMD="$1"
		local DEPFILENAME="$2"
		local DEPDIR="$3"
		local REPOURL="$4"
		local CHECKCMD
		CHECKCMD="$($DEPCMD &> /dev/null --version && echo "OK" || echo "NOK")"


		# The check now says, don't update dependencies if all of these conditions are true:
		#  1. The dependency file exists
		#  2. The dependency can actually be ran, confirming it is a valid file
		#  3. TinkerGame has not updated or autoupdater isn't enabled, so there would be no change in dependency version and thus no need to update
		# If any of these are false, we need to check our dependencies (if a file is missing we would need to update, or if it cannot be used we need to update, and also if STL updated we may need a newer version, so update).
		if [[ -f "$(command -v "$DEPCMD")" && "$CHECKCMD" = "OK" ]] \
		&& ! ( [ "$STEAMDECK_AUTOUP" -eq 1 ] && checkSteamDeckSTLUpdated ); then
			writelog "INFO" "${FUNCNAME[0]} - Using '$DEPCMD' binary found in path: '$(command -v "$DEPCMD")'"
			echo "Dependency '$DEPCMD' already installed, nothing to do."
		else
			writelog "INFO" "${FUNCNAME[0]} - Downloading $DEPCMD version automatically from URL '$REPOURL'"
			writelog "INFO" "${FUNCNAME[0]} - curl -Lq \"$REPOURL\" -o \"$DEPDIR/$DEPFILENAME\""

			notiShow "$(strFix "$NOTY_STEAMDECK_DEPSDOWNLOAD" "$DEPCMD")" "X"
			strFix "$NOTY_STEAMDECK_DEPSDOWNLOAD" "$DEPCMD"

			fetchAndExtractDependency "$REPOURL" "$DEPDIR" "$DEPFILENAME" || steamDeckInstallFail

			STEAMDECKWASUPDATE=1
		fi
	}

	# if this really changes, it could be grepped directly from /etc/pacman.d/mirrorlist as well: (was previously used for wget, keeping commented in case we need it in future)
	#SDREPO="https://steamdeck-packages.steamos.cloud/archlinux-mirror/extra/os/x86_64/"
	# ARCHURL="https://archlinux.org/packages/community/x86_64"
	ARCHARCHIVEURL="https://archive.archlinux.org/packages"

	INNOEXTRACTVERS="1.9-11"
	INNOEXTRACTFILE="$INNOEXTRACT-$INNOEXTRACTVERS-x86_64.pkg.tar.zst"
	INNOEXTRACTURL="$ARCHARCHIVEURL/i/$INNOEXTRACT/$INNOEXTRACTFILE"

	CABEXTRACTVERS="1.9.1-2"
	CABEXTRACTFILE="$CABEXTRACT-$CABEXTRACTVERS-x86_64.pkg.tar.zst"
	CABEXTRACTURL="$ARCHARCHIVEURL/c/$CABEXTRACT/$CABEXTRACTFILE"

	printf '\n'

	installDependencyVersionFromURL "$INNOEXTRACT" "$INNOEXTRACTFILE" "$STLDEPS" "$INNOEXTRACTURL" || steamDeckInstallFail
	installDependencyVersionFromURL "$CABEXTRACT" "$CABEXTRACTFILE" "$STLDEPS" "$CABEXTRACTURL" || steamDeckInstallFail

	updateSteamDeckLastVers # If everything went well, we update the lastversion file

	if [ -f "$(command -v "yad")" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using yad binary found in path: '$(command -v "yad")'"
		echo "Dependency 'yad' already installed, nothing to do."
		# Force update of global config file to add Yad path if it exists in $HOME/tg/deps/yad/bin
		touch "$FUPDATE"
		updateConfigEntry "YAD" "$( command -v "yad" )" "$STLDEFGLOBALCFG"
	else
		printf '\n'
		writelog "INFO" "${FUNCNAME[0]} - Using yad app image"
		setYadBin "ai" "sd" || steamDeckInstallFail
	fi
}

function installFilesSteamDeck {
	local INSTALLEDPROGVERS
	local SCRIPTDIR

	if [[ "$INTERNETCONNECTION" -eq 1 ]]; then
		# Notification for either updating or downloading STL on Deck
		if [ -d "$SYSTEMSTLCFGDIR/.git" ]; then
			notiShow "$NOTY_STEAMDECK_UPDATE" "X"
			echo "$NOTY_STEAMDECK_UPDATE"
			STEAMDECKWASUPDATE=1
		else
			notiShow "$NOTY_STEAMDECK_DOWNLOAD" "X"
			echo "$NOTY_STEAMDECK_DOWNLOAD"
		fi

		# Attempt to get update files from Git
		if ! gitUpdate "$PREFIX" "$PROJECTPAGE"; then
			writelog "WARN" "${FUNCNAME[0]} - Could not clone/pull changes from git repo, doing some checks"
			if ! ping -q -c1 archlinux.org &>/dev/null; then
				writelog "WARN" "${FUNCNAME[0]} - Could not ping Arch Linux website, maybe there is a connectivity problem - Install / Update may fail"
			else
				writelog "WARN" "${FUNCNAME[0]} - Looks like GitHub is ok, attempting to update via a fresh clone to '${PREFIX}-temp'"
			fi

			if ! gitUpdate "${PREFIX}-temp" "$PROJECTPAGE"; then
				writelog "WARN" "${FUNCNAME[0]} - Still failed to download from GitHub, though it should be up -Not trying to update again, maybe something is wrong with install files"
				echo "Could not pull down changes from Git, even though GitHub should be up. Not attempting another update right now, maybe try again later or try a fresh install if the issue persists."
			else
				# TODO clean this up

				# Currently we assume the removal of the existing files and moving of the new files will succeed ok
				# There could be a very rare instance where due to permission faults or somethimg, this fails
				# We aren't worried about this for now, but a PR might be welcome on this in future :-)
				writelog "INFO" "${FUNCNAME[0]} - Fresh clone succeeded ok, overwriting existing installation with fresh clone"

				# This was disabled because I thought it caused issues on Steam Deck
				# It needs testing before it can be safely enabled, if we even want to re-enable this functionality

				# rm -rf "$PREFIX"
				# mv "${PREFIX}-temp" "$PREFIX"
				# rm -rf "${PREFIX}-temp"

				writelog "INFO" "${FUNCNAME[0]} - Successfully pulled updated changes!"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Fetching from git seems to have succeeded ok."
		fi
	else
		# Get version of existing STL install, if present, and compare with our version
		writelog "WARN" "${FUNCNAME[0]} - No Internet Connection detected, cannot clone Git repo - Attempting to manually install"

		SCRIPTDIR="$( realpath "$0" )"
		SCRIPTDIR="${SCRIPTDIR%/*}"

		# Offline installation of STL was previously installed/attempted - With check to try and ensure scriptdir is a valid STL install and not a standalone script
		if ! [ -d "$SCRIPTDIR/lang" ] && ! [ -d "$SCRIPTDIR/misc" ] && ! [ -d "$SCRIPTDIR/guicfgs" ]; then
			writelog "WARN" "${FUNCNAME[0]} - Script dir '$SCRIPTDIR' does not look like a valid TinkerGame installation directory! Not copying files in case this script is not in a proper STL folder"
			echo "WARNING: Not updating offline filees - It looks like you're trying to install TinkerGame as a standalone script outside of its downloaded files."
		elif [ -f "$PREFIX/tinkergame" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found existing TinkerGame files at '$PREFIX', checking if we need to update"
			INSTALLEDPROGVERS="$( grep -i "^PROGVERS=.*." "$PREFIX/tinkergame" | cut -d '"' -f 2 )"
			writelog "INFO" "${FUNCNAME[0]} - Currently installed STL version: $INSTALLEDPROGVERS"
			writelog "INFO" "${FUNCNAME[0]} - This script's STL version: $PROGVERS"
			# Check if we actually need to update (running script ver > currently installed script ver)
			# Not a fool-proof test, sometimes PROGVERS isn't bumped, but a user can always manually copy the files if they want to - We'll assume they downloaded the latest version ahead of time and want to manually install that
			if [[ "$PROGVERS" > "$INSTALLEDPROGVERS" ]]; then
				writelog "INFO" "${FUNCNAME[0]} - Existing TinkerGame installation is older than current version - Installation will continue by copying downloaded files at '$SCRIPTDIR' to '$PREFIX'"
				echo "Updating TinkerGame to '$PROGVERS' by copying installation files to '$PREFIX' for offline installation..."
				cp -R "$SCRIPTDIR"/* "$PREFIX"
				STEAMDECKWASUPDATE=1
			else
				writelog "INFO" "${FUNCNAME[0]} - Existing TinkerGame installation is newer than or same as current version - No code to update"
				echo "Existing TinkerGame install is up-to-date, verifying dependencies..."
				STEAMDECKDIDINSTALL=0
			fi
		else
			# No existing STL installation - Let's create one using the files downloaded with the script currently running!
			writelog "INFO" "${FUNCNAME[0]} - No existing STL installation found - Installation will continue by copying downloaded files at '$SCRIPTDIR' to '$PREFIX'"
			echo "No existing STL installation found, so copying installation files to '$PREFIX' for offline installation..."
			cp -R "$SCRIPTDIR"/* "$PREFIX"
		fi
	fi
}

function steamdedeckt {
	if [ -f "/etc/os-release" ] && grep -q "steamdeck" "/etc/os-release"; then
		ONSTEAMDECK=1

		export STEAMDECKWASUPDATE=0
		export STEAMDECKDIDINSTALL=1
		export STEAMDECKSTEAMRUN=0  # Stores if we're running STL when Steam opens on Steam Deck

		writelog "INFO" "${FUNCNAME[0]} - Seems like we have a Steam Deck here - making some specific settings"

		STLBASE="/home/deck/$SHOSTL"
		export PREFIX="$STLBASE/prefix"
		SYSTEMSTLCFGDIR="$PREFIX"
		STLDEPS="$STLBASE/deps"

		mkProjDir "$PREFIX"
		mkProjDir "$STLDEPS"

		if [ -z "$SUSDA" ]; then
			setSteamPaths
		fi

		# Show icon and title for notifier
		if ! [ -f "$STLICON" ]; then
			SCRIPTDIR="$( realpath "$0" )"
			SCRIPTDIR="${SCRIPTDIR%/*}"
			STLICON="$SCRIPTDIR/misc/tinkergame.svg"
		fi
		export NOTYARGS="-i $STLICON -a $PROGNAME"

		# Differentiate between Game Mode and Desktop Mode on Steam Deck
		if grep -q "generate-drm-mode" <<< "$(pgrep -a "$GAMESCOPE")"; then
			writelog "INFO" "${FUNCNAME[0]} - Detected '$GAMESCOPE' running 'forced' - assuming we're running in Game Mode"
			FIXGAMESCOPE=1
		else
			writelog "INFO" "${FUNCNAME[0]} - Did not detect a running '$GAMESCOPE' process - assuming we're running in Desktop Mode"

			SMALLDESK=1
		fi

		writelog "INFO" "${FUNCNAME[0]} - Set 'FIXGAMESCOPE' to '$FIXGAMESCOPE'"
		writelog "INFO" "${FUNCNAME[0]} - Set 'SMALLDESK' to '$SMALLDESK'"

		INTERNETCONNECTION=1

		# Check if we're running STL on a Steam first launch
		# Assume Steam if all of these are true:
		# - We already have an STL installation (assume install if script in prefix)
		# - The AppID is a placeholder ID (not running a game)
		# - The script is running from CompatibilityTools.d
		if [ -f "$PREFIX/tinkergame" ] && [ "$AID" = "$PLACEHOLDERAID" ] && [[ ${0^^} == *"${CTD^^}"* ]]; then
			writelog "INFO" "${FUNCNAME[0]} - Looks like we're running through Steam on a Steam Deck, we don't want to do any updating here!"
			STEAMDECKSTEAMRUN=1
		elif [[ ${0^^} == *"${PREFIX^^}"* ]] && ! [ "$AID" = "$PLACEHOLDERAID" ]; then
			# Launching a game proper through Steam would mean the dir we're launching from (${0}) would be the compattool dir
			#
			# The check for the AID != PlaceholderAID means we can update if we're just running the script from the prefix (i.e., we double clicked it)
			# But if we have an actual game AppID and we're running from the prefix, we're probably being called from an extra dialog on the main menu, which means we don't want to update (and this stops notifier spam too)
			writelog "INFO" "${FUNCNAME[0]} - Looks like we have a game but we're running from the Steam Deck install Prefix, not doing any updating here!"
			STEAMDECKSTEAMRUN=1
		else
			notiShow "$NOTY_STEAMDECK_INSTALL" "X"
			echo "$NOTY_STEAMDECK_INSTALL on Steam Deck"

			if ! (ping -q -c1 archlinux.org &>/dev/null || ping -q -c1 google.com &>/dev/null); then
				INTERNETCONNECTION=0
				writelog "WARN" "${FUNCNAME[0]} - No Internet Connection detected, attempting to install TinkerGame offline - This may not succeed!"
				writelog "WARN" "${FUNCNAME[0]} - Make sure you have either manually installed all dependencies, or added all manual dependency archives to '$STLDEPS'"
				notiShow "$NOTY_STEAMDECK_NOINTERNET" "X"
				echo "$NOTY_STEAMDECK_NOINTERNET"
			fi
		fi

		export STLSDPATH="${STLDEPS}/usr/bin"
		export PATH="$PATH:$STLSDPATH"

		if [ "$STEAMDECKSTEAMRUN" -eq 0 ]; then
			installFilesSteamDeck
			checkSteamDeckLastVers
			checkSteamDeckDependencies

			# Don't remove dependencies offline
			if [ "$INTERNETCONNECTION" -eq 1 ]; then
				find "$STLDEPS" -type f \( -name "*.zst" -o -name "*.gz" -o -name ".*" \) -exec rm {} \;
			fi

			# update/set compatibility tool to git stl:
			if [ "$INFLATPAK" -eq 0 ]; then
				notiShow "$NOTY_STEAMDECK_ADDCOMPAT" "X"
				CompatTool "add" "$PREFIX/$PROGCMD" >/dev/null
			fi

			GTKCSSFILE="$HOME/.config/gtk-3.0/gtk.css"

			if [ ! -f "$GTKCSSFILE" ] ; then
				writelog "SKIP" "${FUNCNAME[0]} - '$GTKCSSFILE' does not exist - skipping"
			else
				if grep -q "scrollbar" "$GTKCSSFILE"; then
					writelog "SKIP" "${FUNCNAME[0]} - found a scrollbar entry in '$GTKCSSFILE'"
				else
					writelog "INFO" "${FUNCNAME[0]} - backup '$GTKCSSFILE' to '${GTKCSSFILE}_ORIGNAL'"
					cp "$GTKCSSFILE" "${GTKCSSFILE}_ORIGNAL"

					# NOTE: This styles most, but not all, UI elements on Steam Deck
					# It makes the scrollbar wider and easier to grab, and it adds a right margin so UI elements aren't covered by the scollbar
					# However currently the UI is not as uniform on Steam Deck, because file choosers and text fields don't have this margin
					# PRs are welcome to apply styling to these elements :-)
					writelog "INFO" "${FUNCNAME[0]} - adding bigger scrollbar and customising some other UI elements using '$GTKCSSFILE'"
					{
						echo ".scrollbar.vertical slider,"
						echo "scrollbar.vertical slider {"
						echo "min-width: 15px;"
						echo "}"
						echo "spinbutton, combobox button {"
						echo "margin-right: 20px;"
						echo "}"
					} >> "$GTKCSSFILE"
				fi
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Seems like we're being run by Steam here, not doing any installation steps"
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - Not on Steam Deck I guess"
	fi
}

function restoreGtkCss {
	if [ "$ONSTEAMDECK" -eq 1 ]; then
		GTKCSSFILE="$HOME/.config/gtk-3.0/gtk.css"
		if [ -f "${GTKCSSFILE}_ORIGNAL" ] ; then
			writelog "INFO" "${FUNCNAME[0]} - recovering original gtk.css from '${GTKCSSFILE}_ORIGNAL'"
			mv "${GTKCSSFILE}_ORIGNAL" "$GTKCSSFILE"
		fi
	fi
}

function checkSteamDeckLastVers {
	# This function just makes sure that the 'lastvers' file exists at the defined path
	# If it does not we set it and clear the deps to ensure it starts downloading the libs at the right version
	if ! [ -f "$STLSTEAMDECKLASTVERS" ]; then
		clearDeckDeps
		echo "$PROGVERS" > "$STLSTEAMDECKLASTVERS"
	fi
}

function updateSteamDeckLastVers {
	# This function updates the 'lastvers' file after a dependency update if there was a version change
	if checkSteamDeckSTLUpdated; then
		echo "$PROGVERS" > "$STLSTEAMDECKLASTVERS"
	fi
}

function prepareSteamDeckCompatInfo {
	if [ "$AID" -eq "$PLACEHOLDERAID" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - AppID '$AID' is placeholder AppID ('$PLACEHOLDERAID') -- Not fetching Steam Deck compatibility info"
		return
	fi

	if [ ! -x "$(command -v "$JQ")" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Can't get Steam Deck compatibility information because '$JQ' is not installed"
		return 1
	fi

	if [ "$DLSTEAMDECKCOMPATINFO" -eq 1 ]; then
		mapfile -d ";" -t -O "${#DECKCOMPATARR[@]}" DECKCOMPATARR <<< "$( getSteamDeckCompatInfo "$AID" )"
		unset "DECKCOMPATARR[-1]"

		if [ "${#DECKCOMPATARR[@]}" -eq "0" ]; then
			writelog "INFO" "${FUNCNAME[0]} - No compatibility information available for '$AID' - Is this AppID definitely correct?"
		else
			# HTML symbols for Verified (checkmark), Playable (circled question mark) and Unsupported (no-entry sign)
			COMPATMARK=""
			case ${DECKCOMPATARR[0]} in
				*"Verified"*) COMPATMARK="&#10003;" ;;
				*"Playable"*) COMPATMARK="&#128712;" ;;
				*"Unsupported"*) COMPATMARK="&#128683;" ;;
			esac
			STEAMDECKCOMPATRATING="${DECKCOMPATARR[0]} ${COMPATMARK}"
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - DLSTEAMDECKCOMPATINFO is '$DLSTEAMDECKCOMPATINFO' - Not fetching Steam Deck compatability info"
	fi
}

# Fetches compatibility information about a game directly from the Steam store endpoint
# TODO maybe store `display_type` to differentiate what each string refers to, e.g.:
#    - 4 means Verified
#    - 3 means Playable
#    - ???
#    - 1 is the grey subtext for small notes about controllers and internet access
function getSteamDeckCompatInfo {
	if [ ! -x "$(command -v "$JQ")" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Can't get Steam Deck compatibility information because '$JQ' is not installed"
		return 1
	fi

	if [ -z "$1" ]; then
		echo "No AppID given, you need to pass the AppID of the game you want to check the compatibility of"
		writelog "ERROR" "${FUNCNAME[0]} - Need a valid AppID to check the Steam Deck compatibility information"
		return 1
	fi

    AID="$1"
	mkProjDir "$STLGDECKCOMPAT"

	# Unofficial documentation for this endpoint is available here: https://github.com/Revadike/InternalSteamWebAPI/wiki/Get-Deck-Compatibility-Report
    DECKCOMPATENDPOINT="https://store.steampowered.com/saleaction/ajaxgetdeckappcompatibilityreport?nAppID="
    COMPATFILE="$STLGDECKCOMPAT/${AID}-deckcompatrating.json"

	# Check if we can access Steam before fetching the Deck compatibility info
    COMPATINFO=""
	if ! ping -q -c1 store.steampowered.com &>/dev/null; then
		writelog "INFO" "${FUNCNAME[0]} - Looks like we can't access Steam, not removing any Steam Deck compatibility files"

		# No existing file and offline, so skip
		if ! [ -f "$COMPATFILE" ]; then
			writelog "WARN" "${FUNCNAME[0]} - Looks like we can't contact Steam and there is no known Steam Deck compatibility information file at '$COMPATFILE' - Skipping this step since we won't be able to retrieve any useful data"
			return 1
		else
			writelog "INFO" "${FUNCNAME[0]} - Existing file found at '$COMPATFILE', Steam Deck compatibility information will be taken from this since we can't contact Steam - The information here could be outdated depending on when it was fetched!"
		fi
	else
		# Remove existing file
		if [ -f "$COMPATFILE" ]; then
			if ! "$JQ" -e '.success' "$COMPATFILE" 1>/dev/null; then
				writelog "INFO" "${FUNCNAME[0]} - File '$COMPATFILE' containing Steam Deck compatibility information already exists, however it looks like it failed last time - Removing it so we can attempt to redownload it"
				rm "$COMPATFILE"
			elif [ "$(( $(date +"%s") - $(stat -c "%Y" "$COMPATFILE") ))" -gt "86400" ]; then  # Todo maybe let the user define this in the Global Menu (default right now is >  1 day old)
				writelog "INFO" "${FUNCNAME[0]} - File '$COMPATFILE' is older than 1 day - Removing it so we can update in case the compatibility rating has changed"
				rm "$COMPATFILE"
			fi
		fi

		# If the file doesn't exist at all and we can connect to Steam, create it from the response
		if ! [ -f "$COMPATFILE" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Fetching Steam Deck compatibility information for '$AID' from Steam store endpoint with '${DECKCOMPATENDPOINT}${AID}'"
			if ! "$WGET" -q "${DECKCOMPATENDPOINT}${AID}" -O "$COMPATFILE" 2> >(grep -v "SSL_INIT"); then
				# Failed to fetch for some reason, skip getting Deck compat info
				writelog "INFO" "${FUNCNAME[0]} - Failed to fetch Steam Deck compatibility information from Steam store endpoint with '${DECKCOMPATENDPOINT}${AID}'"
				return 1
			fi
		else
			# File exists, don't redownload
			writelog "INFO" "${FUNCNAME[0]} - Steam Deck compatibility rating file '$COMPATFILE' already exists - not redownloading"
		fi
	fi

	# We were able to hit the endpoint successfully, but check if the response success is valid!
	RESULTSLENGTH="$( "$JQ" -e '.results | length' "$COMPATFILE" )"
    if (( RESULTSLENGTH > 0 )); then
        writelog "INFO" "${FUNCNAME[0]} - Successfully retrieved Steam Deck compatility information - Stored to '$COMPATFILE'"

        # Get Verified/Playable/Unsupported/Unknown
        DECKCOMPATRATING="$( "$JQ" -e '.results.resolved_category' "$COMPATFILE" )"
        case $DECKCOMPATRATING in
            1) COMPATTEXT="$STEAMDECKCOMPAT_UNSUPPORTED" ;;
            2) COMPATTEXT="$STEAMDECKCOMPAT_PLAYABLE" ;;
            3) COMPATTEXT="$STEAMDECKCOMPAT_VERIFIED" ;;
            *) COMPATTEXT="$STEAMDECKCOMPAT_UNKNOWN" ;;
        esac
        COMPATINFO+="${COMPATTEXT};"

		writelog "INFO" "${FUNCNAME[0]} - Successfully retrieved Steam Deck compatibility rating of '$COMPATTEXT' for '$AID'"
		writelog "INFO" "${FUNCNAME[0]} - Converting language tokens for Steam Deck compatibility criteria into TinkerGame translated strings"

		# Turn language tokens like '#SteamDeckVerified_TestResult_blah' into an actual translated string from the translation files -- Language strings credited to: https://github.com/SteamDatabase/SteamTracking
        for LANGTOKEN in $( "$JQ" -r '.results.resolved_items[].loc_token' "$COMPATFILE" ); do
            LANGTOKEN="$( echo "$LANGTOKEN" | xargs )"
            if [ -n "$LANGTOKEN" ]; then
				OGLANGTOKEN="$LANGTOKEN"
				# Convert token to uppercase and remove hash at beginning
                LANGTOKEN="${LANGTOKEN^^}"
                LANGTOKEN="${LANGTOKEN//#/}"

				# Get associated translation variable from translation files to match this translated string
				STLLANGTOKEN="${!LANGTOKEN}"
				if [ -n "$STLLANGTOKEN" ]; then
					COMPATINFO+="\"$STLLANGTOKEN\";"
				else
					writelog "WARN" "${FUNCNAME[0]} - Could not find translation string for returned language token '$OGLANGTOKEN' - Seems like we need to update the translation files to include a new string!"
				fi
            else
                writelog "INFO" "${FUNCNAME[0]} - Skipping blank LANGTOKEN '$LANGTOKEN' - though this should probably not happen!"
            fi
        done

		DEVELOPERCOMMENTSURL="$( "$JQ" -e '.results.steam_deck_blog_url' "$COMPATFILE" )"
		if [ "${#DEVELOPERCOMMENTSURL}" -gt 2 ]; then  # DEVELOPERCOMMENTSURL will always have quotes around it (e.g. `""` for blank), so the minimum length will always be 2 since it will be 2 for a blank entry because of the set of quotes
			writelog "INFO" "${FUNCNAME[0]} - Seems like the developer has a blog post with some comments on this game's compatibility, appending it... (length is ${#DEVELOPERCOMMENTSURL}"
			COMPATINFO+="$( strFix "$STEAMDECKVERIFIED_CUSTOMRESULT_DEVPOST" "$DEVELOPERCOMMENTSURL" );"
		else
			writelog "INFO" "${FUNCNAME[0]} - Seems like no developer comments were left for this game - This is fine as most games don't have this, so skipping"
		fi
		writelog "INFO" "${FUNCNAME[0]} - Finished setting Steam Deck compatibility criteria strings"
    else
		# We were able to get a response from the endpoint, but the results body was blank so we can't get any response information - Not sure when this would happen outside of Non-Steam Games
		writelog "WARN" "${FUNCNAME[0]} - No compatibility information available for '$AID' - Maybe the AppID is invalid?"
		rm "$COMPATFILE"
		return 1
    fi

	echo "$COMPATINFO"
}

# This function will check if the version in `$STLSTEAMDECKLASTVERS` does not match the current version
# For example, if we had v14.0 installed before, 'lastvers' would have v14.0
# Then, if we were updating to v15.0, 'lastvers' would be 'v14.0' but 'PROGVERS' would be 'v15.0'
function checkSteamDeckSTLUpdated {
	# This is how updateCfgFile gets the config file version, so re-use it
	CHECKLASTVERSSTEAMDECK="$( cat "$STLSTEAMDECKLASTVERS" )"
	if [ "$CHECKLASTVERSSTEAMDECK" = "$PROGVERS" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Last known TinkerGame install version ('$CHECKLASTVERSSTEAMDECK') and the current version ('$PROGVERS') match -- There has been no update since last launch"
		return 1
	else
		writelog "INFO" "${FUNCNAME[0]} - Last known TinkerGame install version ('$CHECKLASTVERSSTEAMDECK') and the current version ('$PROGVERS') do NOT match -- It seems there has been an update!"
		return 0
	fi
}

# Clear dependencies in /home/deck/tg/deps so that they can be redownloaded the next time TinkerGame is ran on Steam Deck
# This also serves as a quickfix for upstream issue #719, as dependencies can be quickly removed and then re-downloaded to ensure better compatibility with SteamOS updates
# In future, STL should auto-bump these somehow
function clearDeckDeps {
	if [ "$ONSTEAMDECK" -eq 1 ]; then
		# This should be set by steamdedeckt, the regex check at the end is just for extra peace of mind that we don't rm -rf an incorrect directory!
		if [ -n "$STLDEPS" ] && [ -d "$STLDEPS" ]  && [[ $STLDEPS == *"deps"* ]]; then
			writelog "INFO" "${FUNCNAME[0]} - Removing '$STLDEPS' directory"
			rm -rf "$STLDEPS"
			writelog "INFO" "${FUNCNAME[0]} - Successfully removed '$STLDEPS'"
			echo "Removed Steam Deck dependencies, they will be re-downloaded on next launch."
		else
			writelog "SKIP" "${FUNCNAME[0]} - Could not find STL Steam Deck dependencies directory, STLDEPS is '$STLDEPS' - Nothing to do."
			echo "Could not find STL Steam Deck dependencies directory, skipping"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Not on Steam Deck, nothing to do"
		echo "Not on Steam Deck, nothing to do."
	fi
}

### STEAM DECK END

