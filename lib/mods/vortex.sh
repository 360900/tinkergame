#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function getLatestGitHubExeVer {
    SETUPNAME="$1"
    PROJURL="$2"
    EXCLUDEPRERELEASES="${3:-0}"  # i.e. to only get latest stable Vortex

    RELEASESURL="${PROJURL}/releases"
    if [ "$EXCLUDEPRERELEASES" -eq 1 ]; then
        TAGSURL="${RELEASESURL}/latest"  # Will redirect to release tagged with "latest" instead of pre-release
    else
        TAGSURL="${PROJURL}/tags"
    fi

    TAGSGREP="${RELEASESURL#"$GHURL"}/tag"

    LATESTTAG="$("$WGET" -q "${TAGSURL}" -O - 2> >(grep -v "SSL_INIT") | grep -m1 "$TAGSGREP" | grep -oE "${TAGSGREP}[^\"]+")"
    LATESTVER="${LATESTTAG##*/}"

	getGitHubExeVer "$SETUPNAME" "$PROJURL" "$LATESTVER"
}

# Get GitHub release information for a given version tag -- Used by getLatestGitHubExeVer and can also be used standalone i.e. for downloading a specific Vortex version.
function getGitHubExeVer {
	SETUPNAME="$1"
	PROJURL="$2"
	TAG="$3"

	"$WGET" -q "${PROJURL}/releases/expanded_assets/${TAG}" -O - 2> >(grep -v "SSL_INIT") | grep "exe" | grep -m1 "$SETUPNAME" | grep -oE "${SETUPNAME}[^\"]+"
}

#### VORTEX START: ####

function addVortexStage {
	if [ ! -f "$VORTEXSTAGELIST" ]; then
		{
		echo "# List of directories, which ${VTX^} uses as 'Stage directories'"
		echo "# (see Wiki for a comprehensive description)"
		} > "$VORTEXSTAGELIST"
	fi

	if [ -z "$1" ]; then
		export CURWIKI="$PPW/${VTX^}"
		TITLE="${PROGNAME}-AddVortexStage"
		pollWinRes "$TITLE"

		NEWVS="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--file --directory \
		--title="$TITLE" \
		--text="$(spanFont "$GUI_SELECTVORTEXDIR" "H")" "$GEOM")"
	else
		if [ -d "$1" ]; then
			NEWVS="$1"
		elif [ -d "$(dirname "$1")" ]; then
			if mkProjDir "$1"; then
				NEWVS="$1"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Skipping invalid argument '$1'"
			fi
		fi
	fi

	if [ -n "$NEWVS" ]; then
		echo "$NEWVS" >> "$VORTEXSTAGELIST"
		rmDupLines "$VORTEXSTAGELIST"
	fi
}

function wineVortexRun {
	sleep 1  # required!

	## Only use SLR is available and (if user explicitly wants to run Vortex with dotnet OR if dotnet6 is not already installed), because the SLR can cause hardlink deployment to fail
	## See also: https://github.com/sonic2kk/steamtinkerlaunch/issues/828

	writelog "INFO" "${FUNCNAME[0]} - Vortex logs will be stored at '${VWRUN}'"
	writelog "INFO" "${FUNCNAME[0]} - Vortex installation location is '${VORTEXEXE}'"
	if [[ -n "${SLRCMD[*]}" && ( "$VORTEXUSESLRPOSTINSTALL" -eq 1 || ! -d "$VORTEXPFX/$DRC/Program Files/dotnet" ) ]]; then
		writelog "INFO" "${FUNCNAME[0]} - PATH=\"${SLTPATH}\" LD_LIBRARY_PATH=\"\" WINE=\"${VORTEXWINE}\" WINEARCH=\"win64\" WINEDEBUG=\"-all\" WINEPREFIX=\"${VORTEXPFX}\" \"${SLRCMD[*]}\" \"$*\""
		PATH="$STLPATH" LD_LIBRARY_PATH="" LD_PRELOAD="" WINE="$VORTEXWINE" WINEARCH="win64" WINEDEBUG="-all" WINEPREFIX="$VORTEXPFX" "${SLRCMD[@]}" "$@" > "$VWRUN" 2>/dev/null
	else
		writelog "INFO" "${FUNCNAME[0]} - PATH=\"${SLTPATH}\" LD_LIBRARY_PATH=\"\" WINE=\"${VORTEXWINE}\" WINEARCH=\"win64\" WINEDEBUG=\"-all\" WINEPREFIX=\"${VORTEXPFX}\" \"$*\""
		PATH="$STLPATH" LD_LIBRARY_PATH="" LD_PRELOAD="" WINE="$VORTEXWINE" WINEARCH="win64" WINEDEBUG="-all" WINEPREFIX="$VORTEXPFX" "$@" > "$VWRUN" 2>/dev/null
	fi

	unset "${SLRCMD[@]}"  # Ensure SLR is removed so that it won't be fetched and set for games launched after Vortex
}

function cleanVortex {
	MSCOR="mscorsvw.exe"
	if "$PGREP" "$MSCOR" >/dev/null; then
		writelog "INFO" "${FUNCNAME[0]} - Killing leftovers of $MSCOR"
		"$PKILL" -9 "$MSCOR"
	fi
}

