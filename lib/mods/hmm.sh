#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

### HEDGEMODMANAGER (HMM) BEGIN

# NOTE: This was written with HMM in mind, but it may work generally too
# Returns the download URL to the latest GitHub actions build of a repository and the commit SHA it was built from separated by a comma
#
# EX: DefinitelyNotValve/HalfLife2EpisodeThree/suites/12345678/artifacts/87654321;0df23c5
function fetchLatestGitHubActionsBuild {
    PROJAPIURL="$1"
    ARTIFACTNUM=$2
	WORKFLOWNAME="$3"
	ALLOWFAILEDWORKFLOWS="${4:-1}"  # default to allow failed builds

    # /actions/runs
	ARTIFACTRUNSRESPJQ=".workflow_runs"
	## optionally filter by workflow name if we give one
	if [ -n "$WORKFLOWNAME" ]; then
		ARTIFACTRUNSRESPJQ="[ ${ARTIFACTRUNSRESPJQ}[] | select(.name==\"${WORKFLOWNAME}\")]"
    fi
	## optionally filter to only success builds
	if [ "$ALLOWFAILEDWORKFLOWS" -eq 0 ]; then
		ARTIFACTRUNSRESPJQ="[ ${ARTIFACTRUNSRESPJQ}[] | select (.conclusion==\"success\") ]"  # conclusion can be success/failure
	fi
	ARTIFACTRUNSRESPJQ="${ARTIFACTRUNSRESPJQ} | first"
	ARTIFACTRUNSRESP="$( curl -s "${PROJAPIURL}/actions/runs" | "$JQ" "${ARTIFACTRUNSRESPJQ}" )"
	ARTIFACTRUNSUITEID="$( echo "$ARTIFACTRUNSRESP" | "$JQ" '.check_suite_id' )"
    LATESTARTIFACTURL="$( echo "$ARTIFACTRUNSRESP" | "$JQ" '.artifacts_url' | cut -d '"' -f 2 )"

    # /actions/runs/<artifact_id>/artifacts
	LATESTARTIFACTRESP="$( curl -s "${LATESTARTIFACTURL}" | "$JQ" ".artifacts[${ARTIFACTNUM}]" )"
	LATESTARTIFACTID="$( echo "$LATESTARTIFACTRESP" | "$JQ" ".id" )"
    LATESTARTIFACTSHA="$( echo "$LATESTARTIFACTRESP" | "$JQ" ".workflow_run.head_sha" | cut -d '"' -f 2 )"

    ARTIFACTDLURL="suites/${ARTIFACTRUNSUITEID}/artifacts/${LATESTARTIFACTID}"
    echo "${ARTIFACTDLURL};${LATESTARTIFACTSHA::7}"
}

