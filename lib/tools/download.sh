#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function dlCustomProton {
	if [[ -n "$CUPROTOCOMPAT" && "$CUPROTOCOMPAT" -eq 1 ]]; then
		CUPROEXTDIR="$STEAMCOMPATOOLS"
	else
		CUPROEXTDIR="$CUSTPROTEXTDIR"
	fi

	CPURL="${1//\"/}"
	CPURLFILE="${CPURL##*/}"
	DSTDL="$CUSTPROTDLDIR/$CPURLFILE"
	if [ ! -f "$DSTDL" ]; then
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$CPURL")" "S"
		DLCHK="X"
		INCHK="$NON"
		# only "-STL" and "GE" proton have a sha512sum
		if grep -q "\-GE" <<< "$CPURLFILE" || grep -q "GE-" <<< "$CPURLFILE" || grep -q "\-STL" <<< "$CPURLFILE"; then
			DLCHK="sha512sum"
			INCHK="$("$WGET" -q "${CPURL%%.tar*}.${DLCHK}" -O - 2> >(grep -v "SSL_INIT") | cut -d ' ' -f1)"
		fi
		dlCheck "$CPURL" "$DSTDL" "$DLCHK" "Downloading '$CPURL' to '$CUSTPROTDLDIR'" "$INCHK"
	else
		writelog "INFO" "${FUNCNAME[0]} - File '$DSTDL' already exists - nothing to download"
		if [ -z "$2" ]; then
			notiShow "$(strFix "$NOTY_DLCUSTOMPROTON4" "$CPURLFILE")"
		fi
	fi

	PROTNAMERAW="${CPURLFILE%%.tar*}"
	PROTNAME="${PROTNAMERAW//.zip/}"
	if [ -d "$CUPROEXTDIR/$PROTNAME" ]; then
		writelog "INFO" "${FUNCNAME[0]} - directory '$CUPROEXTDIR/$PROTNAME' already exists - nothing to extract"
	else
		# only "-STL" and "GE" proton have a sha512sum
		if grep -q "\-GE" <<< "$CPURLFILE" || grep -q "GE-" <<< "$CPURLFILE" || grep -q "\-STL" <<< "$CPURLFILE"; then
			DLCHK="sha512sum"
			writelog "INFO" "${FUNCNAME[0]} - checking if the checksum of the already downloaded file is correct '${CPURL%%.tar*}.${DLCHK}'"
			INCHK="$("$WGET" -q "${CPURL%%.tar*}.${DLCHK}" -O - 2> >(grep -v "SSL_INIT") | cut -d ' ' -f1)"
			dlCheck "$DLCHK" "$DSTDL" "C" "$INCHK"
		fi

		if grep -q "\.tar\." <<< "$DSTDL"; then
			notiShow "$(strFix "$NOTY_DLCUSTOMPROTON5" "$CPURLFILE")" "S"

			PROTRELPATH="$("$TAR" -tf "$DSTDL" 2>/dev/null | grep "proton$" 2>/dev/null )"
			if [ -n "$PROTRELPATH" ]; then
				if grep -q "^proton$" <<< "$PROTRELPATH"; then
					EXTDEST="$CUPROEXTDIR/$PROTNAME"
					PROTFULLPATH="$EXTDEST/$PROTRELPATH"
					writelog "INFO" "${FUNCNAME[0]} - Archive is a tarbomb - creating parent directory '$EXTDEST' as extract dest dir"
					mkProjDir "$EXTDEST"
				else
					writelog "INFO" "${FUNCNAME[0]} - Archive contains proton in subdirectory '$PROTRELPATH'"
					PROTFULLPATH="$CUPROEXTDIR/$PROTRELPATH"
					EXTDEST="$CUPROEXTDIR"
				fi

				if [ -f "$PROTFULLPATH" ]; then
					writelog "SKIP" "${FUNCNAME[0]} - The destination path '$PROTFULLPATH' already exists - looks like '$DSTDL' was already extracted before"
				else
					notiShow "$(strFix "$NOTY_DLCUSTOMPROTON3" "$CPURL")" "S"
					"$TAR" xf "$DSTDL" -C "$EXTDEST" 2>/dev/null
					getAvailableProtonVersions "up"
					touch "$PROTBUMPTEMP"
				fi
			else
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON6" "$DSTDL")" "S"
				writelog "SKIP" "${FUNCNAME[0]} - Archive doesn't seem to contain a 'proton' file"
			fi
		elif grep -q "\.zip$" <<< "$DSTDL"; then
			if grep -q "proton$" <<< "$("$UNZIP" -l "$DSTDL" 2>/dev/null)"; then
				writelog "INFO" "${FUNCNAME[0]} - Archive contains proton"
				SUBDIR="$(basename "${DSTDL//.zip/}")"
				PROTRELPATH="$SUBDIR/proton"
				PROTFULLPATH="$CUPROEXTDIR/$PROTRELPATH"
				if [ -f "$PROTFULLPATH" ]; then
					writelog "SKIP" "${FUNCNAME[0]} - The destination path '$PROTFULLPATH' already exists - looks like '$DSTDL' was already extracted before"
				else
					notiShow "$(strFix "$NOTY_DLCUSTOMPROTON3" "$CPURL")" "S"
					"$UNZIP" "$DSTDL" -d "$CUPROEXTDIR/$SUBDIR" 2>/dev/null
					getAvailableProtonVersions "up"
					touch "$PROTBUMPTEMP"
					notiShow "$GUI_DONE" "S"
				fi
			else
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON6" "$CPURL")" "S"
				writelog "SKIP" "${FUNCNAME[0]} - Archive doesn't seem to contain a 'proton' file"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Don't know how to extract "
		fi
	fi

	rm "$PROTONCSV" 2>/dev/null

	if [ -f "$PROTFULLPATH" ]; then
		addCustomProtonToList "$PROTFULLPATH"
	fi
}