function setVortexDLMime {
	writelog "INFO" "${FUNCNAME[0]} - INFO: Linking Nexus Mods downloads to ${VTX^}"

	VD="$VTX-${PROGNAME,,}-dl.desktop"
	FVD="$HOME/.local/share/applications/$VD"

	if [ ! -f "$FVD" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating new desktop file $FVD"
		{
		echo "[Desktop Entry]"
		echo "Type=Application"
		echo "Categories=Utilities;"
		echo "Name=${VTX^} ($PROGNAME - ${PROGNAME,,})"
		echo "Comment=Link Handler - For internal use only"
		echo "Icon=$STLICON"
		echo "MimeType=x-scheme-handler/nxm;x-scheme-handler/nxm-protocol"
		echo "Terminal=false"
		echo "X-KeepTerminal=false"
		echo "Path=$(dirname "$VORTEXEXE")"
		if [ "$INFLATPAK" -eq 1 ]; then
			echo "Exec=/usr/bin/flatpak run --command=tinkergame $FLATPAK_ID mods vortex url %u"
		else
			echo "Exec=$(realpath "$0") mods vortex url %u"
		fi
		echo "NoDisplay=true"
		echo "Hidden=false"
		} >> "$FVD"

		MO2D="$MO-${PROGNAME,,}-dl.desktop"
		FMO2D="$HOME/.local/share/applications/$MO2D"
		if [ -f "$FMO2D" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Renaming desktopfile ${FMO2D} to ${FMO2D}-off, because '$VD' was created"
			mv "$FMO2D" "${FMO2D}-off"
		fi
	else
		if grep -q "$VORTEXPFX" "$FVD"; then
			writelog "INFO" "${FUNCNAME[0]} - Desktopfile $FVD seems to be up2date"
			# Do NOT return here: the xdg-mime default association still needs to be
			# (re)applied every run, otherwise a missing or stale mimeapps.list entry
			# silently breaks nxm:// link handling while the desktop file stays intact.
		else
			writelog "INFO" "${FUNCNAME[0]} - Renaming desktopfile $FVD and creating a new one for ${PROGNAME,,}"
			mv "$FVD" "$FVD-old"
			setVortexDLMime
		fi
	fi

	# setting mime types for nxm
	if [ -x "$(command -v "$XDGMIME" 2>/dev/null)" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Setting download defaults for nexusmod protocol via $XDGMIME pointing at $VD"
		# stderr silenced: xdg-mime probes for optional helpers like qtpaths
		# and prints "command not found" noise on systems without them
		"$XDGMIME" default "$VD" x-scheme-handler/nxm 2>/dev/null
		"$XDGMIME" default "$VD" x-scheme-handler/nxm-protocol 2>/dev/null
	else
		writelog "SKIP" "${FUNCNAME[0]} - $XDGMIME not found - couldn't set download defaults for nexusmod protocol - skipping"
	fi
}

function getLatestVortVer {
	# Cache the latest-version lookup in $VTST so GUI windows open instantly
	# instead of blocking on the network every time they are rendered.
	if [ -f "$VTST" ] && grep -q "^VORTEXSETUP=" "$VTST" 2>/dev/null; then
		VTSAGE="$(( $(date +%s) - $(stat -c %Y "$VTST") ))"
		if [ -n "$VTSAGE" ] && [ "$VTSAGE" -lt 86400 ]; then
			loadCfg "$VTST" X
			writelog "INFO" "${FUNCNAME[0]} - Using cached '$VORTEXSETUP' from '$VTST'"
			return
		fi
	fi

	VSET="$VTX-setup"
	if [ "$USEVORTEXPRERELEASE" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Search for latest ${VTX^} Beta Release, if one is available (will fall back to Stable by default)"
		VORTEXSETUP="$(getLatestGitHubExeVer "$VSET" "$VORTEXPROJURL" )"
	else
		writelog "INFO" "${FUNCNAME[0]} - Search for latest ${VTX^} Stable Release"
		VORTEXSETUP="$(getLatestGitHubExeVer "$VSET" "$VORTEXPROJURL" "1" )"
	fi
	writelog "INFO" "${FUNCNAME[0]} - Found '$VORTEXSETUP'"
	echo "VORTEXSETUP=$VORTEXSETUP" > "$VTST"
}

# Get version based on specified release tag (passed either from commandline or preference)
function getVortVer {
	VTXTAGVER="$1"
	VSET="$VTX-setup"
	VORTEXSETUP="$( getGitHubExeVer "$VSET" "$VORTEXPROJURL" "$VTXTAGVER" )"
	if [ -z "$VORTEXSETUP" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Could not find Vortex setup executable for version '$VTXTAGVER' - VORTEXSETUP came back '$VORTEXSETUP'"
		writelog "INFO" "${FUNCNAME[0]} - Falling back to latest Vortex version"

		getLatestVortVer
	else
		writelog "INFO" "${FUNCNAME[0]} - Successfully fetched Vortex - Downloaded executable will be '$VORTEXSETUP'"
	fi
}

function dlLatestVortex {
	# VORTEXCUSTOMVER is set in Global Menu -- Use it if it's set to a sane value and if the setting is enabled
	if [ "$USEVORTEXCUSTOMVER" -eq 1 ] && [ "$VORTEXCUSTOMVER" != "$NON" ] && [ -n "$VORTEXCUSTOMVER" ]; then
		writelog "INFO" "${FUNCNAME[0]} - VORTEXCUSTOMVER specified and is '$VORTEXCUSTOMVER' - Will attempt to find and install this version"
		getVortVer "$VORTEXCUSTOMVER"
	else
		writelog "INFO" "${FUNCNAME[0]} - Downloading latest Vortex version (not using any custom Vortex version)"
		getLatestVortVer
	fi

	if [ -n "$VORTEXSETUP" ]; then
		export VSPATH="$VORTEXDLDIR/$VORTEXSETUP"

		# download:
		if [ ! -d "$VORTEXDLDIR" ]; then
			mkProjDir "$VORTEXDLDIR"
		fi

		if [ ! -f "$VSPATH" ]; then
			VVRAW="$(grep -oP "${VSET}-\K[^X]+" <<< "$VORTEXSETUP")"
			VORTEXVERSION="${VVRAW%.exe}"

			DLURL="$VORTEXPROJURL/releases/download/v$VORTEXVERSION/$VORTEXSETUP"
			# no idea how the sha512 is formatted in the yaml, so simply checking the size
			DLCHK="stat"
			INCHK="$("$WGET" -q "${DLURL//$VORTEXSETUP/latest.yml}" -O - 2> >(grep -v "SSL_INIT") | grep "size:" | gawk -F': ' '{print $2}')"

			writelog "INFO" "${FUNCNAME[0]} - Downloading $VORTEXSETUP to $VORTEXDLDIR from '$DLURL'"
			if [ -n "$1" ]; then
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$VORTEXSETUP")" "S"
				dlCheck "$DLURL" "$VSPATH" "$DLCHK" "Downloading '$VORTEXSETUP'" "$INCHK"
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$VORTEXSETUP")" "S"
			else
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$VORTEXSETUP")"
				dlCheck "$DLURL" "$VSPATH" "$DLCHK" "Downloading '$VORTEXSETUP'" "$INCHK"
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$VORTEXSETUP")"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - No VORTEXSETUP defined - nothing to download - skipping"
	fi
}

function getVortexStage {
	if [ -z "$VORTEXSTAGING" ]; then
		WANTSTAGE="$1"
		mkProjDir "$WANTSTAGE"
		if [ -d "$WANTSTAGE" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Created dir '$WANTSTAGE' $PARTLOG"
			VORTEXSTAGING="$WANTSTAGE"
		fi
	fi
}

function getInstalledGamesWithVortexSupport {
	getVortexSupported
	if [ "$(listInstalledGameIDs | wc -l)" -eq 0 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - No installed games found!"
	else
		mapfile -t -O "${#INSTGAMES[@]}" INSTGAMES <<< "$(listInstalledGameIDs)"
		mapfile -t -O "${#INSTVGAMES[@]}" INSTVGAMES <<< "$(comm -12 <(printf "%s\n" "${VOSTIDS[@]}" | sort -u) <(printf "%s\n" "${INSTGAMES[@]}" | sort -u))"
		if [ -n "$1" ]; then
			printf "%s\n" "${INSTVGAMES[@]}"
		fi
	fi
}

function dlVortexSupportedList {
	VORTEXGAMES="$GLOBALMISCDIR/$VOGAT"
	VORTSUPURL="https://www.nexusmods.com/about/vortex/"
	VORTHTMLLIST="$STLSHM/${VOGAT//txt/html}"
	VORTTMPLIST="$STLSHM/${VOGAT//.txt/-temp.txt}"

	if [ ! -f "$VORTHTMLLIST" ]; then
		dlCheck "$VORTSUPURL" "$VORTHTMLLIST" "X" "Downloading list of ${VTX^} supported games"
	fi

	awk '/supported-games/,/Vortex FAQ/' "$VORTHTMLLIST" | grep -oP "(?<=<li><a href=).*" | grep -v "Nexus Mods" | sed "s:^\"/:\":; s:\">:\";\":; s:</a></li>:\":" | sort -o "$VORTTMPLIST"
	readarray -t VTXOLGAMES <<<"$( grep -wF -f "$VORTTMPLIST" "$VORTEXGAMES" > "${VORTTMPLIST//-temp/-temp2}"
	{
		cat "${VORTTMPLIST//-temp/-temp2}"
		comm -23 "$VORTEXGAMES" "${VORTTMPLIST//-temp/-temp2}"
	} | sort -u )"

	for VTXOLG in "${VTXOLGAMES[@]}"; do
		VTXGN="$( echo "$VTXOLG" | cut -d ";" -f 2 | cut -d '"' -f 2 )"
		VTXGAID="$( echo "$VTXOLG" | cut -d ";" -f 3 | cut -d '"' -f 2 )"
		printf "%s (%s)\n" "$VTXGN" "$VTXGAID"
	done

	rm "${VORTTMPLIST//-temp/-temp2}" "$VORTTMPLIST" 2>/dev/null
}

function getGameSteamCollections {
	SCGAME="$1"

	if [ -z "$SUSDA" ] || [ -z "$STUIDPATH" ]; then
		setSteamPaths
	fi
	if [ -d "$SUSDA" ]; then
		SC="$STUIDPATH/$SRSCV"

		if [ ! -f "$SC" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - File '${SC##*/}' not found in steam userid dir - skipping"
		else
			writelog "INFO" "${FUNCNAME[0]} - File '${SC##*/}' found in steam userid dir - searching collections for game '$SCGAME'"

			while read -r SCAT; do
				mapfile -t -O "${#GSCATS[@]}" GSCATS <<< "$SCAT"
			done <<< "$(sed -n "/\"$SCGAME\"/,/}/p;" "$SC" | sed -n "/\"tags\"/,/}/p" | sed -n "/{/,/}/p" | grep -v '{\|}' | awk '{print $2}' | sed "s:\"::g")"
			if [ -n "$2" ]; then
				OUT1="$(printf "%s," "${GSCATS[@]}")"
				printf "%s\n" "${OUT1%*,}"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$SUSDA' not found - this should not happen! - skipping"
	fi
}

function VortexGamesDialog {
	writelog "INFO" "${FUNCNAME[0]} - Opening ${VTX^} Dialog for en/disabling ${VTX^} for installed games"
	setVortexVars
	getInstalledGamesWithVortexSupport
	export CURWIKI="$PPW/${VTX^}"
	TITLE="${PROGNAME}-${VTX^} Toggle"
	pollWinRes "$TITLE"

	setShowPic
	VGNLIST="$STLSHM/VGNLIST.txt"
	VGNSCLIST="$STLSHM/VGNSCLIST.txt"

	VINGAMES="$(while read -r f; do
		if [ -z "$f" ]; then
			continue
		fi

		loadCfg "$GEMETA/$f.conf" X
		VTXGAMFILENAME="$( grep "$f" "$VORTEXGAMES" | cut -d ";" -f 2 | cut -d '"' -f 2 )"
		if [ -n "$VTXGAMFILENAME" ]; then
			GNAM="$VTXGAMFILENAME"
			GNAM="$( echo "${VTXGAMFILENAME//$'\n'/;}" | cut -d ";" -f 2 )"
		fi
		writelog "INFO" "${FUNCNAME[0]} - Game is '$VTXGAMFILENAME'"

		if [ ! -f "$STLGAMEDIRID/${f}.conf" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Game config '$STLGAMEDIRID/${f}.conf' not found, so creating a minimal one from '$STLDEFGAMECFG'"
			grep -v "config Version" "$STLDEFGAMECFG" >> "$STLGAMEDIRID/${f}.conf"
		fi

		if grep -q "Vortex" <<< "$(getGameSteamCollections "$f" "X")"; then
			echo TRUE
			echo "$f"
			echo "$GNAM"
			echo "$GUI_Y"
			echo "$f" >> "$VGNSCLIST"
		else
			if grep -q "^USEVORTEX=\"0\"" "$STLGAMEDIRID/${f}.conf" || ! grep -q "^USEVORTEX=" "$STLGAMEDIRID/${f}.conf"; then
				echo FALSE
				echo "$f"
				echo "$GNAM"
				echo "$GUI_N"
			else
				echo TRUE
				echo "$f"
				echo "$GNAM"
				echo "$GUI_N"
			fi
		fi
	done <<< "$(printf "%s\n" "${INSTVGAMES[@]}")" | \
	"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist --column="Use Vortex" --column="Game ID" --column="Game Title" --column "Vortex Steam Collection" --separator=";" --print-column="2" \
	--text="$(spanFont "$GUI_VINFO" "H")\n<span font=\"italic\">($GUI_VINFO1)</span>" --title="$TITLE" "$GEOM")"
	case $? in
		0)
			while read -r checkvgame; do
				VGNAM="$(grep "^$checkvgame" "$VGNLIST" | awk -F ';' '{print $2}')"
				GVCFG="$STLGAMEDIRID/${checkvgame}.conf"

				if ! grep -q "$checkvgame" <<< "${VINGAMES[@]}"; then
					writelog "INFO" "${FUNCNAME[0]} - Disabling ${VTX^} for '$VGNAM' in '$GVCFG', if not already disabled"
					touch "$FUPDATE"
					updateConfigEntry "USEVORTEX" "0" "$GVCFG"
					if grep -q "$checkvgame" "$VGNSCLIST" 2>/dev/null; then
						writelog "WARN" "${FUNCNAME[0]} - To really disable ${VTX^} for '$VGNAM', the game needs to be removed from the ${VTX^} Steam Collection manually"
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - Enabling ${VTX^} for '$VGNAM' if not already enabled"
					touch "$FUPDATE"
					updateConfigEntry "USEVORTEX" "1" "$GVCFG"
				fi

			done <<< "$(printf "%s\n" "${INSTVGAMES[@]//\"/}")"

		;;
		1) writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL"
		;;
	esac

	rm "$VGNLIST" "$VGNSCLIST" 2>/dev/null
}

function VortexSymDialog {
	setVortexVars
	VPDRC="$VORTEXPFX/$DRC"
	if [ -d "$VPDRC" ]; then
		export CURWIKI="$PPW/${VTX^}"
		TITLE="${PROGNAME}-${VTX^} Symlinks"
		pollWinRes "$TITLE"

		setShowPic

		cd "$VPDRC" >/dev/null || return
		find . -type l -printf '%p\n%l\n' | "$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --column="Symlink in '${VPDRC}/'" --column="Points to Game WinePrefix" --print-column="1" \
		--text="$(spanFont "$GUI_VOSY" "H")\n" --title="$TITLE" "$GEOM"
		cd - >/dev/null || return
	else
		writelog "SKIP" "${FUNCNAME[0]} - Directory '$VPDRC' not found "
	fi
}

function getVortexSupported {
	function gVSIDs {
		SDIR="$1"
		if [ -d "$SDIR" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Searching for SteamIDs in '$SDIR'"
			mapfile -t -O "${#VOSTIDS[@]}" VOSTIDS <<< "$(grep -iR "STEAMAPP_ID =\|STEAM_ID =\|steamAppId:" "$SDIR" | grep -v "module.exports" | grep -oP "'\K[^']+" | grep "[0-9]" | sort -u)"
		fi
	}

	setVortexVars
	VGPDIR="$VORTEXINSTDIR/$RABP"
	VUPDIR="$VORTEXPFX/$DRCU/$STUS/$APDA/Vortex/plugins"

	gVSIDs "$VGPDIR"
	gVSIDs "$VUPDIR"
}

# If extra formatting is added this file may need updated
function getVortexSupportedNames {
	VOSTINDEXJS="index.js"
	VOSTINFOJSON="info.json"

	VORTEXPFX="${VORTEXCOMPDATA//\"/}/pfx"
	setVortexVars
	VORTEXINSTDIR="${VORTEXINSTDIR:-$VORTEXPFX/$BTVP}"
	VORTEXEXE="$VORTEXINSTDIR/${VTX^}.exe"

	if [ ! -f "$VORTEXEXE" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Cannot get Vortex game list - No Vortex executable at '$VORTEXEXE' - Vortex may not be installed"
		echo "Cannot get Vortex game list - Are you sure Vortex is installed?"
		return
	fi

	VGPDIR="$VORTEXINSTDIR/$RABP"
	for VOSTGAMDIR in "$VGPDIR/game-"*/; do
		if [ -f "$VOSTGAMDIR/$VOSTINDEXJS" ] && [ -f "$VOSTGAMDIR/$VOSTINFOJSON" ]; then
			# Get Vortex game name from the Vortex supported gamedir's `info.json` file
			VOSTGAMDIRNAM="$( "$JQ" '.name' "$VOSTGAMDIR/$VOSTINFOJSON" | sed 's-^"--g;s-^Game:--g;s-"$--g;s-^Stub:--g;s-^Game--g;s-^\ --g' )"

			# Match Steam AppIDs from `index.js` file - grep order is order if preference to search on
			VOSTGAMDIRAID="$( sed "s-'--g;s-\"--g" "$VOSTGAMDIR/$VOSTINDEXJS" | grep -ioE "steamAppId: [0-9]+|STEAMAPP_ID = [0-9]+|STEAM_ID = [0-9]+|APPID = [0-9]+|steamId: [0-9]+" | grep -oE "[0-9]+" | head -n1 )"

			# If we still can't find it, search based on domain name (usually this is directory name without game- pfx) from Vortex games list, may be incomplete so we don't search on it by default
			if [ -z "$VOSTGAMDIRAID" ]; then
				VORTEXGAMES="$GLOBALMISCDIR/$VOGAT"
				VSGDN="$( basename "$VOSTGAMDIR" | sed 's:game-::g' )"
				VOSTGAMDIRAID="$( grep -im1 "$VSGDN" "$VORTEXGAMES" | cut -d ";" -f 3 | cut -d '"' -f 2 )"
				# If we STILL can't find it, search Vortex games list based on the game's "full" name in `info.json`
				if [ -z "$VOSTGAMDIRAID" ]; then
					VOSTGAMDIRAID="$( grep -im1 "$VOSTGAMDIRNAM" "$VORTEXGAMES" | cut -d ";" -f 3 | cut -d '"' -f 2 )"
					# Special hack for kotor as Vortex groups these two games together annoyingly and doesn't list them separately - an improved way to handle this would be welcome
					if [[ $VOSTGAMDIRNAM = *"Knights of the Old Republic"* ]]; then
						printf "Star Wars: Knights of the Old Republic (32370)\nStar Wars: Knights of the Old Republic II (208580)\n"
						continue
					fi
				fi
			fi

			printf '%s (%s)\n' "$VOSTGAMDIRNAM" "$VOSTGAMDIRAID"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Could not find '$VOSTINDEXJS' or '$VOSTINFOJSON' for Vortex game in '$VOSTGAMDIR' - Skipping"
		fi
	done
}

function checkVortexRegs {
	function addReg {
		MODGREG="$STLSHM/modgames.reg"
		if [ ! -f "$MODGREG" ]; then
			echo "Windows Registry Editor Version 5.00" > "$MODGREG"
		fi
		{
			echo "[$1]"
			echo "\"$2\"=\"$3\""
		} >> "${MODGREG}"
	}

	if grep -q "Wow6432Node" <<< "$1"; then
		REGKEY="$1"
		REG32KEY="${REGKEY//\\Wow6432Node\\/}"
	elif grep -q "WOW6432Node" <<< "$1"; then
		REGKEY="${1//WOW6432Node/Wow6432Node}"
		REG32KEY="${REGKEY//\\Wow6432Node\\/}"
	else
		REG32KEY="$1"
		REGKEY="${REG32KEY//Software\\\\/Software\\\\Wow6432Node\\\\}"
	fi
	PATHKEY="$2"
	INSTP="$3"

	writelog "INFO" "${FUNCNAME[0]} - Checking RegKey '$REGKEY' and updating RegKey '$REG32KEY' in registry for game '$NEXUSGAMEID' now"

	# check if registry path exists:
	if wineVortexRun "$VORTEXWINE" reg QUERY "$REGKEY" >/dev/null ; then
		writelog "INFO" "${FUNCNAME[0]} - Registry path $REGKEY already set"
		# value of the currently set registry path:
		REGPATH="$(wineVortexRun "$VORTEXWINE" reg QUERY "$REGKEY" | grep -i "$PATHKEY" | awk -F 'REG_SZ' '{print $NF}' | awk '{$1=$1};1' | tr -d "\n\r")"
		if [ "$REGPATH" == "${INSTP//\\\\/\\}" ]; then
			writelog "INFO" "${FUNCNAME[0]} - The registry entry '$REGPATH' for '$PATHKEY' is identical to the gamepath '${INSTP//\\\\/\\}'"
		else
			if [ -n "$REGPATH" ]; then
				writelog "WARN" "${FUNCNAME[0]} - The registry entry '$REGPATH' for '$PATHKEY' is not equal to gamepath '${INSTP//\\\\/\\}' - resetting registry to '${INSTP//\\\\/\\}'"
			else
				writelog "WARN" "${FUNCNAME[0]} - The registry entry for '$PATHKEY' is empty - resetting registry to '${INSTP//\\\\/\\}'"
			fi
			wineVortexRun "$VORTEXWINE" reg DELETE "$REGKEY" /f >/dev/null
		fi
	else
		writelog "NEW" "${FUNCNAME[0]} - Registry path '$REGKEY' does not exist - creating '$PATHKEY' entry for '$INSTP'"
	fi
	if [ -n "$INSTP" ]; then
		addReg "$REG32KEY" "$PATHKEY" "$INSTP"
	else
		writelog "SKIP" "${FUNCNAME[0]} - INSTP is empty - REG32KEY is '$REG32KEY' and PATHKEY is '$PATHKEY'"
	fi
}

function setVortSet {
	echo "${VTX^}.exe --set $1" >> "$VORTSETCMD"
}

function runVortex {
	cd "$VORTEXINSTDIR" >/dev/null || return
	# VORTEXDISABLEGPU: Vortex (Electron) can fail to composite its window under
	# Proton on some setups (hybrid graphics, ANGLE/DXVK/Vulkan), leaving the
	# window permanently white - Chromium's software renderer avoids that
	if [ -z "$VORTEXDISABLEGPU" ]; then
		VORTEXDISABLEGPU=1
	fi
	if [ "$VORTEXDISABLEGPU" -eq 1 ]; then
		VORTEXGPUBUT=("--disable-gpu")
	else
		VORTEXGPUBUT=()
	fi
	if [ -n "$VORTEXARGS" ] && [ "$VORTEXARGS" != "$NON" ]; then
		wineVortexRun "$VORTEXWINE" "${VTX^}.exe" "--force-device-scale-factor=${VORTEXDEVICESCALEFACTOR}" "${VORTEXGPUBUT[@]}" "$VORTEXARGS" "$@"
	else
		wineVortexRun "$VORTEXWINE" "${VTX^}.exe" "--force-device-scale-factor=${VORTEXDEVICESCALEFACTOR}" "${VORTEXGPUBUT[@]}" "$@"
	fi
	cd - >/dev/null || return
}

function runVortSetCmd {
	if [ -f "$VORTSETCMD" ]; then
		rmDupLines "$VORTSETCMD"
		cd "$VORTEXINSTDIR" >/dev/null || return
		wineVortexRun "$VORTEXWINE" "$VORTSETCMD"
		cd - >/dev/null || return
	fi
}

function setVortexDLPath {
	# configure Vortex Download Dir:
	if [ ! -d "$VORTEXDOWNLOADPATH" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating ${VTX^} Download Dir '$VORTEXDOWNLOADPATH'"
		mkProjDir "$VORTEXDOWNLOADPATH"
	fi

	VDPF="$VORTEXDOWNLOADPATH/__vortex_downloads_folder"
	if [ ! -f "$VDPF" ]; then
		echo "{\"instance\":\"empty\"}" > "$VDPF"
	fi

	VORTEXDOWNLOADWINPATH="Z:${VORTEXDOWNLOADPATH//\//\\\\}"
	writelog "INFO" "${FUNCNAME[0]} - Setting ${VTX^} Download WinDir '$VORTEXDOWNLOADWINPATH' in ${VTX^}"
	echo "@echo off" > "$VORTSETCMD"
	setVortSet "settings.downloads.path=true"
	setVortSet "settings.downloads.path=\\\"$VORTEXDOWNLOADWINPATH\\\""
}

function setGameVortexStaging {
	VGAMEDIR="$1"

	if [ ! -d  "$VGAMEDIR" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - argument 1 '$1' is no valid directory - can't continue"
	else
		writelog "INFO" "${FUNCNAME[0]} - Looking for the mount point of the partition where the game dir '$VGAMEDIR' is"
		# find matching Staging Directory:
		GAMEMP="$( df --output=target "$VGAMEDIR" | tail -n1 )"  # df returns "Mounted on" heaqding, use tail to get actual path (using this method ensures file paths with spaces work too)
		writelog "INFO" "${FUNCNAME[0]} - Mount point of partition where the game is installed: '$GAMEMP'"
		unset CONFSTAGE VORTEXSTAGING

		if [ -f "$VORTEXSTAGELIST" ]; then
			CONFSTAGE="$(grep "${GAMEMP}/" "$VORTEXSTAGELIST")"
		fi

		if [ -n "$CONFSTAGE" ]; then
			if [ -d "$CONFSTAGE" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Configured VORTEXSTAGING dir found: '$CONFSTAGE'"
				VORTEXSTAGING="$CONFSTAGE"
			else
				writelog "ERROR" "${FUNCNAME[0]} - Configured entry '$CONFSTAGE' found in '$VORTEXSTAGELIST', but this isn't a useable directory"
			fi
		fi

		if [ -z "$VORTEXSTAGING" ]; then
			if [ "$DISABLE_AUTOSTAGES" -eq 1 ]; then
				writelog "SKIP" "${FUNCNAME[0]} - VORTEXSTAGING is empty and autostages was disabled by the user - skipping vortex"
				USEVORTEX="0"
			else
				PARTLOG=" - using that as VORTEXSTAGING dir for all games on partition' $GAMEMP'"
				HOMEMP="$(df -P "${STLVORTEXDIR%/*}" | awk 'END{print $NF}')"
				writelog "INFO" "${FUNCNAME[0]} - HOMEMP is $HOMEMP and GAMEMP is $GAMEMP"

				# don't pollute base steam installation with a ~/.steam/steam/Vortex dir, so default to $STLVORTEXDIR/stageing
				if [ "$GAMEMP" == "$HOMEMP" ]; then
					getVortexStage "$STLVORTEXDIR/staging"
				fi

				# try in base directory of the partition:
				getVortexStage "$GAMEMP/${VTX^}"

				# then try in the current SteamLibrary dir besides steamapps, as it should be writeable by the user and is unused from steam(?):
				getVortexStage "$(awk -F 'steamapps' '{print $1}' <<< "$VGAMEDIR")${VTX^}"

				# updating Vortex config with the new found VORTEXSTAGING dir:
				touch "$VORTEXSTAGELIST"
				if [ -n "$VORTEXSTAGING" ]; then
					if ! grep -q "$VORTEXSTAGING" < "$VORTEXSTAGELIST"; then
						writelog "INFO" "${FUNCNAME[0]} - Adding '$VORTEXSTAGING' to the ${VTX^} Stage List '$VORTEXSTAGELIST'"
						addVortexStage "$VORTEXSTAGING"
					fi
				fi
			fi
		fi

		if [ -z "$VORTEXSTAGING" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - No useable staging directory autodetected - giving up"
			USEVORTEX="0"
		fi

		if [ -n "$VORTEXSTAGING" ]; then
			writelog "INFO" "${FUNCNAME[0]} - VORTEXSTAGING set to '$VORTEXSTAGING' - configuring '$NEXUSGAMEID' Staging folder installPath"
			VGSGM="$VORTEXSTAGING/$NEXUSGAMEID/mods"

			writelog "INFO" "${FUNCNAME[0]} - Creating ${VTX^} Staging folder '$VGSGM'"
			mkProjDir "$VGSGM"

			VGSGMSF="$VGSGM/__vortex_staging_folder"
			if [ ! -f "$VGSGMSF" ]; then
				echo "{\"instance\":\"empty\",\"game\":\"NEXUSGAMEID\"}" > "$VGSGMSF"
			fi

			GAMESTAGINGWINFOLDER="Z:${VGSGM//\//\\\\}"
			GAMESTAGINGWINFOLDER="${GAMESTAGINGWINFOLDER//$NEXUSGAMEID/\{GAME\}}"
			writelog "INFO" "${FUNCNAME[0]} - Setting Staging folder '$GAMESTAGINGWINFOLDER' in Vortex"

			setVortSet "settings.mods.installPath.$NEXUSGAMEID=true"
			setVortSet "settings.mods.installPath.$NEXUSGAMEID=\"\\\"$GAMESTAGINGWINFOLDER\\\"\""
			setVortSet "settings.mods.activator.$NEXUSGAMEID=\"\\\"hardlink_activator\\\"\""
		fi
	fi
}

function activateVortexGame {
	NEXUSGAMEID="$(grep "\"$1\"" "$VORTEXGAMES" | cut -d ';' -f1)"
	NEXUSGAMEID="${NEXUSGAMEID//\"}"
	if [ -n "$NEXUSGAMEID" ]; then
			NEXRAND="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 9 | head -n1)" # valid?
			writelog "INFO" "${FUNCNAME[0]} - Activating game '$NEXUSGAMEID' ($1) in ${VTX^}" "E"
			setVortSet "settings.mods.activator.$NEXUSGAMEID=\"\\\"hardlink_activator\\\"\""
			setVortSet "settings.profiles.activeProfileId=\"\\\"$NEXRAND\\\"\""
			setVortSet "settings.profiles.lastActiveProfile.$NEXUSGAMEID=\"\\\"$NEXRAND\\\"\""
			setVortSet "settings.profiles.nextProfileId=\"\\\"$NEXRAND\\\"\""
			runVortSetCmd
	else
		writelog "ERROR" "${FUNCNAME[0]} - No valid  NEXUSGAMEID found for '$1'" "E"
	fi
}

function setupGameVortex {
	VZGAMEDIR="Z:${1//\//\\\\}"
	VORTGETSET="$STLSHM/vortgetset.txt"

	if [ ! -f "$VORTGETSET" ]; then
		WINEDEBUG="-all" WINEPREFIX="$VORTEXPFX" "$VORTEXWINE" "$VORTEXEXE" "--get" "settings" > "$VORTGETSET" 2>/dev/null
	fi

	if [ -f "$VORTGETSET" ] && grep -q "$NEXUSGAMEID=\"hardlink_activator\"" "$VORTGETSET"; then
		writelog "SKIP" "${FUNCNAME[0]} - '$NEXUSGAMEID' is already added to Vortex"
	else
		writelog "INFO" "${FUNCNAME[0]} - Activating game dir '$VZGAMEDIR' for '$NEXUSGAMEID ($VAID)' in Vortex"
		setVortSet "settings.gameMode.discovered.$NEXUSGAMEID.environment.SteamAPPId=\"\\\"$VAID\\\"\""
		setVortSet "settings.gameMode.discovered.$NEXUSGAMEID.hidden=false"
		setVortSet "settings.gameMode.discovered.$NEXUSGAMEID.path=true"
		setVortSet "settings.gameMode.discovered.$NEXUSGAMEID.path=\"\\\"$VZGAMEDIR\\\"\""
		setVortSet "settings.gameMode.discovered.$NEXUSGAMEID.pathSetManually=true"
	fi
}

function setInstPathReg {
	NEXUSGAMEFILE="$VORTEXINSTDIR/$RABP/game-$NEXUSGAMEID/index.js"

	if [ ! -f "$NEXUSGAMEFILE" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Could not find '$NEXUSGAMEFILE' - maybe ${VTX} uses a different name for the game than '$NEXUSGAMEID'?"
	else
		writelog "INFO" "${FUNCNAME[0]} - Found '$NEXUSGAMEFILE' - looking for usable data"

		# search registry install path in NEXUSGAMEFILE
		if grep -E 'instPath.*winapi.RegGetValue' "$NEXUSGAMEFILE" -A1 | grep "HKEY_LOCAL_MACHINE" -q ; then
			writelog "INFO" "${FUNCNAME[0]} - Found some instPath registry value in '$NEXUSGAMEFILE' - trying to extract it"
			REGKEY=""
			PATHKEY=""
			RAWREG="$(grep -E 'instPath.*winapi.RegGetValue' "$NEXUSGAMEFILE" -A3 | tr -d "\n\r" | awk -F 'RegGetValue' '{print $2}' | cut -d';' -f1 | tr -s " " | sed "s:^(::g" | sed "s:)$::g" | sed 's/, /,/g' | awk '{$1=$1;print}')"

			if [ -n "$RAWREG" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Analyzing found registry snippet $RAWREG"

				if grep -q "HKEY" <<< "$RAWREG"; then
					writelog "INFO" "${FUNCNAME[0]} - Found a HKEY entry: $RAWREG - working on it"
					SNIP="','S" # :)
					REGWIP1="${RAWREG//HINE$SNIP/HINE\\S}"
					REGWIP="${REGWIP1//T_USER','S/T_USER\\\\S}"

					writelog "INFO" "${FUNCNAME[0]} - REGWIP is $REGWIP"

					REGWIPKEY="$(awk -F ',' '{print $1}' <<< "$REGWIP" | sed "s:'::g")"
					PATHKEY="$(awk -F ',' '{print $2}' <<< "$REGWIP" | sed "s:'::g")"

					if grep -q -i "WOW6432Node" <<< "$REGWIPKEY"; then
						writelog "INFO" "${FUNCNAME[0]} - Squeezing in a 'WOW6432Node' into the '$REGWIPKEY' string"
						REGKEY="${REGWIPKEY/[Ss][Oo][Ff][Tt][Ww][Aa][Rr][Ee]/Software\\\\\\WOW6432Node}"
					else
						REGKEY="$REGWIPKEY"
					fi

					writelog "INFO" "${FUNCNAME[0]} - Final REGKEY is '$REGKEY'"
				else
					if grep -q "hive" <<< "$RAWREG"; then
						writelog "INFO" "${FUNCNAME[0]} - Found a hive, key, name placeholder - required?"
					else
						writelog "SKIP" "${FUNCNAME[0]} - No valid registry found in cut entry '$RAWREG' - skipping"
					fi
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - Haven't found any useable registry entries in '$NEXUSGAMEFILE' - skipping registry insert"
			fi

			# insert registry key when found:
			if [ -n "$REGKEY" ] && [ -n "$PATHKEY" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Inserting registry key '$REGKEY' '$PATHKEY' 'Z:${VGAMEDIR//\//\\\\}'"
				checkVortexRegs "$REGKEY" "$PATHKEY" "Z:${VGAMEDIR//\//\\\\}"
			else
				writelog "SKIP" "${FUNCNAME[0]} - REGKEY '$REGKEY' or PATHKEY '$PATHKEY' is empty - skipping registry insert"
			fi
		fi
	fi
}

function prepareVortexGame {
	VAID="$1"

	if [ -z "$VAID" ]; then
		return
	fi

	if grep -q "\"$VAID\"" "$SEENVORTEXGAMES" 2>/dev/null; then
		NEXUSGAMEID="$(grep "\"$VAID\"" "$VORTEXGAMES" | cut -d ';' -f1)"
		writelog "INFO" "${FUNCNAME[0]} - '$NEXUSGAMEID ($VAID)' is already setup for '${VTX^}' - remove from '$SEENVORTEXGAMES' for retry"
	else
		if grep -q "\"$VAID\"" "$VORTEXGAMES"; then
			if [ -z "$NEXUSGAMEID" ]; then
				NEXUSGAMEID="$(grep "\"$VAID\"" "$VORTEXGAMES" | cut -d ';' -f1)"
				NEXUSGAMEID="${NEXUSGAMEID//\"}"
				updateConfigEntry "NEXUSGAMEID" "$NEXUSGAMEID" "$STLGAMECFG"
				updateConfigEntry "NEXUSGAMEID" "$NEXUSGAMEID" "$GEMETA/$AID.conf"
			fi

			VGNAME="$(grep "\"$VAID\"" "$VORTEXGAMES" | cut -d ';' -f2)"
			VGNAME="${VGNAME//\"}"
			writelog "INFO" "${FUNCNAME[0]} - $(strFix "$NOTY_PREPVTX" "$VGNAME" "$VAID" "$NEXUSGAMEID")"
			notiShow "$(strFix "$NOTY_PREPVTX" "$VGNAME" "$VAID" "$NEXUSGAMEID")" "S"
			# prepare symlinks in VORTEXPFX
			VAPPMAFE="$(listAppManifests | grep -m1 "${VAID}.acf")"
			VGPFX="$(setGPfxFromAppMa "$VAID" "$VAPPMAFE")"

			GPFXSTUS="$VGPFX/$DRCU/$STUS"
			if [ -d "$GPFXSTUS" ]; then
				setModGameSyms "set" "$VGPFX" "$VGNAME" "$VAID" "$VORTEXPFX" "$VAPPMAFE"
				VGAMEDIR="$(getGameDirFromAID "$VAID")"
				writelog "INFO" "${FUNCNAME[0]} - Game dir for '$VAID' found is: '$VGAMEDIR')"
				setInstPathReg
				checkVortexRegs "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Valve\Steam\Apps\$VAID" "Installed Path" "Z:${VGAMEDIR//\//\\\\}"
				setModGameReg "$VORTEXPFX" "$VORTEXWINE"
			fi

			grep "\"$VAID\"" "$VORTEXGAMES" >> "$SEENVORTEXGAMES"
			rmDupLines "$SEENVORTEXGAMES"
			if [ ! -d  "$VGAMEDIR" ]; then
				writelog "ERROR" "${FUNCNAME[0]} - variable VGAMEDIR '$VGAMEDIR' is no valid directory - can't continue"
			elif [ -z  "$VGAMEDIR" ]; then
				writelog "ERROR" "${FUNCNAME[0]} - variable VGAMEDIR does not exist - can't continue"
			else
				setupGameVortex "$VGAMEDIR"
				setGameVortexStaging "$VGAMEDIR"
			fi

			if [ -z "$2" ]; then
				writelog "INFO" "${FUNCNAME[0]} - $(strFix "$NOTY_APPLVTX" "$NEXUSGAMEID" "$VORTSETCMD")"
				notiShow "$(strFix "$NOTY_APPLVTX" "$NEXUSGAMEID" "$VORTSETCMD")" "S"
				runVortSetCmd
				writelog "INFO" "${FUNCNAME[0]} - Symlinks, registry entries and $VTX settings for '$NEXUSGAMEID' should be ready at this point for ${VTX^}"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Skip game '$VAID' is not supported by ${VTX^} or the ID is not listed in '$VORTEXGAMES'" "E"
		fi
	fi
}

function prepareAllInstalledVortexGames {
	writelog "INFO" "${FUNCNAME[0]} - Preparing all installed games supported by ${VTX^}" "E"
	setVortexVars
	while read -r line; do
		unset NEXUSGAMEID
		prepareVortexGame "$line" "X"
	done <<< "$(getInstalledGamesWithVortexSupport X)"
	writelog "INFO" "${FUNCNAME[0]} - Applying ${VTX^} settings for all games via autogenerated cmd '$VORTSETCMD'" "E"
	runVortSetCmd
	writelog "INFO" "${FUNCNAME[0]} - Symlinks, registry entries and $VTX settings for all found supported games should be ready at this point for ${VTX^}" "E"
}

function setVortexNoDecoration {
	if [ "$VORTEXNODECORATION" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - VORTEXNODECORATION is 1 - setting Wine X11 Driver 'Decorated' to 'N' in the ${VTX^} prefix so no WM/DE window title bar is drawn for ${VTX^}"
		wineVortexRun "$VORTEXWINE" reg ADD "HKCU\Software\Wine\X11 Driver" /v Decorated /t REG_SZ /d N /f >/dev/null 2>&1
	else
		writelog "INFO" "${FUNCNAME[0]} - VORTEXNODECORATION is 0 - leaving the default window title bar for ${VTX^}"
		wineVortexRun "$VORTEXWINE" reg ADD "HKCU\Software\Wine\X11 Driver" /v Decorated /t REG_SZ /d Y /f >/dev/null 2>&1
	fi
}

function listVortexSteamLibraries {
	# Modern Vortex parses libraryfolders.vdf with the simple-vdf package and
	# expects the nested per-library format Steam has written since ~2020:
	#
	#   "libraryfolders"
	#   {
	#       "0"
	#       {
	#           "path"   "Z:\\home\\...\\Steam"
	#       }
	#   }
	#
	# The legacy flat form ("1" "Z:\\path") once written here is no longer
	# understood, which left Vortex with an empty Steam playground.  Keep the
	# legacy emitter (listWinSteamLibraries) for MO2, which still reads it.
	listSteamLibraries

	unset SLARR
	SL1="${SROOT%*/}"
	mapfile -t -O "${#SLARR[@]}" SLARR <<< "$SL1"

	while read -r line; do
		W1="${line//\/steamapps/}"
		mapfile -t -O "${#SLARR[@]}" SLARR <<< "$W1"
	done < "$STELILIST"

	unset SLARRU
	while IFS= read -r SLC; do
		if ! grep -qx "$SLC" <<< "$(printf "%s\n" "${SLARRU[@]-}")"; then
			mapfile -t -O "${#SLARRU[@]}" SLARRU <<< "$SLC"
		fi
	done <<< "$(printf "%s\n" "${SLARR[@]-}")"

	COUNTER=0
	for W1 in "${SLARRU[@]}"; do
		W2="${W1//\//\\\\}"
		printf "\"%s\"\n{\n\t\"path\"\t\t\"Z:%s\"\n\t\"label\"\t\t\"\"\n}\n" "$COUNTER" "$W2"
		COUNTER=$((COUNTER+1))
	done
}

function setVortexConfigVdf {
	mkdir -p "$VORTEXPFX/$DRC/$PFX86S/config"
	mkdir -p "$VORTEXPFX/$DRC/$PFX86S/$SAC"
	VTXSTCFG="$VORTEXPFX/$DRC/$PFX86S/$COCOV"
	writelog "INFO" "${FUNCNAME[0]} - Updating '$COCOV' in the ${VTX^} pfx, to make newly games available when auto-detectable"
	cp "$CFGVDF" "$VTXSTCFG"
	while read -r line; do
		BIF="$(awk '{print $2}' <<< "$line")"
		BIF="${BIF//\"}"
		# modern Steam keeps libraries in libraryfolders.vdf - config.vdf may
		# not contain any BaseInstallFolder (or an empty) line to rewrite
		if [ -n "$BIF" ]; then
			sed "s:$BIF:Z\:$BIF:" -i "$VTXSTCFG"
		fi
	done <<< "$(grep "BaseInstallFolder" "$VTXSTCFG")"

	VTXSTEAMDIR="$VORTEXPFX/$DRC/$PFX86S/config"
	VTXLFVD="$VTXSTEAMDIR/$LIFOVDF"
	writelog "INFO" "${FUNCNAME[0]} - Updating '$LIFOVDF' in the ${VTX^} pfx, so ${VTX^} can find the Steam game libraries"
	rm "$VTXLFVD" 2>/dev/null
	{
		echo "\"libraryfolders\""
		echo "{"
		listVortexSteamLibraries
		echo "}"
	} >> "$VTXLFVD"

	# Vortex resolves its Steam base folder from HKCU\Software\Valve\Steam,
	# value SteamPath, before it reads libraryfolders.vdf.  No real Steam is
	# installed into this prefix, so that key is missing and Vortex ends up
	# with no libraries at all - point it at the virtual Steam dir we just
	# populated (C:\Program Files (x86)\Steam inside this prefix).
	wineVortexRun "$VORTEXWINE" reg ADD "HKCU\\Software\\Valve\\Steam" /v SteamPath /t REG_SZ /d "C:\\${PFX86S//\//\\}" /f >/dev/null 2>&1
}

function purgeVortexCache {
	setVortexVars
	if [ ! -f "$VORTEXEXE" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - No ${VTX^} executable found at '$VORTEXEXE' - nothing to purge. Install/start ${VTX^} first." "E"
		return
	fi

	# Vortex caches the Steam library list and discovery state in memory for
	# the lifetime of the process and writes it back on exit, so a corrected
	# libraryfolders.vdf/SteamPath is ignored until the app is restarted.
	# Kill every Vortex instance plus the prefix wineserver (which holds the
	# tray/background helpers alive and can re-write stale state), then re-run
	# the settings reset so the next Vortex start re-scans from scratch.
	writelog "INFO" "${FUNCNAME[0]} - Killing any running ${VTX^} instances to clear the stale Steam inventory cache"
	if [ -n "$PGREP" ] && "$PGREP" -f "$VORTEXINSTDIR/Vortex.exe" >/dev/null 2>&1; then
		"$PKILL" -9 -f "$VORTEXINSTDIR/Vortex.exe" 2>/dev/null
	fi
	if [ -n "$PGREP" ] && "$PGREP" -f "Black Tree Gaming" >/dev/null 2>&1; then
		"$PKILL" -9 -f "Black Tree Gaming" 2>/dev/null
	fi

	if [ -n "$VORTEXWINE" ] && [ -d "$VORTEXPFX" ]; then
		if command -v wineserver >/dev/null 2>&1; then
			writelog "INFO" "${FUNCNAME[0]} - Stopping the ${VTX^} prefix wineserver"
			WINEPREFIX="$VORTEXPFX" wineserver -k >/dev/null 2>&1
		fi
	fi

	writelog "INFO" "${FUNCNAME[0]} - Rebuilding ${VTX^} Steam detection and game registration"
	resetVortexSettings
}

function resetVortexSettings {
	setVortexVars
	if [ ! -f "$VORTEXEXE" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - No ${VTX^} executable found at '$VORTEXEXE' - reset has nothing to configure. Install/start ${VTX^} first." "E"
		return
	fi
	runVortex "--get" "settings"
	grep -v "^info: Epic" "$VWRUN" > "$STLSHM/vortsetbefore.txt"
	rm "$VWRUN" 2>/dev/null
	setVortexDLPath
	setVortexConfigVdf
	rm "$SEENVORTEXGAMES" 2>/dev/null
	prepareAllInstalledVortexGames
	runVortex "--get" "settings"
	grep -v "^info: Epic" "$VWRUN" > "$STLSHM/vortsetafter.txt"

	writelog "INFO" "${FUNCNAME[0]} - Diff between ${VTX^} settings before and after reset:" "E"
	diff -u "$STLSHM/vortsetbefore.txt" "$STLSHM/vortsetafter.txt"
}

function setVortexReleaseChannel {
	# Vortex settings.update.channel can be either 'stable', 'beta', or 'none' (where 'none' is 'No automatic updates')
	writelog "INFO" "${FUNCNAME[0]} - DISABLEVORTEXAUTOUPDATE is '1'"
	VTXUPDATECHANNEL="stable"
	if [ "$DISABLEVORTEXAUTOUPDATE" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Disabling Vortex automatic updates"
		VTXUPDATECHANNEL="none"
	else
		if [ "$USEVORTEXPRERELEASE" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Setting Vortex to use Pre-Release channel"
			VTXUPDATECHANNEL="beta"
		else
			writelog "INFO" "${FUNCNAME[0]} - Setting Vortex to use Stable channel"
			VTXUPDATECHANNEL="stable"
		fi
	fi

	setVortSet "settings.update.channel=\"\\\"$VTXUPDATECHANNEL\\\"\""
}

function startVortex {
	setVortexVars
	setVortexSLR
	askVortex "$1"
	if [ "$USEVORTEX" -eq 1 ]; then
		unset VORTEXFORCEUPDATE
		if [ ! -f "$VORTEXEXE" ]; then
			writelog "WARN" "${FUNCNAME[0]} - VORTEXEXE '$VORTEXEXE' does not exist - installing now"
			StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${VTX^}")" "dlLatestVortex S" "DownloadVortexStatus"
			StatusWindow "$(strFix "$NOTY_INSTSTART" "${VTX^}")" "installVortex" "InstallVortexStatus"
			# the installer decides the final install directory (the default
			# changed between Vortex versions) - re-resolve VORTEXEXE instead
			# of trusting the pre-install guess from above
			VORTEXEXE=""
			setVortexInstallDirs
		elif [ -n "$DISABLEVORTEXAUTOUPDATE" ] && [ "$DISABLEVORTEXAUTOUPDATE" -eq 0 ]; then
			# A Vortex install exists - check whether an update is available before launching,
			# so a single "Start" action keeps Vortex up-to-date instead of needing a separate
			# download/install menu. Updated but Vortex is already installed.
			if [ -f "$VORTEXEXE" ] && [ "$VORTEXEXE" != "$NON" ]; then
				INSTVTXVER="$(getInstVtxVers)"
				getLatestVortVer
				LATESTVTXVER="${VORTEXSETUP#"${VTX}"-setup-}"
				LATESTVTXVER="${LATESTVTXVER//.exe}"
				if [ -n "$INSTVTXVER" ] && [ -n "$LATESTVTXVER" ] && [ "$LATESTVTXVER" != "$INSTVTXVER" ] && [ "$(printf '%s\n' "$INSTVTXVER" "$LATESTVTXVER" | sort -V | head -n1)" == "$INSTVTXVER" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Installed ${VTX^} '$INSTVTXVER' is older than latest '$LATESTVTXVER' - updating before launch"
					VORTEXFORCEUPDATE=1
					StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${VTX^}")" "dlLatestVortex S" "DownloadVortexStatus"
					StatusWindow "$(strFix "$NOTY_INSTSTART" "${VTX^}")" "installVortex" "InstallVortexStatus"
				fi
			fi
		fi

		if [ "$RUN_VORTEX_WINETRICKS" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Starting $WINETRICKS before Vortex"
			chooseWinetricks
			WINE="$VORTEXWINE" WINEDEBUG="-all" WINEPREFIX="$VORTEXPFX" "$WINETRICKS"
		fi

		if [ "$RUN_VORTEX_WINECFG" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Starting $WINECFG before Vortex"
			WINE="$VORTEXWINE" WINEDEBUG="-all" WINEPREFIX="$VORTEXPFX" "$WINECFG"
		fi

		if [ -f "$VORTEXEXE" ]; then
			setVortexDLMime
			setVortexDLPath
			setVortexConfigVdf
			setVortexReleaseChannel
			setVortexNoDecoration

			if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
				StatusWindow "${VTX^}" "prepareVortexGame $2" "PrepareVortexGameStatus"
			elif [ -n "$AID" ] && [ "$AID" != "$PLACEHOLDERAID" ]; then
				StatusWindow "${VTX^}" "prepareVortexGame $AID" "PrepareVortexGameStatus"
			fi

			if [ -n "$NEXUSGAMEID" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Starting ${VTX^} now with command 'runVortex \"--game\" \"$NEXUSGAMEID\"' in WINEPREFIX '$VORTEXPFX'"
				runVortex "--game" "$NEXUSGAMEID"
			else
				if [ "$2" == "url" ]; then
					if [ -z "$3" ]; then
						writelog "INFO" "${FUNCNAME[0]} - need arg3"
						howto
					else
						writelog "INFO" "${FUNCNAME[0]} - Starting ${VTX^} now with command 'runVortex \"-d\" \"$3\""
						runVortex "-d" "$3"
					fi
				elif [ "$2" == "getset" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Showing ${VTX^} settings as requested"
					runVortex "--get" "settings"
					grep -v "^info: Epic" "$VWRUN"
					rm "$VWRUN" 2>/dev/null
				elif [ "$1" == "activate" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Activating game '$2'"
					activateVortexGame "$2"
				else
					StatusWindow "${VTX^}" "prepareAllInstalledVortexGames" "PrepareVortexGameStatus"
					writelog "INFO" "${FUNCNAME[0]} - Starting ${VTX^} without options" "E"
					runVortex
				fi
			fi

			cleanVortex
			writelog "INFO" "${FUNCNAME[0]} - ${VTX^} exited - starting game now"
		else
			writelog "ERROR" "${FUNCNAME[0]} - VORTEXEXE '$VORTEXEXE' not found! - exit" "E"
			exit
		fi
	fi
}

function setVortexSELaunch {
	if [ "$1" == "$AID" ] && [ -d "$EFD" ]; then
		SEEXE="$EFD/$2"
		if [ ! -f "$SEEXE" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Special exe '$2' for '$SGNAID' not found in gamedir '$EFD' - starting normal exe"
		else
			writelog "INFO" "${FUNCNAME[0]} - Found special exe '$2' for '$SGNAID' in gamedir '$EFD'"
			export CURWIKI="$PPW/Vortex"
			TITLE="ScriptExtenderRequester"
			pollWinRes "$TITLE"

			"$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --center "${WINDECO[@]}" \
			--title="$TITLE" \
			--text="$GUI_SEBINFOUND '$EFD/$2'" \
			--button="${GE^^}":0 \
			--button="$BUT_SAVERUN ${GE^^}":1 \
			--button="$BUT_SAVERUN ${2^^}":2 \
			"$GEOM"

			case $? in
				0)  {
					writelog "INFO" "${FUNCNAME[0]} - Starting with the regular Game Exe '$GE'"
					USECUSTOMCMD="0"
					}
				;;
				1) 	{
					writelog "INFO" "${FUNCNAME[0]} - Starting with the regular Game Exe '$GE' and don't ask again"
					USECUSTOMCMD="0"
					updateConfigEntry "SELAUNCH" "0" "$STLGAMECFG"
					}
				;;
				2)  {
					writelog "INFO" "${FUNCNAME[0]} - Starting with the Script Extender Exe '$2' and saving as default"
					writelog "INFO" "${FUNCNAME[0]} - Configuring default start of special exe '$2' by enabling SELAUNCH in '$STLGAMECFG'"
					updateConfigEntry "CUSTOMCMD" "$SEEXE" "$STLGAMECFG"
					updateConfigEntry "USECUSTOMCMD" "1" "$STLGAMECFG"
					updateConfigEntry "ONLY_CUSTOMCMD" "1" "$STLGAMECFG"
					updateConfigEntry "SELAUNCH" "0" "$STLGAMECFG"
					CUSTOMCMD="$SEEXE"
					USECUSTOMCMD="1"
					ONLY_CUSTOMCMD=1
					writelog "INFO" "${FUNCNAME[0]} - Starting $SEEXE instead of the game exe directly after this ${VTX^} instance"
					}
				;;
			esac
		fi
	fi
}

function checkVortexSELaunch {
	# (mostly for Vortex)
	# if $1 is 1 check if a preconfigured exe instead of the game is defined/found - f.e. script extender for skyrim, fallout etc
	# if $1 is 2 it is assumed the check already happended before'

	if [ -z "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - using fix '2' as SECHECK"
		SECHECK="2"
	else
		writelog "INFO" "${FUNCNAME[0]} - using argument 1 '$1' as SECHECK"
		SECHECK="$1"
	fi

	if [ "$SECHECK" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - SELAUNCH set to '$SECHECK' - skipping any SE checks and directly starting what is configured in '$STLGAMECFG'"
	else
		if [ "$SECHECK" -eq 2 ] && [ -n "$SELAUNCH" ] && [ "$SELAUNCH" -eq 1 ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Skipping option $SECHECK because SELAUNCH is already enabled"
		else
			setVortexSELaunch "377160" "f4se_loader.exe" "$SECHECK" # Fallout4
			setVortexSELaunch "611660" "f4sevr_loader.exe" "$SECHECK"	# Fallout4 VR
			setVortexSELaunch "611670" "sksevr_loader.exe" "$SECHECK" # Skyrim VR
			setVortexSELaunch "489830" "skse64_loader.exe" "$SECHECK" # Skyrim Special Edition
			setVortexSELaunch "72850" "skse_loader.exe" "$SECHECK"	# Skyrim
			setVortexSELaunch "933480" "skse_loader.exe" "$SECHECK"	# Enderal
			setVortexSELaunch "22300" "fose_loader.exe" "$SECHECK"	# Fallout 3
			setVortexSELaunch "22370" "fose_loader.exe" "$SECHECK"	# Fallout 3 GOTY
			setVortexSELaunch "22380" "nvse_loader.exe" "$SECHECK"	# Fallout New Vegas
			setVortexSELaunch "22330" "obse_loader.exe" "$SECHECK"	# Oblivion
		fi
	fi
}

function getInstVtxVers {
	grep -ahm1 "\"version\": " "${VORTEXINSTDIR}/${VTXRAA}" | cut -d ':' -f2 | cut -d '"' -f2 # fragile
}

function VortexOptions {
	export CURWIKI="$PPW/Vortex"
	TITLE="${PROGNAME}-${FUNCNAME[0]}"

	if [ "$ONSTEAMDECK" -eq 1 ]; then
		pollWinRes "$TITLE" 1
	else
		pollWinRes "$TITLE" 4
	fi

	setShowPic

	VTXHEAD="${VTX^} Options"

	setVortexInstallDirs

	if [ -n "${VORTEXCOMPDATA}" ]; then
		TT_CODA="${VTX^} $CODA: $VORTEXCOMPDATA"
	fi

	if [ -f "${VORTEXINSTDIR}/${VTXRAA}" ]; then
		TT_CODA="$(printf '%s\n%s\n' "${TT_CODA}" "Version installed: $(getInstVtxVers)")"
		VTXISINSTALLED="1"
	else
		VTXISINSTALLED="0"
	fi

	if [ -f "${VORTEXSTAGELIST}" ]; then
		TT_STAGES="$(cat "${VORTEXSTAGELIST}")"
	fi

	if [ -f "${VORTEXINSTDIR}/${VTXRAA}" ]; then
		TT_CODA="$(printf '%s\n%s\n' "${TT_CODA}" "Version installed: $(getInstVtxVers)")"
	fi

	if [ "$ONSTEAMDECK" -eq 1 ]; then
		INVTX="$(realpath "$0") mods vortex install"
	else
		INVTX="$(realpath "$0") mods vortex install gui"
	fi

	# Only present the actions that make sense for the current install state:
	# 'Install' when not installed, 'Start Vortex' when installed, and
	# 'Games'/'Symlinks' only once an installation exists. A standalone
	# 'Download' button is omitted because Install/Start already fetch the
	# latest setup when needed.
	unset VTXFIELDS
	if [ "$VTXISINSTALLED" -eq 0 ]; then
		VTXFIELDS+=( --field="$FBUT_GUISET_VTXINST!$TT_CODA":FBTN "$INVTX" )
	else
		VTXFIELDS+=( --field="$FBUT_GUISET_VTXSTART":FBTN "$(realpath "$0") mods vortex start" )
		VTXFIELDS+=( --field="$FBUT_GUISET_VTXINST!$TT_CODA":FBTN "$INVTX" )
		VTXFIELDS+=( --field="$FBUT_GUISET_VTXGAMES":FBTN "$(realpath "$0") mods vortex games" )
		VTXFIELDS+=( --field="$FBUT_GUISET_VTXSYMS":FBTN "$(realpath "$0") mods vortex symlinks" )
	fi
	VTXFIELDS+=( --field="$FBUT_GUISET_VTXSTAGE!$TT_STAGES":FBTN "$(realpath "$0") mods vortex stage" )

	"$YAD" --image "$SHOWPIC" "${YADIMGTOP[@]}" --center --window-icon="$STLICON" --form "${WINDECO[@]}" --title="$TITLE" \
	--text="$VTXHEAD" --columns="$COLCOUNT" --f1-action="$F1ACTIONCG" --separator="" \
	"${VTXFIELDS[@]}" \
	--button="$BUT_DONE:0" "$GEOM"

	writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_DONE' - Closing Menu"
}

function setModWine {
	USEDNPROTONVAR="$1"
	USEDNPROTON="${!1}"
	DNPROTON="${!2}"
	DNWINEVAR="$3"
	INUVP="$USEDNPROTON"

	if [ -z "$DNPROTON" ] || [ ! -f "$DNPROTON" ]; then
		if [ -z "${ProtonCSV[0]}" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Getting avaialble Proton versions"
			getAvailableProtonVersions "up" X
		fi
		DNPROTON="$(getProtPathFromCSV "$USEDNPROTON")"
		if [ ! -f "$DNPROTON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Proton version mismatch"
			DNPROTON="$(fixProtonVersionMismatch "$USEDNPROTONVAR" "$STLDEFGLOBALCFG" X)"
			writelog "INFO" "${FUNCNAME[0]} - Resolve, USEDNPROTONVAR is now '$USEDNPROTONVAR'"
		fi
		writelog "INFO" "${FUNCNAME[0]} - DNPROTON is '${DNPROTON}'"

		if [ ! -f "$DNPROTON" ]; then
			createDLProtList
			DLURL="$(printf "%s\n" "${ProtonDLList[@]}" | grep -m1 "$USEDNPROTON")"
			if [ -n "$DLURL" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Downloading: '$DLURL'" "E"
				StatusWindow "$GUI_DLCUSTPROT" "dlCustomProton ${DLURL//|/\"}" "DownloadCustomProtonStatus"
				DNPROTON="$(getProtPathFromCSV "$USEDNPROTON")"
			else
				writelog "SKIP" "${FUNCNAME[0]} - No download URL found for requested '$USEDNPROTON' - skipping" "E"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - DNPROTON is a file -- it is '$DNPROTON'"
		fi
	fi

	if [ -n "$DNPROTON" ] && [ -f "$DNPROTON" ]; then
		export "$2"="$DNPROTON"
		CHECKDNWINED="$(dirname "$DNPROTON")/$DBW"
		CHECKDNWINEF="$(dirname "$DNPROTON")/$FBW"

		if [ -f "$CHECKDNWINED" ]; then
			FWINEVAR="$CHECKDNWINED"
		elif [ -f "$CHECKDNWINEF" ]; then
			FWINEVAR="$CHECKDNWINEF"
		else
			writelog "ERROR" "${FUNCNAME[0]} - $DNWINEVAR was not found - can't continue"
		fi

		if [ -f "$FWINEVAR" ]; then
			export "$DNWINEVAR"="$FWINEVAR"
		fi

		if [ "$INUVP" != "$USEDNPROTON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Updating 'USEDNPROTON' in '${STLDEFGLOBALCFG##*/}' to '$USEDNPROTON'" "E"
			touch "$FUPDATE"
			updateConfigEntry "$USEDNPROTONVAR" "$USEDNPROTON" "$STLDEFGLOBALCFG"
		fi
	else
		writelog "ERROR" "${FUNCNAME[0]} - DNPROTON was not found - can't continue" "E"
	fi
}

# Custom function to force SLR for a program outside of Steam running with Proton e.g. Vortex (may also work for One-Time Run)
function setNonGameSLRReap {
	USESLR=1
	HAVESLR=0
	HAVEREAP="${HAVEREAP:-0}"
	HAVESLRCT="${HAVESLRCT:-0}"

	# 0 - No SLR force, let setSLRReap determine what Proton version to use (Default)
	# 1 - Proton SLR
	# 2 - Native SLR
	FORCESLRTYPE="$1"

	# Only get SLRPROTONNAME if we're forcing Proton, otherwise ignore
	if [ -n "$FORCESLRTYPE" ] && [ "$FORCESLRTYPE" -eq 1 ]; then
		SLRPROTONNAME="$( getProtPathFromCSV "$2" )"  # This could be the name of the Proton version to run i.e. Vortex
	fi

	unset "${SLRCMD[@]}"
	setSLRReap "1" "$FORCESLRTYPE" "$SLRPROTONNAME"  # Get SLRCMD, optionally enforcing Proton (so we don't fall back to native Linux) and setting the Proton version to fetch the SLR info from (e.g. whether to use soldier, sniper, etc)
}

# Resolve the Vortex install directory and executable based on what is actually
# installed. Vortex changed its install location over the years: older releases
# install to 'Program Files/Black Tree Gaming Ltd/Vortex', newer ones to
# 'Program Files/Vortex' or - because the installer is Squirrel-based - into the
# per-user 'AppData/Local/Programs/Vortex'. The VORTEXEXE variable is used as a
# cache so a caller that already resolved a valid path (e.g. after
# installation) keeps it.
function setVortexInstallDirs {
	if [ -z "$VORTEXEXE" ] || ! grep -q "exe" <<< "$VORTEXEXE"; then
		VORTEXINSTDIR=""
		for VDIR in "$VORTEXPFX/$BTVP" "$VORTEXPFX/$DRC/Program Files/${VTX^}" \
			"$VORTEXPFX/$DRC/Program Files (x86)/${VTX^}" \
			"$VORTEXPFX/$DRCU/$STUS/$ADLO/Programs/${VTX^}"; do
			if [ -f "$VDIR/${VTX^}.exe" ]; then
				VORTEXINSTDIR="$VDIR"
				break
			fi
		done
		if [ -z "$VORTEXINSTDIR" ]; then
			# last resort: locate wherever the Vortex installer actually
			# placed the exe (the default dir changed between Vortex versions)
			VORTEXFOUND="$(find "$VORTEXPFX/$DRC" "$VORTEXPFX/$DRC/Program Files" "$VORTEXPFX/$DRC/Program Files (x86)" "$VORTEXPFX/$DRCU" -maxdepth 8 -type f -name "${VTX^}.exe" -print -quit 2>/dev/null)"
			if [ -n "$VORTEXFOUND" ]; then
				VORTEXINSTDIR="$(dirname "$VORTEXFOUND")"
				writelog "INFO" "${FUNCNAME[0]} - Found ${VTX^} executable at '$VORTEXFOUND'"
			fi
		fi
		if [ -z "$VORTEXINSTDIR" ]; then
			VORTEXINSTDIR="$VORTEXPFX/$BTVP"  # fall back to the original default
		fi
		VORTEXEXE="$VORTEXINSTDIR/${VTX^}.exe"
	fi
}

function setVortexVars {
	VORTEXPFX="${VORTEXCOMPDATA//\"/}/pfx"
	setVortexInstallDirs

	if [ "$USEVORTEXPROTON" == "$NON" ]; then
		if [ ! -f "$PROTONCSV" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Looking for available Proton versions"
			getAvailableProtonVersions "up" X
		fi

		if ! grep -q "^GE" "$PROTONCSV"; then
			writelog "INFO" "${FUNCNAME[0]} - Seems like there is no GE Proton available - getting one:"
			autoBumpGE "X"
		fi

		delEmptyFile "$PROTONCSV"

		if [ ! -f "$PROTONCSV" ]; then
			writelog "ERROR" "${FUNCNAME[0]} - Could find '$PROTONCSV'"
		else
			SETVTXPROT="$(grep "^GE" "$PROTONCSV" | sort -V | tail -n1)"
			SETVTXPROT="${SETVTXPROT%%;*}"
			USEVORTEXPROTON="$SETVTXPROT"
			touch "$FUPDATE"
			updateConfigEntry "USEVORTEXPROTON" "$USEVORTEXPROTON" "$STLDEFGLOBALCFG"
			writelog "INFO" "${FUNCNAME[0]} - USEVORTEXPROTON is '$NON', so using latest Proton-GE '$SETVTXPROT' automatically" "E"
		fi
	else
		SETVTXPROT="$USEVORTEXPROTON"
	fi

	export DOTNET_ROOT="$VTX_DOTNET_ROOT"

	writelog "INFO" "${FUNCNAME[0]} - Using $USEVORTEXPROTON for $VTX"

	VORTEXGAMES="$GLOBALMISCDIR/$VOGAT"
	if [ -z "$VORTEXWINE" ] || [ ! -f "$VORTEXWINE" ]; then
		setModWine "SETVTXPROT" "VORTEXPROTON" "VORTEXWINE"
	fi
}

## NOTE: We can't use this in setVortexVars because the SLR should only be used to install Vortex pretty much, but there
## are cases where the user can force it. So we only call this and then unset SLRCMD when necessary. Using this function
## gives us creater control over when the SLR is used because we have to *explicitly* use it (setVortexVars is called
## from a bunch of places).
##
## This can fix prepareAllInstalledVortexGames failing when trying to create links, which it can't seem to do on SteamOS when running in the SLR!!
## See #823 for background.
function setVortexSLR {
	## Both of the SLR options for Vortex assume a valid Vortex Proton version.
	## otherwise the SLR won't be used.

	# Use SLR to install Vortex -- Recommended, see https://github.com/sonic2kk/steamtinkerlaunch/issues/806
	if [ "$VORTEXUSESLR" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - VORTEXUSESLR is '$VORTEXUSESLR', using Steam Linux Runtime to install Vortex"
		setNonGameSLRReap "1" "$USEVORTEXPROTON"  # Force the requested SLR for Vortex Proton version if we enable SLR option
	else
		writelog "INFO" "${FUNCNAME[0]} - Vortex will run WITHOUT the Steam Linux Runtime"
	fi

	## Use SLR for Vortex in general - Not recommended, see https://github.com/sonic2kk/steamtinkerlaunch/issues/828
	if [ "$VORTEXUSESLRPOSTINSTALL" -eq 1 ]; then
		writelog "WARN" "${FUNCNAME[0]} - WARNING: VORTEXUSESLRPOSTINSTALL is '$VORTEXUSESLRPOSTINSTALL', Vortex will be launched with the Steam Linux Runtime -- This may cause problems with mod deployment!"
		setNonGameSLRReap "1" "$USEVORTEXPROTON"
	fi
}

# TODO handle getting passed a custom executable
function installVortex {
	if [ -z "$VORTEXSETUP" ]; then
		if [ -f "$VTST" ]; then
			source "$VTST"
		fi
	fi

	if [ -z "$VSPATH" ]; then
		VSPATH="$VORTEXDLDIR/$VORTEXSETUP"
	fi

	if [ -f "$VSPATH" ]; then
		setVortexVars
		setVortexSLR
		if [ -f "$VORTEXEXE" ] && { [ -z "$VORTEXFORCEUPDATE" ] || [ "$VORTEXFORCEUPDATE" -eq 0 ]; }; then
			writelog "SKIP" "${FUNCNAME[0]} - '$VORTEXEXE' does already exists - nothing to install - skipping" "E"
			notiShow "$(strFix "$NOTY_INSTSTOP" "${VTX^}")" "X"
		else
			if [ ! -f "$VORTEXPROTON" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - VORTEXPROTON '$VORTEXPROTON' not found - can't continue" "E"
				notiShow "$GUI_NOVORTEXPROTON" "X"
			else
				writelog "INFO" "${FUNCNAME[0]} - Using '$VORTEXPROTON' for installation" "E"
				mkProjDir "$VORTEXCOMPDATA"

				## TODO dotnet installation currently fails on Steam Deck because it needs to be installed with the SLR
				## There is no clean way to run Winetricks from the SLR if it's in `/usr/bin/winetricks` or similar, so
				## for now we leave it up to Vortex to install dotnet6.
				##
				## This could be fixed with some hacky symlinking of dotnet perhaps, even temporarily while we install
				## some winetricks components, and then removed afterwards, but this would be a separate feature.
				## Removing this line should helph get Vortex working on SteamOS for now, until they break it again.
				##
				## For context, see https://github.com/sonic2kk/steamtinkerlaunch/issues/806#issuecomment-1565759961

				# Vortex 1.8.0+ only requires DotNet6 (only need to pass desktop6, as installDotNet will append dotnet)
				# writelog "INFO" "${FUNCNAME[0]} - Installing .NET 6 for Vortex Mod Manager"
				# notiShow "$(strFix "$NOTY_INSTSTART" "${DOTN^}")" "S"
				# installDotNet "$VORTEXPFX" "$VORTEXWINE" "desktop6"  # Should be easy to bump if a newer version is ever required

				touch "${VORTEXCOMPDATA}/tracked_files"
				STEAM_COMPAT_CLIENT_INSTALL_PATH="$SROOT" STEAM_COMPAT_DATA_PATH="$VORTEXCOMPDATA" "$VORTEXPROTON" "run" 2> "$STLSHM/${FUNCNAME[0]}_protonrun.log"
				notiShow "$GUI_DONE" "S"
				sleep 3
				writelog "INFO" "${FUNCNAME[0]} - Installing '$VSPATH' into '$VORTEXPFX'" E
				notiShow "$(strFix "$NOTY_INSTSTART" "${VSPATH##*/}")" "S"
				# writelog "INFO" "${FUNCNAME[0]} - 'WINEDEBUG=\"-all\" WINEPREFIX=\"$VORTEXPFX\" \"$VORTEXWINE\" \"$VSPATH\" \"/S\"'" E

				# --------------------------
				# Get SLR for Vortex Proton
				unset "${SLRCMD[@]}"
				if [ "$VORTEXUSESLR" -eq 1 ]; then
					setNonGameSLRReap "1" "$USEVORTEXPROTON"
				fi

				# If we got the runtime above and we want to use the SLR with Vortex, use it to install Vortex
				if [ "$VORTEXUSESLR" -eq 1 ] && [ -n "${SLRCMD[*]}" ]; then
					writelog "INFO" "${FUNCNAME[0]} - 'WINEDEBUG=\"-all\" WINEPREFIX=\"$VORTEXPFX\" \"${SLRCMD[*]}\" \"$VORTEXWINE\" \"$VSPATH\" \"/S\"'" E
					WINEDEBUG="-all" WINEPREFIX="$VORTEXPFX" "${SLRCMD[@]}" "$VORTEXWINE" "$VSPATH" "/S"
				else
					writelog "INFO" "${FUNCNAME[0]} - 'WINEDEBUG=\"-all\" WINEPREFIX=\"$VORTEXPFX\" \"$VORTEXWINE\" \"$VSPATH\" \"/S\"'" E
					WINEDEBUG="-all" WINEPREFIX="$VORTEXPFX" "$VORTEXWINE" "$VSPATH" "/S"
				fi
				unset "${SLRCMD[@]}"
				# --------------------------

				notiShow "$(strFix "$NOTY_INSTSTOP" "${VSPATH##*/}")" "S"
				writelog "INFO" "${FUNCNAME[0]} - Base ${VTX^} installation finished" E
				setVortexDLMime
				notiShow "$GUI_DONE" "S"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$VSPATH' not found - nothing to install - skipping"
	fi

	unset "${SLRCMD[@]}"
}

function installVortexGui {
	export CURWIKI="$PPW/Vortex"
	TITLE="${PROGNAME}-${FUNCNAME[0]}"
	pollWinRes "$TITLE"
	setShowPic

	createProtonList X

	if [ -f "${VORTEXINSTDIR}/${VTXRAA}" ]; then
		GUI_VTXINST="$(printf '%s\n%s\n' "${GUI_VTXINST}" "Version installed: $(getInstVtxVers)")"
	fi
	mkProjDir "$VORTEXDLDIR"
	VTXDLV="$(find "${VORTEXDLDIR}" -name "${VTX}-setup*" | sort -V | tail -n1 | awk -F'${VTX}-setup' '{print $NF}')"
	if [ -n "$VTXDLV" ]; then
		VSD1="${VTXDLV//${VORTEXDLDIR}\/${VTX}-setup-}"
		VSD="${VSD1//.exe}"
		GUI_VTXINST="$(printf '%s\n%s\n' "${GUI_VTXINST}" "Newest setup downloaded: ${VSD}")"
	fi

	getLatestVortVer
	if [ -n "$VORTEXSETUP" ]; then
		VSO1="${VORTEXSETUP//${VTX}-setup-}"
		VSO="${VSO1//.exe}"
		GUI_VTXINST="$(printf '%s\n%s\n' "${GUI_VTXINST}" "Newest setup online: ${VSO}")"
	fi

	VTXINSTARGS="$("$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--title="$TITLE" --separator="|" \
		--text="$(spanFont "$GUI_VTXINST" "H")" \
		--field="$GUI_USEVORTEXPROTON!$DESC_USEVORTEXPROTON ('USEVORTEXPROTON')":CB "$(cleanDropDown "$USEVORTEXPROTON" "$PROTYADLIST")" \
		--button="$BUT_CAN:0" --button="$BUT_INSTALL:2" "$GEOM"
		)"
		case $? in
			0)	{
					writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN' - Exiting"
				}
			;;
		2)	{
				mapfile -d "|" -t -O "${#VTARR[@]}" VTARR < <(printf '%s' "$VTXINSTARGS")
				USEVORTEXPROTON="${VTARR[0]}"
				if [ "$USEVORTEXPROTON" != "$NON" ]; then
					touch "$FUPDATE"
					updateConfigEntry "USEVORTEXPROTON" "$USEVORTEXPROTON" "$STLDEFGLOBALCFG"
					writelog "INFO" "${FUNCNAME[0]} - Saved 'USEVORTEXPROTON'='$USEVORTEXPROTON' for $VTX in the Global Config"
				fi
				StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${VTX^}")" "dlLatestVortex S" "DownloadVortexStatus"
				StatusWindow "$(strFix "$NOTY_INSTSTART" "${VTX^}")" "installVortex" "InstallVortexStatus"
			}
		;;
		esac
}

function askVortex {
	if [ "$USEVORTEX" -eq "1" ] && [ "$1" == "ask" ]; then
		if [ "$WAITVORTEX" -gt 0 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Opening ${VTX^} Requester with timeout '$WAITVORTEX'"
			fixShowGnAid
			export CURWIKI="$PPW/Vortex"
			TITLE="${PROGNAME}-OpenVortex"
			pollWinRes "$TITLE"

			setShowPic

			"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
			--title="$TITLE" \
			--text="$(spanFont "$SGNAID - $GUI_ASKVORTEX" "H")" \
			--button="$BUT_VORTEX":0 \
			--button="$BUT_CAN":4 \
			--timeout="$WAITVORTEX" \
			--timeout-indicator=top \
			"$GEOM"

			case $? in
				0)  {
						writelog "INFO" "${FUNCNAME[0]} - Selected to Start ${VTX^}, so not disabling it"
					}
				;;
				4)  {
						writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL - Not starting ${VTX^}"
						USEVORTEX="0"
					}
				;;
				70) {
						writelog "INFO" "${FUNCNAME[0]} - TIMEOUT - Not starting ${VTX^}"
						USEVORTEX="0"
					}
				;;
			esac
		else
			writelog "INFO" "${FUNCNAME[0]} - ${VTX^} Requester was skipped because WAITVORTEX is '$WAITVORTEX'"
		fi
	fi
}

# vtxWinecfg and mo2Winecfg are separate functions and separate from oneTimeWinetricks in case they may need some custom logics
function vtxWinecfg {
	setVortexVars
	fallbackIfNoRunProton "$USEVORTEXPROTON"
	getWinecfgExecutable

	if [ -d "$VORTEXPFX" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Running Winecfg for Vortex"
		writelog "INFO" "${FUNCNAME[0]} - WINEDEBUG=\"-all\" WINEPREFIX=\"$VORTEXPFX\" \"$VORTEXWINE\" \"$OTWINECFGEXE\""
		WINEDEBUG="-all" WINEPREFIX="$VORTEXPFX" "$VORTEXWINE" "$OTWINECFGEXE"
	else
		writelog "ERROR" "${FUNCNAME[0]} - Vortex is not installed or prefix is missing, cannot run Winecfg for Vortex -- VORTEXPFX is '$VORTEXPFX'"
		echo "Vortex is not installed or prefix is missing, cannot run Winecfg for Vortex"
	fi
}

function vtxWinetricks {
	setVortexVars
	chooseWinetricks
	if [ -d "$VORTEXPFX" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Running Winetricks for Vortex"
		writelog "INFO" "${FUNCNAME[0]} - WINEDEBUG=\"-all\" WINEPREFIX=\"$VORTEXPFX\" WINE=\"$VORTEXWINE\" \"$WINETRICKS\""
		WINEDEBUG="-all" WINEPREFIX="$VORTEXPFX" WINE="$VORTEXWINE" "$WINETRICKS"
	else
		writelog "ERROR" "${FUNCNAME[0]} - Vortex is not installed or prefix is missing, cannot run Winetricks for Vortex -- VORTEXPFX is '$VORTEXPFX'"
		echo "Vortex is not installed or prefix is missing, cannot run Winetricks for Vortex"
	fi
}

#### VORTEX STOP ####

# Takes a custom Proton version name and sets it to RUNPROTON -- Mostly used for mo2winecfg and vtxWinecfg
function fallbackIfNoRunProton {
	NEWRUNPROTONNAME="$1"
	if [ -n "$RUNPROTON" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - RUNPROTON is already defined as '$RUNPROTON' -- Skipping"
		return
	fi

	NEWRUNPROTONPATH="$( getProtPathFromCSV "${NEWRUNPROTONNAME}" )"
	if [ -z "$NEWRUNPROTONPATH" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Could not find path to NEWRUNPROTONNAME '${NEWRUNPROTONPATH}' (is it defined in ProtonCSV.txt?) -- Aborting"
		return
	fi

	# NEWRUNPROTONPATH points to Proton script file, so use -f
	if [ ! -f "$NEWRUNPROTONPATH" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Found Proton path path '${NEWRUNPROTONPATH}' in ProtonCSV for '${NEWRUNPROTONNAME}', but this path does not exist! Aborting"
		return
	fi

	writelog "INFO" "${FUNCNAME[0]} - RUNPROTON is empty and found valid replacement based on '${NEWRUNPROTONPATH}' - Updated RUNPROTON path is '${NEWRUNPROTONPATH}'"
	RUNPROTON="$NEWRUNPROTONPATH"
}

function warnInvalidModToolLaunch {
	MODTOOLNAME="$1"
	"$YAD" --title="TinkerGame - $MODTOOLNAME Invalid Usage" --text="$( strFix "$GUI_MODTOOLINVALIDUSAGE" "$MODTOOLNAME")" --button="OK"
}

#### MO2 MOD ORGANIZER START: ####

