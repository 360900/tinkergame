#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function getReShadeExeArch {
	if [ -n "$ARCHALTEXE" ] && [[ ! "$ARCHALTEXE" =~ ${DUMMYBIN}$ ]]; then
		CHARCH="$ARCHALTEXE"
	else
		CHARCH="$GP"
	fi
}

# Install steps for ReShade and SpecialK are a bit different
function installReshadeForSpecialK {
	writelog "INFO" "${FUNCNAME[0]} - Installing ReShade DLLs for use with SpecialK (DLLs will not be renamed so SpecialK can read them)"

	# Raw copy ReShade DLLs using installRSdll -- Should make integrating things like ReShade update easier
	# These DLLSs are not tracked, we should be tracking them in ReShade.txt so toggling ReShade off correctly removes them
	# When turning ReShade off we should also check the DLL names and if SpecialK is no longer in use, to clean up a SpecialK+ReShade install (i.e. if using ReShade64.dll but SpecialK is off, just remove instead of renaming to .dll_off)	installRSdll "$RS_32" "0" "$RS_32"
	getReShadeExeArch

	# Very similar logic used for installReshade
	if [ "$(getArch "$CHARCH")" == "32" ]; then
		# Remove any existing ReShade DLLs so they can be replaced with SpecialK ones
		# TODO check if INI needs renamed someway
		removeReShadeInstallation "1"  # Remove any existing ReShade installation

		#32bit
		writelog "INFO" "${FUNCNAME[0]} - Installing 32bit ${RESH} for ${SPEK} as '$CHARCH' is 32bit"
		installd3d47dll "$D3D47_32" "$INSTDESTDIR"
		installRSdll "$RS_32" "0" "$RS_32"
		installRSdll "${RS_32//.dll/.json}" "0" "${RS_32//.dll/.json}"
	elif [ "$(getArch "$CHARCH")" == "64" ]; then
		removeReShadeInstallation "1"  # Remove any existing ReShade installation

		#64bit
		writelog "INFO" "${FUNCNAME[0]} - Installing 64bit ${RESH} for ${SPEK} as '$CHARCH' is 64bit"
		installd3d47dll "$D3D47_64" "$INSTDESTDIR"
		installRSdll "$RS_64" "0" "$RS_64"
		installRSdll "${RS_64//.dll/.json}" "0" "${RS_64//.dll/.json}"
	else
		writelog "SKIP" "${FUNCNAME[0]} - ERROR in ${RESH}+${SPEK} installation - no file information detected for '$CHARCH' or any 'neighbor file' - setting USERESHADE=0 for this session"
		export USERESHADE=0
	fi
}

