#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

# status label for a custom proton download - derive the proton name from its
# download url so the log shows which version is being downloaded
function dlCustProtonStatusText {
	local CPURL="${1//\"/}"
	if [ -z "$CPURL" ]; then
		echo "$GUI_DLCUSTPROT"
		return
	fi
	local PROTNAME="${CPURL##*/}"
	PROTNAME="${PROTNAME%%.tar*}"
	PROTNAME="${PROTNAME//.zip/}"
	if [ -z "$PROTNAME" ]; then
		PROTNAME="$CPURL"
	fi
	echo "${GUI_DLCUSTPROT}: ${PROTNAME}"
}

function dlCustomProton {
	local CPURL="${1//\"/}" CPURLFILE DSTDL CUPROEXTDIR PROTNAME
	local DLCHK=X INCHK="$NON" CHKDATA ARCHIVEFILES ENTRY PROTRELPATH=""
	local PROTDIR PROTFULLPATH EXTSTAGE STAGEDTOOL DLRC
	if ! [[ "$CPURL" =~ ^https?://[^[:space:]]+$ ]]; then
		writelog "ERROR" "${FUNCNAME[0]} - Invalid download URL '$CPURL'"
		return 1
	fi
	CPURLFILE="${CPURL##*/}"
	case "$CPURLFILE" in
		*.tar.gz) PROTNAME="${CPURLFILE%.tar.gz}" ;;
		*.tar.xz) PROTNAME="${CPURLFILE%.tar.xz}" ;;
		*.zip) PROTNAME="${CPURLFILE%.zip}" ;;
		*) writelog "ERROR" "${FUNCNAME[0]} - Unsupported Proton archive '$CPURLFILE'"; return 1 ;;
	esac
	if [ -z "$PROTNAME" ] || [ "$PROTNAME" == . ] || [ "$PROTNAME" == .. ]; then
		return 1
	fi
	if [ "${CUPROTOCOMPAT:-0}" -eq 1 ]; then
		CUPROEXTDIR="$STEAMCOMPATOOLS"
	else
		CUPROEXTDIR="$CUSTPROTEXTDIR"
	fi
	DSTDL="$CUSTPROTDLDIR/$CPURLFILE"
	mkProjDir "$CUSTPROTDLDIR" || return 1
	mkProjDir "$CUPROEXTDIR" || return 1

	# Fetch and validate the expected digest once, for new and cached archives.
	case "$CPURLFILE" in
		*-GE*|GE-*|*-STL*)
			DLCHK=sha512sum
			CHKDATA="$("$WGET" -q "${CPURL%.*.*}.${DLCHK}" -O - 2> >(grep -v "SSL_INIT" >&2))" || return $?
			read -r INCHK _ <<< "$CHKDATA"
			if ! [[ "$INCHK" =~ ^[[:xdigit:]]{128}$ ]]; then
				writelog "ERROR" "${FUNCNAME[0]} - Missing or invalid '$DLCHK' checksum for '$CPURLFILE'"
				return 1
			fi
			INCHK="${INCHK,,}"
			;;
	esac
	if [ ! -s "$DSTDL" ]; then
		dlCheck "$CPURL" "$DSTDL" "$DLCHK" "Downloading '$CPURL' to '$CUSTPROTDLDIR'" "$INCHK" || return $?
	else
		writelog "INFO" "${FUNCNAME[0]} - File '$DSTDL' already exists - nothing to download"
		if [ "$DLCHK" != X ]; then
			dlCheck "$DLCHK" "$DSTDL" C "$INCHK" || return $?
		fi
		if [ -z "${2:-}" ]; then
			notiShow "$(strFix "$NOTY_DLCUSTOMPROTON4" "$CPURLFILE")"
		fi
	fi

	notiShow "$(strFix "$NOTY_DLCUSTOMPROTON5" "$CPURLFILE")" "S"
	case "$CPURLFILE" in
		*.tar.*) ARCHIVEFILES="$("$TAR" -tf "$DSTDL")" || return $? ;;
		*.zip) ARCHIVEFILES="$("$UNZIP" -Z1 "$DSTDL")" || return $? ;;
	esac
	while IFS= read -r ENTRY; do
		while [[ "$ENTRY" == ./* ]]; do ENTRY="${ENTRY#./}"; done
		# Refuse traversal and ambiguous layouts rather than installing outside
		# the chosen tool directory or registering the wrong proton executable.
		case "$ENTRY" in
			/*|..|../*|*/../*|*/..)
				writelog "ERROR" "${FUNCNAME[0]} - Unsafe archive path '$ENTRY'"
				return 1 ;;
		esac
		case "$ENTRY" in
			proton|*/proton)
				if [ -n "$PROTRELPATH" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - Archive contains multiple proton files"
					return 1
				fi
				PROTRELPATH="$ENTRY" ;;
		esac
	done <<< "$ARCHIVEFILES"
	if [ -z "$PROTRELPATH" ]; then
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON6" "$DSTDL")" "S"
		writelog "ERROR" "${FUNCNAME[0]} - Archive does not contain a 'proton' file"
		return 1
	fi
	if [ "$PROTRELPATH" == proton ]; then
		PROTDIR="$PROTNAME"
		PROTFULLPATH="$CUPROEXTDIR/$PROTDIR/proton"
	else
		PROTDIR="${PROTRELPATH%%/*}"
		PROTFULLPATH="$CUPROEXTDIR/$PROTRELPATH"
	fi
	if [ -f "$PROTFULLPATH" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Proton already installed under '$PROTFULLPATH'"
	elif [ -e "$CUPROEXTDIR/$PROTDIR" ] || [ -L "$CUPROEXTDIR/$PROTDIR" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Incomplete destination '$CUPROEXTDIR/$PROTDIR' exists - leaving it untouched"
		return 1
	else
		# Extract on the destination filesystem, then publish the tool only after
		# the extractor succeeds. Failed extraction cannot leave an installed tool.
		EXTSTAGE="$(mktemp -d "$CUPROEXTDIR/.proton-install.XXXXXX")" || return 1
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON3" "$CPURL")" "S"
		DLRC=0
		case "$CPURLFILE" in
			*.tar.*) "$TAR" xf "$DSTDL" -C "$EXTSTAGE" || DLRC=$? ;;
			*.zip) "$UNZIP" -q "$DSTDL" -d "$EXTSTAGE" || DLRC=$? ;;
		esac
		if [ "$DLRC" -ne 0 ] || [ ! -f "$EXTSTAGE/$PROTRELPATH" ]; then
			writelog "ERROR" "${FUNCNAME[0]} - Extraction of '$DSTDL' failed"
			rm -rf -- "$EXTSTAGE"
			[ "$DLRC" -ne 0 ] || DLRC=1
			return "$DLRC"
		fi
		if [ "$PROTRELPATH" == proton ]; then
			STAGEDTOOL="$EXTSTAGE"
		else
			STAGEDTOOL="$EXTSTAGE/$PROTDIR"
		fi
		if ! mv -T -- "$STAGEDTOOL" "$CUPROEXTDIR/$PROTDIR"; then
			rm -rf -- "$EXTSTAGE"
			return 1
		fi
		if [ "$STAGEDTOOL" != "$EXTSTAGE" ]; then
			rm -rf -- "$EXTSTAGE"
		fi
		getAvailableProtonVersions "up"
		touch "$PROTBUMPTEMP"
	fi
	rm -f -- "$PROTONCSV"
	addCustomProtonToList "$PROTFULLPATH"
}