function createDLProtList {
	if [ ! -x "$(command -v "$JQ")" ]; then
		writelog "WARN" "${FUNCNAME[0]} - 'jq' is not installed - Can't generate list of online Proton versions"
	else
		writelog "INFO" "${FUNCNAME[0]} - Generating list of online available custom Proton builds"

		PROTDLLIST="$STLSHM/ProtonDL.txt"
		MAXAGE=360

		if [ ! -f "$PROTDLLIST" ] || test "$(find "$PROTDLLIST" -mmin +"$MAXAGE")"; then
			rm "$PROTDLLIST" 2>/dev/null
			while read -r CPURL; do
				if grep -q "$GHURL" <<< "${!CPURL}"; then
					SRCURL="${!CPURL}"
					SRCURL="${SRCURL//\/releases}"
					SRCURL="${SRCURL//$GHURL/$AGHURL\/repos}"
					SRCURL="${SRCURL}/releases"

					"$WGET" -q "$SRCURL" -O - | "$JQ" -r '.[].assets[].browser_download_url' | grep "tar.gz\|tar.xz" | grep -v "Yad\|7.x" >> "$PROTDLLIST"
				fi
			done <<< "$(grep "^CP_" "$STLURLCFG" | cut -d '=' -f1)"
		fi
	fi

	delEmptyFile "$PROTDLLIST"

	if [ ! -f "$PROTDLLIST" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Could not generating list of online available custom Proton builds - Probably $GHURL changed something"
	else
		unset ProtonDLList
		unset ProtonDLDispList

		while read -r CPVERS; do
			mapfile -t -O "${#ProtonDLList[@]}" ProtonDLList <<< "$CPVERS"
			mapfile -t -O "${#ProtonDLDispList[@]}" ProtonDLDispList <<< "${CPVERS##*/}"
		done < "$PROTDLLIST"
	fi
}

function dlCustomProtonGUI {
	createDLProtList

	writelog "INFO" "${FUNCNAME[0]} - Opening dialog to choose a download"

	DLPROTLIST="$(printf "!%s\n" "${ProtonDLDispList[@]//\"/}" | tr -d '\n' | sed "s:^!::" | sed "s:!$::")"
	export CURWIKI="$PPW/Download-Custom-Proton"
	TITLE="${PROGNAME}-DownloadCustomProton"
	pollWinRes "$TITLE"

	if [ -z "$DLPROTON" ]; then
		DLPROTON="${ProtonDLDispList[0]}"
	fi

	if [ -z "$DLPROTLIST" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Empty download list - is '$JQ' installed and are we online?"
		notiShow "$GUI_EMPTYDLIST" "X"
	fi

	DLDISPCUSTPROT="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
	--title="$TITLE" \
	--text="$(spanFont "$GUI_DLCUSTPROTTEXT" "H")" \
	--field=" ":LBL " " --separator="" \
	--field="$GUI_DLCUSTPROTTEXT2!$GUI_DLCUSTPROTTEXT":CBE "$(cleanDropDown "${DLPROTON/#-/ -}" "$DLPROTLIST")" \
	"$GEOM"
	)"

	if [ -n "${DLDISPCUSTPROT}" ]; then
		if grep -q "^http" <<< "${DLDISPCUSTPROT}"; then
			writelog "INFO" "${FUNCNAME[0]} - The URL '$DLDISPCUSTPROT' was entered manually - downloading directly"
			StatusWindow "$GUI_DLCUSTPROT" "dlCustomProton ${DLDISPCUSTPROT}" "DownloadCustomProtonStatus"
		else
			DLURL="$(printf "%s\n" "${ProtonDLList[@]}" | grep -m1 "${DLDISPCUSTPROT}")"
			writelog "INFO" "${FUNCNAME[0]} - '${DLDISPCUSTPROT}' was selected - downloading '$DLURL'"
			StatusWindow "$GUI_DLCUSTPROT" "dlCustomProton ${DLURL}" "DownloadCustomProtonStatus"
		fi

		createProtonList
	fi
}

function openSteamGridDir {
	writelog "INFO" "${FUNCNAME[0]} - Opening Steam Grid directory"
	"$XDGO" "$STUIDPATH/config/grid"
}

# Set artwork for Steam game by copying/linking/moving passed artwork to steam grid folder
function setGameArt {
	function applyGameArt {
		GAMEARTAPPID="$1"
		GAMEARTSOURCE="$2"  # e.g. /home/gaben/GamesArt/cs2_hero.png
		GAMEARTSUFFIX="$3"  # e.g. "_hero" etc
		GAMEARTCMD="$4"

		SGGRIDDIR="$STUIDPATH/config/grid"
		GAMEARTBASE="$( basename "$GAMEARTSOURCE" )"
		GAMEARTDEST="${SGGRIDDIR}/${GAMEARTAPPID}${GAMEARTSUFFIX}.${GAMEARTBASE#*.}"  # path to filename in grid e.g. turns "/home/gaben/GamesArt/cs2_hero.png" into "~/.local/share/Steam/userdata/1234567/config/grid/4440654_hero.png"

		if [ -n "$GAMEARTSOURCE" ]; then
			if [ -f "$GAMEARTDEST" ]; then
				writelog "WARN" "${FUNCNAME[0]} - Existing art already exists at '$GAMEARTDEST' - Removing file..."
				rm "$GAMEARTDEST"
			fi

			if [ -f "$GAMEARTSOURCE" ]; then
				$GAMEARTCMD "$GAMEARTSOURCE" "$GAMEARTDEST"
				writelog "INFO" "${FUNCNAME[0]} - Successfully set game art for '$GAMEARTSOURCE' at '$GAMEARTDEST'"
			else
				writelog "WARN" "${FUNCNAME[0]} - Given game art '$GAMEARTSOURCE' does not exist, skipping..."
			fi
		fi
	}

	GAME_APPID="$1"  # We don't validate AppID as it would drastically slow down the process for large libraries

	SETARTCMD="cp"  # Default command will copy art
	for i in "$@"; do
		case $i in
			-hr=*|--hero=*)
				SGHERO="${i#*=}"  # <appid>_hero.png -- Banner used on game screen, logo goes on top of this
				shift ;;
			-lg=*|--logo=*)
				SGLOGO="${i#*=}"  # <appid>_logo.png -- Logo used e.g. on game screen
				shift ;;
			-ba=*|--boxart=*)
				SGBOXART="${i#*=}"  # <appid>p.png -- Used in library
				shift ;;
			-tf=*|--tenfoot=*)
				SGTENFOOT="${i#*=}"  # <appid>.png -- Used as small boxart for e.g. most recently played banner
				shift ;;
			--copy)
				SETARTCMD="cp"  # Copy file to grid folder -- Default
				shift ;;
			--link)
				SETARTCMD="ln -s"  # Symlink file to grid folder
				shift ;;
			--move)
				SETARTCMD="mv"  # Move file to grid folder
				shift ;;
		esac
	done

	applyGameArt "$GAME_APPID" "$SGHERO" "_hero" "$SETARTCMD"
	applyGameArt "$GAME_APPID" "$SGLOGO" "_logo" "$SETARTCMD"
	applyGameArt "$GAME_APPID" "$SGBOXART" "p" "$SETARTCMD"
	applyGameArt "$GAME_APPID" "$SGTENFOOT" "" "$SETARTCMD"

	writelog "INFO" "${FUNCNAME[0]} - Finished setting game art for '$GAME_APPID'. Restart Steam for the changes to take effect."
	echo "Finished setting game art for '$GAME_APPID'. Restart Steam for the changes to take effect."
}