# Helper to create ReShade INI
function createReShadeINI {
	if [ "$CREATERESHINI" -eq 0 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - ReShade INI creation is disabled (CREATERESHINI is '$CREATERESHINI') -- Skipping"
		return
	fi

	writelog "INFO" "${FUNCNAME[0]} - Creating ReShade INI file"

	if [ -f "$FRSINI" ]; then
		if grep -q "EffectSearchPaths=.\$RSSUB\Shaders" "$FRSINI"; then
			writelog "SKIP" "${FUNCNAME[0]} - Already have '$FRSINI' with default paths pointing to '$RSSUB'"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Found a '$FRSINI' without default paths pointing to '$RSSUB' - not touching it"
		fi
	else
		if [ -f "$FRSOINI" ] && grep -q "EffectSearchPaths=.*$RSSUB.*Shaders" "$FRSOINI"; then
			writelog "INFO" "${FUNCNAME[0]} - Re-enabling previously disabled '$FRSOINI'"
			mv "$FRSOINI" "$FRSINI"
		else
			# This used to use echo but was changed to use printf to address ShellCheck SC2028
			# In testing using both echo and printf produced the same string result, but if this causes issues we can re-evaluate
			writelog "INFO" "${FUNCNAME[0]} - Creating initial '$FRSINI' with default paths pointing to '$RSSUB'"
			{
				echo "[GENERAL]"
				printf "EffectSearchPaths=.\\%s\Shaders\n" "$RSSUB"
				printf "TextureSearchPaths=.\\%s\Textures\n" "$RSSUB"
				echo "PreprocessorDefinitions=RESHADE_DEPTH_LINEARIZATION_FAR_PLANE=1000.0,RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0,RESHADE_DEPTH_INPUT_IS_REVERSED=1,RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0"
			} > "$FRSINI"
		fi
	fi
}

function checkReshade {
	setShadDestDir

	RSLIST="$SHADDESTDIR/$RSTXT"
	RSOLIST="${RSLIST}_off"
	FRSINI="$SHADDESTDIR/$RSINI"
	FRSOINI="$SHADDESTDIR/${RSINI}_off"

	# TODO remove later:
	RSENABLED="${RESH}-${PROGNAME,,}-enabled.txt"
	RSDISABLED="${RESH}-${PROGNAME,,}-disabled.txt"
	# this doesn't cover all migration constellations, but better than nothing
	if [ "$USERESHADE" -eq 1 ] && [ -f "$SHADDESTDIR/$RSENABLED" ]; then
		mv "$SHADDESTDIR/$RSENABLED" "$RSLIST"
		if [ -f "$SHADDESTDIR/$RS_DX_DEST" ] && grep -q "$RESH" "$SHADDESTDIR/$RS_DX_DEST"; then
			echo "$RS_DX_DEST" >> "$RSLIST"
		fi

		if [ -f "$SHADDESTDIR/$RS_D9_DEST" ] && grep -q "$RESH" "$SHADDESTDIR/$RS_D9_DEST"; then
			echo "$RS_D9_DEST" >> "$RSLIST"
		fi
		sort "$RSLIST" -u -o "$RSLIST"
	elif [ "$USERESHADE" -eq 1 ] && [ -f "$SHADDESTDIR/$RSDISABLED" ]; then
		mv "$SHADDESTDIR/$RSDISABLED" "$RSOLIST"
		if [ -f "$SHADDESTDIR/$RS_DX_DEST" ] && grep -q "$RESH" "$SHADDESTDIR/$RS_DX_DEST"; then
			echo "$RS_DX_DEST" >> "$RSOLIST"
		fi

		if [ -f "$SHADDESTDIR/$RS_D9_DEST" ] && grep -q "$RESH" "$SHADDESTDIR/$RS_D9_DEST"; then
			echo "$RS_D9_DEST" >> "$RSOLIST"
		fi
		sort "$RSOLIST" -u -o "$RSOLIST"
	fi

	if [ "$USERESHADE" -eq 1 ]; then
		createReShadeINI

		# EXPERIMENTALLY RE-ENABLED
		# NOTE that this has no ReShade updating or version override checks, so it is missing many features that regular ReShade has!
		if [ "$USESPECIALK" -eq 1 ] && [ "$USERESHSPEKPLUGIN" -eq 1 ]; then
			writelog "WARN" "${FUNCNAME[0]} - Both '$SPEK' and '$RESH' are enabled." "E"
			writelog "WARN" "${FUNCNAME[0]} - This has historically caused crashes, but has been experimentally re-enabled!"
			writelog "WARN" "${FUNCNAME[0]} - Manual intervention may be required to fix crashes, such as renaming the SpecialK DLL to fix the SpecialK UI, or running dos2unix on INI files to fix crashes"
			writelog "WARN" "${FUNCNAME[0]} - For more information, see: https://github.com/sonic2kk/steamtinkerlaunch/issues/894"

			writelog "INFO" "${FUNCNAME[0]} - Using ${RESH} and $SPEK together"
			mkProjDir "$SHADDESTDIR"
			installReshadeForSpecialK
		else
			if [ -f "$RSOLIST" ]; then
				writelog "INFO" "${FUNCNAME[0]} - ${RESH} has been disabled previously using '${PROGNAME,,}' - enabling it now"
				while read -r rsdll; do
					if [ -f "$SHADDESTDIR/${rsdll}_off" ]; then
						mv "$SHADDESTDIR/${rsdll}_off" "$SHADDESTDIR/$rsdll"
					else
						writelog "WARN" "${FUNCNAME[0]} - '$SHADDESTDIR/${rsdll}_off' was supposed to be reenabled, but the file is missing"
					fi
				done < "$SHADDESTDIR/${RSTXT}_off"
				mv "$RSOLIST" "$RSLIST"
			fi

			if [ ! -f "$SHADDESTDIR/$D3D47" ]; then
				writelog "INFO" "${FUNCNAME[0]} - USERESHADE is '$USERESHADE' - looks like ${RESH} is not yet installed in '$SHADDESTDIR' - installing because USERESHADE is enabled"
				installReshade
			fi

			if [ -f "$FRSINI" ] && [ ! -f "$RSLIST" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Looks like ${RESH} was installed previously using '${PROGNAME,,}' without creating '$RSLIST' - recreating it now"
				installReshade F
			fi

			writelog "INFO" "${FUNCNAME[0]} - Setting WINEDLLOVERRIDES for ${RESH}: dxgi=n,b;d3d9=n,b;${D3D47//.dll}=n,b;d3d11=n,b;opengl32=n,b;${RESHADEDLLNAME//.dll}=n,b"
			WINEDLLOVERRIDES="$WINEDLLOVERRIDES;dxgi=n,b;d3d9=n,b;${D3D47//.dll}=n,b;d3d11=n,b;opengl32=n,b;${RESHADEDLLNAME//.dll}=n,b"
			if [ "$USESPECIALK" -eq 1 ] && [ "$USERESHSPEKPLUGIN" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Adding SpecialK DLL name to WINEDLLOVERRIDES because it is enabled and 'USERESHSPEKPLUGIN' is also enabled"
				WINEDLLOVERRIDES+=";$( basename "$SPEKDST" )=n,b"
			fi
			export WINEDLLOVERRIDES="$WINEDLLOVERRIDES"
		fi
	else
		if [ -f "$FRSINI" ]; then
			writelog "INFO" "${FUNCNAME[0]} - ${RESH} has been disabled by the user, so renaming '$FRSINI' to '$FRSOINI'"
			mv "$FRSINI" "$FRSOINI"
		fi

		if [ -f "$RSLIST" ]; then
			writelog "INFO" "${FUNCNAME[0]} - ${RESH} has been installed previously with '${PROGNAME,,}' - disabling it now"
			while read -r rsdll; do
				if [ -f "$SHADDESTDIR/${rsdll}" ]; then
					mv "$SHADDESTDIR/$rsdll" "$SHADDESTDIR/${rsdll}_off"
				else
					writelog "WARN" "${FUNCNAME[0]} - '$SHADDESTDIR/${rsdll}' was supposed to be disabled, but the file is already missing"
				fi
			done < "$RSLIST"
			mv "$RSLIST" "$RSOLIST"
		fi

		if [ "$USESPECIALK" -eq 0 ]; then
			if [ -f "$SHADDESTDIR/$RS_DX_DEST" ] && grep -q "$RESH" "$SHADDESTDIR/$RS_DX_DEST"; then
				writelog "WARN" "${FUNCNAME[0]} - Found unknown '$RESH' dll '$RS_DX_DEST' in '$SHADDESTDIR'"
			fi

			if [ -f "$SHADDESTDIR/$RS_D9_DEST" ] && grep -q "$RESH" "$SHADDESTDIR/$RS_D9_DEST"; then
				writelog "WARN" "${FUNCNAME[0]} - Found unknown '$RESH' dll '$RS_D9_DEST' in '$SHADDESTDIR'"
			fi
		fi
	fi
}

function extSpek {
	SRCARCH="$1"
	SPEXT64="$SPEKDLDIR/$SPEKVERS/${SPEK}64.dll"

	if [ -f "$SPEXT64" ] && [ "$AUTOSPEK" -eq 0 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Already have '$SPEXT64' - skipping extraction" "E"
	else
		if [ ! -f "$SRCARCH" ]; then
			SRCARCH="${SRCARCH//lK/l_K}"
		fi
		if [ -f "$SRCARCH" ]; then
			SRCARCHEXT="${SRCARCH##*.}"
			if [ "$SRCARCHEXT" = "zip" ]; then  # zip archive from GitHub Actions (downloaded from nightly.link URL)
				writelog "INFO" "${FUNCNAME[0]} - Extracting '$SRCARCH' into '$SPEKDLDIR/$SPEKVERS' using '$UNZIP'"
				"$UNZIP" -o "$SRCARCH" -d "$SPEKDLDIR/$SPEKVERS"
			else  # else assume 7zip
				if [ -x "$(command -v "$SEVZA")" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Extracting '$SRCARCH' to '$SPEKDLDIR/$SPEKVERS'" "E"
					"$SEVZA" x "$SRCARCH" -o"$SPEKDLDIR/$SPEKVERS" 2>/dev/null
				else
					writelog "SKIP" "${FUNCNAME[0]} - Can't extract '$SRCARCH', because '$SEVZA' wasn't found!" "E"
				fi
			fi
		fi
	fi
}

# Get latest artifact download link from nightly.link
function getLatestNightlyLinkArtifactURL {
	NIGHTLYLINKURL="$1"
	NIGHTLYLINKURLPAT="$2"

	"$WGET" -q "${NIGHTLYLINKURL}" -O - 2> >(grep -v "SSL_INIT") | grep -oP "${NIGHTLYLINKURLPAT}" | head -n1  # Grep all links matching this pattern and pick the first one (should only be one anyway)
}

# Use innoextract to extract SpecialK32/64.dll from executable
function extractSpecialKEXE {
	POSSIBLESPEKEXE="$1"
	if  [ -x "$(command -v "$INNOEXTRACT")" ]; then
		SPEKEXESPEK32PATH="app/${SPEK}32.dll"
		SPEKEXESPEK64PATH="app/${SPEK}64.dll"

		SPEKEXEFILESLIST="$( "$INNOEXTRACT" "--list" "$POSSIBLESPEKEXE" )"

		if grep -q "$SPEKEXESPEK32PATH" <<< "$SPEKEXEFILESLIST" && grep -q "$SPEKEXESPEK64PATH" <<< "$SPEKEXEFILESLIST"; then
			notiShow "$( strFix "$NOTY_USESPEKCUSTOMEXE" "$( basename "$POSSIBLESPEKEXE" )" )"
			writelog "INFO" "${FUNCNAME[0]} - Found valid SpecialK executable to extract"
			# Extract EXE, select and move DLLs to SPEKVERS folder, remove all innoextract files
			"$INNOEXTRACT" -m -s -d "$SPEKDLDIR/$SPEKVERS" "$POSSIBLESPEKEXE"

			mv "$SPEKDLDIR/$SPEKVERS/$SPEKEXESPEK32PATH" "$SPEKDLDIR/$SPEKVERS"
			mv "$SPEKDLDIR/$SPEKVERS/$SPEKEXESPEK64PATH" "$SPEKDLDIR/$SPEKVERS"

			writelog "INFO" "${FUNCNAME[0]} - Successfully extracted '${SPEK}32.dll' and '${SPEK}64.dll' from '$( basename "$POSSIBLESPEKEXE" )'"
		else
			writelog "SKIP" "${FUNCNAME[0]} - SpecialK executable did not contain both '$SPEKEXESPEK32PATH' and '$SPEKEXESPEK64PATH' -- Not extracting"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Cannot extract custom SpecialK EXE because dependency '$INNOEXTRACT' is missing!"
	fi
}

function dlSpecialK {
	if [ -n "$1" ]; then
		SPEKVERS="$1"
	fi

	SPEKARC="${SPEK}.7z"

	mkProjDir "$SPEKDLDIR/$SPEKVERS"
	mkProjDir "$SPEKDLDIR/custom"  # Ensure custom is here, in case user downloads SpecialK and then wants to use custom -- Very minor QoL

	if [ "$SPEKVERS" == "stable" ]; then
		SPEKDLURL="$SPEKURL$SPEKARC"
		writelog "INFO" "${FUNCNAME[0]} - Using Stable SpecialK download URL '$SPEKDLURL'"
	elif [ "$SPEKVERS" == "nightly" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using SpecialK Nightly release, fetching from nightly.link"

		SPEKAPIURLPATH="${SPEKPROJURL//$GHURL}"
		SPEKNIGHTLYHASH="$( fetchLatestGitHubActionsBuild "${AGHURL}/repos${SPEKAPIURLPATH}" 1 "Builds" 0 | cut -d ';' -f2 )"  # Get commit hash for latest SpecialK artifact from only success workflows named "Builds"
		SPEKNIGHTLYURL="https://nightly.link${SPEKAPIURLPATH}/workflows/build-windows/main"

		writelog "INFO" "${FUNCNAME[0]} - SpecialK GitHub Actions hash is '$SPEKNIGHTLYHASH'"
		writelog "INFO" "${FUNCNAME[0]} - SpecialK nightly.link URL is '$SPEKNIGHTLYURL'"

		SPEKNIGHTLYURLPATTERN="${SPEKNIGHTLYURL}.*?${SPEKNIGHTLYHASH}[a-zA-Z0-9].zip(?=\")"  # Hash in archive name is 8 chars, but fetchLatestGitHubActionsBuild only returns 7, so accept one extra alphanumeric character when parsing name
		SPEKDLURL="$( getLatestNightlyLinkArtifactURL "$SPEKNIGHTLYURL" "$SPEKNIGHTLYURLPATTERN" )"
		SPEKARC="$( basename "$SPEKDLURL" )"  # Need to make sure the archive name uses the nightly archive name, which isn't fixed

		writelog "INFO" "${FUNCNAME[0]} - SpecialK DL URL is '$SPEKDLURL'"
		writelog "INFO" "${FUNCNAME[0]} - SpecialK Archive name from DL URL is '$SPEKARC'"
	elif [ "$SPEKVERS" == "custom" ]; then
		writelog "INFO" "${FUNCNAME[0]} - SpecialK version '$SPEKVERS' selected, not downloading anything"
	else
		SPEKDLURL="$SPEKGHURL/download/SK_${SPEKVERS//./_}/$SPEKARC"
	fi

	SPEKDL="$SPEKDLDIR/$SPEKVERS/$SPEKARC"

	SPEK32SRC="$SPEKDLDIR/$SPEKVERS/${SPEK}32.dll"
	SPEK64SRC="$SPEKDLDIR/$SPEKVERS/${SPEK}64.dll"

	SPEK32BASE="${SPEK}32.dll"
	SPEK64BASE="${SPEK}64.dll"

	## For custom SpecialK, we either use existing placed DLLs or attempt to extract them from a SpecialK EXE
	## If we have no custom exe and no SpecialK32/64 DLL pair, SpecialK will not be installed
	if [ "$SPEKVERS" == "custom" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Custom SpecialK version selected -- Looking for manually placed SpecialK DLLs or EXE to extract them from"
		POSSIBLECUSTOMSPEKEXE="$( find "$SPEKDLDIR/$SPEKVERS" -type f -name "*.exe" -print -quit )"
		POSSIBLECUSTOMSPEKEXE="$( realpath "$POSSIBLECUSTOMSPEKEXE" )"

		if [ -f "$SPEK32SRC" ] && [ -f "$SPEK64SRC" ]; then
			notiShow "$NOTY_USESPEKCUSTOMDLL"
			writelog "INFO" "${FUNCNAME[0]} - Found '${SPEK}32.dll' and '${SPEK}64.dll' -- Using this as SpecialK version"
		elif [ -f "$POSSIBLECUSTOMSPEKEXE" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found possible SpecialK EXE '$POSSIBLECUSTOMSPEKEXE' -- Attempting to extract SpecialK DLLs from this executable"
			extractSpecialKEXE "$POSSIBLECUSTOMSPEKEXE"
		fi
	else  # download SpecialK
		if [ ! -f "$SPEK32SRC" ] && [ ! -f "$SPEK64SRC" ]; then
			notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$SPEK")"
			dlCheck "$SPEKDLURL" "$SPEKDL" "X" "Downloading '$SPEKDLURL' to '$SPEKDLDIR'"
			extSpek "$SPEKDL"
		elif [ "$AUTOSPEK" -eq 1 ] && { [ "$SPEKVERS" == "stable" ] || [ "$SPEKVERS" == "nightly" ] ;}; then
			writelog "INFO" "${FUNCNAME[0]} - AUTOSPEK is enabled and SPEKVERS is '$SPEKVERS' - so looking for $SPEK updates" "E"
			notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$SPEK")"
			dlCheck "$SPEKDLURL" "$SPEKDL" "X" "Downloading '$SPEKDLURL' to '$SPEKDLDIR'"
			extSpek "$SPEKDL"
		else
			writelog "INFO" "${FUNCNAME[0]} - Already have the SpecialK DLLs, nothing to update" "E"
		fi
	fi

	writelog "INFO" "${FUNCNAME[0]} - Cleaning up SpecialK version folder '$SPEKDLDIR/$SPEKVERS'"
	# Clean up everything that isn't SPEK32SRC and SPEK64SRC
	for SPEKVERDIRFILE in "$SPEKDLDIR/$SPEKVERS"/*; do
		SPEKVERDIRFILEBASENAME="$( basename "$SPEKVERDIRFILE" )"
		SPEKVERDIRFILEREALPATH="$( realpath "$SPEKVERDIRFILE" )"  # Just in case
		if [ "$SPEKVERDIRFILEBASENAME" != "$SPEK32BASE" ] && [ "$SPEKVERDIRFILEBASENAME" != "$SPEK64BASE" ]; then
			rmFileIfExists "$SPEKVERDIRFILEREALPATH"
			rmDirIfExists "$SPEKVERDIRFILEREALPATH"
		fi
	done

	# Check to make sure DLLs are still satisfied
	if [ -f "$SPEK32SRC" ]; then
		writelog "INFO" "${FUNCNAME[0]} - '$SPEK32SRC' is ready" "E"
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$SPEK32SRC' is missing!" "E"
	fi

	if [ -f "$SPEK64SRC" ]; then
		writelog "INFO" "${FUNCNAME[0]} - '$SPEK64SRC' is ready" "E"
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$SPEK64SRC' is missing!" "E"
	fi
}

## Get rendering API from PCGamingWiki compatibility list
## This is missing some supported games (such as NieR:Replicant and Monster Hunter World) but is generally a good reference point
##
## For compatibility reasons we use d3d11.dll as the SpecialK DLL name for Direct3D 11 games, as this seems to be more compatible than dxgi.dll on Linux -- Mainly when it comes to using ReShade and SpecialK
## ReShade and SpecialK work better together for Direct3D 11 games if we use d3d11.dll as the name
##
## Behaviour is this:
## - If we find Direct3D 11 as the rendering API for our game, use d3d11.dll as the SpecialK DLL name
## - If we find an unknown rendering API for our game, use dxgi.dll as a fallback
## - If we cannot find our game in the list, assume D3D11 and fall back to d3d11.dll
##    - TODO this point is not ideal, we should add an API override at some point
function getSpecialKGameRenderApi {
	SPEKCOMP="$SPEKDLDIR/${SPEK}_compat.html"
	MAXAGE=1440
	if [ ! -f "$SPEKCOMP" ] || test "$(find "$SPEKCOMP" -mmin +"$MAXAGE")"; then
		dlCheck "$SPEKCOMPURL" "$SPEKCOMP" "X" "Downloading '$SPEKCOMP'"
	fi

	if [[ -n "$SPEKDLLNAME" ]] && [[ "$SPEKDLLNAME" != "$AUTO" ]]; then
		# Use custom SpecialK DLL name if we're not using 'auto' OR if the DLL name field is blank
		writelog "INFO" "${FUNCNAME[0]} - User selected SpecialK DLL override name '$SPEKDLLNAME' - Will attempt to use this as the SpecialK DLL name"
		FOUNDSPEKDLLNAME="$SPEKDLLNAME"
	else
		writelog "INFO" "${FUNCNAME[0]} - Searching Render Api for '$GN' in '$SPEKCOMP'"
		RAPI="$(sed -n "/id=\"Compatibility_list\"/,$ p" "$SPEKCOMP" | grep -A1 "${GN// /\*.\*}" | tail -n1 | cut -d '>' -f2 | cut -d '<' -f1)"
		if [ -n "$RAPI" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found Render Api '$RAPI'"
			if [ "$RAPI" == "Direct3D 12" ]; then
				FOUNDSPEKDLLNAME="$DXGI"
			elif [ "$RAPI" == "Direct3D 11" ]; then
				FOUNDSPEKDLLNAME="$D3D11"
			elif [ "$RAPI" == "Direct3D 9" ]; then
				FOUNDSPEKDLLNAME="$D3D9"
			elif [ "$RAPI" == "OpenGL" ]; then
				FOUNDSPEKDLLNAME="$OGL32"
			else
				writelog "INFO" "${FUNCNAME[0]} - Unknown Render Api '$RAPI' - assuming 'Direct3D 11'"
				FOUNDSPEKDLLNAME="$DXGI"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Could not find Render Api - assuming 'Direct3D 11'"
			FOUNDSPEKDLLNAME="$DXGI"
		fi
	fi

	SPEKDST="$SPEKDDIR/$FOUNDSPEKDLLNAME"
	writelog "INFO" "${FUNCNAME[0]} - SpecialK DLL install path is '$SPEKDST'"
}

## Example to get key UsingWine under section [Compatibility.General] in dxgi.ini and change it from False toTrue
## writeValueToIni "Compatibility.General" "UsingWINE" "false" "true" "dxgi.ini"
function writeValueToIni {
	INISECTION="$1"  # i.e Compatibility.General
	INIKEY="$2"  # i.e. UsingWINE
	INIFROMVAL="$3"  # value to change from, i.e. false
	INITOVAL="$4"  # value to change to i.e. true
	INIFILE="$5"  # i.e. dxgi.ini

	ININEWSTR="${INIKEY}=${INITOVAL}"

	if [ -f "$INIFILE" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Found the ini file '$INIFILE' - setting '$ININEWSTR' under '$INISECTION'" "E"
		if grep -q "$INIKEY=$INIFROMVAL" "$INIFILE"; then
			writelog "INFO" "${FUNCNAME[0]} - Setting '$INIKEY' in the config to '$INITOVAL'" "E"
			sed "s:$INIKEY=$INIFROMVAL:$ININEWSTR:" -i "$INIFILE"
		else
			writelog "INFO" "${FUNCNAME[0]} - Adding a new entry '$INIKEY' in the ini, because it is missing" "E"
			if grep -q "$INISECTION" "$INIFILE"; then
				# Just key=val is missing
				sed "/\[$INISECTION\]/a $ININEWSTR" -i "$INIFILE"
			else
				# Heading and key=val missing
				writelog "INFO" "${FUNCNAME[0]} - Creating new section '$INISECTION' with '$ININEWSTR' in '$INIFILE'"

				{
					echo "[$INISECTION]"
					echo "$ININEWSTR"
					echo ""
				} >> "$SPEKINI"
			fi
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - Could not find INI file at '$INIFILE'"
	fi
}

function prepareSpecialKIni {
	SPEKDLLNAMEFORINI="$( basename "$SPEKDST" )"
	SPEKINI="${SPEKDLLNAMEFORINI//.dll/.ini}"  # Name INI after chosen SpecialK DLL name

	COGE="Compatibility.General"
	UWI="UsingWINE"

	ROSD="Render.OSD"
	SIVC="ShowInVideoCapture"

	if [ -n "$SPEKINI" ]; then
		if [ ! -f "$SPEKINI" ]; then
			writelog "INFO" "${FUNCNAME[0]} - SpecialK INI '$SPEKINI' does not exist, creating initial blank INI"
			touch "$SPEKINI"
		fi

		writeValueToIni "$COGE" "$UWI" "false" "true" "$SPEKINI"  # SpecialK may already detect and set this appropriately now
		writeValueToIni "$ROSD" "$SIVC" "true" "false" "$SPEKINI"  # Seems to be needed to prevent crashing sometimes
	fi
}

function useSpecialK {
	function installSpekDll {
		SPEKSRC="$1"
		SPEKDLLCONFLICTFOUND=0
		SHOULDINSTALLSPEK=1
		SPEKD3D47DLL="$4"
		SPEKD3D47DLLPATH="${SPEKDDIR}/${D3D47}"  # this will always be named /path/to/d3dcompiler_47, because we name the DLL differently on move, we don't need to keep the architecture in the DLL name
		SPEKDLLEXPORTNAME="$( basename "$SPEKDST" )"  # Make sure we use an actual name and not 'auto'

		if [ "$USERESHADE" -eq 1 ] && [ -f "$SPEKDDIR/$RSTXT" ] && [ "$USERESHSPEKPLUGIN" -eq 0 ]; then
			## ReShade is already installed and in use, and ReShade+SpecialK have selected DLL names conflict

			## Check each entered ReShade DLL name and see if any conflict with the entered SpecialK DLL name
			writelog "INFO" "${FUNCNAME[0]} - ReShade is installed and not loaded as SpecialK plugin -- Checking for DLL naming conflicts"
			mapfile -d "," -t -O "${#SPEKRSDLLNAMECHECKARR[@]}" SPEKRSDLLNAMECHECKARR < <(printf '%s' "$RESHADEDLLNAME")

			SPEKREALDLLNAME="$( basename "$SPEKDST" )"  # Makes sure we don't compare against 'auto'
			for SPEKRSCHECKDLL in "${SPEKRSDLLNAMECHECKARR[@]}"; do
				if [[ "$SPEKRSCHECKDLL" == "$SPEKREALDLLNAME" ]] && [ -f "$SPEKRSCHECKDLL" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - ReShade is enabled and the chosen SpecialK DLL name conflicts with the ReShade DLL name -- Not installing SpecialK"
					notiShow "$( strFix "$NOTY_SPEKRESHDLLCONFLICT" "$RESH" "$SPEK" )"
					SPEKDLLCONFLICTFOUND=1
					break
				fi
			done

			if [ -f "$SPEKDST" ] && [ -f "$SPEKENA" ] && grep -qw "$SPEKDST" "$SPEKENA"; then
				if [ "$AUTOSPEK" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - Updating existing tracked SpecialK DLLs"
					removeSpekDlls  # Remove existing SpecialK DLLs so we can update them, if auto-update SpecialK is enabled
				else
					writelog "INFO" "${FUNCNAME[0]} - SpecialK is installed, tracked, and up-to-date -- Nothing to do"
					SHOULDINSTALLSPEK=0
				fi
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - SpecialK loading normally"
			# Check to see if SpecialK DLL already exists and is not tracked by us
			# There's probably scope to make installRSdll generic so it applies for both ReShade+SpecialK
			if [ ! -f "$SPEKDST" ]; then
				writelog "INFO" "${FUNCNAME[0]} - No SpecialK DLL installation found, installing as normal"
			elif [ -f "$SPEKDST" ] && ! grep -qw "$SPEKDST" "$SPEKENA"; then
				writelog "WARN" "${FUNCNAME[0]} - The chosen SpecialK DLL name already exists at '$SPEKDST' but is not tracked by us -- This may cause issues!"
				writelog "WARN" "${FUNCNAME[0]} - Attempting to back up existing found DLL with name '$SPEKDST' so that we can install SpecialK"

				SPEKDLLBAKNAM="$SPEKDST.bak"
				if [ -f "$SPEKDLLBAKNAM" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - Backup DLL name already exists at '$SPEKDST/$SPEKDLLBAKNAM', cannot move this DLL to allow SpecialK to install -- Not installing SpecialK"
					notiShow "$NOTY_SPEKDLLCONFLICT" "X"
					SPEKDLLCONFLICTFOUND=1
				else
					writelog "INFO" "${FUNCNAME[0]} - Moving existing DLL '$SPEKDST' to '$SPEKDLLBAKNAM' so we can install SpecialK without conflicts"
					mv "$SPEKDST" "$SPEKDLLBAKNAM"
				fi
			elif [ -f "$SPEKDST" ] && [ -f "$SPEKENA" ] && grep -qw "$SPEKDST" "$SPEKENA"; then
				if [ "$AUTOSPEK" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - Updating existing tracked SpecialK DLLs"
					removeSpekDlls  # Remove existing SpecialK DLLs so we can update them, if auto-update SpecialK is enabled
				else
					writelog "INFO" "${FUNCNAME[0]} - SpecialK is installed, tracked, and up-to-date -- Nothing to do"
					SHOULDINSTALLSPEK=0
				fi
			fi
		fi

		# Make sure we don't track DLL renames
		rmFileIfExists "$SPEKENA"
		touch "$SPEKENA"

		if [ "$SPEKDLLCONFLICTFOUND" -eq 0 ] && [ "$SHOULDINSTALLSPEK" -eq 1 ]; then
			installd3d47dll "$SPEKD3D47DLL" "$SPEKDDIR"

			writelog "INFO" "${FUNCNAME[0]} - Installing '${SPEKSRC##*/}' as '$GP' is $2-bit" "E"
			notiShow "$NOTY_SPECIALKINSTALLING"
			cp "$SPEKSRC" "$SPEKDST"
			echo "$SPEKDST" >> "$SPEKENA"
			if [ -f "${SPEKSRC//dll/pdb}" ]; then
				SPEKPDB="${SPEKSRC##*/}"
				SPEKPDB="${SPEKPDB//dll/pdb}"
				writelog "INFO" "${FUNCNAME[0]} - Also installing debugging '$SPEKPDB'" "E"
				cp "${SPEKSRC//dll/pdb}" "$SPEKDDIR"
				echo "$SPEKDDIR/$SPEKPDB" >> "$SPEKENA"
			fi
			prepareSpecialKIni  # Moved here so this is created only once we confirm SpecialK can be installed
		elif [ "$SPEKDLLCONFLICTFOUND" -eq 0 ] && [ "$SHOULDINSTALLSPEK" -eq 0 ]; then
			# In this scenario, SpecialK is already installed so we don't need to install it, so write out the DLL name to the SPEKENA file to ensure we don't end up with a blank file
			# We can't always write out to the file unconditionally as SPEKDLLCONFLICTFOUND means SpecialK wasn't installed
			echo "$SPEKDST" >> "$SPEKENA"  # SpecialK DLL
			echo "$SPEKD3D47DLLPATH" >> "$SPEKENA"  # d3d47 DLL

			installd3d47dll "$SPEKD3D47DLL" "$SPEKDDIR"

			prepareSpecialKIni  # Needed here to update some values that may only exist after first launch
		elif [ "$SPEKDLLCONFLICTFOUND" -eq 1 ]; then
			writelog "ERROR" "${FUNCNAME[0]} - Could not install SpecialK -- DLL naming conflict was found"
		fi

		if [ "$SPEKDLLCONFLICTFOUND" -eq 0 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Setting WINEDLLOVERRIDES for ${SPEK}: dxgi=n,b;d3d9=n,b;${D3D47//.dll}=n,b;d3d11=n,b;opengl32=n,b;${SPEKDLLEXPORTNAME//.dll}=n,b"
			export WINEDLLOVERRIDES="$WINEDLLOVERRIDES;dxgi=n,b;d3d9=n,b;${D3D47//.dll}=n,b;d3d11=n,b;opengl32=n,b;${SPEKDLLEXPORTNAME//.dll}=n,b"
		fi
	}

	# Manage installing 32bit/64bit SpecialK DLL
	function installSpekArchDll {
		if [ "$USECUSTOMCMD" -eq 1 ] && [ -f "$CUSTOMCMD" ]; then
			ARCHEXE="$CUSTOMCMD"
		else
			ARCHEXE="$GP"
		fi

		if [ "$(getArch "$ARCHEXE")" == "32" ]; then
			installSpekDll "$SPEK32SRC" "32" "x86" "$D3D47_32"
		elif [ "$(getArch "$ARCHEXE")" == "64" ]; then
			installSpekDll "$SPEK64SRC" "64" "x64" "$D3D47_64"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Could not determine the architecture of '$GP' - not installing '$SPEK'" "E"
		fi
	}

	SPEKDDIR="$EFD"
	setFullGameExePath "SPEKDDIR"
	SPEKENA="$SPEKDDIR/${SPEK}_enabled.txt"

	# Ensure SpecialK DLL name ends with '.dll', even if we're not using SpecialK
	if [ -n "$SPEKDLLNAME" ] && ! [[ $SPEKDLLNAME == *.* ]]; then
		# Don't rename DLL if we're using "auto"
		if [[ ! "$SPEKDLLNAME" == "${AUTO}" ]]; then
			writelog "INFO" "${FUNCNAME[0]} - Renaming SPEKDLLNAME to '${SPEKDLLNAME}.dll'"
			SPEKDLLNAME="${SPEKDLLNAME}.dll"
		elif [[ "$SPEKDLLNAME" == "${AUTO}.dll" ]]; then
			SPEKDLLNAME="$AUTO"
		fi

		touch "$FUPDATE"
		updateConfigEntry "SPEKDLLNAME" "$SPEKDLLNAME" "$STLGAMECFG"
	fi

	if [ "$USESPECIALK" -eq 1 ]; then
		if [ "$AUTOSPEK" -eq 1 ] && { [ "$SPEKVERS" == "stable" ] || [ "$SPEKVERS" == "nightly" ];}; then
			writelog "INFO" "${FUNCNAME[0]} - Updating $SPEK in the gamedir because AUTOSPEK is enabled"
		fi

		writelog "INFO" "${FUNCNAME[0]} - ${SPEK} is enabled - Installing dlls if required"
		dlSpecialK

		getSpecialKGameRenderApi

		writelog "INFO" "${FUNCNAME[0]} - Using '$SPEKDST' as $SPEK destination dll"

		installSpekArchDll
	else
		if [ -f "$SPEKENA" ]; then
			writelog "INFO" "${FUNCNAME[0]} - ${SPEK} was enabled before, removing existing $SPEK dlls"
			removeSpekDlls
			if [ "$USERESHADE" -eq 1 ]; then
				removeReShadeSpecialKInstallation "1"
			fi
		fi
	fi
}

function removeSpekDlls {
	while read -r spekdll; do
		rm "$spekdll" 2>/dev/null
	done < "$SPEKENA"
	rm "$SPEKENA" 2>/dev/null
}