# Map 'uname -m' to the architecture suffix custom Proton archives use.
# Prints nothing on architectures TinkerGame has no builds for, which
# disables architecture filtering and selection (keep everything).
function getHostProtonArch {
	case "$(uname -m)" in
		x86_64|amd64) echo "x86_64" ;;
		aarch64|arm64) echo "aarch64" ;;
	esac
}

# Drop download URLs for foreign-architecture builds from stdin. Builds
# without an architecture in the file name (TKG, STL) are kept, and unknown
# host architectures disable filtering.
function filterProtonArch {
	local OTHERARCH
	case "$(getHostProtonArch)" in
		x86_64)  OTHERARCH="aarch64|arm64" ;;
		aarch64) OTHERARCH="x86_64|amd64" ;;
		*)       cat; return ;;
	esac
	# Never fail: an empty result must not break the caller's pipeline
	grep -Ev -- "-(${OTHERARCH})\." || true
}

# Echo the first line from stdin matching the host architecture. Falls back
# to the first line when nothing matches (unlabelled builds, unknown host
# architecture), so a stale cached list cannot resolve to a foreign build.
function pickHostProton {
	local ARCHPAT
	case "$(getHostProtonArch)" in
		x86_64)  ARCHPAT="x86_64|amd64" ;;
		aarch64) ARCHPAT="aarch64|arm64" ;;
		*)       head -n1; return ;;
	esac

	# Buffer stdin: grep inside the command substitution would drain it
	local LINES=()
	mapfile -t LINES
	if [ "${#LINES[@]}" -eq 0 ]; then
		return
	fi

	local MATCH
	MATCH="$(printf "%s\n" "${LINES[@]}" | grep -m1 -E -- "-(${ARCHPAT})\." || true)"
	if [ -n "$MATCH" ]; then
		printf "%s\n" "$MATCH"
	else
		printf "%s\n" "${LINES[0]}"
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

					# '7\.x' with an escaped dot: the filter is a regex, so an
					# unescaped dot also matches the '-' in asset names like
					# GE-Proton11-7-x86_64.tar.gz and drops every x86_64 build
					# filterProtonArch then drops builds for foreign architectures
					"$WGET" -q "$SRCURL" -O - | "$JQ" -r '.[].assets[].browser_download_url' | grep "tar.gz\|tar.xz" | grep -v "Yad\|7\.x" | filterProtonArch >> "$PROTDLLIST"
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

	if [ -z "$DLPROTLIST" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Empty download list - is '$JQ' installed and are we online?"
		notiShow "$GUI_EMPTYDLIST" "X"
	fi

	# Each row carries its URL in a hidden second column: the selection maps
	# to exactly one archive, so a near-identical name like 'Proton-10a0'
	# can never be downloaded when 'Proton-10.0' was selected.
	# yad reads one cell per line, so name and URL go on separate lines
	local -a DLCELLS=()
	local IDX DLGRC DLSRCURL DLRC=0
	for IDX in "${!ProtonDLDispList[@]}"; do
		DLCELLS+=("${ProtonDLDispList[$IDX]}" "${ProtonDLList[$IDX]}")
	done

	DLDISPCUSTPROT="$(printf '%s\n' "${DLCELLS[@]}" | "$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --center --on-top "${WINDECO[@]}" \
	--list --column="$GUI_USEPROTON" --column="$GUI_URL" --hide-column=2 --separator="" --print-column="2" \
	--button="$BUT_DONE":0 --button="$GUI_URL":3 --button="$BUT_CAN":1 \
	--title="$TITLE" \
	--text="$(spanFont "$GUI_DLCUSTPROTTEXT" "H")" \
	"$GEOM"
	)"
	DLGRC=$?

	if [ "$DLGRC" -eq 3 ]; then
		# manual entry keeps the combobox capability: type an arbitrary archive URL
		if ! DLSRCURL="$("$YAD" --window-icon="$STLICON" --center --on-top "${WINDECO[@]}" \
		--entry \
		--title="$TITLE" \
		--text="$(spanFont "$GUI_DLCUSTPROTTEXT" "H")" \
		--button="$BUT_DONE":0 --button="$BUT_CAN":1 \
		"$GEOM")"; then
			writelog "INFO" "${FUNCNAME[0]} - Manual URL entry cancelled"
			return 0
		fi
	elif [ "$DLGRC" -ne 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Download selection cancelled"
		return 0
	else
		DLSRCURL="$DLDISPCUSTPROT"
	fi

	if [ -z "$DLSRCURL" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Nothing selected - skipping download"
		return 0
	fi
	if ! grep -qE '^https?://[^[:space:]]+$' <<< "$DLSRCURL"; then
		writelog "ERROR" "${FUNCNAME[0]} - '$DLSRCURL' is not a valid download URL"
		return 1
	fi

	writelog "INFO" "${FUNCNAME[0]} - Selected '$DLSRCURL' - starting download"
	StatusWindow "$(dlCustProtonStatusText "$DLSRCURL")" dlCustomProton "DownloadCustomProtonStatus" "$DLSRCURL" || DLRC=$?
	createProtonList
	return "$DLRC"
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
				StatusWindow "$(dlCustProtonStatusText "$CPURL")" "dlCustomProton ${CPURL}" "DownloadCustomProtonStatus"
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
				StatusWindow "$(dlCustProtonStatusText "$CPURL")" "dlCustomProton ${CPURL}" "DownloadCustomProtonStatus"
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

# Resolve a requested Proton name to exactly one release URL by comparing
# archive basenames literally (optionally with a host-architecture suffix).
# A substring match would hand 'Proton-10a0.tar.gz' to a request for
# 'Proton-10.0'.
function resolveProtonDownloadURL {
	local REQUEST="${1:-}" URL BASE
	[ -n "$REQUEST" ] || return 1
	while IFS= read -r URL; do
		[ -n "$URL" ] || continue
		BASE="${URL##*/}"
		case "$BASE" in
			*.tar.gz) BASE="${BASE%.tar.gz}" ;;
			*.tar.xz) BASE="${BASE%.tar.xz}" ;;
			*.zip) BASE="${BASE%.zip}" ;;
		esac
		case "$BASE" in
			"$REQUEST"|"$REQUEST-x86_64"|"$REQUEST-amd64"|"$REQUEST-aarch64"|"$REQUEST-arm64")
				printf '%s\n' "$URL"
				return 0
				;;
		esac
	done
	return 1
}

