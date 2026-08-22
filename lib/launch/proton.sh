#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function setProtonPathVersion {
	if [ -n "$INPROTV" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using directly known '$INPROTV' as Proton Version for '$1'"
		echo "$INPROTV"
	else
		if [ -n "$1" ]; then
			PRTPATH="$1"
			CTVDF="$(dirname "$PRTPATH")/$CTVDF"
			PPV="$(dirname "$PRTPATH")/version"
			if [ -f "$CTVDF" ]; then
				PROTVOUT="$(grep "display_name" "$CTVDF" | grep -v "e.g." | sed "s:\" \":\";\":g" | cut -d ';' -f2)"
			elif [ -f "$PPV" ]; then
				PROTVOUT="$(awk '{print $2}' < "$PPV")"
			fi

			if [ -z "$PROTVOUT" ]; then
				# if no useful version was provided - hardcode it here:
				if grep -q "Proton 3.7" <<<"$PRTPATH"; then
					PROTVOUT="proton-3.7-8"
				else
					# fallback if everything fails - in the rare cases where this unknown proton version is used this might cause problems
					# if you need it open an issue and it will get a hardcoded entry as well
					PROTVOUT="proton-unknown-$((900 + RANDOM % 100))"
				fi
			fi
			#writelog "INFO" "${FUNCNAME[0]} - Setting the Proton Version for '$1' to '${PROTVOUT//\"/}'"	# checking $PROTONCSV should be enough
			echo "${PROTVOUT//\"/}"
		fi
	fi
}

function fillProtonCSV {
	if [ -n "$1" ]; then
		protonfileV="$1"
	else
		protonfileV="$(setProtonPathVersion "$PROTBIN")"
	fi

	if [ -n "$protonfileV" ]; then
		PCSV="\"${protonfileV//\"/}\";\"$(readlink -f "$PROTBIN")\""
		if [[ ! " ${ProtonCSV[*]} " =~ $PCSV ]]; then  # $PCSV can always be read if interested
			mapfile -t -O "${#ProtonCSV[@]}" ProtonCSV <<< "$PCSV"
		else
			writelog "SKIP" "${FUNCNAME[0]} - '$PCSV' is already in the Proton array"
		fi
	fi
}

