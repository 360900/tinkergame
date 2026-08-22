#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function dld3d47 {
	function dld3d4732 {
		dlCheck "$DL_D3D47_32" "$D3D47DLDIR/${D3D47//.dll/.zip}" "X" "Downloading '$D3D47_32' into '$D3D47DLDIR'"
		find "$DLDST" -size 0 -delete
		"$UNZIP" "$DLDST" -d "$D3D47DLDIR" 2>/dev/null
		mv "$D3D47DLDIR/$D3D47" "$D3D47DLDIR/$D3D47_32" 2>/dev/null
	}

	function dld3d4764 {
		if [ ! -f "$D3D47DLDIR/$D3D47_64" ]; then
			dlCheck "$DL_D3D47_64" "$D3D47DLDIR/$D3D47_64" "X" "Downloading '$D3D47_64' into '$D3D47DLDIR'"
			find "$D3D47DLDIR/$D3D47_64" -size 0 -delete
		fi
	}
	mkProjDir "$D3D47DLDIR"
	dld3d47"$1"
}

function installd3d47dll {
	D3D47DESTPATH="$2/$D3D47"

	if [ "$USESPEKD3D47" -eq 0 ] && [ "$USESPECIALK" -eq 1 ]; then  # We need to check if SpecialK is enabled so we don't end up removing this if it's installed for ReShade
		# User has disabled d3dcompiler_47 for use with SpecialK -- Check if it's installed and tracked by us, and if so, remove it!
		writelog "INFO" "${FUNCNAME[0]} - USESPEKD3D47 is '$USESPEKD3D47'"
		writelog "INFO" "${FUNCNAME[0]} - D3D47DESTPATH is '$D3D47DESTPATH'"
		if [ -f "$SPEKENA" ]; then
			# DLL exists in game files and SpecialK tracked file is present
			if grep -qw "$D3D47DESTPATH" "$SPEKENA"; then
				# DLL exists and is present in SpecialK tracking file, assume this is ours and remove it!
				writelog "INFO" "${FUNCNAME[0]} - Found tracked '$D3D47' DLL at '$D3D47DESTPATH' -- Assuming this is ours and removing it!"
				rm "$D3D47DESTPATH"  # Remove DLL file
				sed -i "s#${D3D47DESTPATH}##g" "$SPEKENA"  # Remove tracked D3D47 DLL (apparently sed doesn't like using delete with paths, so we use substituion)
			fi
		fi
	elif [ ! -f "$D3D47DESTPATH" ]; then
		if [ ! -f "$D3D47DLDIR/$1" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Sourcefile '$D3D47DLDIR/$1' missing - trying to download"
			dld3d47 "32"
			dld3d47 "64"
		fi

		if [ ! -f "$D3D47DLDIR/$1" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Sourcefile '$D3D47DLDIR/$1' still missing - skipping this file"
		else
			# We should only copy the DLL and write to the DLL tracking file if the DLL is not already in the destination folder
			cp "$D3D47DLDIR/$1" "$D3D47DESTPATH" >/dev/null 2>/dev/null
			writelog "INFO" "${FUNCNAME[0]} - Copied '$D3D47DLDIR/$1' to '$2/$D3D47'"
			if [ "$USESPECIALK" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Writing '$D3D47DESTPATH' to '$SPEKENA'"
				echo "$D3D47DESTPATH" >> "$SPEKENA"
			elif [ "$USERESHADE" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Writing '$D3D47' to '$2/$RSTXT'"
				echo "$D3D47" >> "$2/$RSTXT"
				sort "$2/$RSTXT" -u -o "$2/$RSTXT"
			else
				writelog "WARN" "${FUNCNAME[0]} - Function was called but neither ReShade nor SpecialK was specified -- No need to write out to a file that we're tracking this DLL"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Destfile '$D3D47DESTPATH' already exists - skipping"
	fi
}

function autoBumpReShade {
	RSVERSLATEST="$( fetchGitHubTags "$RESHADEPROJURL" "1" )"
	RSVERSLATEST="${RSVERSLATEST//v/}"
	if [ "$AUTOBUMPRESHADE" -eq 1 ] && [[ "$RSVERS" < "$RSVERSLATEST" ]]; then
		writelog "INFO" "${FUNCNAME[0]} - Found newer version of '$RESH' - Updating '$RSVERS' to '$RSVERSLATEST"
		touch "$FUPDATE"
		updateConfigEntry "RSVERS" "$RSVERSLATEST" "$STLDEFGLOBALCFG"
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$RSVERS' is the latest version of '$RESH' - not updating"
	fi
}

function createDLReShadeList {
	if ! ping -q -c1 github.com &>/dev/null; then
		writelog "INFO" "${FUNCNAME[0]} - Can't reach GitHub, so not attempting to fetch ReShade versions list"
 		RESHADEVERSIONS="none"
	else
		RSVERSONLINE="$( fetchGitHubTags "$RESHADEPROJURL" "3" )"
		RSVERSONLINE="${RSVERSONLINE//$'\n'/!}"
		RSVERSONLINE="${RSVERSONLINE//$!/}"
		RSVERSONLINE="${RSVERSONLINE//v/}"
		writelog "INFO" "${FUNCNAME[0]} - Found the following '$RESH' versions online '$RSVERSONLINE'"
		RESHADEVERSIONS="$RSOVRVERS!$RSVERSONLINE!4.91!3.4.1"
	fi
}

function dlReShade {
	if [ -z "$1" ]; then
		DLVERS="$RSVERS"
	else
		DLVERS="$1"
	fi

	DLDST="${RESHADESRCDIR}/${RSSU}_${DLVERS}.exe"
	RSSETUP="${RESHADEDLURL}/${RSSU}_${DLVERS}.exe"

	dlCheck "$RSSETUP" "$DLDST" "X" "Downloading $RSSU"
	echo "$DLVERS" > "${DLDST//.exe/.log}"

	if [ ! -s "$DLDST" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Downloaded file '$DLDST' is empty - removing"
		rm "$DLDST" 2>/dev/null
	else
		"$UNZIP" -qo "$DLDST" -d "$RESHADESRCDIR/${DLVERS}" 2>/dev/null
		writelog "INFO" "${FUNCNAME[0]} - Downloaded and extracted ${RESH}-v${DLVERS} file '$DLDST'"
	fi
}

function overrideReShadeVersion {
	## ReShade version priority is as follows:
	## 1. Game Menu Override version ('RSOVRVERS') -- Only applies if 'RSOVRD' checkbox is toggled on
	## 2. SpecialK ReShade Override version ('RSSPEKVERS') -- Only applies if ReShade+SpecialK are used together, and if '$USERSSPEKVERS' checkbox is toggled on
	## 3. Global Menu ReShade version ('RSVERS')

	if [ "$RSOVRD" -eq 1 ]; then  # Game Menu ReShade Override version -- Takes priority over Global ReShade version AND SpecialK ReShade version
		if [[ ! "$RSOVRVERS" = "$RSVERS" ]]; then
			writelog "INFO" "${FUNCNAME[0]} - Overriding global '$RESH' version '$RSVERS' with '$RSOVRVERS'"
       		RSVERS="$RSOVRVERS"
   		else
       		writelog "SKIP" "${FUNCNAME[0]} - '$RESH' Override version and '$RESH' global version match - Not overriding"
   		fi
	elif [ "$USESPECIALK" -eq 1 ] && [ "$USERESHADE" -eq 1 ] && [ "$USERSSPEKVERS" -eq 1 ] && [ "$USERESHSPEKPLUGIN" -eq 1 ]; then  # Global Menu ReShade version to load when ReShade is loaded via SpecialK
		writelog "INFO" "${FUNCNAME[0]} - Overriding global '$RESH' version '$RSVERS' with SpecialK ReShade version override '$RSSPEKVERS' as it is enabled and ReShade+SpecialK are enabled together"
		RSVERS="$RSSPEKVERS"
	else
    	writelog "SKIP" "${FUNCNAME[0]} - '$RESH' override is disabled - Skipping"
	fi
}

# prepare reshade files if not found:
function prepareReshadeFiles {
	overrideReShadeVersion
	if [ "$DOWNLOAD_RESHADE" -eq 1 ]; then
	writelog "INFO" "${FUNCNAME[0]} - DOWNLOAD_RESHADE enabled"
		if [ ! -f "$D3D47DLDIR/$D3D47_32" ]; then dd
			writelog "404" "${FUNCNAME[0]} - '$D3D47DLDIR/$D3D47_32' missing - downloading"

			if [ ! -d "$RESHADESRCDIR" ]; then
				writelog "404" "${FUNCNAME[0]} - '$RESHADESRCDIR' does not exist - trying to create it"
				mkProjDir "$RESHADESRCDIR"
			fi
		fi
		dld3d47 "32"
		dld3d47 "64"

		#Check if ReShade file are missing
		if [ ! -f "$RESHADESRCDIR/$RSVERS/$RS_64" ] || [ ! -f "$RESHADESRCDIR/$RSVERS/$RS_32" ]; then
			writelog "404" "${FUNCNAME[0]} - '$RESHADESRCDIR/$RSVERS/$RS_64' and/or '$RS_32' missing - downloading"
			dlReShade
		fi

		if [ ! -f "$RESHADESRCDIR/$RSVERS/$RS_64_VK" ] || [ ! -f "$RESHADESRCDIR/$RSVERS/$RS_32_VK" ]; then
			writelog "404" "${FUNCNAME[0]} - '$RESHADESRCDIR/$RSVERS/$RS_64_VK' and/or '$RS_32_VK' missing - downloading"
			dlReShade
		fi

		#Check if ReShade file is zero bytes
		if [ ! -s "$RESHADESRCDIR/$RSVERS/$RS_64" ] || [ ! -s "$RESHADESRCDIR/$RSVERS/$RS_32" ]; then
			writelog "404" "${FUNCNAME[0]} - '$RESHADESRCDIR/$RSVERS/$RS_64' and/or '$RS_32' corrupted - downloading"
			dlReShade
		fi
		if [ ! -s "$RESHADESRCDIR/$RSVERS/$RS_64_VK" ] || [ ! -s "$RESHADESRCDIR/$RSVERS/$RS_32_VK" ]; then
			writelog "404" "${FUNCNAME[0]} - '$RESHADESRCDIR/$RSVERS/$RS_64_VK' and/or '$RS_32_VK' corrupted - downloading"
			dlReShade
		fi

		if [ "$RESHADEUPDATE" -eq 1 ]; then
			if [ -f "${RESHADESRCDIR}/${RSSU}.log" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found ${RESH} download log '${RESHADESRCDIR}/${RSSU}.log'"
				if [ "$RSVERS" != "$(cat "${RESHADESRCDIR}/${RSSU}.log")" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Last downloaded is ${RESH} version '$(cat "${RESHADESRCDIR}/${RSSU}.log")' is not equal to the latest available ${RESH} version '$RSVERS' - updating"
					dlReShade
				fi
			fi
		fi
	fi

	# make sure Depth3D is even wanted
	if [ "$RESHADE_DEPTH3D" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - RESHADE_DEPTH3D enabled"
		StatusWindow "$GUI_DLSHADER" "dlShaders depth3d" "DownloadShadersStatus"
	fi
}

function SHADSRC {
	echo "$STLSHADDIR/${1,,}"
}

function createShaderRepoList {
	SHADREPOURL="https://www.pcgamingwiki.com/w/api.php?action=parse&page=${RESH}&format=json&prop=text"
	MAXAGE=1440

	if [ ! -f "$SHADREPOLIST" ] || test "$(find "$SHADREPOLIST" -mmin +"$MAXAGE")"; then
		# Use MediaWiki API to fetch shader repository list
		if [ -x "$(command -v "$JQ")" ]; then
			"$WGET" -q "$SHADREPOURL" -O - 2> >(grep -v "SSL_INIT") | "$JQ" -r '.parse.text."*"' 2>/dev/null | sed -n '/Repository</,/table>/p' | grep "^<td>" | awk 'ORS=NR%3?FS:RS' | sed "s:<td><a rel=\"nofollow\" class=\"external text\" href=::; s:</a></td> <td>:;:; s:</td> <td>:;:; s:\">:\";:; s:<br />: :; s: ;:;:; s:/tree/master::; s:/reshade/Shaders::" > "$SHADREPOLIST"
		else
			writelog "WARN" "${FUNCNAME[0]} - jq is not available for JSON parsing - Shader repository list cannot be fetched from API"
		fi

		# If the fetch failed and the repo list is empty, ensure at least the custom list will be available
		if [ ! -s "$SHADREPOLIST" ]; then
			touch "$SHADREPOLIST"
			writelog "WARN" "${FUNCNAME[0]} - Failed to fetch shader repository list from API - Will use custom list only"
		fi
	fi

	RCL="repocustomlist.txt"
	SHADREPOCUSTOMLIST="$STLSHADDIR/$RCL"

	if [ ! -f "$SHADREPOCUSTOMLIST" ]; then
		cp "$GLOBALMISCDIR/$RCL" "$SHADREPOCUSTOMLIST"
	fi

	if [ -f "$SHADREPOCUSTOMLIST" ]; then
		cat "$SHADREPOCUSTOMLIST" >> "$SHADREPOLIST"
		sort -u "$SHADREPOLIST" -o "$SHADREPOLIST"
	fi

	sed '/^$/d' -i "$SHADREPOLIST"
	sed '/^#/d' -i "$SHADREPOLIST"
}

function unblockrssub {
	if grep -q "^${RSSUB}$" "$SHADERREPOBLOCKLIST"; then
		writelog "INFO" "${FUNCNAME[0]} - Removing essential '${RSSUB}' from the shader blocklist '$SHADERREPOBLOCKLIST'"
		grep -v "^${RSSUB}$" "$SHADERREPOBLOCKLIST" > "$STLSHM/SHADERREPOBLOCKLIST_tmp.txt"
		mv "$STLSHM/SHADERREPOBLOCKLIST_tmp.txt" "$SHADERREPOBLOCKLIST"
	fi
}

function dlShaders {
	createShaderRepoList
	touch "$SHADERREPOBLOCKLIST"
	unblockrssub

	if [ -z "$1" ]; then
		if [ "$DLSHADER" -eq 1 ]; then
			while read -r SHADLINE; do
				SHADURL="$(cut -d ';' -f1 <<< "$SHADLINE")"
				SHADNAM="$(cut -d ';' -f2 <<< "$SHADLINE")"
				if ! grep -qi "^${SHADNAM}$" "$SHADERREPOBLOCKLIST"; then
					writelog "INFO" "${FUNCNAME[0]} - Updating $SHADNAM"
					notiShow "$(strFix "$NOTY_DLSHADERS" "$SHADNAM")" "S"
					gitUpdate "$(SHADSRC "$SHADNAM")" "${SHADURL//\"/}"
				else
					writelog "SKIP" "${FUNCNAME[0]} - Skipping $SHADNAM"
				fi
			done < "$SHADREPOLIST"
			notiShow "$GUI_DONE" "S"
		fi
	else
		if [ "$1" == "list" ]; then
			while read -r SHADLINE; do
				SHADNAM="$(cut -d ';' -f2 <<< "$SHADLINE")"
				echo "\"${SHADNAM,,}\""
			done < "$SHADREPOLIST" | sort
		elif [ "$1" == "repos" ]; then
			ShaderRepoDialog
		else
			SHADURL="$(grep -i ";$1;" "$SHADREPOLIST" | cut -d ';' -f1)"
			if [ -n "$SHADURL" ]; then
				gitUpdate "$(SHADSRC "$1")" "${SHADURL//\"/}"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Invalid shader $1"
			fi
		fi
	fi
}

function ShaderRepoDialog {
	createShaderRepoList
	unblockrssub
	fixShowGnAid
	export CURWIKI="$PPW/Shader-Repositories"
	TITLE="${PROGNAME}-${FUNCNAME[0]}"
	pollWinRes "$TITLE"

	setShowPic

	REPOPICKS="$(
	while read -r SHADLINE; do
		SHADURL="$(cut -d ';' -f1 <<< "$SHADLINE")"
		SHADNAM="$(cut -d ';' -f2 <<< "$SHADLINE")"
		SHADAUT="$(cut -d ';' -f3 <<< "$SHADLINE")"
		SHADDES="$(cut -d ';' -f4 <<< "$SHADLINE")"

		if grep -qi "^${SHADNAM}$" "$SHADERREPOBLOCKLIST"; then
			echo FALSE
		else
			echo TRUE
		fi

		echo "$SHADURL"
		echo "$SHADNAM"
		echo "$SHADAUT"
		echo "$SHADDES"
	done < "$SHADREPOLIST" | \
	"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist --column="$GUI_USE" --column="$GUI_URL" --column="$GUI_NAME" --column="$GUI_AUTH" --column="$GUI_DESC" --separator="" --print-column="3" \
	--text="$(spanFont "$(strFix "$GUI_SHADREPDIALOG" "$SGNAID")" "H")" --title="$TITLE" --button="$BUT_CAN:0" --button="$BUT_SELECT:2" "$GEOM")"
	case $? in
		0)	{
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN' - Cancelling selection"
			}
		;;
		2)	{
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_SELECT' - Saving Selection"

				if [ -z "$REPOPICKS" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Nothing selected"
					REPOPICKS=""
				else
					rm "$SHADERREPOBLOCKLIST" 2>/dev/null
					while read -r SHADLINE; do
						SHADNAM="$(cut -d ';' -f2 <<< "$SHADLINE")"
						if ! grep -q "$SHADNAM" <<< "$REPOPICKS"; then
							echo "${SHADNAM,,}" >> "$SHADERREPOBLOCKLIST"
						fi
					done < "$SHADREPOLIST"
					touch "$SHADERREPOBLOCKLIST"
					sort -u "$SHADERREPOBLOCKLIST" -o "$SHADERREPOBLOCKLIST"
					unblockrssub
				fi
			}
		;;
	esac
}

function setFullGameExePath {
	if [[ ( "$USECUSTOMCMD" -eq 1 && -f "$CUSTOMCMD" && "$CUSTOMCMDRESHADE" -eq 1 ) || "$ONLY_CUSTOMCMD" -eq 1 ]]; then
		# Use Alternative EXE Path if defined instead of custom command path
		# We should only use the custom command directory if no alternatiive EXE path is defined, and
		# we should prioritise the alt path if it is defined
		DEFINEDALTEXEPATH="$(GETALTEXEPATH)"
		FGEP="${DEFINEDALTEXEPATH:-${CUSTOMCMD%/*}}"
		writelog "INFO" "${FUNCNAME[0]} - Using the directory '$FGEP' of the used custom command as absolute game exe path"

		if [ "$CUSTOMCMDRESHADE" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - User enabled 'CUSTOMCMDRESHADE' - Using custom command directory with exe as ReShade installation directory"
		fi

		export "$1"="$FGEP"
	else
		if [ "$USECUSTOMCMD" -eq 1 ] && [ ! -f "$CUSTOMCMD" ]; then
			writelog "WARN" "${FUNCNAME[0]} - User enabled Custom Command, but custom command at '$CUSTOMCMD' is not a file!"
		fi

		if [ "$CUSTOMCMDRESHADE" -eq 0 ]; then
			writelog "INFO" "${FUNCNAME[0]} - User did not enable 'CUSTOMCMDRESHADE' - Using the game's exe directory as the ReShade installation directory"
		fi
		setShaderDest
		if [ -n "$SHADDESTDIR" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using SHADDESTDIR '$SHADDESTDIR' for '$1'"
			export "$1"="$SHADDESTDIR"
		elif [ -n "$EFD" ]; then
			loadCfg "$GEMETA/$AID.conf" X
			if [ -z "$EXECUTABLE" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Using the base game directory '$EFD' as absolute game exe path - probably never reached?"
				export "$1"="$EFD"
			else
				if [ "$ISORIGIN" -eq 1 ] && grep -q "$L2EA" <<< "$EXECUTABLE" ; then
					MYMETA="$EVMETAID/${EVALSC}_${AID}.vdf"
					if [ -f "$MYMETA" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Origin game detected - looking for the real executable name instead of the used command '$EXECUTABLE'"
						touch "$FUPDATE"
						updateConfigEntry "ORIGINEXE" "$EXECUTABLE" "$GEMETA/${AID}.conf" # unused, but who knows what it is good for later
						# shellcheck disable=SC1003
						EXECUTABLE="$(grep "Uninstall" "$MYMETA" -A10 | grep "DisplayIcon" | awk -F '\\' '{print $NF}')"
						EXECUTABLE="${EXECUTABLE//\"}"
						touch "$FUPDATE"
						updateConfigEntry "EXECUTABLE" "$EXECUTABLE" "$GEMETA/${AID}.conf"
						GAMEEXE="${EXECUTABLE//.exe}"
						touch "$FUPDATE"
						updateConfigEntry "GAMEEXE" "$GAMEEXE" "$GEMETA/${AID}.conf"
					else
						writelog "WARN" "${FUNCNAME[0]} - Origin game detected - but $EVALSC file $MYMETA not found - can't look for original game name"
					fi
				else
					writelog "WARN" "${FUNCNAME[0]} - Using some weird old function to determine the absolute exe path - please report, this should never be reached"
				fi

				if grep -q "\\\\" <<< "$EXECUTABLE"; then
					RELEX="${EXECUTABLE//\\//}"
					FGEP="${EFD}/${RELEX%/*}"
					if [ ! -d "$FGEP" ] && [ -d "$EFD" ]; then
						if grep -q "/" <<< "${RELEX%/*}"; then
							FGEP="${EFD}"
							while read -r subdir; do
								FGEP="$(find "$FGEP" -iname "$subdir")"
							done <<< "$(tr '/' '\n' <<< "${RELEX%/*}")"
						else
							FGEP="$(find "${EFD}" -iname "${RELEX%/*}")"
						fi
					fi

					if [ -d "$FGEP" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Using '$FGEP' as absolute game exe path"
						export "$1"="$FGEP"
					fi
				fi
			fi
		fi
	fi
}

function setShaderDest {
	if [ -z "$SHADLOGGED" ]; then
		SHADLOGGED=0
	fi

	if [ -n "$(GETALTEXEPATH)" ]; then
		SHADDESTDIR="$(GETALTEXEPATH)"
		writelog "INFO" "${FUNCNAME[0]} - Overriding SHADDESTDIR to '$SHADDESTDIR' because ALTEXEPATH is set to '$ALTEXEPATH'"
	fi

	if [ -z "$SHADDESTDIR" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Determining Shader destination directory SHADDESTDIR"
		if [ -z "$1" ] || [ "$1" == "last" ]; then
			if [ "$ABSGAMEEXEPATH" != "$NON" ]; then
				SHADDESTDIR="${ABSGAMEEXEPATH%/*}"
				writelog "INFO" "${FUNCNAME[0]} - Using variable ABSGAMEEXEPATH for Shader destination directory '$SHADDESTDIR'"
			else
				resetAID "last"
				if [ -f "$LASTRUN" ] && grep -q "$AID" "$LASTRUN"; then
					ABSGAMEEXEPATH="$(grep "^PREVABSGAMEEXEPATH" "$LASTRUN" | cut -d '=' -f2)"
					ABSGAMEEXEPATHDIR="${ABSGAMEEXEPATH%/*}"
					if [ -d "${ABSGAMEEXEPATHDIR//\"/}" ]; then
						SHADDESTDIR="${ABSGAMEEXEPATHDIR//\"/}"
						writelog "INFO" "${FUNCNAME[0]} - Using last PREVABSGAMEEXEPATH variable from '$LASTRUN' for Shader destination directory '$SHADDESTDIR'"
					else
						writelog "WARN" "${FUNCNAME[0]} - Found PREVABSGAMEEXEPATH variable in '$LASTRUN' but its directory does not exist"
					fi
				else
					notiShow "$NOTY_NOAIDNOPREV"
				fi
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Using argument '$1' for Shader destination directory '$SHADDESTDIR'"
			if [ -f "$1" ]; then
				SHADDESTDIR="$(dirname "$1")"
			else
				SHADDESTDIR="$1"
			fi
		fi

		if [ -n "$SHADDESTDIR" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using Shader destination directory '$SHADDESTDIR'"
		fi
	fi

	if [ -n "$SHADDESTDIR" ] && [ "$SHADLOGGED" -eq 0 ] ; then
		writelog "INFO" "${FUNCNAME[0]} - Shader destination directory is '$SHADDESTDIR'"
		SHADLOGGED=1
	fi
}

function disableThisGameShaderRepo {
	RMREP="$1"
	if [ -n "$2" ]; then
		SHADDESTDIR="$2"
	else
		setShaderDest
	fi

	if [ -z "$RSDSTS" ]; then
		RSDST="$SHADDESTDIR/$RSSUB"
		RSDSTS="$RSDST/Shaders"
		RSDSTT="$RSDST/Textures"
		RSDSTE="$RSDST/enabled"
	fi

	if [ -n "$RMREP" ] && [ -f "$RSDSTE/$RMREP" ]; then
		notiShow "$(strFix "$NOTY_SHADDIS" "$RMREP")"

		# removed disabled shaders
		if [ -d "$RSDSTS" ]; then
			while read -r syml; do
				if [[ "$(readlink "$syml")" =~ $RMREP ]]; then
					writelog "INFO" "${FUNCNAME[0]} - Removing shader symlink '$syml' from deactivated repo '$RMREP'" "X" "$SHADLOG"
					rm "$syml"
				fi
			done <<< "$(find -L "$RSDSTS")"
		fi
		# removed disabled textures
		if [ -d "$RSDSTT" ]; then
			while read -r syml; do
				if [[ "$(readlink "$syml")" =~ $RMREP ]]; then
					writelog "INFO" "${FUNCNAME[0]} - Removing texture symlink '$syml' from deactivated repo '$RMREP'" "X" "$SHADLOG"
					rm "$syml"
				fi
			done <<< "$(find -L "$RSDSTT")"
		fi
		rm "$RSDSTE/$RMREP"
	fi
}

function enableThisGameShaderRepo {
	SELREPO="$1"
	REPDIR="$STLSHADDIR/$SELREPO"

	if grep -q "^${SELREPO}$" "$SHADERREPOBLOCKLIST"; then
		writelog "SKIP" "${FUNCNAME[0]} - The selected repo '$SELREPO' is in the block list '$SHADERREPOBLOCKLIST'" "X" "$SHADLOG"
	else
		if [ -n "$2" ]; then
			SHADDESTDIR="$2"
		else
			setShaderDest
		fi

		if [ ! -d "$REPDIR" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - The directory '$REPDIR' for the selected repo '$SELREPO' does not exist" "X" "$SHADLOG"
		else
			if [ -z "$RSDSTS" ]; then
				RSDST="$SHADDESTDIR/$RSSUB"
				RSDSTS="$RSDST/Shaders"
				RSDSTT="$RSDST/Textures"
				RSDSTE="$RSDST/enabled"

				mkProjDir "$RSDSTS"
				mkProjDir "$RSDSTT"
				mkProjDir "$RSDSTE"
			fi

			if [ -f "$RSDSTE/$SELREPO" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - Repo '$SELREPO' is already activated for the game" "X" "$SHADLOG"
			else
				notiShow "$(strFix "$NOTY_SHADENA" "$SELREPO")"
				# updating shaders
				writelog "INFO" "${FUNCNAME[0]} - Updating shaders for activated repo '$SELREPO'" "X" "$SHADLOG"
				SHADERSRC="$(find "$REPDIR" -type d -iname "Shaders")"
				if [ -n "$SHADERSRC" ]; then
					while read -r shaderfile; do
						writelog "INFO" "${FUNCNAME[0]} - Creating symlink '$RSDSTS/${shaderfile##*/}' for shader '$shaderfile'" "X" "$SHADLOG"
						ln -s "$shaderfile" "$RSDSTS/${shaderfile##*/}" 2>/dev/null
					done <<< "$(find "$SHADERSRC" -mindepth 1 -maxdepth 1)"
					touch "$RSDSTE/$SELREPO"
				fi

				# updating textures
				writelog "INFO" "${FUNCNAME[0]} - Updating textures for activated repo '$SELREPO'" "X" "$SHADLOG"
				TEXTURESRC="$(find "$REPDIR" -type d -iname "Textures")"
				if [ -n "$TEXTURESRC" ]; then
					while read -r texfile; do
						writelog "INFO" "${FUNCNAME[0]} - Creating symlink '$RSDSTT/${texfile##*/}' for texture '$texfile'" "X" "$SHADLOG"
						ln -s "$texfile" "$RSDSTT/${texfile##*/}" 2>/dev/null
					done <<< "$(find "$TEXTURESRC" -mindepth 1 -maxdepth 1)"
				fi
			fi
		fi
	fi
}

function GameShaderDialog {
	touch "$SHADERREPOBLOCKLIST"

	setShaderDest "$1"

	RSDST="$SHADDESTDIR/$RSSUB"
	RSDSTS="$RSDST/Shaders"
	RSDSTT="$RSDST/Textures"
	RSDSTE="$RSDST/enabled"

	if [ -f "$SHADLOG" ]; then
		rm "$SHADLOG" 2>/dev/null
	fi

	if [ "$SHADDESTDIR" != "$NON" ]; then
		mkProjDir "$RSDSTS"
		mkProjDir "$RSDSTT"
		mkProjDir "$RSDSTE"
	fi

	if [ -d "$RSDST" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Opening Shader Selection Dialog for dir '$RSDST'"

		SHADDLLAST="$STLSHADDIR/lastdl.txt"
		MAXAGE=1440

		if [ ! -f "$SHADDLLAST" ] || test "$(find "$SHADDLLAST" -mmin +"$MAXAGE")"; then
			StatusWindow "$GUI_DLSHADER" "dlShaders" "DownloadShadersStatus"
			echo "$(date) - ${FUNCNAME[0]}" > "$SHADDLLAST"
		fi

		export CURWIKI="$PPW/Shader-Management"
		TITLE="${PROGNAME}-Shader"
		pollWinRes "$TITLE"

		setShowPic

		unset AVAILREPOS
		unset SELREPOS
		unset UNSELREPOS

		# appending a ';' to the reponames to prevent cutting the wrong, similar filename
		mapfile -d "|" -t -O "${#AVAILREPOS[@]}" AVAILREPOS <<< "$(find "$STLSHADDIR" -mindepth 1 -maxdepth 1 -not -empty -type d -printf "%p;\n")"

		SELREPOS="$(while read -r repo; do REPONAME="${repo##*/}"; if [ -f "$RSDSTE/${REPONAME//;}" ]; then	echo TRUE ; echo "${REPONAME//;}"; else echo FALSE ; echo "${REPONAME//;}" ;fi ; done <<< "$(printf "%s\n" "${AVAILREPOS[@]}")" | \
		"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist --column="$GUI_ADD" --column=Shader-Repo --separator=" " --print-column="2" \
		--text="$(spanFont "$(strFix "$GUI_SHADERDIALOG" "${RSDST##*/}")" "H")" --title="$TITLE" "$GEOM")"
		case $? in
			0)  {
					UNSELREPO=( "${AVAILREPOS[@]}" )

					if [ -n "${SELREPOS[0]}" ]; then
						writelog "INFO" "${FUNCNAME[0]} - At least one repo was enabled, so automatically enabling required repo '$RSSUB'" "X" "$SHADLOG"
						SELREPOS=( "${SELREPOS[@]}" "$RSSUB" )

						writelog "INFO" "${FUNCNAME[0]} - Activating shaders for enabled repos" "X" "$SHADLOG"

						while read -r SELREPO; do
							writelog "INFO" "${FUNCNAME[0]} - Enabled: $SELREPO" "X" "$SHADLOG"
							unset REPDIR
							enableThisGameShaderRepo "$SELREPO"
							REPDIR="$STLSHADDIR/${SELREPO};"
							UNSELREPO=( "${UNSELREPO[@]/$REPDIR}" )

						done <<< "$(printf "%s\n" "${SELREPOS[@]}")"
					fi

					writelog "INFO" "${FUNCNAME[0]} - Deactivating shaders for disabled repos" "X" "$SHADLOG"

					while read -r UNSEL; do
						if [ -n "$UNSEL" ] && [ "$UNSEL" != ";" ]; then
							unset RMREP
							RMREP="${UNSEL//;}"
							RMREP="${RMREP##*/}"
							if [ "$RMREP" != "$RSSUB" ]; then
								writelog "INFO" "${FUNCNAME[0]} - Disabled: $RMREP" "X" "$SHADLOG"
								disableThisGameShaderRepo "$RMREP"
							fi
						fi
					done <<< "$(printf "%s\n" "${UNSELREPO[@]}")"

					if [ -z "${SELREPOS[0]}" ] && [ -f "$RSDSTE/$RSSUB" ]; then
						writelog "INFO" "${FUNCNAME[0]} - No repo was enabled, so also disabling the repo '$RSSUB'" "X" "$SHADLOG"
						disableThisGameShaderRepo "$RSSUB"
					fi

					writelog "INFO" "${FUNCNAME[0]} - Deactivating shaders for blocked repos" "X" "$SHADLOG"
					while read -r BLOCKREP; do
						disableThisGameShaderRepo "$BLOCKREP"
					done < "$SHADERREPOBLOCKLIST"
				}
			;;
			1)  writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL"
			;;
		esac
	else
		writelog "SKIP" "${FUNCNAME[0]} - Dest Dir '$SHADDESTDIR' does not exist and could not be created - skipping"
		if [ -z "$SHADDESTDIR" ]; then
			SHADDESTDIR="$NON"
		fi
		notiShow "$(strFix "$NOTY_MISSDIR" "$SHADDESTDIR")"
	fi

	if [ -n "$2" ];	then "$2";	fi
}

function getArch {
	# maybe remove reduntant lines later
	if [ "$(file "$1" | grep -c "PE32 ")" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Architecture for '$1' is 32bit"
		echo "32"
	elif [ "$(file "$1" | grep -c "PE32+ ")" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Architecture for '$1' is 64bit"
		echo "64"
	else
		if [ "$(find "$(dirname "$1")" -name "*.exe" | wc -l)" -ge 0 ]; then
			TESTEXE="$(find "$(dirname "$1")" -name "*.exe" | head -n1)"
			if [ "$(file "$TESTEXE" | grep -c "PE32 ")" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Architecture for bundled '$TESTEXE' for '$1' is 32bit"
				echo "32"
			elif [ "$(file "$TESTEXE" | grep -c "PE32+ ")" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Architecture for bundled '$TESTEXE' for '$1' is 64bit"
				echo "64"
			fi
		elif [ "$(find "$(dirname "$1")" -name "*.dll" | wc -l)" -ge 0 ]; then
			TESTDLL="$(find "$(dirname "$1")" -name "*.dll" | head -n1)"
			if [ "$(file "$TESTDLL" | grep -c "PE32 ")" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Architecture for bundled '$TESTDLL' for '$1' is 32bit"
				echo "32"
			elif [ "$(file "$TESTDLL" | grep -c "PE32+ ")" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Architecture for bundled '$TESTDLL' for '$1' is 64bit"
				echo "64"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Could not detect architecture for '$1' directly or indirectly"
		fi
	fi
}

function chooseShaders {
	if [ "$CHOOSESHADERS" -eq 1 ]; then
		setShadDestDir
		writelog "INFO" "${FUNCNAME[0]} - Opening Shader Menu - shader destination path is '$SHADDESTDIR'"
		GameShaderDialog "$SHADDESTDIR"
	fi
}

# Sort & add given ReShade DLL name to our tracked list of ReShade DLLs, if it is not already present
function appendToRSTXT {
	if ! [ -f "$INSTDESTDIR/$RSTXT" ]; then
		writelog "INFO" "${FUNCNAME[0]} - '$INSTDESTDIR/$RSTXT' does not already exist -- Will create a new file"
		touch "$INSTDESTDIR/$RSTXT"
	fi

	if ! grep -qw "$1" "$INSTDESTDIR/$RSTXT"; then
		echo "$1" >> "$INSTDESTDIR/$RSTXT"
		writelog "INFO" "${FUNCNAME[0]} - Added '$1' to list of tracked ReShade DLLs at to '$INSTDESTDIR/$RSTXT'"
	else
		writelog "INFO" "${FUNCNAME[0]} - ReShade DLL '$1' already on list of tracked ReShade DLLs at '$INSTDESTDIR/$RSTXT' - Nothing to do."
	fi

	sort "$INSTDESTDIR/$RSTXT" -u -o "$INSTDESTDIR/$RSTXT"
}

# $2 used to specify NOD3D9 wehn we copied both DXGI and D3D9 DLLs, but we no longer do that, so $2 is unused
# Last refactored for: https://github.com/sonic2kk/steamtinkerlaunch/pull/881
function installRSdll {
	RSDLLNAMECONFLICTFOUND=0

	# Manage creating backup if untracked DLL with our selected ReShade DLL name already exists at location
	# This function could be changed in future to take the path as a parameter as well, but that was not important at time of writing
	function manageDuplicateRSDLL {
		writelog "WARN" "${FUNCNAME[0]} - DLL with name '$1' found in game dir '$INSTDESTDIR' but is not tracked by us - This is possibly a game/mod DLL"
		writelog "WARN" "${FUNCNAME[0]} - Backing up DLL at '$INSTDESTDIR/$1' to '$INSTDESTDIR/${1}.bak' and moving our ReShade DLL anyway"

		if [ -f "$INSTDESTDIR/${1}.bak" ]; then
			writelog "ERROR" "${FUNCNAME[0]} - ERROR: Back-up DLL name '${1}.bak' already exists -- This is probably a very bad thing!"
		fi

		mv "$INSTDESTDIR/$1" "$INSTDESTDIR/${1}.bak" 2>/dev/null
		cp "$RESHADESRCDIR/$RSVERS/$2" "$INSTDESTDIR/$1" >/dev/null 2>/dev/null
	}

	if [ ! -f "$INSTDESTDIR/$1" ] || [ "$1" == "F" ]; then
		if [ ! -f "$RESHADESRCDIR/$RSVERS/$3" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Sourcefile '$RESHADESRCDIR/$RSVERS/$3' missing - skipping this file"
		else
			# Installing DLL for the first time
			cp "$RESHADESRCDIR/$RSVERS/$3" "$INSTDESTDIR/$1" >/dev/null 2>/dev/null
			writelog "INFO" "${FUNCNAME[0]} - Copied '$RESHADESRCDIR/$RSVERS/$3' to '$INSTDESTDIR/$1'"
		fi
	else
		# Check for ReShade DLL name conflicts
		if [ -f "$INSTDESTDIR/$1" ] && [ -f "$INSTDESTDIR/$RSTXT" ] && ! grep -qw "$1" "$INSTDESTDIR/$RSTXT"; then
			RSDLLNAMECONFLICTFOUND=1
		fi

		if [ "$RESHADEUPDATE" -eq 0 ]; then
			if [ "$RSDLLNAMECONFLICTFOUND" -eq 1 ]; then
				# DLL with name matching our ReShade DLL name exists, but was not installed by us (missing from ReShade.txt) - Backing up existing DLL and installing ReShade DLL anyway
				writelog "INFO" "${FUNCNAME[0]} - ReShade update is DISABLED"
				writelog "WARN" "${FUNCNAME[0]} - Specified ReShade DLL name conflict detected!"

				manageDuplicateRSDLL "$1" "$3"  # 1 = target ReShade DLL name, 3 = ReShade DLL name from STL downloads folder to copy with the name specified in $1
			else
				writelog "SKIP" "${FUNCNAME[0]} - Destfile '$INSTDESTDIR/$1' already exists and is tracked by us, but not checking the installed version, because RESHADEUPDATE is '$RESHADEUPDATE'"
			fi
		else
			if grep -q "${RSVERS%%_*}" <<< "$(strings "$INSTDESTDIR/$1" | grep "^Initializing")"; then
				# Existing ReShade DLL found and matches our selected version -- Don't update
				writelog "SKIP" "${FUNCNAME[0]} - Destfile '$INSTDESTDIR/$1' already exists and looks up-to-date - skipping this file"
			else
				if [ "$RSDLLNAMECONFLICTFOUND" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - ReShade update is ENABLED"
					writelog "INFO" "${FUNCNAME[0]} - Specified ReShade DLL name conflict detected!"

					manageDuplicateRSDLL "$1" "$3"  # 1 = target ReShade DLL name, 3 = ReShade DLL name from STL downloads folder to copy with the name specified in $1
				else
					# DLL either does not already exist or if it does, it's in the ReShade.txt file
					writelog "INFO" "${FUNCNAME[0]} - Destfile '$INSTDESTDIR/$1' already exists, but has a different version or is not a ReShade DLL - updating"
					cp "$RESHADESRCDIR/$RSVERS/$3" "$INSTDESTDIR/$1" >/dev/null 2>/dev/null
				fi
			fi
		fi
	fi
}

# install reshade:
function installReshade {
	if [ "$USERESHADE" -eq 1 ]; then
		prepareReshadeFiles
		setShadDestDir  # Have to use setShadDestDir because setShadDest will use ABSGAMEEXEPATH which is not Custom Command

		INSTDESTDIR="$SHADDESTDIR"

		# Default ReShade DLL name to use to dxgi.dll if no DLL name is provided
		if [ -z "$RESHADEDLLNAME" ]; then
			writelog "INFO" "${FUNCNAME[0]} - RESHADEDLLNAME is blank - Defaulting to '$DXGI'"
			RESHADEDLLNAME="$DXGI"
		fi

		# checking for previous dll conficts between $RS_DX_DEST and $RS_D9_DEST
		# note: modern ReShade uses "ReShade_exenamehere.log", and old versions use "dxgi.log" (if ReShade dll is named dxgi.dll). we support both names.
		RESHADE_CONFLICTS=$(find "$INSTDESTDIR" -maxdepth 1 \( -name "${RS_DX_DEST//.dll/.log}" -or -name "ReShade_*.log" \) -print0 | xargs -0 -r grep -l "Another ReShade instance was already loaded from" | wc -l)
		if [ "$RESHADE_CONFLICTS" -ge 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found $RS_DX_DEST conflict with $RS_D9_DEST"
			if [ -f "$INSTDESTDIR/$RS_D9_DEST" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Removing $RS_D9_DEST"
				rm "$INSTDESTDIR/$RS_D9_DEST"
			else
				writelog "SKIP" "${FUNCNAME[0]} - $RS_D9_DEST not found"
			fi

			if [ -z "$NOD3D9" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Blocking re-installation of '$RS_D9_DEST' by setting NOD3D9=1 in '$STLGAMECFG'"
				updateConfigEntry "NOD3D9" "1" "$STLGAMECFG"
				export NOD3D9=1
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - No conflict found in old logfiles"
		fi

		getReShadeExeArch

		if [ -d "$INSTDESTDIR" ]; then
			# Get ReShade DLL names from comma separated list -- User will probably mostly only pass one, but this will handle cases where they might want multiple (ex: d3d9, opengl32)
			RSDLLNAMEARR=()  # Make sure the array of DLL names is always reset when installReshade is called, to avoid duplicate entries
			mapfile -d "," -t -O "${#RSDLLNAMEARR[@]}" RSDLLNAMEARR < <(printf '%s' "$RESHADEDLLNAME")

			for CUSTRSDLL in "${RSDLLNAMEARR[@]}"; do
				# Append extension if no extension in DLL
				if ! [[ $CUSTRSDLL == *.* ]]; then
					CUSTRSDLL="${CUSTRSDLL}.dll"
				fi
			done

			# Check architecture to know which ReShade DLL architectures to copy over
			if [ "$(getArch "$CHARCH")" == "32" ]; then
				#32bit:
				writelog "INFO" "${FUNCNAME[0]} - Installing 32bit ${RESH} as '$CHARCH' is 32bit"
				RSD3D47DLL="$D3D47_32"
				RSARCHDLL="$RS_32"
			elif [ "$(getArch "$CHARCH")" == "64" ]; then
				#64bit:
				writelog "INFO" "${FUNCNAME[0]} - Installing 64bit ${RESH} as '$CHARCH' is 64bit"
				RSD3D47DLL="$D3D47_64"
				RSARCHDLL="$RS_64"
			else
				#feelsbad.jpg:
				writelog "SKIP" "${FUNCNAME[0]} - ERROR in ${RESH} installation - no file information detected for '$CHARCH' or any 'neighbor file' - setting USERESHADE=0 for this session"
				export USERESHADE=0
			fi

			# Common conditional to install either 32bit/64bit ReShade DLLs, since process is same, just different DLL names
			# USESPECIALK check needed because we can't use custom DLL names when using SpecialK -- It expects the raw ReShade32/ReShade64 DLL names
			#
			# Only install ReShade "normally" if (ReShade is on and SpecialK is off) or (if ReShade+SpecialK are on and ReShade SpecialK Plugin is disabled)
			if [[ ( "$USERESHADE" -eq 1 && "$USESPECIALK" -eq 0 ) || ( "$USERESHADE" -eq 1 && "$USESPECIALK" -eq 1 && "$USERESHSPEKPLUGIN" -eq 0 ) ]]; then
				removeReShadeSpecialKInstallation "1"  # Remove any existing ReShade SpecialK Plugin installation so we can replace it with a 'regular' ReShade install

				# Check to make sure none of our ReShade names conflict with SpecialK -- This will abort install, and is the only place we need to abort install
				if [ "$USESPECIALK" -eq 1 ] && [ "$USERESHSPEKPLUGIN" -eq 0 ]; then
					getSpecialKGameRenderApi
					SPEKREALDLLNAME="$( basename "$SPEKDST" )"
					for CUSTRSDLL in "${RSDLLNAMEARR[@]}"; do
						if [[ "$CUSTRSDLL" = "$SPEKREALDLLNAME" ]] && [ -f "$SPEKREALDLLNAME" ] && [ ! -f "$INSTDESTDIR/$RSTXT" ]; then
							# If our ReShade DLL matches the chosen SpecialK DLL name, if the SpecialK DLL is already in the game files, and if it's not a ReShade DLL (i.e. RSTXT doesn't exist), assume we have a SpecialK conflict
							# If ReShade+SpecialK are installed fresh at the same time, ReShade is installed early, and this logic prevents logging that ReShade won't be installed because it conflicts with SpecialK
							# Which is incorrect because it's detecting our installed ReShade DLLs as SpecialK DLLs
							writelog "ERROR" "${FUNCNAME[0]} - SpecialK is enabled and the chosen ReShade DLL name conflicts with the SpecialK DLL name -- Not installing ReShade"
							notiShow "$( strFix "$NOTY_SPEKRESHDLLCONFLICT" "$SPEK" "$RESH" )"

							return
						fi
					done
				fi

				# actual ReShade DLL name (either d3d9/d3d11/dxgi, or a custom user selected name)
				# notiShow "$NOTY_RESHADEINSTALLING"
				for CUSTRSDLL in "${RSDLLNAMEARR[@]}"; do
					installRSdll "$CUSTRSDLL" "0" "$RSARCHDLL"
				done

				#d3d47 - Required for ReShade
				# NOTE 25/08/23: *Is* it still required?
				installd3d47dll "$RSD3D47DLL" "$INSTDESTDIR"

				# Rewrite the ReShade TXT file to ensure it only has our installed ReShade DLLs
				if [ -f "$RSTXT" ]; then
					rm "$RSTXT"
				fi

				# Add d3dcompiler_47 and custom ReShade DLL names, removing any non-ReShade DLLs (ensures previously entered DLL names get removed and not incorrectly tracked as ReShade DLLs)
				# appendToRSTXT "$D3D47"
				for CUSTRSDLL in "${RSDLLNAMEARR[@]}"; do
					writelog "INFO" "${FUNCNAME[0]} - Writing '$CUSTRSDLL' to '$RSTXT'"
					appendToRSTXT "$CUSTRSDLL"
				done
			else
				if [ "$USERESHADE" -eq 1 ] && [ "$USESPECIALK" -eq 1 ]; then
					# End here, as ReShade Installation code will be handled by SpecialK
					writelog "SKIP" "${FUNCNAME[0]} - USERESHADE and USESPECIALK are enabled together, and ReShade is being used as a Plugin, skipping custom ReShade DLL name as SpecialK needs specific ReShade DLL names"
				fi
			fi

			# This makes sure if we updated any DLL names in RSDLLNAMEARR to end with '.dll' that these are written out to the game config file
			# Doing this ensures we don't end up with the array containing 'dxgi.dll' but the config file value being 'dxgi' (if the user left out the extension)
			# This is not strictly necessary but I wanted this consistency -- It's also why we loop through RSDLLNAMEARR twice :-)
			touch "$FUPDATE"
			CONFIGRSDLLNAMESTR="$( printf '%s,' "${RSDLLNAMEARR[@]}" )"
			writelog "INFO" "${FUNCNAME[0]} - Updating RESHADEDLLNAME config entry to include any potentially-updated ReShade DLL names so they all end with '.dll' if no extension was provided"
			updateConfigEntry "RESHADEDLLNAME" "${CONFIGRSDLLNAMESTR%,}" "$STLGAMECFG"
		else
			writelog "SKIP" "${FUNCNAME[0]} - INSTDESTDIR '$INSTDESTDIR' not found"
		fi
	fi
}

# Remove ReShade files (i.e. to replace with SpecialK)
function removeReShadeInstallation {
	KEEPRESHADEINI="${1:-0}"

	writelog "INFO" "${FUNCNAME[0]} - INSTDESTDIR is '$INSTDESTDIR'"

	while read -r RSDLLREMOVEFILE; do
		RSDLLREMOVEPATH="${INSTDESTDIR}/$RSDLLREMOVEFILE"
		if [ -f "$RSDLLREMOVEPATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Removing non-SpecialK ReShade DLL from '$RSDLLREMOVEPATH'"
			rm "$RSDLLREMOVEPATH"
		fi
	done < "$INSTDESTDIR/$RSTXT"

	if [ -f "$INSTDESTDIR/$RSINI" ] && [ "$KEEPRESHADEINI" -eq 0 ]; then
		rm "$INSTDESTDIR/$RSINI"
	fi

	if [ -f "$INSTDESTDIR/$RSTXT" ]; then
		rm "$INSTDESTDIR/$RSTXT"
	fi
}

# Remove ReShade SpecialK Plugin installation (i.e. to replace it with non-plugin installation)
function removeReShadeSpecialKInstallation {
	KEEPRESHADEINI="${1:-0}"

	# DLLs and JSON files
	RESHSPEKREMOVEDLLS=( "$INSTDESTDIR/$RS_32" "$INSTDESTDIR/${RS_32//.dll/.json}" "$INSTDESTDIR/$RS_64" "$INSTDESTDIR/${RS_64//.dll/.json}" )
	for RESHSPEKREMOVEDLL in "${RESHSPEKREMOVEDLLS[@]}"; do
		rmFileIfExists "$RESHSPEKREMOVEDLL"
	done

	# INI file
	if [ "$KEEPRESHADEINI" -eq 0 ]; then
		rmFileIfExists "$INSTDESTDIR/$RSINI"
	fi
}

function installDepth3DReshade {
	SHADERPOOL="depth3d"

	if [ "$RESHADE_DEPTH3D" -eq 1 ]; then
		StatusWindow "$GUI_DLSHADER" "dlShaders $SHADERPOOL" "DownloadCustomProtonStatus"
		setShadDestDir
		enableThisGameShaderRepo "$SHADERPOOL"
	fi
}

# Get archiecture of executable that ReShade is being used for, so we know which DLL to copy (32bit/64bit)