# Shows the Yad GUI for selecting artwork to pass to setGameArt
function setGameArtGui {
	writelog "INFO" "${FUNCNAME[0]} - Starting the GUI for setting game artwork"

	if [ -z "$SUSDA" ] || [ -z "$STUIDPATH" ]; then
		setSteamPaths
	fi

	export CURWIKI="$PPW/Custom-Game-Artwork"
	TITLE="${PROGNAME}-$SGA"
	pollWinRes "$TITLE"

	SGAGAMENAME="Unknown Game"
	if [ -n "$1" ]; then
		SGAGAMENAME="$( getTitleFromID "$1" "1" )"
		if [ -z "$AID" ] || [ "$AID" -eq "$PLACEHOLDERAID" ]; then
			AID="$1"
		fi
	fi

	setShowPic

	SGASETACTIONS="copy!link!move"
	SGASET="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
	--title="$TITLE" --separator="|" --image="$SHOWPIC" \
	--text="$(spanFont "$( strFix "$GUI_SGATITLE" "$SGAGAMENAME" "$1" )" "H")\n$GUI_SGATEXT" \
	--field=" ":LBL " " \
	--field="$GUI_SGAHERO!$DESC_SGAHERO ('SGAHERO')":FL "${SGAHERO/#-/ -}" \
	--field="$GUI_SGALOGO!$DESC_SGALOGO ('SGALOGO')":FL "${SGALOGO/#-/ -}" \
	--field="$GUI_SGABOXART!$DESC_SGABOXART ('SGABOXART')":FL "${SGABOXART/#-/ -}" \
	--field="$GUI_SGATENFOOT!$DESC_SGATENFOOT ('SGATENFOOT')":FL "${SGATENFOOT/#-/ -}" \
	--field="$GUI_SGASETACTION!$DESC_SGASETACTION ('SGASETACTION')":CB "$( cleanDropDown "copy" "$SGASETACTIONS" )" \
	--button="$BUT_CAN":0 --button="$BUT_DONE":2 "$GEOM" )"

	case $? in
		0)  writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN'" ;;
		2)  writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_DONE'"
			mapfile -d "|" -t -O "${#SGASETARR[@]}" SGASETARR < <(printf '%s' "$SGASET")
			SGAHERO="${SGASETARR[1]}"
			SGALOGO="${SGASETARR[2]}"
			SGABOXART="${SGASETARR[3]}"
			SGATENFOOT="${SGASETARR[4]}"
			SGACOPYMETHOD="${SGASETARR[5]}"

			setGameArt "$1" --hero="$SGAHERO" --logo="$SGALOGO" --boxart="$SGABOXART" --tenfoot="$SGATENFOOT" "--${SGACOPYMETHOD}"
	esac
}