## Get internal name for a Proton version, first by checking for a 'compatibilitytool.vdf' file in its root directory, then for a Proton version file
## Right now this is only used by addNonSteamGame
## TODO at some point maybe we should store this in the ProtonCSV as well? Then the format would be 'versionfilename;protonpath;internalname'
function getProtonInternalName {
	## Tools are not necessarily guaranteed to have this comment, but I checked several and they all had it:
	## - TinkerGame (naturally)
	## - All GE-Proton8 releases
	## - Standard Proton-tkg releases
	## - Luxtorpeda
	##
	## Steam Linux Runtime 1.0 (scout) / Native Linux Steam Linux Runtime is identified as 'steamlinuxruntime'
	## No idea where the Steam Client gets this from, maybe it's just hardcoded, I couldn't find a string anywhere in the SteamLinuxRuntime installation folder or the 'appmanifest_1070560.acf'
	function getProtonInternalNameVdf {
		CTVPATH="$1"
		if [ -f "$CTVPATH" ]; then
			grep -i "// internal" "$CTVPATH" | sed 's-// Internal name of this tool--' | xargs
		else
			writelog "WARN" "${FUNCNAME[0]} - Could not find compatibilitytool.vdf file for Proton version at '$CTVPATH'"
			echo ""
		fi
	}

	## Get the Proton version version text file
	function getProtonInternalNameVersionFile {
		PPVPATH="$1"
		if [ -f "$PPV" ]; then
			awk '{print $2}' < "$PPV"
		else
			writelog "WARN" "${FUNCNAME[0]} - Could not find Proton version file at '$PPVPATH'"
		fi
	}

	## Check if the path provided is for a Valve Proton version, by making some assumptions around the directory structure
	function checkIsValveProton {
		VPP="$1"  # Valve Proton Path

		writelog "INFO" "${FUNCNAME[0]} - Checking if Proton version at '$VPP' is a Valve Proton version"
		# We used to check only for 'dist', but Proton 9.0 onwards (including Experimental & Hotfix) use 'files' instead of 'dist'
		# The only assumption we can make for a Valve Proton version now is if it's missing the compatibilitytools.vdf file, since
		# They Valve Proton can have either 'files' or 'dist'
		#
		# The main thing we *need* to check for is "$VPP/$CTVDF" (compatibilitytools.vdf in the compat tool folder), as all
		# third-party compat tools should have this and Valve Proton versions do not (their info is stored in appinfo.vdf internal to Steam)
		# The checks for 'files' and 'dist' are just for sanity to make sure this is a valid Proton version altogether
		if [[ ! -f "$VPP/$CTVDF" && ( -d "$VPP/dist" || -d "$VPP/files" ) ]]; then
			writelog "INFO" "${FUNCNAME[0]} - Looks like we have a Valve Proton release here"
			return 0
		else
			writelog "INFO" "${FUNCNAME[0]} - Doesn't look like a Valve Proton release, directory structure doesn't match"
			return 1
		fi
	}

	## Build the Valve Proton internal name based on its version + some hardcoding for Experimental and Hotfix
	function getValveProtonInternalName {
		BASEPRTNAM="$1"
		INTPROTNAM="proton_"
		FINALINTPROTNAM=""

		writelog "INFO" "${FUNCNAME[0]} - Building Proton version internal name using version information"
		PRTVERS="$( echo "${BASEPRTNAM%-*}" | cut -d '-' -f2 )"  # Turn proton-8.0-3c into proton-8.0, then into 8.0

		PRTMAJORVERS="$( echo "$PRTVERS" | cut -d '.' -f1 )"  # Get minor version e.g. '8' from '8.0', '4' from '4.11'
		PRTMINORVERS="$( echo "$PRTVERS" | cut -d '.' -f2 )"  # Get minor version e.g. '0' from '8.0', '11' from '4.11'

		## If minor vers > 0, we need to include it in the internal name -- Defaults to just major version
		INTPROTVERSUFFIX="${PRTMAJORVERS}"
		if [ "$PRTMINORVERS" -gt 0 ]; then
			INTPROTVERSUFFIX+="${PRTMINORVERS}"
		fi

		FINALINTPROTNAM="${INTPROTNAM}${INTPROTVERSUFFIX}"

		writelog "INFO" "${FUNCNAME[0]} - Final Internal Proton name for given Proton name '$BASEPRTNAM' string is '$FINALINTPROTNAM'"
		echo "$FINALINTPROTNAM"
	}

	PROTCSVSTR="$1"

	PRTVERS="$( echo "$PROTCSVSTR" | cut -d ';' -f1 )"
	PRTPATH="$( echo "$PROTCSVSTR" | cut -d ';' -f2 )"
	PRTPATHDIR="$( dirname "$PRTPATH" )"

	CTVDFPA="$PRTPATHDIR/$CTVDF"
	PPV="$PRTPATHDIR/version"

	INTPROTNAME="$( getProtonInternalNameVdf "$CTVDFPA" )"  # First attempt to get the internal name from compatibilitytool.vdf
	if [ -n "$INTPROTNAME" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Got Proton Internal name '$INTPROTNAME' from '$CTVDFPA'"
		echo "$INTPROTNAME"
	elif [[ $PRTVERS == experimental* ]]; then  # Experimental hardcode
		writelog "INFO" "${FUNCNAME[0]} - Looks like we have Proton Experimental -- Hardcoding internal name 'proton_experimental'"
		echo "proton_experimental"
	elif [[ $PRTVERS == hotfix* ]]; then  # Hotfix hardcode
		writelog "INFO" "${FUNCNAME[0]} - Looks like we have Proton Hotfix here -- Hardcoding internal name to 'proton_hotfix'"
		echo "proton_hotfix"
	else
		writelog "INFO" "${FUNCNAME[0]} - Could not get internal Proton name for '$PRTVERS' from '$CTVDF' - Maybe it didn't have this file"
		writelog "INFO" "${FUNCNAME[0]} - Checking if we have a Valve Proton version here to build the internal name from"

		if checkIsValveProton "$PRTPATHDIR"; then
			writelog "INFO" "${FUNCNAME[0]} - Seems we have a Valve Proton version, building internal name manually"
			getValveProtonInternalName "$PRTVERS"
		else
			writelog "INFO" "${FUNCNAME[0]} - Doesn't seem like we have a Valve Proton version"
			writelog "INFO" "${FUNCNAME[0]} - Still could not find Proton internal name from '$CTVDF' - Giving up and falling back to the Proton version, some tools use this as their internal name"
			echo "$PRTVERS"
		fi
	fi
}

function printProtonArr {
	printf "%s\n" "${ProtonCSV[@]//\"/}"
}

function prettyPrintProtonArr {
	for PV in "${ProtonCSV[@]//\"/}"
	do
		PVNAME=$( echo "$PV" | cut -d ';' -f1 )
		PVPATH=$( echo "$PV" | cut -d ';' -f2 )

		if [ -n "$1" ]; then
			if [ "$1" == "name" ] || [ "$1" == "n" ]; then
				printf "%s\n" "$PVNAME"
			elif [ "$1" == "path" ] || [ "$1" == "p" ]; then
				printf "%s\n" "$PVPATH"
			fi
		else
			printf "%s -> %s\n" "$PVNAME" "$PVPATH"
		fi

	done
}

function delEmptyFile {
	if [ -f "$1" ]; then
		if [ "$(wc -l < "$1")" -le 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Removing empty file '$1'"
			rm "$1" 2>/dev/null
		fi
	fi
}

function rmDupLines {
	if grep -q "gawk" <<< "$AWKBIN"; then
		gawk -i inplace '!visited[$0]++' "$1"
	else
		awk '!seen[$0]++' "$1" > "$STLSHM/${FUNCNAME[0]}"
		cp "$STLSHM/${FUNCNAME[0]}" "$1"
		rm "$STLSHM/${FUNCNAME[0]}" 2>/dev/null
	fi
}

function getProtNameFromPath {
	grep "$1" "$PROTONCSV" | cut -d ';' -f1
}

function getAvailableProtonVersions {
	# skip this function if a linux game was started
	if [ "$ISGAME" -eq 2 ] || [ -n "$2" ]; then
		# ...and if USEWINE is enabled
		if [ -n "$USEWINE" ] && [ "$USEWINE" -eq 1 ]; then
			writelog "SKIP" "${FUNCNAME[0]} - USEWINE is enabled - skipping this function"
		elif [ -f "$STLGAMECFG" ] && grep -q "USEWINE=\"1\"" "$STLGAMECFG" ; then
			writelog "SKIP" "${FUNCNAME[0]} - USEWINE is enabled in the to-be-loaded gameconfig '$STLGAMECFG' - skipping this function"
			# could still be enabled via steamcollection, but this would be an overkill here, as ${FUNCNAME[0]} is non-fatal
		else
			delEmptyFile "$PROTONCSV"

			# find new proton versions in CUSTPROTEXTDIR
			if [ ! -f "$CUSTOMPROTONLIST" ] || [ "$(find -L "$CUSTPROTEXTDIR" -mindepth 1 -maxdepth 1 -type d | wc -l)" -gt "$(wc -l < "$CUSTOMPROTONLIST")" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Updating protonlist '$CUSTOMPROTONLIST' with possible new proton versions from '$CUSTPROTEXTDIR'"
				find -L "$CUSTPROTEXTDIR" -type f -name "proton" >> "$CUSTOMPROTONLIST"
			fi

			if [ ! -f "$PROTONCSV" ] || { [ -n "$1" ] && [ "$1" = "up" ]; } || [ "$1" == "F" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Initially creating an array with available Proton versions"

				# following symlinks (find -L) and using maxdepth 2 to avoid duplicates caused by _(user created)_ symlinks

				# user installed compatibilitytool:
				if [ -d "$STEAMCOMPATOOLS" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Adding Proton versions found in STEAMCOMPATOOLS '$STEAMCOMPATOOLS'"
					while read -r PROTBIN; do
						if [ -f "$PROTBIN" ]; then
							writelog "INFO" "${FUNCNAME[0]} - Found proton directory: '$PROTBIN'"
							fillProtonCSV
						fi
					done <<< "$(find -L "$STEAMCOMPATOOLS" -mindepth 2 -maxdepth 2 -type f -name "proton")"
				else
					writelog "SKIP" "${FUNCNAME[0]} - Directory STEAMCOMPATOOLS '$STEAMCOMPATOOLS' not found - skipping"
				fi

				if [ -n "$STEAM_EXTRA_COMPAT_TOOLS_PATHS" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Adding Proton versions found in STEAM_EXTRA_COMPAT_TOOLS_PATHS '$STEAM_EXTRA_COMPAT_TOOLS_PATHS'"
					while read -r extrapath; do
						writelog "INFO" "${FUNCNAME[0]} - Searching for Proton version in '$extrapath'"
						while read -r PROTBIN; do
							if [ -f "$PROTBIN" ]; then
								writelog "INFO" "${FUNCNAME[0]} - Found proton directory: '$PROTBIN'"
								fillProtonCSV
							fi
						done <<< "$(find -L "$extrapath" -mindepth 2 -maxdepth 2 -type f -name "proton")"
					done <<< "$(tr ':' '\n' <<< "$STEAM_EXTRA_COMPAT_TOOLS_PATHS")"
				else
					if [ -d "$SYSSTEAMCOMPATOOLS" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Adding Proton versions found in SYSSTEAMCOMPATOOLS '$SYSSTEAMCOMPATOOLS'"
						while read -r PROTBIN; do
							if [ -f "$PROTBIN" ]; then
								writelog "INFO" "${FUNCNAME[0]} - Found proton directory: '$PROTBIN'"
								fillProtonCSV
							fi
						done <<< "$(find -L "$SYSSTEAMCOMPATOOLS" -mindepth 2 -maxdepth 2 -type f -name "proton")"
					else
						writelog "SKIP" "${FUNCNAME[0]} - Directory SYSSTEAMCOMPATOOLS '$SYSSTEAMCOMPATOOLS' not found - skipping"
					fi
				fi

				# official proton versions installed via Steam in default SteamLibrary
				if ! grep -q "\"path\".*.\"$SROOT\"" "$LFVDF"; then
					if [ -d "$DEFSTEAMAPPSCOMMON" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Adding Proton versions found in DEFSTEAMAPPSCOMMON '$DEFSTEAMAPPSCOMMON'"
						while read -r protondir; do
							PROTBIN="$protondir/proton"
							if [ -f "$PROTBIN" ]; then
								writelog "INFO" "${FUNCNAME[0]} - Found proton directory: '$protondir'"
								fillProtonCSV
							fi
						done <<< "$(find -L "$DEFSTEAMAPPSCOMMON" -mindepth 2 -maxdepth 2 -type f -name "proton")"
					else
						writelog "SKIP" "${FUNCNAME[0]} - Directory DEFSTEAMAPPSCOMMON '$DEFSTEAMAPPSCOMMON' not found - this should not happen! - skipping"
					fi
				fi

				# official proton versions installed via Steam in additional SteamLibrary Paths
				if [ -f "$CFGVDF" ] || [ -f "$LFVDF" ]; then
					if ! grep -q "BaseInstallFolder\|\"path\"" "$CFGVDF" "$LFVDF" 2>/dev/null; then
						writelog "INFO" "${FUNCNAME[0]} - No additional Steam Libraries configured in '$CFGVDF' or '$LFVDF' - so no need to search in there"
					else
						writelog "INFO" "${FUNCNAME[0]} - Adding Proton versions found in additional SteamLibrary Paths"
						while read -r protondir; do
							PROTBIN="$protondir/proton"
							if [ -f "$PROTBIN" ]; then
								writelog "INFO" "${FUNCNAME[0]} - Found proton directory: '$protondir'"
								fillProtonCSV
							fi
						done <<< "$(while read -r SLP; do if [ -d "${SLP//\"/}/$SAC" ]; then find "${SLP//\"/}/$SAC" -mindepth 1 -maxdepth 1 -type d -name "Proton*"; fi; done <<< "$(grep "BaseInstallFolder\|\"path\"" "$CFGVDF" "$LFVDF" 2>/dev/null | rev | cut -f1 | rev | sort -u)")"
					fi
				else
					writelog "SKIP" "${FUNCNAME[0]} - Neither file CFGVDF '$CFGVDF' nor file LFVDF '$LFVDF' found - this should not happen! - skipping"
				fi

				# custom Proton List:
				if [ -f "$CUSTOMPROTONLIST" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Adding Proton versions found in CUSTOMPROTONLIST '$CUSTOMPROTONLIST'"

					rmDupLines "$CUSTOMPROTONLIST"
					sed '/^$/d' -i "$CUSTOMPROTONLIST"

					while read -r PROTLINE; do
						writelog "INFO" "${FUNCNAME[0]} - Checking line '$PROTLINE' in '$CUSTOMPROTONLIST'"

						if grep -q ";" <<< "$PROTLINE"; then
							PROTBIN="$(cut -d ';' -f2 <<< "$PROTLINE")"
							PROTVERS="$(cut -d ';' -f1 <<< "$PROTLINE")"
							writelog "INFO" "${FUNCNAME[0]} - Adding '$PROTVERS' to the list"
							fillProtonCSV "$PROTVERS"
						elif [ -f "$PROTLINE" ]; then
							writelog "INFO" "${FUNCNAME[0]} - File '$PROTLINE' exists - adding it to the list"
							PROTBIN="$PROTLINE"
							fillProtonCSV
						else
							writelog "INFO" "${FUNCNAME[0]} - Removing invalid line '$PROTLINE' from '$CUSTOMPROTONLIST'"
							mapfile -t -O "${#ProtonMissing[@]}" ProtonMissing <<< "$PROTLINE"
						fi
					done <<< "$(grep -v "^#" "$CUSTOMPROTONLIST")"

					# remove files from custom list which do not exist (anymore)
					if [ -n "${ProtonMissing[0]}" ]; then
						while read -r NOPROT; do
							sed "/${NOPROT//\//\\/}/d" -i "$CUSTOMPROTONLIST"
						done <<< "$(printf "%s\n" "${ProtonMissing[@]}")"
						unset ProtonMissing
					fi
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - Creating an array with available Proton versions using the file '$PROTONCSV' which was created during a previous run"
				mapfile -t -O "${#ProtonCSV[@]}" ProtonCSV < "$PROTONCSV"
			fi
			printProtonArr > "$PROTONCSV"
			rmDupLines "$PROTONCSV"
		fi
	fi
}