# Filter a Proton download list (stdin) down to one provider and print the
# host-compatible build. Fails when that provider published no matching
# archive instead of silently picking another provider's build.
function pickProviderProton {
	local PROVIDER="${1:-}" CONFIGURL="" BASEPAT="" MATCHES="" CANDIDATES
	CANDIDATES="$(cat)"
	[ -n "$CANDIDATES" ] || return 1
	case "$PROVIDER" in
		any)
			pickHostProton <<< "$CANDIDATES"
			return $?
			;;
		ge)
			CONFIGURL="${CP_PROTONGE:-}"
			BASEPAT='GE-Proton|proton-ge-custom|GloriousEggroll'
			;;
		tkg)
			CONFIGURL="${CP_PROTONTKG:-}"
			BASEPAT='wine-tkg|Frogging-Family'
			;;
		*)
			return 1
			;;
	esac
	if [ -n "$CONFIGURL" ]; then
		MATCHES="$(grep -F -- "$CONFIGURL" <<< "$CANDIDATES" || true)"
	fi
	if [ -z "$MATCHES" ]; then
		MATCHES="$(grep -E -- "$BASEPAT" <<< "$CANDIDATES" || true)"
	fi
	[ -n "$MATCHES" ] || return 1
	pickHostProton <<< "$MATCHES"
}