function CustomFallbackPicture {
	if [ "$USECUSTOMFALLBACKPIC" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using custom fallback picture if possible and required"

		if [ ! -f "$CUSTOMFALLBACKPIC" ]; then
			if [ -n "$GITHUBUSER" ] && [ "$GITHUBUSER" != "$NON" ]; then
				dlCheck "$GHURL/${GITHUBUSER}.png" "$CUSTOMFALLBACKPIC" "X" "Downloading github avatar for user '$GITHUBUSER' to use as custom fallback picture"
			fi
		fi

		if [ -f "$CUSTOMFALLBACKPIC" ]; then
			SHOWPIC="$CUSTOMFALLBACKPIC"
			writelog "INFO" "${FUNCNAME[0]} - Using '$SHOWPIC' as custom fallback picture"
		else
			writelog "INFO" "${FUNCNAME[0]} - No custom fallback picture found - using internal picture instead"
		fi
	fi
}

# This could use a bit of a rewrite
function setShowPic {
	GRIDBANNER="$( find "$STUIDPATH/config/grid" -iname "${AID}_hero.*" -type f -exec realpath {} \; | head -n1  )"

	if [ "$STLPLAY" -eq 1 ] && [ -f "$STLGPNG/${AID}.png" ]; then
		SHOWPIC="$STLGPNG/${AID}.png"
	elif [ "$USEGAMEPICS" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Determining game picture"
		if [ -s "$STLGHEADD/$AID.jpg" ]; then
			SHOWPIC="$STLGHEADD/$AID.jpg"
			writelog "INFO" "${FUNCNAME[0]} - Using '$SHOWPIC' as game picture"
		else
			SHOWPIC="$STLICON"
			CustomFallbackPicture

			if [ ! -f "$STLGHEADD/$AID.jpg" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Using '$SHOWPIC' as fallback picture, because '$STLGHEADD/$AID.jpg' doesn't exist"
			elif [ ! -s "$STLGHEADD/$AID.jpg" ]; then
				# If we have a 0bytes file and we get here, try replace it with GRIDBANNER
				if [ -z "$SUSDA" ] || [ -z "$STUIDPATH" ]; then
					setSteamPaths
				fi
				# CUSTPIC replaced with GRIDBANNER, because CUSTPIC expects PNG
				CUSTPIC="$STUIDPATH/config/grid/${AID}_hero.png"
				if [ -f "$GRIDBANNER" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Found custom game picture under '$GRIDBANNER'"
					if [ -x "$(command -v "$CONVERT" 2>/dev/null)" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Replacing the empty '$STLGHEADD/$AID.jpg' file with a scaled down version and using that"
						"$CONVERT" "$GRIDBANNER" -resize "460x215!" "$STLGHEADD/$AID.jpg"
						SHOWPIC="$STLGHEADD/$AID.jpg"
					else
						writelog "SKIP" "${FUNCNAME[0]} - Command '$CONVERT' not found, so scaling the custom game picture is not possible - skipping"
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - Using '$SHOWPIC' as fallback picture, because '$STLGHEADD/$AID.jpg' has zero bytes"
					writelog "INFO" "${FUNCNAME[0]} - Leaving '$STLGHEADD/$AID.jpg' as is to avoid another download attempt"
					writelog "INFO" "${FUNCNAME[0]} - Feel free to replace it with a custom picture"
				fi
			elif [[ ( ! -f "$STLGHEADD/$AID.jpg" || ! -s "$STLGHEADD/$AID.jpg" ) && -n "$GRIDBANNER" ]]; then
				# If banner image still doesn't exist, use grid folder one (i.e. non-steam games)
				# Find custom image in grid folder and store resized image at '$STLGHEADD/<org_image_name_with_extension>'
				writelog "INFO" "${FUNCNAME[0]} - Using hero image found in Steam Grid folder - '$GRIDBANNER'"
				CUSTPIC="$GRIDBANNER"
				"$CONVERT" "$CUSTPIC" -resize "460x215!" "$STLGHEADD/${AID}.jpg"
				SHOWPIC="$STLGHEADD/${AID}.jpg"
			fi
		fi
	else
		SHOWPIC="$NOICON"
		writelog "INFO" "${FUNCNAME[0]} - Using '$SHOWPIC' as invisible picture"
	fi
}

function addCustomProtonToList {
	if [ -f "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Received directly the file as argument"
		if [ -n "$2" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Received '$2' as Proton Version"
			OUTNEWCUSTPROT="$2;$1"
		else
			OUTNEWCUSTPROT="$1"
		fi
	else
		NEWCUSTPROT="$1"

		if grep -q "||" <<< "$NEWCUSTPROT"; then
			if grep -q "|http" <<< "$NEWCUSTPROT"; then
				CPURLWIP="$(tr '|' '"' <<< "$NEWCUSTPROT" | sed "s:\"http:\";\"http:g")"
				CPURL="$(cut -d ';' -f2 <<< "$CPURLWIP")"
				StatusWindow "$GUI_DLCUSTPROT" "dlCustomProton ${CPURL}" "DownloadCustomProtonStatus"
			else
				CPWIP="$(tr -s '|' <<< "$NEWCUSTPROT" | tr '|' '"')"
				if [ -f "${CPWIP//\"/}" ]; then
					OUTNEWCUSTPROT="$CPWIP"
				fi
			fi
		else
			if grep -q "|http" <<< "$NEWCUSTPROT"; then
				CPURLWIP="$(tr '|' '"' <<< "$NEWCUSTPROT" | sed "s:\"http:\";\"http:g")"
				CPURL="$(cut -d ';' -f2 <<< "$CPURLWIP")"
				StatusWindow "$GUI_DLCUSTPROT" "dlCustomProton ${CPURL}" "DownloadCustomProtonStatus"
			else
				CPWIP="$(tr '|' '"' <<< "$NEWCUSTPROT" | sed "s:\"/:\";\"/:g")"
				CPWIPF="$(cut -d ';' -f2 <<< "$CPWIP")"
				if [ -f "${CPWIPF//\"/}" ]; then
					OUTNEWCUSTPROT="$CPWIP"
				fi
			fi
		fi
	fi

	if [ -n "$OUTNEWCUSTPROT" ] ; then
		writelog "INFO" "${FUNCNAME[0]} - Adding '$OUTNEWCUSTPROT' to '$CUSTOMPROTONLIST'"
		echo "$OUTNEWCUSTPROT" >> "$CUSTOMPROTONLIST"
		writelog "INFO" "${FUNCNAME[0]} - (Re-)creating the internal List of available Proton-Versions"
		getAvailableProtonVersions "up" X
	fi
}

function dlLatestGE {
	createDLProtList

	if [ -n "${ProtonDLList[0]}" ]; then
		if [ "$1" == "latestge" ] || [ "$1" == "lge" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Downloading latest Proton GE"
		else
			writelog "INFO" "${FUNCNAME[0]} - Downloading latest custom Proton ${ProtonDLDispList[0]//\"/}"
		fi
		StatusWindow "$GUI_DLCUSTPROT" "dlCustomProton ${ProtonDLList[0]//\"/} $2" "DownloadCustomProtonStatus"
	else
		writelog "ERROR" "${FUNCNAME[0]} - Could not create list of downloadable Proton-Versions"
	fi
}

function dlCustomProtonGate {
	if [ -z "$1" ]; then
		dlCustomProtonGUI
	else
		if grep -q "^http" <<< "$1"; then
			writelog "INFO" "${FUNCNAME[0]} - '$1' is an URL - sending directly to dlCustomProton"
			StatusWindow "$GUI_DLCUSTPROT" "dlCustomProton $1" "DownloadCustomProtonStatus"
		else
			if [ "$1" == "latest" ] || [ "$1" == "l" ] || [ "$1" == "latestge" ] || [ "$1" == "lge" ]; then
				dlLatestGE "$1"
			elif [ "$1" == "latesttkg" ] || [ "$1" == "ltkg" ]; then
				createDLProtList
				writelog "INFO" "${FUNCNAME[0]} - Downloading latest Proton TKG"
				StatusWindow "$GUI_DLCUSTPROT" "dlCustomProton $(printf "%s\n" "${ProtonDLList[@]}" | grep -im1 "tkg")" "DownloadCustomProtonStatus"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Don't know what to do with argument '$1'"
			fi
		fi
	fi
}

function addCustomProton {
	if [ -z "$1" ]; then
		if [ ! -f "$CUSTOMPROTONLIST" ]; then
			{
			echo "# List of custom proton paths, which are not stored in the usual default locations (see README)"
			echo "# (optionally with identifying name (f.e. proton version) as field one)"
			echo "# Files can be added by using the '$PROGCMD' command line or the GUI (or manually of course)"
			echo "# Two valid examples:"
			echo "# \"Proton-47.11-FWX-3\";\"/random/path/to/a/custom/binary/proton\""
			echo "# \"/random/path/to/a/custom/binary/proton\""
			echo "# (In the first example \"Proton-47.11-FWX-3\" will be used as identifying proton version"
			echo "# in the second example the identifying proton version will be searched in '$CTVDF'"
			echo "# and 'version' files in the besides the given proton binary."
			echo "# When no proton version could be found, the selected file will be marked as invalid and removed at once)"
			echo "################################################"
			} > "$CUSTOMPROTONLIST"
		fi
		export CURWIKI="$PPW/Custom-Proton-Autoupdate"
		TITLE="${PROGNAME}-AddCustomProton"
		pollWinRes "$TITLE"

		NEWCUSTPROT="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--title="$TITLE" \
		--text="$(spanFont "$GUI_ADDCUSTOMBINARY" "H")" \
		--field=" ":LBL " " \
		--field="$GUI_PROTONVERSIONNAME!$DESC_PROTONVERSIONNAME" "Proton-" \
		--field="$GUI_CUSTOMPROTONBINARY":FL "proton" --file-filter="$GUI_PROTONFILES (proton)| proton" \
		"$GEOM"
		)"

		addCustomProtonToList "$NEWCUSTPROT"
	else
		if grep -q "proton$" <<< "$1"; then
			if [ -f "$1" ]; then
				writelog "INFO" "${FUNCNAME[0]} - '$1' is a path to an existing 'proton' file - adding to the Custom Proton List"
				addCustomProtonToList "$@"
			else
			writelog "SKIP" "${FUNCNAME[0]} - File '$1' does not exist - skipping"
			fi
		fi
	fi
}