# HMM doesn't really have a "setup" exe, but MO2 and Vortex use this naming convention so... keeping it :-)
function getLatestHMMVer {
	HMMSET="HedgeModManager"

	writelog "INFO" "${FUNCNAME[0]} - Searching for latest '$HMMSET' Release under '$HMMPROJURL'"
	HMMSETUP="$( getLatestGitHubExeVer "HedgeModManager" "https://github.com/thesupersonic16/HedgeModManager" )"
	if [ -n "$HMMSETUP" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Found '$HMMSETUP'"
	else
		writelog "ERROR" "${FUNCNAME[0]} - Could not find any '$HMMSET' Release"
	fi
}

function checkLatestHMM {
	AVAILABLEHMMVER="$1"
	HMMSPATH="$2"

	HMMUPDATEAVAILABLE=0

	# Auto-update executable - May not be needed if HMM auto updater works
	if [ -f "$HMMVERFILE" ]; then
		CURRHMMVER="$( head -n 1 "$HMMVERFILE" )"
		if [[ "$CURRHMMVER" = "$AVAILABLEHMMVER" ]]; then
			writelog "INFO" "${FUNCNAME[0]} - Latest HedgeModManager already downloaded - Nothing to do"  # Probably have to do a version check here later
			echo "Latest HedgeModManager is already downloaded or was downloaded previously"
		else
			writelog "INFO" "${FUNCNAME[0]} - HedgeModManager update is available ($CURRHMMVER -> $AVAILABLEHMMVER) - Updating"
			echo "HedgeModManager update is available ($CURRHMMVER -> $AVAILABLEHMMVER) - Updating"
			if [ -f "$HMMSPATH" ]; then
				rm "$HMMSPATH"
			else
				writelog "INFO" "${FUNCNAME[0]} - HedgeModManager executable doesn't exist - nothing to remove before updating"  # Could happen if EXE is removed but version tracking file is not
				echo "No existing HedgeModManager executable"
			fi
			HMMUPDATEAVAILABLE=1
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - No HedgeModManager version file found at '$HMMVERFILE' - Nothing to check, assuming we need to update"
		echo "Could not get existing HedgeModManager version - Downloading latest '$AVAILABLEHMMVER'"
		HMMUPDATEAVAILABLE=1
	fi
}

function dlLatestHMM {

	function dlLatestHMMDev {
		HMMARCHIVENAME="${HMM}-Release.zip"
		HMMARCHIVEPATH="$HMMDLDIR/${HMMARCHIVENAME}"

		HMMSETUP="${HMM}.exe"
		HMMSETUPBASE="$( basename "${HMMSETUP}" )"  # Doing this in case "HMMSETUP" ever changes
		HMMSPATH="$HMMDLDIR/$HMMSETUP"

		HMMUPDATEAVAILABLE=0

		HMMAPIURLPATH="${HMMPROJURL//$GHURL}"
		HMMLATESTDEV="${HMMPROJURL}/$( fetchLatestGitHubActionsBuild "${AGHURL}/repos${HMMAPIURLPATH}" 1 )"  # Used to get the latest dev version SHA
		HMMLATESTDEVURL="https://nightly.link${HMMAPIURLPATH}/workflows/build/rewrite/${HMMARCHIVENAME}"  # Use nightly.link to get latest artifact download link for HMM
		HMMVER="$( echo "$HMMLATESTDEV" | cut -d ";" -f 2 )"

		writelog "INFO" "${FUNCNAME[0]} - HedgeModManager artifact URL: '$HMMLATESTDEVURL' ($HMMVER)"

		checkLatestHMM "$HMMVER" "$HMMSPATH"

		mkProjDir "$HMMDLDIR"
		if [ ! -f "$HMMSPATH" ] || [ "$HMMUPDATEAVAILABLE" -eq 1 ]; then
			# No exe OR we need to update, check if we have the archive to extract it from
			writelog "INFO" "${FUNCNAME[0]} - Either no HedgeModManager executable downloaded and extracted, or there is an update available - HMMUPDATEAVAILABLE is '${HMMUPDATEAVAILABLE}'"
			if [ ! -f "$HMMARCHIVEPATH" ] || [ "$HMMUPDATEAVAILABLE" -eq 1 ]; then
				# (No archive and no exe) or update available, download from GitHub
				writelog "INFO" "${FUNCNAME[0]} - Either no HedgeModManager artifact present, or an update is available - HMMUPDATEAVAILABLE is '${HMMUPDATEAVAILABLE}'"

				# Download
				writelog "INFO" "${FUNCNAME[0]} - Downloading latest HedgeModManager Development Artifact from URL '$HMMLATESTDEVURL'"
				echo "Downloading latest HedgeModManager Development Artifact"
				notiShow "$(strFix "$NOTY_HMMDL" "$HMMDLVER")" "X"
				dlCheck "$HMMLATESTDEVURL" "$HMMARCHIVEPATH" "X" "Downloading latest HedgeModManager Development '$HMMVER'" &>/dev/null
			else
				# We have existing archive but no executable
				writelog "INFO" "${FUNCNAME[0]} - Found existing and up-to-date HedgeModManager archive at '$HMMSPATH' - Extracting"
				echo "Found up-to-date HedgeModManager Development release archive - Extracting "
			fi

			# Extract
			# Check if download success
			if [ -f "$HMMARCHIVEPATH" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Downloaded latest HedgeModManager Artifact - Extracting archive at '$HMMARCHIVEPATH'"
				echo "Extracting latest HedgeModManager Development Artifact"
				"$UNZIP" -qo "$HMMARCHIVEPATH" -d "$HMMDLDIR"  # Extract quiet and overwrite existing file if present without confirmation

				# If download sucess, try to extract
				if [ -f "$HMMSPATH" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Successfully extracted HedgeModManager archive at '$HMMSPATH'"
					echo "Successfully extracted HedgeModManager archive"
					writelog "Info" "${FUNCNAME[0]} - Removing archive '$HMMARCHIVENAME' after successful extraction"
					rm "$HMMARCHIVEPATH"
					echo "$HMMVER" > "$HMMVERFILE"  # Update version on successfull download and extract
				else
					# Download failed
					writelog "WARN" "${FUNCNAME[0]} - Failed to extract HedgeModManager archive at '$HMMSPATH'"
					echo "Failed to extract HedgeModManager archive"
				fi
			else
				# Download failed
				writelog "WARN" "${FUNCNAME[0]} - Failed to download latest HedgeModManager Development archive ('$HMMVER') to '$( basename "$HMMSETUP" )'"
				echo "Failed to download latest HedgeModManager development release archive"
			fi
		else
			# We have executable - Nothing to do
			writelog "INFO" "${FUNCNAME[0]} - Found existing and up-to-date HedgeModManager executable at '$HMMSPATH'"
			echo "Found up-to-date HedgeModManager executable - Nothing to download"
		fi
	}

	# Download latest HedgeModManager stable release
	function dlLatestHMMStable {
		getLatestHMMVer

		# These values return the version URL from GitHub, so when we called "basename" we're getting the URL basename
		# The format that comes back is something like /releases/7.8-2/HedgeModManager.exe
		if [ -n "$HMMSETUP" ]; then
			mkProjDir "$HMMDLDIR"
			HMMSETUPBASE="$( basename "$HMMSETUP" )"
			HMMVER="$( dirname "$HMMSETUP" )"
			HMMVER="${HMMVER##*/}"
			HMMSPATH="$HMMDLDIR/$HMMSETUPBASE"

			echo "Latest available version is '$HMMVER' - Checking to see if we are up-to-date"
			checkLatestHMM "$HMMVER" "$HMMSPATH"

			if [ ! -f "$HMMSPATH" ] || [ "$HMMUPDATEAVAILABLE" -eq 1 ]; then
				DLURL="${HMMPROJURL//"HedgeModManager"}$HMMSETUP"
				writelog "INFO" "${FUNCNAME[0]} - Downloading '$HMMSETUPBASE' to '$( basename "$HMMDLDIR" )' from '$DLURL'"
				echo "Downloading HedgeModManager ${HMMVER}"
				notiShow "$(strFix "$NOTY_HMMDL" "$HMMVER")" "X"
				dlCheck "$DLURL" "$HMMSPATH" "X" "Downloading HedgeModManager $HMMSETUP $HMMVER" &>/dev/null
				if [ -f "$HMMSPATH" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Successfully downloaded HedgeModManager $HMMVER - continuing installation"
					echo "Successfully downloaded HedgeModManager $HMMVER to '$( basename "$HMMSETUP" )'"
					echo "$HMMVER" > "$HMMVERFILE"
				else
					writelog "ERROR" "${FUNCNAME[0]} - Failed to download HedgeModManager from '$DLURL'"
					echo "Failed to download HedgeModManager"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - HedgeModManager executable already downloaded - Nothing to do"
				echo "HedgeModManager is up-to-date"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - No HMMSETUP defined - nothing to download - skipping"
			echo "Could not find HedgeModManager release"
		fi
	}

	# Internet connection check
	if ! ping -q -c1 github.com &>/dev/null; then
		writelog "WARN" "${FUNCNAME[0]} - Looks like we're offline or GitHub is down, not attempting to download HedgeModManager when offline - May cause issues if no HMM exe is downloaded!"
		writelog "WARN" "${FUNCNAME[0]} - Will still attempt to install Winetricks as they may be cached"
		echo "WARNING: Can't reach GitHub - Not attempting to download HedgeModManager"

		# Set HMMVER offline if we have it in the HMMVERFILE + some warning logging if there is no version file
		if [ -f "$HMMVERFILE" ]; then
			HMMVER="$( head -n 1 "$HMMVERFILE" )"
			if [ -z "$HMMVER" ]; then
				writelog "WARN" "${FUNCNAME[0]} - HedgeModManager version stored in HMMVERFILE at '$HMMVERFILE' appears to be empty, installation may have failed last time!"
			else
				writelog "INFO" "${FUNCNAME[0]} - HedgeModManager version stored in HMMVERFILE is '$HMMVER' - It seems like HedgeModManager successfully installed before, so running offline should work fine"
			fi

			if [ -f "$HMMDLDIR/${HMM}.exe" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Offline HedgeModManager executable found in '$HMMDLDIR/${HMM}.exe' - Assuming that this is a valid, pre-downloaded HMM executable that the user placed for offline use"
				HMMSPATH="$HMMDLDIR/$HMMSETUP"
			else
				writelog "WARN" "${FUNCNAME[0]} - No Offline HedgeModManager executable found in '$HMMDLDIR' with name '${HMM}.exe' - Installation will probably not work when we get to 'installHMM' stage!"
			fi
		else
			writelog "WARN" "${FUNCNAME[0]} - No HMMVERFILE found at '$HMMVERFILE' - HedgeModManager may not have been installed and so may fail to start offline!"
		fi
	fi

	DLVER="$1"
	if [ -z "$DLVER" ]; then
		writelog "INFO" "${FUNCNAME[0]} - No value passed for whether user wants stable or development HedgeModManager - Assuming they want stable!"
	fi
	writelog "INFO" "${FUNCNAME[0]} - User wants HedgeModManager '${DLVER:-stable}'"

	# This will come from desktop file usually
	if [[ "$DLVER" = "$HMMAUTO" ]]; then
		DLVER="$HMMDLVER"
	fi

	if [[ "$DLVER" = "$HMMDEV" ]]; then
		# Get latest GitHub artifacts ver
		writelog "INFO" "${FUNCNAME[0]} - Checking latest available HedgeModManager Development version"
		echo "Checking latest available HedgeModManager Development version"

		dlLatestHMMDev
	else
		# If we don't pass dev, assume we want stable
		writelog "INFO" "${FUNCNAME[0]} - Checking latest available HedgeModManager Release/Stable version"
		echo "Checking latest available HedgeModManager Release version"

		dlLatestHMMStable
	fi
}

# NOTE: Winetricks *needs* GE-Proton to install dotnet48 correctly!
function setHMMVars {
	HMMPFX="${HMMCOMPDATA}/pfx"
	if [ -z "$HMMEXE" ]; then
		HMMEXE="$HMMDLDIR/${HMM}.exe"
		writelog "INFO" "${FUNCNAME[0]} - HMM EXE was not set - It is now '$HMMEXE'"
	fi
	HMMGAMES="$GLOBALMISCDIR/hmmgames.txt"
	if [ -z "$HMMWINE" ] || [ ! -f "$HMMWINE" ]; then
		if [ "$USEHMMPROTON" == "$NON" ]; then
			if [ ! -f "$PROTONCSV" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Looking for available Proton versions"
				getAvailableProtonVersions "up" X
			fi

			if ! grep -q "^GE" "$PROTONCSV"; then
				writelog "INFO" "${FUNCNAME[0]} - calling autoBumpGE"
				autoBumpGE "X"
			else
				writelog "INFO" "${FUNCNAME[0]} - Seems like we have a GE-Proton version available already"
			fi

			SETHMMPROT="$(grep "^GE" "$PROTONCSV" | sort -V | tail -n1)"

			SETHMMPROT="${SETHMMPROT%%;*}"

			USEHMMPROTON="$SETHMMPROT"

			touch "$FUPDATE"
			updateConfigEntry "USEHMMPROTON" "$USEHMMPROTON" "$STLDEFGLOBALCFG"
			writelog "INFO" "${FUNCNAME[0]} - USEHMMPROT is '$NON', so using latest GE-Proton"
		else
			writelog "INFO" "${FUNCNAME[0]} - USEHMMPROTON was set -- it is '$USEHMMPROTON'"
			SETHMMPROT="$USEHMMPROTON"
		fi

		# Sometimes ProtonCSV can have a version of GE-Proton that doesn't actually exist (or that used to exist, but doesn't anymore)
		#
		# This check forces it to look in the file in a different order (reverse version sort order `sort -Vr`) which should get it to find GE-Proton
		# and updates the relevant HMM Proton/Wine variables + writes out to config file
		#
		# The real fix here is to correctly re-populate the Proton versions in ProtonCSV.txt so that STL never tries to use an invalid Proton version to begin with!
		#
		# This check could be much cleaner, but the check is here outside of the above check to force the Proton value to get updated for any existing users
		if [ ! -f "$( getProtPathFromCSV "$SETHMMPROT" )" ]; then
			writelog "WARN" "${FUNCNAME[0]} - SETHMMPROT was not a directory -- Attempting to find it again"
			SETHMMPROT="$(grep "^GE" "$PROTONCSV" | sort -Vr | tail -n1)"
			SETHMMPROT="${SETHMMPROT%%;*}"

			if [ ! -f "$( getProtPathFromCSV "$SETHMMPROT" )" ]; then
				writelog "ERROR" "${FUNCNAME[0]} - Still could not find GE-Proton in PROTONCSV - This should be reported!"
			else
				writelog "INFO" "${FUNCNAME[0]} - SETHMMPROT was updated to value '$SETHMMPROT'"
				USEHMMPROTON="$SETHMMPROT"

				touch "$FUPDATE"
				updateConfigEntry "USEHMMPROTON" "$USEHMMPROTON" "$STLDEFGLOBALCFG"
			fi
		fi

		setModWine "SETHMMPROT" "HMMRUNPROT" "HMMWINE"
	fi
}

# Doesn't really "install" HMM, just creates the prefix for it if it doesn't already exist
# HMM's UI needs `dotnet48` to run and `d3dx9 vcrun2019 d3dcompiler_47` to render - we don't want to install this for every game, give HMM its own prefix to run in
# We can remove these if HMM ever works with Wine out of the box
function installHMM {
	if [ -f "$HMMSPATH" ]; then
		setHMMVars
		chooseWinetricks  # Force install of Winetricks earlier to prevent potential missing Winetricks var
		if [ -f "$HMMEXE" ]; then
			writelog "INFO" "${FUNCNAME[0]} - HedgeModManager executable found at '$HMMEXE' - Checking if we need to set up its Wine prefix"
			if [ ! -d "$HMMCOMPDATA" ]; then
				writelog "INFO" "${FUNCNAME[0]} - No existing HedgeModManager prefix found - Creating one"
				echo "Installing HedgeModManager $HMMVER"
				notiShow "$( strFix "$NOTY_HMMINST" "$HMMVER" )" "X"
				mkProjDir "$HMMCOMPDATA/pfx"

				# Install dotnet48
				writelog "INFO" "${FUNCNAME[0]} - Installing dotnet48 for $HMM"
				installDotNet "$HMMPFX" "$HMMWINE" "48" "HMMPREFIX" "X"  # 'X' here is to enable the experimental '--force' parameter
				writelog "INFO" "${FUNCNAME[0]} - Done"

				# Setup prefix with Proton
				touch "${HMMCOMPDATA}/tracked_files"
				STEAM_COMPAT_CLIENT_INSTALL_PATH="$SROOT" STEAM_COMPAT_DATA_PATH="$HMMCOMPDATA" "$HMMRUNPROT" "run" 2> "$STLSHM/${FUNCNAME[0]}_protonrun.log"

				# Install other needed Winetricks
				writelog "INFO" "${FUNCNAME[0]} - Installing 'd3dx9' 'vcrun2019' 'd3dcompiler_47' with '$HMMWINE' - These extra Winetricks are needed for HedgeModManager to run as well"
				OGGPFX="$GPFX"
				GPFX="$HMMPFX"
				RUNWINE="$HMMWINE"
				installWinetricksPaks "d3dx9 vcrun2019 d3dcompiler_47" "$HMMWINE" "extWine64Run"

				writelog "INFO" "${FUNCNAME[0]} - Installing extra 7zip dependency -- Experimental, may not work"
				installWinetricksPaks "7zip" "$HMMWINE" "extWine64Run"

				GPFX="$OGGPFX"
				writelog "INFO" "${FUNCNAME[0]} - Finished installing extra HedgeModManager winetricks"

				configureHMMPfxReg &>/dev/null

				writelog "INFO" "${FUNCNAME[0]} - Finished setting up HedgeModManager prefix"
				echo "Successfully installed HedgeModManager $HMMVER"
				notiShow "$NOTY_HMMINSTFIN" "X"
			else
				writelog "SKIP" "${FUNCNAME[0]} - HedgeModManager prefix already exists - Not recreating - Skipping installation"

				configureHMMPfxReg &>/dev/null  # The registry configuration needed may change overtime and may not have been fully configured at installation

				echo "Finished installing HedgeModManager"
			fi
		else
			writelog "ERROR" "${FUNCNAME[0]} - HedgeModManager '$HMMEXE' went missing - Maybe user is connected to the Internet"
			echo "HedgeModManager executable '$HMMEXE' went missing or was never downloaded to begin with - Are you connected to the Internet?"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$HMMSPATH' not found - Nothing to install - skipping"
	fi

	# Create .desktop file for 1-click install support and adding HMM to application menu
	writelog "INFO" "${FUNCNAME[0]} - Adding HedgeModManager to application menu and setting up link handlers"
	echo "Adding HedgeModManager to application menu and setting up link handlers"
	createHMMDesktopFile
}

# Remove Steam reg keys - needed to get HMM to find games with our prefix
function configureHMMPfxReg {
	writelog "INFO" "${FUNCNAME[0]} - Removing extra Steam registry keys from HedgeModManager prefix '$HMMPFX'"

	# Reg paths
	HKLMSTEAM="HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Valve\\Steam"
	HKCUSTEAM="HKEY_CURRENT_USER\\Software\\Valve\\Steam"
	KHCUSTEAMACTPRO="${HKCUSTEAM}\\ActiveProcess"

	# Reg values
	STEXE="SteamExe"
	STPA="SteamPath"
	INSTPA="InstallPath"
	STCLIDLL="SteamClientDll"
	STCLIDLL64="SteamClientDll64"

	# HKEY_LOCAL_MACHINE
	updateWineRegistryKey "delete" "$HKLMSTEAM" "$INSTPA" "$HMMPFX" "$HMMWINE"

	# KEY_CURRENT_USER
	updateWineRegistryKey "delete" "$HKCUSTEAM" "$STEXE" "$HMMPFX" "$HMMWINE"
	updateWineRegistryKey "delete" "$HKCUSTEAM" "$STPA" "$HMMPFX" "$HMMWINE"

	# ActiveProcess
	updateWineRegistryKey "delete" "$KHCUSTEAMACTPRO" "$STPA" "$HMMPFX" "$HMMWINE"
	updateWineRegistryKey "delete" "$KHCUSTEAMACTPRO" "$STCLIDLL" "$HMMPFX" "$HMMWINE"
	updateWineRegistryKey "delete" "$KHCUSTEAMACTPRO" "$STCLIDLL64" "$HMMPFX" "$HMMWINE"

	writelog "INFO" "${FUNCNAME[0]} - Finished removing registry keys from HedgeModManager prefix"
}

# Game-specific Winetricks
function prepareHMMGameWinetricks {
	# HMMGTWEAKAID="$1"  # Game AppID
	HMMGINSTPFX="$2"  # Prefix to install winetricks to (i.e. game prefix)

	# Set GPFX to game's prefix - Can't guarantee current GPFX will be the game's prefix so force it to ensure winetrick(s) are installed to the game's prefix and not HMM's prefix
	OGGPFX="$GPFX"
	GPFX="$HMMGINSTPFX"
	writelog "SKIP" "${FUNCNAME[0]} - No known tweaks needed for HMM mods currently - skipping"
	GPFX="$OGGPFX"
}

# Install dotnet48 for every 64bit game
function prepareHMMGames {
	setHMMVars

	# Get all hardcoded HMM supported games
	writelog "INFO" "${FUNCNAME[0]} - Reading all hardcoded HedgeModManager supported games from '$HMMGAMES'"
	echo "Setting up installed HedgeModManager compatible games"
	notiShow "$NOTY_HMMCONFIG" "X"
	while read -r HMMG; do
		# Get HMM game information from hmmgames.txt lines - games are stored as: "game name";appid;"architecture"
		HMMGN="$( echo "$HMMG" | cut -d ";" -f 1 | cut -d '"' -f2 )"
		HMMGAID="$( echo "$HMMG" | cut -d ";" -f 2 | cut -d '"' -f2 )"
		HMMGARCH="$( echo "$HMMG" | cut -d ";" -f 3 | cut -d '"' -f2 )"

		# Sometimes on Steam Deck it seems like the Wineprefix is created in a different library folder than the one the game is installed in
		# Might be a Steam Client bug, but if it persists / if this is the new behaviour, this check may need updated!
		HMMGAPPMA="$( listAppManifests | grep -m1 "${HMMGAID}.acf" )"
		HMMGPFX="$( setGPfxFromAppMa "$HMMGAID" "$HMMGAPPMA" )"
		if [ ! -d "$HMMGPFX" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Wineprefix for game '$HMMGN ($HMMGAID)' did not already exist at '$HMMGPFX' - The game may not have been started before!"
		fi

		# If HMM game is 64bit, installed and has a compatdata dir, install dotnet48 for that game
		if [[ "$HMMGARCH" = "64" ]]; then
			GPFX="$HMMPFX"

			# Check if we have a valid compatdata for a game (pfx/drive_c/users/steamuser)
			GPFXSTUS="$HMMGPFX/$DRCU/$STUS"
			if [ -d "$GPFXSTUS" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found compatdata dir for '$HMMGN' at '$GPFXSTUS' - Assuming it is installed"

				writelog "INFO" "${FUNCNAME[0]} - Install dotnet48 for install 64bit HedgeModManager game '$HMMGN'"
				notiShow "$( strFix "$NOTY_HMMGAMCONFIG" "$HMMGN" )" "X"
				if [ -z "$1" ]; then
					echo "Running configuration for '$HMMGN'"
					installDotNet "$HMMGPFX" "$HMMWINE" "48" "$HMMGN" &>/dev/null
					writelog "INFO" "${FUNCNAME[0]} - Finished installing dotnet48 for '$HMMGN'"
				else
					echo "Running configuration for '$HMMGN' using --force"
					installDotNet "$HMMGPFX" "$HMMWINE" "48" "$HMMGN" "X" &>/dev/null
					writelog "INFO" "${FUNCNAME[0]} - Finished installing dotnet48 for '$HMMGN' using --force"
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - Could not find compatdata dir for '$HMMGN' - Assuming that it is not installed"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - '$HMMGN' is 32bit, skipping"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Checking if we need to apply any game-specific tweaks to improve mod compatibility"
		prepareHMMGameWinetricks "$HMMGAID" "$HMMGPFX"
	done <"$HMMGAMES"
	echo "Finished configuring installed HedgeModManager games"
}

function startHMM {
	# TODO HMM button on UI somewhere in future? Not sure
	HMMDLVERARG="$1"
	HMMDOTNETFORCE="$2"

	dlLatestHMM "$HMMDLVERARG"
	installHMM

	# If this variable has *any* value, `--force` will be added to the installDotNet for each HMM game - This essentially forces a reinstall of dotnet for each game on each HMM bootup
	prepareHMMGames "$HMMDOTNETFORCE"

	writelog "INFO" "${FUNCNAME[0]} - Starting HedgeModManager in prefix '$HMMPFX' with Wine '$HMMWINE' and using executable at '$HMMEXE'"
	echo "Starting HedgeModManager"
	notiShow "$( strFix "$NOTY_HMMSTART" "$HMMVER" )" "X"

	WINEDEBUG="-all" WINEPREFIX="$HMMPFX" "$HMMWINE" "$HMMEXE" "$HMMARGS" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
}

# This will only remove the HMM Wineprefix and download executable files -- It will not remove any installed Winetricks or mods
function uninstallHMM {
	writelog "INFO" "${FUNCNAME[0]} - Preparing to uninstall HedgeModManager"
	echo "Preparing to uninstall HedgeModManager"

	rmDirIfExists "$HMMCOMPDATA"
	rmDirIfExists "$HMMDLDIR"
	rmFileIfExists "$HMMDFPA"
	rmFileIfExists "$HMMDFDLPA"

	writelog "INFO" "${FUNCNAME[0]} - Successfully uninstalled HedgeModManager"
	echo "Uninstalled HedgeModManager"
}

function listSupportedHMMGames {
	# List HMM compatible games from in format "Game Name (appid) (architecture)"
	while read -r HMMGAME; do
		HMMGAMENAME="$( echo "$HMMGAME" | cut -d ";" -f 1 | cut -d '"' -f2 )"
		HMMGAMEAID="$( echo "$HMMGAME" | cut -d ";" -f 2 | cut -d '"' -f2 )"
		HMMGAMEARCH="$( echo "$HMMGAME" | cut -d ";" -f 3 | cut -d '"' -f2 )"

		echo "$HMMGAMENAME ($HMMGAMEAID) ($HMMGAMEARCH-bit)"
	done < "$GLOBALMISCDIR/hmmgames.txt"
}

# Output installed HMM supported games in the format "Game (AppID) -> /path/to/prefix"
function listInstalledHMMGames {
	writelog "INFO" "${FUNCNAME[0]} - Looking for installed HedgeModManager games"
	OGGPFX="$GPFX"
	while read -r HMMGAME; do
		HMMGN="$( echo "$HMMGAME" | cut -d ";" -f 1 | cut -d '"' -f2 )"
		HMMGAID="$( echo "$HMMGAME" | cut -d ";" -f 2 | cut -d '"' -f2 )"

		# Check if game has compatdata dir, if it does then assume it is installed, also attempt to preserve existing GPFX, though this will probably only be called from the command line
		HMMGAPPMA="$( listAppManifests | grep -m1 "${HMMGAID}.acf" )"
		HMMGPFX="$( setGPfxFromAppMa "$HMMGAID" "$HMMGAPPMA" )"

		# Check if it has a "proper" directory structure and is not just a blank compatdata
		if [ -d "$HMMGPFX/$DRCU/$STUS" ]; then
			printf "%s (%s) -> %s\n" "$HMMGN" "$HMMGAID" "$HMMGPFX"
		fi
	done < "$GLOBALMISCDIR/hmmgames.txt"
	GPFX="$OGGPFX"
}

function listOwnedHMMGames {
	writelog "INFO" "${FUNCNAME[0]} - Looking for owned HedgeModManager games"

	HMMGAMES="$GLOBALMISCDIR/hmmgames.txt"
	while read -r line; do
		OWNEDHMMGAMELINE="$( grep "\"$line\"" "$HMMGAMES" )"
		OWNEDHMMGAMENAME="$( echo "$OWNEDHMMGAMELINE" | cut -d ";" -f 1 | cut -d '"' -f 2 )"
		OWNEDHMMGAMEAID="$( echo "$OWNEDHMMGAMELINE" | cut -d ";" -f 2 | cut -d '"' -f 2 )"
		OWNEDHMMGAMEARCH="$( echo "$OWNEDHMMGAMELINE" | cut -d ";" -f 3 | cut -d '"' -f 2 )"

		# If we have all of these, we can safely assume the game is installed -- Virtually identical logic to Vortex's list-owned
		if [ -n "$OWNEDHMMGAMENAME" ] && [ -n "$OWNEDHMMGAMEAID" ] && [ -n "$OWNEDHMMGAMEARCH" ]; then
			printf "%s (%s) (%s-bit)\n" "$OWNEDHMMGAMENAME" "$OWNEDHMMGAMEAID" "$OWNEDHMMGAMEARCH"
		fi
	done <<< "$(getOwnedAids)"
}

# Handle incoming mod download requests for HMM via mimetype URL "gamebananaidentifier:modurl" (ex: hedgemmgens:https://gamebanana.com/mmdl/455806,Mod,50766)
# HMM starts as a separate process for this, so it's fine to just call the exe (+selected proton +correct prefix) with the `-gb` parameter
function dlHedgeMod {
	setHMMVars

	if [ ! -d "$HMMPFX" ]; then
		writelog "INFO" "${FUNCNAME[0]} - HedgeModManager is not installed!"
		echo "It looks like HedgeModManager is not installed. Can't download URL, please try again!"
		notiShow "$NOTY_HMMDLMODFAIL" "X"  # Temp, use strings and better message later
	else
		writelog "INFO" "${FUNCNAME[0]} - Downloading HedgeModManager mod '$1' using '$HMMEXE' in prefix '$HMMPFX' with Wine '$HMMWINE'"


		BANANAHANDLER="$( echo "$1" | cut -d ":" -f 1 )"  # GameBanana Mime handler and Mod ID

		MODGAMENAME="$( grep "$BANANAHANDLER" "$HMMGAMES" | cut -d ";" -f 1 | cut -d '"' -f 2 )"
		MODID="$( basename "$( echo "$1" | cut -d ":" -f 3 )" | cut -d "," -f 3 )"

		echo "Downloading HedgeModManager $MODGAMENAME mod '$1'..."
		notiShow "$( strFix "$NOTY_HMMDLMOD" "$MODGAMENAME" "$MODID" )" "X"

		WINEDEBUG="-all" WINEPREFIX="$HMMPFX" "${HMMWINE}" "${HMMEXE}" -gb "$1" &>/dev/null
	fi
}

# Create a .desktop file entry/entries for HedgeModManager
#
# This seems to not work on Steam Deck - Maybe the .desktop file should just called xdg-open?
# Though the issue seemed more to be that HMM's desktop file wasn't being called at all from Firefox...
function createHMMDesktopFile {
	HMMICONNM="icon256.png"
	HMMICOPATH="$HMMDLDIR/$HMMICONNM"
	HMMICOURL="${HMMPROJURL}/raw/rewrite/HedgeModManager/Resources/Graphics/${HMMICONNM}"

	# Download HMM icon file from HMM repo to the HMM DL folder if it wasn't already downloaded
	if [ ! -f "$HMMICOPATH" ]; then
		"$WGET" "$HMMICOURL" -O "$HMMICOPATH"
	fi

	rmFileIfExists "$HMMDFPA"

	# Generate application launch .desktop file - Re-create each time to set correct path
	writelog "INFO" "${FUNCNAME[0]} - Creating new HedgeModManager desktop file at '$HMMDFPA'"
	{
		echo "[Desktop Entry]"
		echo "Type=Application"
		echo "Categories=Game;"
		echo "Name=${HMMNICE}"
		echo "Comment=A mod manager for Hedgehog Engine games on PC (Installed by TinkerGame)"
		echo "MimeType=x-scheme-handler/hedgemm"
		if [ "$INFLATPAK" -eq 1 ]; then
			echo "Exec=/usr/bin/flatpak run --command=tinkergame $FLATPAK_ID mods hedge start ${HMMAUTO} \"%u\""  # "hedge start" takes dl channel as argument, next arg is the URL
		else
			echo "Exec=$(realpath "$0") mods hedge start ${HMMAUTO} \"%u\""  # "hedge start" takes dl channel as argument, next arg is the URL
		fi
		echo "Icon=${HMMICOPATH}"
		echo "Terminal=false"
		echo "X-KeepTerminal=false"
	} > "$HMMDFPA"

	# Get all HMM mime handlers in use on GameBanana from hardcoded list in hmmgames.txt
	HMMGAMEMIMES="x-scheme-handler/hedgemm"
	while read -r HMMGAME; do
		# 4th col in hmmgames.txt is the MimeType name
		HMMGAMEMIMES+=";x-scheme-handler/$( echo "$HMMGAME" | cut -d ";" -f 4 | cut -d '"' -f2 )"
	done < "$GLOBALMISCDIR/hmmgames.txt"

	if [ ! -f "$HMMDFDLPA" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating HedgeModManager Desktop file for handing supported game MimeTypes"
	else
		writelog "INFO" "${FUNCNAME[0]} - Updating HedgeModManager Desktop file for handing supported game MimeTypes"
		rm "$HMMDFDLPA"
	fi

	# Create Desktop file for handling mod dowwnloads using HMM handlers
	{
		echo "[Desktop Entry]"
		echo "Type=Application"
		echo "Categories=Utilities;"
		echo "Name=${HMM} ($PROGNAME) - GameBanana Handler"
		echo "Comment=Link Handler - For internal use only"
		echo "Icon=$STLICON"
		echo "MimeType=$HMMGAMEMIMES"
		echo "Terminal=false"
		echo "X-KeepTerminal=false"
		echo "Path=$HMMDLDIR"
		if [ "$INFLATPAK" -eq 1 ]; then
			echo "Exec=/usr/bin/flatpak run --command=tinkergame $FLATPAK_ID mods hedge url %u"  # "hedge url" takes the download URL as argument
		else
			echo "Exec=$(realpath "$0") mods hedge url %u"  # "hedge url" takes the download URL as argument
		fi
		echo "NoDisplay=true"
		echo "Hidden=false"
	} >> "$HMMDFDLPA"

	# Associate GameBanana Mimes with DL desktop file
	if [ -x "$(command -v "$XDGMIME" 2>/dev/null)" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Setting download defaults for HedgeModManager GameBanana protocols via '$XDGMIME' pointing at '$HMMDFDLPA'"
		for HMMMIME in ${HMMGAMEMIMES//;/ }; do
			"$XDGMIME" default "$HMMDFDL" "$HMMMIME"
		done
	else
		writelog "SKIP" "${FUNCNAME[0]} - Required Mime handler '$XDGMIME' not found - couldn't set download defaults for HedgeModManager GameBanana protocols - skipping"
	fi
}

### HEDGEMODMANAGER (HMM) END

#### MO2 + Vortex ####
# NOTE: This was written with MO2 and Vortex in mind (seems to also currently work for HMM)
# It relies on projects having proper releases and tagging
# It may need tweaking if this is used for other projects in future or might require an entirely new function