function dlLatestGE {
	createDLProtList

	local PROVIDER=any LATESTPROTON DLARGS
	case "${1:-}" in
		latestge|lge) PROVIDER=ge ;;
		latesttkg|ltkg) PROVIDER=tkg ;;
	esac

	if ! LATESTPROTON="$(printf "%s\n" "${ProtonDLList[@]}" | pickProviderProton "$PROVIDER")" || [ -z "$LATESTPROTON" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - No downloadable Proton build found for provider '$PROVIDER'"
		notiShow "$GUI_EMPTYDLIST" "X"
		return 1
	fi

	case "$PROVIDER" in
		ge)
			writelog "INFO" "${FUNCNAME[0]} - Downloading latest Proton GE"
			;;
		tkg)
			writelog "INFO" "${FUNCNAME[0]} - Downloading latest Proton TKG"
			;;
		*)
			writelog "INFO" "${FUNCNAME[0]} - Downloading latest custom Proton ${LATESTPROTON##*/}"
			;;
	esac

	DLARGS=("${LATESTPROTON//\"/}")
	if [ -n "${2:-}" ]; then
		DLARGS+=("$2")
	fi
	StatusWindow "$(dlCustProtonStatusText "${DLARGS[0]}")" dlCustomProton "DownloadCustomProtonStatus" "${DLARGS[@]}"
}

function dlCustomProtonGate {
	if [ -z "${1:-}" ]; then
		dlCustomProtonGUI
		return $?
	fi

	if grep -q "^http" <<< "$1"; then
		writelog "INFO" "${FUNCNAME[0]} - '$1' is an URL - sending directly to dlCustomProton"
		StatusWindow "$(dlCustProtonStatusText "$1")" dlCustomProton "DownloadCustomProtonStatus" "$1"
		return $?
	fi

	case "$1" in
		latest|l|latestge|lge|latesttkg|ltkg)
			dlLatestGE "$1"
			;;
		*)
			writelog "SKIP" "${FUNCNAME[0]} - Don't know what to do with argument '$1'"
			return 1
			;;
	esac
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
