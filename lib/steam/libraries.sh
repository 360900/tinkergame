#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function setSteamPath {
	HSR="$HOME/.steam/root"
	HSS="$HOME/.steam/steam"

	if [ -z "${!1}" ]; then
		if [ -e "${HSR}/${2}" ]; then
			# readlink might be better in both STPAs here to be distribution independant, possible side effects not tested!
			STPA="$(readlink -f "${HSR}/${2}")"
			export "$1"="$STPA"
			echo "$1=\"$STPA\"" >> "$STPAVARS"
			writelog "INFO" "${FUNCNAME[0]} - Set '$1' to '$STPA'"
		elif [ -e "${HSS}/${2}" ]; then
			STPA="$(readlink -f "${HSS}/${2}")"
			export "$1"="$STPA"
			echo "$1=\"$STPA\"" >> "$STPAVARS"
			writelog "INFO" "${FUNCNAME[0]} - Set '$1' to '$STPA'"
		else
			writelog "WARN" "${FUNCNAME[0]} - '$2' not found for variable '$1' in '$HSR' or '$HSS'!"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$1' already defined as '${!1}'"
		echo "$1=\"${!1}\"" >> "$STPAVARS"
	fi
}

function setSteamPaths {
	if [ -f "$STPAVARS" ] && grep -q "^SUSDA" "$STPAVARS" ; then
		writelog "INFO" "${FUNCNAME[0]} - Reading Steam Path variables from '$STPAVARS'"
		loadCfg "$STPAVARS" X
	else
		setSteamPath "SROOT"
		mkProjDir "$SROOT/$CTD"
		setSteamPath "SUSDA" "$USDA"
		setSteamPath "DEFSTEAMAPPS" "$SA"
		setSteamPath "DEFSTEAMAPPSCOMMON" "$SAC"
		setSteamPath "CFGVDF" "$COCOV"
		setSteamPath "LOGUVDF" "$LUCOV"
		setSteamPath "LFVDF" "$SA/$LIFOVDF"
		setSteamPath "FAIVDF" "$AAVDF"
		setSteamPath "PIVDF" "$APVDF"
		setSteamPath "STEAMCOMPATOOLS" "$CTD"
		setSteamPath "ICODIR" "steam/games"

		if [ -z "$STEAM_COMPAT_CLIENT_INSTALL_PATH" ]; then
			export STEAM_COMPAT_CLIENT_INSTALL_PATH="$SROOT"
			echo "STEAM_COMPAT_CLIENT_INSTALL_PATH=\"$SROOT\"" >> "$STPAVARS"
		fi

		if [ -f "$STLDEFGLOBALCFG" ] && grep -q "^STEAMUSERID=" "$STLDEFGLOBALCFG" ; then
			STEAMUSERID="$(grep "^STEAMUSERID=" "$STLDEFGLOBALCFG" | grep -o "[[:digit:]]*")"
			STUIDPATH="$SUSDA/$STEAMUSERID"

			writelog "INFO" "${FUNCNAME[0]} - Parsing Steam UserID from global config as '$STEAMUSERID' -- STUIDPATH is now '$STUIDPATH'"
		else
			if [ -d "$SUSDA" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Trying to determine Steam UserID and userdata path"

				STEAMUSERID=""
				STUIDPATH=""

				# Try to set the path to the userdata folder (this contains grids, shortcuts.vdf, etc)
				# fillLoginUsersCSV will fall back to taking the first userdata folder in the Steam userdata dir and will set it to MostRecent=1
				# if it doesn't get any matches in loginusers.vdf, so we don't have to do the fallback here
				if [ ! -f "$LOGINUSERSCSV" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Filling Users CSV"
					fillLoginUsersCSV
				fi

				# Try to find the Steam Userdata folder and current Steam UserID based on generated LoginUsersCSV
				# This allows us to select the currently logged in user as the Steam User we want to use, meaning
				# we will use their userdata directory.
				#
				# If the currently logged in user changes we will then be able to use their userdata directory instead
				# This allows us to use the correct userdata folder for the currently logged in user by default when
				# there are multiple Steam user accounts logged into the same machine
				#
				# See also: https://github.com/sonic2kk/steamtinkerlaunch/issues/1140
				while read -r loginuser; do
					LOGINUSERCSVSHORTAID="$( echo "${loginuser}" | cut -d ';' -f2  )"
					LOGINUSERCSVMOSTRECENT="$( echo "${loginuser}" | cut -d ';' -f3  )"

					# if the loginuser loop variable is the MostRecent in loginusers.vdf, then:
					# - set the current Steam User ID to the Short UserID
					# - set the Steam userdata path to the base path + the Short UserID
					if [ "${LOGINUSERCSVMOSTRECENT}" -eq 1 ]; then
						STEAMUSERID="${LOGINUSERCSVSHORTAID}"
						STUIDPATH="${SUSDA}/${STEAMUSERID}"

						writelog "INFO" "${FUNCNAME[0]} - Found MostRecent Steam User '${STEAMUSERID}' from '${LOGINUSERSCSV}' - STUIDPATH is now '${STUIDPATH}'"
						break
					fi
				done < "$LOGINUSERSCSV"

				# Since fillLoginUsersCSV should handle the fallback for us, if we still have no matches,
				# assume no users found at all, meaning no users are logged in!
				# This will cause problems, so log a warning
				#
				# Hopefully this never happens under normal usage... We should always be able to find the Steam User
			if [ -z "${STEAMUSERID}" ] || [ -z "${STUIDPATH}" ]; then
				writelog "WARN" "${FUNCNAME[0]} - Could not find any logged in Steam users in '$LOGINUSERSCSV' (are any users logged in?) - other variables depend on it, expect problems!"
				elif [ ! -d "${STUIDPATH}" ]; then
					# If we were able to get the Most Recent Steam user but the userdata path for this user with this UserID does not actually exist, something has gone horribly wrong!
					# One possible but unlikely scenario is that the MostRecent user in LognUsersCSV file was removed from the Steam Client, so the userdata path would no longer exist
					# Users should remove /dev/shm/tinkergame if the accounts or Steam Client config changes in any way so this would only be a temporary issue
					writelog "WARN" "${FUNCNAME[0]} - Built Steam userdata path for User ID '${STEAMUSERID}' at path '${STUIDPATH}', but this path does not exist! This will probably cause problems!" "E"
				fi
			else
				writelog "WARN" "${FUNCNAME[0]} - Steam '$USDA' directory not found, other variables depend on it - Expect problems" "E"
			fi
		fi

		SUIC="$STUIDPATH/config"
		FLCV="$SUIC/$LCV"

		{
		echo "STUIDPATH=\"$STUIDPATH\""
		echo "STEAMUSERID=\"$STEAMUSERID\""
		echo "SUIC=\"$SUIC\""
		echo "FLCV=\"$FLCV\""
		} >> "$STPAVARS"

		writelog "INFO" "${FUNCNAME[0]} - Found SteamUserId '$STEAMUSERID'"
	fi
}

function setAwkBin {
	if [ -z "$AWKBIN" ];then
		if [ -x "$(command -v "gawk")" ]; then
			AWKBIN="gawk"
			if [ -z "$1" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found '$AWKBIN' as an 'awk' variant. It should work without any issues, because 'gawk' was tested completely"
			fi
		elif [ -x "$(command -v "mawk")" ]; then
			AWKBIN="mawk"
			if [ -z "$1" ]; then
				writelog "WARN" "${FUNCNAME[0]} - Only found '$AWKBIN' as an 'awk' variant. It might be incompatible in several functions, as only 'gawk' was tested completely!"
			fi
		elif [ -x "$(command -v "awk")" ]; then
			AWKBIN="mawk"
			if [ -z "$1" ]; then
				writelog "WARN" "${FUNCNAME[0]} - Only found '$AWKBIN' as an 'awk' variant. It might be incompatible in several functions, as only 'gawk' was tested completely!"
			fi
		fi

		if [ -z "$AWKBIN" ];then
			writelog "ERROR" "${FUNCNAME[0]} - No 'awk' variant found, but at least one is required (best would be 'gawk') - Can't continue" "E"
			exit
		else
			export AWKBIN="$AWKBIN"
		fi
	fi
}

function awk {
	if [ -z "$AWKBIN" ];then
		setAwkBin "X"
	fi
	"$AWKBIN" "$@"
}

function OpenWikiPage {
	if [ -n "$1" ]; then
		if grep -q "$PPW" <<< "$1"; then
			WIKURL="$1"
		else
			WIKURL="$PPW/$1"
		fi
	else
		if [ -n "$CURWIKI" ]; then
			WIKURL="$CURWIKI"
		fi
	fi

	if [ -n "$WIKURL" ]; then
		if [ "$ONSTEAMDECK" -eq 1 ]; then
			# Only open wiki on Steam Deck Game Mode
			if [ "$FIXGAMESCOPE" -eq 0 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Opening wiki URL '$WIKURL' using xdg-open on Steam Deck since Yad AppImage does not have WebKit support"
				"$XDGO" "$WIKURL"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Running in Steam Deck Game Mode - Opening wiki page using xdg-open here may not work or may have undesired results - Skipping"
			fi
		else
			TITLE="${PROGNAME}-Wiki"
			pollWinRes "$TITLE"
			"$YAD" --window-icon="$STLICON" --title="$TITLE" --on-top --center "${WINDECO[@]}" --html --uri="$WIKURL" "$GEOM" >/dev/null 2>/dev/null
		fi
	fi
}

function OpenWiki {
	"${PROGCMD}" wiki "$CURWIKI"
}

export -f OpenWiki

function StatusWindow {
    TITLE="${PROGNAME}-$3"
    pollWinRes "$TITLE"
	writelog "INFO" "${FUNCNAME[0]} - for '$1'"

    RUNFUNC="$2"
    # wget (and other tools) update their progress in place using carriage
    # returns - convert them to newlines so the read loop actually sees each
    # tick instead of staying silent until the very end
    $RUNFUNC |
	tr '\r' '\n' |
    while read -r line; do
		# truncate: a long progress line widens the dialog past the screen
		# (the progress label has no ellipsize mode)
		echo "# ${line:0:60}"
	done | "$YAD" --window-icon="$STLICON" --title="$TITLE" --on-top --progress --progress-text="$1..." --pulsate --center --no-buttons --auto-close "${WINDECO[@]}" "$GEOM"
}

function setColGui {
	HAVCOL=0
	if grep -q "^COLCOUNT" "$CURGUICFG"; then
		CCR="$(grep "^COLCOUNT" "$CURGUICFG" | cut -d '=' -f2)"
		CURCOL="${CCR//\"}"
		HAVCOL=1
	else
		CURCOL=1
	fi

	export CURWIKI="$PPW/Gui-Columns"

	TITLE="${FUNCNAME[0]}"
	WTR="${CURGUICFG##*/}"
	WINTITLE="${WTR//.conf}"
	SELCOL="$("$YAD" --f1-action="$F1ACTION" --center --form --separator="\n" --field="Columns in $WINTITLE":NUM "$CURCOL" --title="$TITLE" "$GEOM")"

	if [ -z "$SELCOL" ] || [ "$SELCOL" -eq 0 ]; then
		SELCOL=1
	fi

	if [ "$HAVCOL" -eq 0 ]; then
		echo "COLCOUNT=\"$SELCOL\"" >> "$CURGUICFG"
	else
		if [ "$CURCOL" -ne "$SELCOL" ]; then
			sed "s:COLCOUNT=\"$CURCOL\":COLCOUNT=\"$SELCOL\":g" -i "$CURGUICFG"
		fi
	fi
}
export -f setColGui

function dlCheck {
	function chkFile {
		if [ "$FLCHK" == "stat" ]; then
			ISCHK="$("$FLCHK" -c%s "$DLDST" | cut -d ' ' -f1)"
		else
			ISCHK="$("$FLCHK" "$DLDST" | cut -d ' ' -f1)"
		fi
		CHKTXT="$(strFix "$NOTY_CHK" "$FLCHK" "$DLDST")"
		writelog "INFO" "${FUNCNAME[0]} - $CHKTXT"
		notiShow "$CHKTXT" "S"

		if [ "$ISCHK" == "$INCHK" ];then
			CHKTXT="$(strFix "$NOTY_CHKOK" "$FLCHK" "${DLDST##*/}" "$ISCHK")"
			writelog "INFO" "${FUNCNAME[0]} - $CHKTXT"
			notiShow "$CHKTXT" "S"
		else
			CHKTXT="$(strFix "$NOTY_CHKNOK" "${DLDST##*/}" "$ISCHK" "$INCHK")"
			writelog "WARN" "${FUNCNAME[0]} - $CHKTXT"
			notiShow "$CHKTXT" "S"
		fi
		sleep 2
	}

	DLSRC="$1"
	DLDST="$2"
	FLCHK="$3"
	DLTITLE="$4"
	INCHK="$5"

	if [ "$FLCHK" != "C" ]; then
		if [ -f "$DLDST" ] && [ "$FLCHK" != "X" ]; then
			chkFile
		else
			if [ "$DLTITLE" != "$NON" ]; then
				writelog "INFO" "${FUNCNAME[0]} - $DLTITLE"
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$DLDST")" "S"
			if grep -q "show-progress" <<< "$("$WGET" --help)" && [ "$ONSTEAMDECK" -eq 0 ]; then
				writelog "INFO" "${FUNCNAME[0]} - '$WGET -q --show-progress $DLSRC -O $DLDST'"
				"$WGET" -q --show-progress "$DLSRC" -O "$DLDST" 2>&1 | tr '\r' '\n' | sed -u "s:^[[:space:]]*::" | grep -v "SSL_INIT"
			else
				writelog "INFO" "${FUNCNAME[0]} - '$WGET -q $DLSRC -O $DLDST'"
				"$WGET" -q "$DLSRC" -O "$DLDST" 2>&1 | tr '\r' '\n' | sed -u "s:^[[:space:]]*::" | grep -v "SSL_INIT"
			fi
			else
				"$WGET" -q "$DLSRC" -O "$DLDST" 1>/dev/null 2>&1
			fi
		fi
	else
		FLCHK="$1"
		DLDST="$2"
		INCHK="$4"
		writelog "INFO" "${FUNCNAME[0]} - Only checking already downloaded file '$DLDST'"
		chkFile
	fi

	if [ -n "$INCHK" ] && [ "$INCHK" != "$NON" ]; then
		if [ "$FLCHK" == "X" ]; then
			notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$DLDST")" "S"
			writelog "INFO" "${FUNCNAME[0]} - $(strFix "$NOTY_DLCUSTOMPROTON2" "$DLDST")"
		elif [ "$FLCHK" != "C" ]; then
			chkFile
		fi
	fi
}

function getGamePic {
	if [ "$DLGAMEDATA" -eq 1 ] && [ "$STLPLAY" -eq 0 ]; then
		DLPIC="$1"
		if [[ ( ! -f "$DLPIC" || ! -s "$DLPIC" ) && "$STLPLAY" -eq 0 ]]; then
			DLTITLE="Downloading picture for game '$(basename "${1//.jpg/}")'"
			dlCheck "$2" "$DLPIC" "X" "$DLTITLE"
		fi
	fi
}

function getGameName {
	if [ -n "$GN" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using 'GN' as Game Name: '$GN'"
		GNRAW="$GN"
	elif [ -f "$STLGAMEDIRID/$1.conf" ]; then
		GNRAW="$(grep "#GAMENAME" "$STLGAMEDIRID/$1.conf" | cut -d '=' -f2)"
		writelog "INFO" "${FUNCNAME[0]} - Found Game Name '$GNRAW' in '$STLGAMEDIRID/$1.conf'"
	elif grep -q "_${1}\." <<< "$(listAppManifests)" ; then
		APPMA="$(grep "_${1}\." <<< "$(listAppManifests)")"
		if [ -f "$APPMA" ]; then
			GNRAW1="$(grep "\"name\"" "$APPMA" | awk -F '"name"' '{print $NF}')"
			GNRAW="$(awk '{$1=$1};1' <<< "$GNRAW1")"
			writelog "INFO" "${FUNCNAME[0]} - Found Game Name '$GNRAW' in '$APPMA'"
		else
			writelog "SKIP" "${FUNCNAME[0]} - file '$APPMA' not found"
		fi
	elif [ -f "$STLAPPINFOIDDIR/${1}.bin" ]; then
		GNRAW="$(getAppInfoData "$AID" "name")"
		writelog "INFO" "${FUNCNAME[0]} - Found Game Name '$GNRAW' in '$STLAPPINFOIDDIR/${1}.bin'"
	else
		if [ "$DLGAMEDATA" -eq 1 ]; then
			APIURL="https://api.steampowered.com/ISteamApps/GetAppList/v2"
			APIDL="$STLDLDIR/SteamApps.json"
			MAXAGE=1440
			writelog "INFO" "${FUNCNAME[0]} - Downloading gamedata for '$1'"

			if [ ! -f "$APIDL" ] || test "$(find "$APIDL" -mmin +"$MAXAGE")"; then
				dlCheck	"$APIURL" "$APIDL" "X" "Downloading $APIDL"
			fi
		fi

		if [ -f "$APIDL" ]; then
			if [ ! -x "$(command -v "$JQ")" ]; then
				writelog "WARN" "${FUNCNAME[0]} - Can't get data from '$APIDL' because '$JQ' is not installed"
			else
				writelog "INFO" "${FUNCNAME[0]} - Searching Game Name for '$1' in $APIDL"
				GNRAW="$("$JQ" ".applist.apps[] | select (.appid==$1) | .name" "$APIDL")"

				if [ -n "$GNRAW" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Found Game Name '$GNRAW' in $APIDL"
				fi
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - file '$APIDL' not found"
		fi
	fi
	writelog "INFO" "${FUNCNAME[0]} - Outgoing game name is '${GNRAW//\"/}'"

	GAMENAME="${GNRAW//\"/}"
}

function writeDesktopFile {
	DESTDTF="$2"
	DESTPIC="$3"

	if [ -f "$DESTDTF" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - $DESTDTF already exists"
	else
		getGameName "$1"
		if [ -z "$GAMENAME" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Could not find gamename for game id '$1'"
		elif [ -n "$GAMENAME" ] && [ "$GAMENAME" != "$NON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Creating '$DESTDTF' for '$GAMENAME' ($1)"
			{
				echo "[Desktop Entry]"
				echo "Name=${GAMENAME//\"/}"
				echo "Comment=$DF_COMMENT"
				echo "Exec=steam steam://rungameid/$1"
				echo "Icon=$DESTPIC"
				echo "Terminal=false"
				echo "Type=Application"
				echo "Categories=Game;"
			} >> "$DESTDTF"
		fi
	fi
}

function createDesktopIconFile {
	if [ "$1" -eq "$1" ] 2>/dev/null; then
		AID="$1"
	else
		AID="$(getIDFromTitle "$1")"
	fi

	WANTGPNG="$STLGPNG/${AID}.png"

	if [ "$STLPLAY" -eq 1 ]; then
		mkProjDir "$STLISLDFD"
		INTDTFILE="$STLISLDFD/$AID.desktop"
	else
		mkProjDir "$STLIDFD"
		INTDTFILE="$STLIDFD/$AID.desktop"
	fi

	if [ -f "$INTDTFILE" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Already have an internal desktop file '$INTDTFILE'"
	else
		if [ -n "$AID" ] && [ ! -f "$WANTGPNG" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Don't have a desktop icon yet - trying to create it"
			if [ "$STLPLAY" -eq 1 ]; then
				if [ -n "$4" ]; then
					GAMENAME="$3"
					HAVEPA="$4"
					standaloneGameIcon "$WANTGPNG" "$AID" "$GAMENAME" "$HAVEPA"
				else
					writelog "WARN" "${FUNCNAME[0]} - Not enough arguments passes to create an icon - got '$*'"
				fi
			else
				getGameIcon
			fi
		fi

		# create desktop file internally for optionally using it on the desktop
		if [ -f "$WANTGPNG" ] && [ ! -f "$INTDTFILE" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Creating $INTDTFILE"
			if [ "$STLPLAY" -eq 1 ]; then
				if [ -n "$4" ]; then
					GAMENAME="$3"
					HAVPA="$4"
					standaloneDesktopFile "$INTDTFILE" "$WANTGPNG" "$AID" "$GAMENAME" "$HAVEPA"
				else
					writelog "WARN" "${FUNCNAME[0]} - Not enough arguments passes to create a desktopfile - got '$*'"
				fi
			else
				writeDesktopFile "$AID" "$INTDTFILE" "$WANTGPNG"
			fi
		fi
	fi

	# set desktop file mode from command line:
	if [ -f "$INTDTFILE" ] && [ "$CREATEDESKTOPICON" -eq 0 ] && [ -n "$2" ]; then
		CREATEDESKTOPICON="$2"
	fi

	# copy the desktop file to the system
	if [ -f "$INTDTFILE" ] && [ "$CREATEDESKTOPICON" -ne 0 ]; then
		if [ "$CREATEDESKTOPICON" -eq "1" ] || [ "$CREATEDESKTOPICON" -eq "3" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Creating desktop icon for '$AID' on the desktop"
			cp "$INTDTFILE" "$HOME/Desktop/" 2>/dev/null
		fi

		if [ "$CREATEDESKTOPICON" -eq "2" ] || [ "$CREATEDESKTOPICON" -eq "3" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Creating desktop icon for '$AID' for the desktop application menu"
			cp "$INTDTFILE" "$HOME/.local/share/applications/" 2>/dev/null
		fi
	fi
}

function getOwnedHexAids {
	if [ -z "$PIVDF" ]; then
		setSteamPaths
	fi

	if [ -f "$PIVDF" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Searching in '$PIVDF' for HexAids"
		HAIDS="61707069647300023000"
		"$XXD" -c "$(wc -c "$PIVDF")" -p "$PIVDF" | sed -E "s:$HAIDS:\n$HAIDS:g" | grep -o "$HAIDS.\{0,6\}" | sed "s:$HAIDS::"
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$PIVDF' not found"
	fi
}

function getOwnedAids {
	mkProjDir "$STLSHM"
	OAIDLIST="$STLSHM/owned-aids.txt"
	if [ ! -f "$OAIDLIST" ]; then
		while read -r line; do
			getAidFromHexAid "$line" >> "$OAIDLIST"
		done <<< "$(getOwnedHexAids)"

		sort -n -u "$OAIDLIST" -o "$OAIDLIST"
	fi

	if [ -f "$OAIDLIST" ]; then
		cat "$OAIDLIST"
	fi
}

function getAidFromHexAid {
	unset REVAID
	while read -r line; do
		REVAID="$REVAID${line}"
	done <<< "$(fold -2 <<< "$1" | tac)"
	printf "%d\n" "0x$REVAID"
}

function getHexAidForAid {
	unset HEXAID
	if [ -f "$GEMETA/$1.conf" ]; then
		loadCfg "$GEMETA/$1.conf" X
	fi

	if [ -n "$HEXAID" ]; then
		if [ -z "$2" ]; then
			echo "$HEXAID"
		fi
	else
		HXTST="$(printf '%x\n' "$1" | fold -w2 | tail -n1)"

		if [ "${#HXTST}" -eq 1 ]; then
			SHEX1="$(printf '0%x\n' "$1" | fold -w2 | tac)";
		else
			SHEX1="$(printf '%x\n' "$1" | fold -w2 | tac)";
		fi

		while read -r line; do
			HEXAID="$HEXAID${line}"
		done <<< "$SHEX1"

		if [ -z "$2" ]; then
			echo "$HEXAID"
		fi
		touch "$FUPDATE"
		touch "$GEMETA/$1.conf"
		updateConfigEntry "HEXAID" "$HEXAID" "$GEMETA/$1.conf"
	fi
}

function getRawAppIDInfo {
	AIIDRAW="$STLAPPINFOIDDIR/${1}.bin"

	if [ -z "$FAIVDF" ]; then
		setSteamPaths
	fi

	if [ -z "$LOGRAWINFO" ]; then
		LOGRAWINFO=1
	fi

	if [ -s "$AIIDRAW" ] && [ -z "$2" ]; then
		if [ -z "$LOGRAWINFO" ]; then
			LOGRAWINFO=1
		fi

		if [ "$LOGRAWINFO" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found raw $APIN file '$AIIDRAW'"
		fi
	else
		if [ -n "$2" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Updating raw $APIN file '$AIIDRAW'"
		fi

		if [ ! -s "$AIIDRAW" ]; then
			rm "$AIIDRAW" 2>/dev/null
		fi

		HEXAID="$(getHexAidForAid "$1")"
		HAID="02617070696400"

		SHMAIVDF="$STLSHM/${AIVDF//\.vdf/\.hex}"
		if [ ! -f "$SHMAIVDF" ]; then
			"$XXD" -c "$(wc -c "$FAIVDF")" -p "$FAIVDF" "$SHMAIVDF"
		fi
		sed -E "s:$HAID:\n$HAID:g" "$SHMAIVDF" | grep "^${HAID}${HEXAID}00" | "$XXD" -r -p - "$AIIDRAW"
	fi
}

function getAppInfoData {
	# $1=AID; $2=category; optional $3=skip stdout; optional $4=force writing metadata again
	if [ -n "$2" ] && [ "$STLPLAY" -eq 0 ]; then
		AILIST="$GLOBALMISCDIR/$AITXT"
		if ! [ -f "$AILIST" ]; then
			SCRIPTDIR="$( realpath "$0" )"
			SCRIPTDIR="${SCRIPTDIR%/*}"

			writelog "INFO" "${FUNCNAME[0]} - No '$AITXT' found in Global Misc Dir '$GLOBALMISCDIR', checking for one in the script dir '$SCRIPTDIR'"
			if [ -f "$SCRIPTDIR/misc/$AITXT" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found '$AITXT' in '$SCRIPTDIR/misc' - Using this"
				AILIST="$SCRIPTDIR/misc/$AITXT"
			else
				writelog "INFO" "${FUNCNAME[0]} - Could not find '$AITXT' in script directory - giving up"
			fi
		fi

		if grep -q "$2" "$AILIST"; then

			UPDAT="${2^^}"
			unset "$UPDAT"

			if [ -f "$GEMETA/$1.conf" ]; then
				loadCfg "$GEMETA/$1.conf" X
			fi

			if [ -n "${!UPDAT}" ] && [ -z "$4" ]; then
				if [ -z "$3" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Got value '${!UPDAT}' for '$UPDAT' from '$GEMETA/$1.conf'"
					echo "${!UPDAT}"
				fi
			else
				LOGRAWINFO=0
				getRawAppIDInfo "$1"
				SRCHEX="$STLAPPINFOIDDIR/$1.bin"

				if [ -f "$SRCHEX" ]; then
					if [ -z "$3" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Retrieving data for '$2' from '$SRCHEX'"
					fi

					HVAR="$(echo -n "$2" | "$XXD" -ps)"
					unset HXOUT

					if [ "$2" == "metacritic_score" ]; then
						UPVALHX="$("$XXD" -c "$(wc -c "$SRCHEX")" -p "$SRCHEX" | sed -E "s:$HVAR:\n$HVAR:g" | grep "^$HVAR" | head -c "$(( $(wc -c <<< "$HVAR") + 3))" | tail -c2)"
						if [ -n "$UPVALHX" ]; then
							UPVAL="$((16#$UPVALHX))"
						fi
					else
						OCOUNT=0
						ZCOUNT=0
						while read -r line; do
							if [ "$line" == "01" ]; then
								OCOUNT=$((OCOUNT+1))
								if [[ "$OCOUNT" -eq 2 ]]; then
									break
								fi
							elif [ "$line" == "00" ] ; then
								ZCOUNT=$((ZCOUNT+1))
								if [[ "$ZCOUNT" -eq 2 ]]; then
									break
								fi
							else
								HXOUT="$HXOUT$line"
							fi
						done <<< "$("$XXD" -c "$(wc -c "$SRCHEX")" -p "$SRCHEX" | sed -E "s:01$HVAR:\n01$HVAR:g" | grep "^01$HVAR" | fold -2)"
						UPVALHX="${HXOUT//${HVAR}00/}"
						UPVALHX1="${UPVALHX//${HVAR}/}"
						UPVALHXO="${UPVALHX1%*00}"

						UPVAL="$("$XXD" -r -p - <<< "$UPVALHXO")"
					fi

					if [ -n "$UPVAL" ]; then
						touch "$FUPDATE"
						touch "$GEMETA/$1.conf"
						updateConfigEntry "$UPDAT" "$UPVAL" "$GEMETA/$1.conf"
						if [ -z "$3" ]; then
							echo "$UPVAL"
						fi
					fi
				fi
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - '$2' is not in '$AILIST'"
		fi
	fi
}

function writeAllAIMeta {
	if [ -n "$1" ] && [ "$1" -eq "$1" ]; then
		if [ -n "$2" ]; then
			rm "$STLAPPINFOIDDIR/${1}.bin" 2>/dev/null
		fi
		AILIST="$GLOBALMISCDIR/$AITXT"
		while read -r line; do
		 	getAppInfoData "$1" "$line" X "$2"
		done < "$GLOBALMISCDIR/$AITXT"
	else
		writelog "SKIP" "${FUNCNAME[0]} - need SteamAppId as arg 1"
	fi
}

function getGameIcon {
	function IcotoPng {
		if [ -x "$(command -v "$CONVERT" 2>/dev/null)" ]; then
			if [ -x "$(command -v "$IDENTIFY" 2>/dev/null)" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Determining largest ico in '$WANTGICO' using '$IDENTIFY'"
				LICO="$("$IDENTIFY" "$WANTGICO" | sort -n -k3 | tail -n1 | grep -oP '\[\K[^\]]+')"
			else
				writelog "INFO" "${FUNCNAME[0]} - Command '$IDENTIFY' not found, using first ico in '$WANTGICO'"
				LICO="0"
			fi

			if [ -z "$LICO" ] || [ "$LICO" -ne "$LICO" ] 2>/dev/null; then
				writelog "INFO" "${FUNCNAME[0]} - No specific ico found using the first one in '$WANTGICO'"
				LICO="0"
			fi

			if [ "$LICO" -eq "$LICO" ] 2>/dev/null; then
				writelog "INFO" "${FUNCNAME[0]} - Converting ico '$LICO' in '$WANTGICO' to '$WANTGPNG' using command: $CONVERT ${WANTGICO}[${LICO}] $WANTGPNG"
				"$CONVERT" "${WANTGICO}[${LICO}]" "$WANTGPNG"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Command '$CONVERT' not found, so converting '$WANTGICO' to '$WANTGPNG' is not possible - skipping"
		fi
	}

	function getIco {
		WANTGICO="$STLGICO/${AID}.ico"
		if [ -f "$WANTGICO" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Already have game ico '$WANTGICO'"
			IcotoPng
		else
			ICONAME="$(getAppInfoData "$AID" "clienticon")"
			if [ -n "$ICONAME" ]; then
				ICOPATH="$ICODIR/${ICONAME}.ico"
				if [ -f "$ICOPATH" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Found ico for '$AID' under '$ICOPATH'"
					cp "$ICOPATH" "$WANTGICO"
					IcotoPng
				else
					writelog "SKIP" "${FUNCNAME[0]} - Absolute path for Steam ico '$ICONAME' not valid - skipping"
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - Could not find the icon name for '$AID' in $APIN - skipping"
			fi
		fi
	}

	function extractGZip {
		BIGGESTPNG="$("$UNZIP" -l "$WANTGZIP" | grep "\.png" | sort -n | tail -n1 | awk -F ':[0-9][0-9]   ' '{print $NF}')" # weak 'awk' might break here(?)
		if [ -n "$BIGGESTPNG" ];then
			writelog "INFO" "${FUNCNAME[0]} - Extracting biggest png file '$BIGGESTPNG' in archive '$WANTGZIP' to '$WANTGPNG'"
			writelog "INFO" "${FUNCNAME[0]} - $UNZIP -dqq ${WANTGPNG//.png} $WANTGZIP $BIGGESTPNG"
			"$UNZIP" -q -d "${WANTGPNG//.png}" "$WANTGZIP" "$BIGGESTPNG"
			mv "${WANTGPNG//.png}/$BIGGESTPNG" "$WANTGPNG"
			rm -rf "${WANTGPNG//.png}"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Could not determine the biggest png file in archive '$WANTGZIP'- skipping"
		fi
	}

	if [ -z "$AID" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Don't have a Steam gameid - skipping"
	else
		WANTGPNG="$STLGPNG/${AID}.png"
		if [ -f "$WANTGPNG" ]; then
			writelog "Info" "${FUNCNAME[0]} - Already have game icon png '$WANTGPNG' - nothing to to"
		else
			if [ -z "$ICODIR" ]; then
				setSteamPaths
			fi

			if [ ! -d "$ICODIR" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - Steam ico directory not found - skipping"
			else
				WANTGZIP="$STLGZIP/${AID}.zip"
				if [ -f "$WANTGZIP" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Already have game icon zip '$WANTGZIP' - extracting"
					extractGZip "$WANTGZIP" "$WANTGPNG"
				else
					writelog "INFO" "${FUNCNAME[0]} - Looking for icon hash in $APIN"

					LICONZIP="$(getAppInfoData "$AID" "linuxclienticon")"
					if [ -n "$LICONZIP" ]; then
						LICONPATH="$ICODIR/${LICONZIP}.zip"
						if [ -f "$LICONPATH" ]; then
							writelog "INFO" "${FUNCNAME[0]} - Found icon zip for '$AID' under '$LICONPATH'"
							cp "$LICONPATH" "$WANTGZIP"
							extractGZip "$WANTGZIP" "$WANTGPNG"
						else
							writelog "INFO" "${FUNCNAME[0]} - Absolute path for Steam icon zip '$LICONZIP' not valid - trying to find ico instead"
							getIco
						fi
					else
						writelog "SKIP" "${FUNCNAME[0]} - Could not find the icon zip for '$AID' in $APIN - trying to find ico instead"
						getIco
					fi
				fi
			fi
		fi
	fi
}

function getGameData {
	if ! grep -q ",${1}," <<< "$NOGAMES" && [ "$STLPLAY" -eq 0 ]; then
		DLPIC="$STLGHEADD/$1.jpg"
		if [ ! -f "$DLPIC" ] || [ ! -s "$DLPIC" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Downloading picture '$DLPIC' from '$STASSURL/$1/header.jpg'" "X" "$GGDLOG"
			getGamePic "$DLPIC" "$STASSURL/$1/header.jpg"
		fi

		DESTDTF="$STLGDESKD/$1.desktop"
		if [ ! -f "$DESTDTF" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Creating desktopfile '$DESTDTF'" "X" "$GGDLOG"
			writeDesktopFile "$1" "$DESTDTF" "$DLPIC"
		fi
	fi
}

function getParsableGameList {
	if [ -z "$SUSDA" ] || [ -z "$STUIDPATH" ]; then
		setSteamPaths
	fi
	if [ -d "$SUSDA" ]; then
		SC="$STUIDPATH/$SRSCV"
		APPI="Apps"
		APPO="StartMenuShortcutCheck"
		LIST="$(awk "/$APPI/,/$APPO/" "$SC" | grep -v "$APPI\|$APPO" | awk '{printf "%s+",$0} END {print ""}' | sed 's/"[0-9][0-9]/\n&/g')"
		LISTCNT="$(wc -l <<< "$LIST")"
		writelog "INFO" "${FUNCNAME[0]} - Found '$LISTCNT' parsable Game Entries in '$SC'"
		if [ "$LISTCNT" -eq 0 ]; then
			writelog "SKIP" "${FUNCNAME[0]} - No game found in any Steam collection"
		fi
		echo "$LIST"
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$SUSDA' not found - this should not happen! - skipping"
	fi
}

function getInstalledGamesFromCollection {
	CAT="$1"

	if [ -n "$CAT" ]; then
		while read -r CATAID; do
		echo "$CATAID"
		done <<< "$(getParsableGameList | grep "\"$CAT\"" | sed "s:\"::g" | sort -n | cut -d '+' -f1)"
	fi
}

function listInstalledGameIDs {
	while read -r APPMA; do
		grep -Eo "[[:digit:]]*" <<< "${APPMA##*/}"
	done <<< "$(listAppManifests)"
}

function getGameDataForInstalledGames {
	if [ "$(listInstalledGameIDs | wc -l)" -eq 0 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - No installed games found!"
	else
		while read -r CATAID; do
			if [ -n "$CATAID" ]; then
				getGameData "$CATAID"
			fi
		done <<< "$(listInstalledGameIDs)"
	fi
}

function listSteamShortcutGameIDs {
	if haveAnySteamShortcuts ; then
		while read -r SCVDFE; do
			parseSteamShortcutEntryAppID "$SCVDFE"
		done <<< "$( getSteamShortcutHex )"
	else
		writelog "SKIP" "${FUNCNAME[0]} - No Steam shortcuts found!"
	fi
}

function checkSGDbApi {
	if [ -z "$SGDBAPIKEY" ] || [ "$SGDBAPIKEY" == "$NON" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - No SteamGrid Api Key found - Get one at 'https://www.steamgriddb.com/profile/preferences/api/' (requires a SteamGridDB account) and see the SteamGridDB wiki page for guidance on how to supply the API key."
		writelog "SKIP" "${FUNCNAME[0]} - and save it in the Global Config ('SGDBAPIKEY')"
		return 1
	else
		return 0
	fi
}

## Generic function to fetch some artwork from SteamGridDB based on an endpoint
## TODO: Steam only officially supports PNGs, test to see if WebP works when manually copied, and if it doesn't, we should try to only download PNG files
## TODO: Add max filesize option? Some artworks are really big, we should skip ones that are too large (though this may mean many animated APNG artworks will get skipped, because APNG can be huge)
function downloadArtFromSteamGridDB {
	if checkSGDbApi && [ "$STLPLAY" -eq 0 ]; then
		# Required
		SEARCHID="$1"  # ID to search on (should be either Steam AppID or Game ID, but we just pass it to the endpoint given)
		SEARCHENDPOINT="$2"  # Endpoint which should either be an endpoint for Steam games (Steam AppID endpoint) or Non-Steam Games (SGDB Game ID Endpoint)
		SGDBFILENAME="${3:-SEARCHID}"  # Name to give to file i.e. "124123p.png" (can't use ${SEARCHID}${SUFFIX} because SearchID may not be the AppID) -- Defaults to just using passed AppID

		# Optional
		SEARCHSTYLES="$4"
		SEARCHDIMS="$5"
		SEARCHTYPES="$6"
		SEARCHNSFW="$7"
		SEARCHHUMOR="$8"
		SEARCHEPILEPSY="$9"

		SGDBHASFILE="${10:-SGDBHASFILE}"  # Option to override action to take when file already exists
		FORCESGDBDLTOSTEAM="${11}"  # Option to force downloading artwork to Steam Grid folder

		SGDB_ENDPOINT_STR="${SEARCHENDPOINT}/$(echo "$SEARCHID" | awk '{print $1}' | paste -s -d, -)?"
		# Only include query params if provided
		# e.g.: "?styles=${SEARCHSTYLES}&dimensions=${SEARCHDIMS}&types=${SGDBTYPES}&nsfw=${SEARCHNSFW}&humor=${SEARCHHUMOR}"
		if [ -n "$SEARCHSTYLES" ]; then
			SGDB_ENDPOINT_STR+="&styles=${SEARCHSTYLES}"
		fi
		if [ -n "$SEARCHDIMS" ]; then
			SGDB_ENDPOINT_STR+="&dimensions=${SEARCHDIMS}"
		fi
		if [ -n "$SEARCHTYPES" ]; then
			SGDB_ENDPOINT_STR+="&types=${SEARCHTYPES}"
		fi
		if [ -n "$SEARCHNSFW" ]; then
			SGDB_ENDPOINT_STR+="&nsfw=${SEARCHNSFW}"
		fi
		if [ -n "$SEARCHHUMOR" ]; then
			SGDB_ENDPOINT_STR+="&humor=${SEARCHHUMOR}"
		fi
		if [ -n "$SEARCHEPILEPSY" ]; then
			SGDB_ENDPOINT_STR+="&epilepsy=${SEARCHEPILEPSY}"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Outgoing SteamGridDB endpoint is: $SGDB_ENDPOINT_STR"

		# TODO break into reusable function for both this and `getSGDBGameIDFromTitle`?
		# If the whole batch has no grids we get a 404 and wget gives an error. --content-on-error ensures we still get the response json and the following logic still works
		RESPONSE="$("$WGET" --timeout="${SGDBTIMEOUT}" --tries="${SGDBRETRIES}" --content-on-error --header="Authorization: Bearer $SGDBAPIKEY" -q "$SGDB_ENDPOINT_STR" -O - 2> >(grep -v "SSL_INIT"))"
		if ! "$JQ" -e '.success' 1> /dev/null <<< "$RESPONSE"; then
			writelog "INFO" "${FUNCNAME[0]} - The server response wasn't 'success' for this batch of requested games."
		fi

		# catch single grid without downloads
		RESPONSE_LENGTH=$("$JQ" '.data | length' <<< "$RESPONSE")
		if [ "$RESPONSE_LENGTH" = 0 ]; then
			writelog "INFO" "${FUNCNAME[0]} - No grid found to download - maybe loosen filters?"
			echo "Could not find artwork on SteamGridDB to save with filename '$SGDBFILENAME' -- Check the log for details"
		fi

		# TODO: This could be handled by the http return value - 200 is single-part - 207 is multi-part
		# Rewrite response object to fit the following loop if the response isn't multi-part
		if "$JQ" -e ".data[0].url" 1> /dev/null <<< "$RESPONSE"; then
			RESPONSE="{\"success\":true,\"data\":[$RESPONSE]}"
			RESPONSE_LENGTH=1
		fi

		for i in $(seq 0 $(("$RESPONSE_LENGTH" - 1))); do
			# match the current json array member against the appid list, this assumes we get the same order back we put in before
			if ! "$JQ" -e ".data[$i].success" 1> /dev/null <<< "$RESPONSE"; then
				writelog "INFO" "${FUNCNAME[0]} - The server response for '$SEARCHID' wasn't 'success'"
			fi
			if ! URLSTR=$("$JQ" -e -r ".data[$i].data[0].url" <<< "$RESPONSE"); then
				writelog "INFO" "${FUNCNAME[0]} - No grid found to download for '$SEARCHID' - maybe loosen filters?"
			fi

			GRIDDLURL="${URLSTR//\"}"
			if grep -q "^https" <<< "$GRIDDLURL"; then
				DLSRC="${GRIDDLURL//\"}"

				if [ "$SGDBDLTOSTEAM" -eq 1 ] || [ "$FORCESGDBDLTOSTEAM" -eq 1 ]; then
					if [ -z "$SUSDA" ]; then
						setSteamPaths
					fi
					if [ -d "$SUIC" ]; then
						GRIDDLDIR="${SUIC}/grid"
					fi
				else
					GRIDDLDIR="$STLDLDIR/steamgriddb"
				fi

				mkProjDir "$GRIDDLDIR"
				DLDST="${GRIDDLDIR}/${SGDBFILENAME}.${GRIDDLURL##*.}"  # Makes filename like <appid>.<org_extension>, which could be something like "70_logo.png" (with full path preceding this, so something like "~/Games/Grids/Half-Life/70_logo.png")
				STARTDL=1

				if [ -f "$DLDST" ]; then
					if [ "$SGDBHASFILE" == "skip" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Download of existing file is set to '$SGDBHASFILE' - doing nothing"
						STARTDL=0
					elif [ "$SGDBHASFILE" == "backup" ]; then
						BACKDIR="${GRIDDLDIR}/backup"
						mkProjDir "$BACKDIR"
						writelog "INFO" "${FUNCNAME[0]} - Backup existing file into '$BACKDIR', because SGDBHASFILE is set to '$SGDBHASFILE'"
						mv "$DLDST" "$BACKDIR"
					elif [ "$SGDBHASFILE" == "replace" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Replacing existing file '$DLDST', because SGDBHASFILE is set to '$SGDBHASFILE'"
						rm "$DLDST" 2>/dev/null
					fi
				fi

				if [ "$STARTDL" -eq 1 ]; then
					dlCheck "$DLSRC" "$DLDST" "X" "Downloading '$DLSRC' to '$DLDST'"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - No grid found to download for '$SEARCHID' - maybe loosen filters?"
			fi
		done
	fi
}

# Takes in an Steam AppID or list of Steam AppIDs and downloads (hero, logo boxart) for each one - only supports Steam AppIDs as we can't easily map SteamGridDB Game IDs and Non-Steam Game AppIDs
# For Steam games, the AppID is the ID we search on; for Non-Steam Games, we search on a specific Game ID
# In future, we could make a separate function for this
function getSteamGridDBArtwork {
	# Download artwork with given parameters for each ID passed in
	# Split into batches of 100 games - too many and cloudflare blocks requests because of a too big header file
	while mapfile -t -n 100 ary && ((${#ary[@]})); do
		SGDBSEARCHAID=$(printf '%s\n' "${ary[@]}")

		commandlineGetSteamGridDBArtwork --search-id="$SGDBSEARCHAID" --steam
	done <<< "${1}"
}

# GUI frontend for below 'commandlineGetSteamGridDBArtwork'
function getSteamGridDBArtworkGUI {
	FSGDBAWFILENAMEAPPID="$1"
	AID="$FSGDBAWFILENAMEAPPID"  # AID needed for setShowPic

	FSGDBAW_HEADERTITLE="$( getTitleFromID "$AID" "1" ) ($AID)"  # Display title and AppID for clarity in case showPic is not present/unclear

	writelog "INFO" "${FUNCNAME[0]} - Starting the Gui for SteamGridDB Artwork selection for '$AID'"

	export CURWIKI="$PPW/SteamGridDB"
	TITLE="${PROGNAME}-$FSGDBA"
	pollWinRes "$TITLE"
	setShowPic

	# AppID passed from commandline is used as --filename-appid
	# User can provide Steam AppID, SteamGridDB Game ID, or Game Name (used to attempt to fetch SteamGridDB Game ID)
	# - Steam AppID is prioritised if provided
	# - commandlineGetSteamGridDBArtwork is set to fall back to SteamGridDB Game ID if Game Name doesn't return anything, so passing both is fine
	# SGDBHASFILE will use the global option by default and populate the dropdown with the relevant option, just like the command does
	# It will use the Global Menu default, but also allows the user to specify a different action this time
	#
	# FSGDBAW = Fetcch SteamGridDB ArtWork :-)
	FSGDBAWGUISET="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --scroll --center --on-top "${WINDECO[@]}" \
	--title="$TITLE" --separator="|" --image="$SHOWPIC" \
	--text="$(spanFont "$(strFix "$GUI_FSGDBAW" "$FSGDBAW_HEADERTITLE")" "H")\n${DESC_FSGDBAW}" \
	--field=" ":LBL " " \
	--field="$GUI_FSGDBAWAPPID!$DESC_FSGDBAWAPPID ('FSGDBAWAPPID')" "${FSGDBAWAPPID/#-/ -}" \
	--field="$GUI_FSGDBAWGAMEID!$DESC_FSGDBAWGAMEID ('FSGDBAWGAMEID')" "${FSGDBAWGAMEID/#-/ -}" \
	--field="$GUI_FSGDBAWSEARCHNAME!$DESC_FSGDBAWSEARCHNAME ('FSGDBAWSEARCHNAME')" "${FSGDBAWSEARCHNAME/#-/ -}" \
	--field="$GUI_SGDBHASFILE!$DESC_SGDBHASFILE ('FSGDBAWHASFILE')":CB "$(cleanDropDown "${SGDBHASFILE/#-/ -}" "${SGDBHASFILEOPTS}")" \
	--field="$GUI_FSGDBAWAPPLYARTWORK!$DESC_FSGDBAWAPPLYARTWORK ('FSGDBAWAPPLYARTWORK')":CHK "1" \
	--button="$BUT_CAN":0 --button="$BUT_DONE":2 "$GEOM")"

	case $? in
		0) writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN'" ;;
		2)
			{
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_DONE'"
				mapfile -d "|" -t -O "${#FSGDBAWARR[@]}" FSGDBAWARR < <(printf '%s' "$FSGDBAWGUISET")

				FSGDBAWAPPID="${FSGDBAWARR[1]}"
				FSGDBAWGAMEID="${FSGDBAWARR[2]}"
				FSGDBAWSEARCHNAME="${FSGDBAWARR[3]}"
				FSGDBAWHASFILE="--${FSGDBAWARR[4]}-existing"  # i.e. turns 'replace' into '--replace-existing'
				FSGDBAWAPPLYARTWORK="$( retBool "${FSGDBAWARR[5]}" )"

				if [ -z "${FSGDBAWAPPID}" ] && [ -z "${FSGDBAWGAMEID}" ] && [ -z "${FSGDBAWSEARCHNAME}" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - You must pass at least a Steam AppID, SteamGridDB Game ID, or SteamGridDB Game Name"
					echo "You must pass at least a Steam AppID, SteamGridDB Game ID, or SteamGridDB Game Name"
					notiShow "$NOTY_FSGDBAWINVALID"
					return
				fi

				notiShow "$( strFix "$NOTY_FSGDBAW" "$FSGDBAW_HEADERTITLE" )"

				FSGDBAWGAMETYPEFLAG="--nonsteam"  # Default to non-steam, since Game ID and Game Name will use SGDB /game/ endpoint
				if [ -n "$FSGDBAWAPPID" ]; then
					FSGDBAWGAMETYPEFLAG="--steam"  # Only use SGDB Steam game endpoint if we pass a Steam AppID to search for artwork on
					FSGDBAWSEARCHID="${FSGDBAWAPPID}"
				else
					FSGDBAWSEARCHID="${FSGDBAWGAMEID}"
				fi

				FSGDBAWAPPLYARTWORKFLAG="--apply"  # Checkbox is defaulted to 1 (enabled), so default flag to '--apply'
				if [ "$FSGDBAWAPPLYARTWORK" -eq 0 ]; then
					FSGDBAWAPPLYARTWORKFLAG="--no-apply"
				fi

				# Execute actual fetching of artwork, could probably put notifier here
				writelog "INFO" "${FUNCNAME[0]} - Executing 'commandlineGetSteamGridDBArtwork --search-id=\"${FSGDBAWGAMEID}\" --search-name=\"${FSGDBAWSEARCHNAME}\" --filename-appid=\"${FSGDBAWFILENAMEAPPID}\" \"${FSGDBAWHASFILE}\" \"${FSGDBAWGAMETYPEFLAG}\"'"
				commandlineGetSteamGridDBArtwork --search-id="${FSGDBAWSEARCHID}" --search-name="${FSGDBAWSEARCHNAME}" --filename-appid="${FSGDBAWFILENAMEAPPID}" "${FSGDBAWHASFILE}" "${FSGDBAWAPPLYARTWORKFLAG}" "${FSGDBAWGAMETYPEFLAG}"
			}
	esac
}

# Used to get either Steam or Non-Steam artwork depending on a flag -- Used internally and for commandline usage
function commandlineGetSteamGridDBArtwork {
	SGDBENDPOINTTYPE="steam" # assume Steam game by default (search Steam AppID endpoint)
	GSGDBA_HASFILE="$SGDBHASFILE"  # Optional override for how to handle existinf file (downloadArtFromSteamGridDB defaults to '$SGDBHASFILE')
	GSGDBA_APPLYARTWORK="$SGDBDLTOSTEAM"
	GSGDBA_SEARCHNAME=""
	GSGDBA_FOUNDGAMEID=""  # ID found from SteamGridDB endpoint using GSGDBA_SEARCHNAME
	for i in "${@}"; do
		case $i in
			--search-id=*)  # ID to hit SteamGridDB API endpoint with (for Steam games this is the AppID which we will also use as filename)
				GSGDBA_APPID="${i#*=}"
				GSGDBA_FILENAME="${GSGDBA_APPID}"  # By default, file will be named <appid> with a suffix for each grid type (only non-steam games need this overridden since they search on Game ID and not Steam AppID)
				shift ;;
			--search-name=*)
				GSGDBA_SEARCHNAME="${i#*=}"  # Optional SteamGridDB Game Name -- Will use this to try and find matching SteamGridDB Game Art
				shift ;;
			--steam)
				SGDBENDPOINTTYPE="steam"  # used to generate the correct endpoint to hit, defaults to /heroes/game but this will make it heroes/steam
				shift ;;
			--nonsteam)
				SGDBENDPOINTTYPE="game"
				shift ;;
			--filename-appid=*)
				GSGDBA_FILENAME="${i#*=}"  # AppID to use in filename (Non-Steam Games need a different AppID)
				shift ;;
			## Override Global Menu setting for how to handle existing artwork
			## in case user wants to replace all existing artwork, default STL setting is 'skip' and will only copy files over to grid dir if they don't exist, so user can easily fill in missing artwork only)
			--replace-existing)
				GSGDBA_HASFILE="replace"
				shift ;;
			--backup-existing)
				GSGDBA_HASFILE="backup"
				shift ;;
			--skip-existing)
				GSGDBA_HASFILE="skip"
				shift ;;
			## Flag to force downloading to SteamGridDB folder (used for addNonSteamGame internally)
			--apply)
				GSGDBA_APPLYARTWORK="1"
				shift ;;
			--no-apply)
				GSGDBA_APPLYARTWORK="0"
				shift ;;
		esac
	done

	# If we pass a name to search on and we get a Game ID back from SteamGridDB, set this as the ID to search for artwork on
	if [ -n "$GSGDBA_SEARCHNAME" ]; then
		if [ -n "$GSGDBA_FILENAME" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Searching SteamGridDB for game name matching '$GSGDBA_SEARCHNAME'"
			GSGDBA_FOUNDGAMEID="$( getSGDBGameIDFromTitle "$GSGDBA_SEARCHNAME" )"
			if [ -n "$GSGDBA_FOUNDGAMEID" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found game name matching '$GSGDBA_SEARCHNAME' with Game ID '$GSGDBA_FOUNDGAMEID' -- Using this Game ID to search for SteamGridDB Game Art"
				GSGDBA_APPID="$GSGDBA_FOUNDGAMEID"
				writelog "INFO" "${FUNCNAME[0]} - Forcing endpoint type as --nonsteam since we're searching with a found SteamGridDB Game ID"
				SGDBENDPOINTTYPE="game"
			fi
		else
			writelog "ERROR" "${FUNCNAME[0]} - You must provide a filename AppID when searching with SteamGridDB Game Name"
			echo "You must provide a filename AppID when searching with SteamGridDB Game Name"
		fi
	fi

	SGDBSEARCHENDPOINT_HERO="${BASESTEAMGRIDDBAPI}/heroes/${SGDBENDPOINTTYPE}"
	SGDBSEARCHENDPOINT_LOGO="${BASESTEAMGRIDDBAPI}/logos/${SGDBENDPOINTTYPE}"
	SGDBSEARCHENDPOINT_BOXART="${BASESTEAMGRIDDBAPI}/grids/${SGDBENDPOINTTYPE}"	 # Grid endpoint is used for Boxart and Tenfoot, which SteamGridDB counts as vertical/horizontal grids respectively

	# Download Hero, Logo, Boxart, Tenfoot from SteamGridDB from given endpoint using given AppID
	# On SteamGridDB tenfoot called horizontal Steam grid, so fetch it by passing specific dimensions matching this -- Users can override this, but default is what SteamGridDB expects for the tenfoot sizes
	if [ "$SGDBDLHERO" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Downloading Hero artwork, because SGDBDLHERO is '$SGDBDLHERO'"
		downloadArtFromSteamGridDB "$GSGDBA_APPID" "$SGDBSEARCHENDPOINT_HERO" "${GSGDBA_FILENAME}_hero" "$SGDBHEROSTYLES" "$SGDBHERODIMS" "$SGDBHEROTYPES" "$SGDBHERONSFW" "$SGDBHEROHUMOR" "$SGDBHEROEPILEPSY" "$GSGDBA_HASFILE" "$GSGDBA_APPLYARTWORK"
	fi
	if [ "$SGDBDLLOGO" -eq 1 ]; then
		# Logo doesn't have dimensions, so it's left intentionally blank
		writelog "INFO" "${FUNCNAME[0]} - Downloading Logo artwork, because SGDBDLLOGO is '$SGDBDLLOGO'"
		downloadArtFromSteamGridDB "$GSGDBA_APPID" "$SGDBSEARCHENDPOINT_LOGO" "${GSGDBA_FILENAME}_logo" "$SGDBLOGOSTYLES" "" "$SGDBLOGOTYPES" "$SGDBLOGONSFW" "$SGDBLOGOHUMOR" "$SGDBLOGOEPILEPSY" "$GSGDBA_HASFILE" "$GSGDBA_APPLYARTWORK"
	fi
	if [ "$SGDBDLBOXART" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Downloading Boxart (Steam Vertical Grid) artwork, because SGDBDLBOXART is '$SGDBDLBOXART'"
		downloadArtFromSteamGridDB "$GSGDBA_APPID" "$SGDBSEARCHENDPOINT_BOXART" "${GSGDBA_FILENAME}p" "$SGDBBOXARTSTYLES" "$SGDBBOXARTDIMS" "$SGDBBOXARTTYPES" "$SGDBBOXARTNSFW" "$SGDBBOXARTHUMOR" "$SGDBBOXARTEPILEPSY" "$GSGDBA_HASFILE" "$GSGDBA_APPLYARTWORK"
	fi
	if [ "$SGDBDLTENFOOT" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Downloading Tenfoot (Steam Horizontal Grid) artwork, because SGDBDLTENFOOT is '$SGDBDLTENFOOT'"
		downloadArtFromSteamGridDB "$GSGDBA_APPID" "$SGDBSEARCHENDPOINT_BOXART" "${GSGDBA_FILENAME}" "$SGDBTENFOOTSTYLES" "$SGDBTENFOOTDIMS" "$SGDBTENFOOTTYPES" "$SGDBTENFOOTNSFW" "$SGDBTENFOOTHUMOR" "$SGDBTENFOOTEPILEPSY" "$GSGDBA_HASFILE" "$GSGDBA_APPLYARTWORK"
	fi

	echo "$GSGDBA_APPID" > "$NOSTSGDBIDSHMFILE"  # Store ID in case other functions need it (i.e. addNonSteamGame) -- Little hacky, would rather return this somehow...
}

function getGridsForGames {
	local STGAAIDLIST STGAAID

	STGAAIDLIST="${1:-}"
	while read -r STGAAID; do
		getSteamGridDBArtwork "$STGAAID"
	done <<< "$STGAAIDLIST"
}
function getGridsForOwnedGames {
	if checkSGDbApi; then
		getGridsForGames "$( getOwnedAids )"
	fi
}
function getGridsForInstalledGames {
	if checkSGDbApi; then
		if [ "$(listInstalledGameIDs | wc -l)" -gt 0 ]; then
			getGridsForGames "$( listInstalledGameIDs )"
		else
			writelog "SKIP" "${FUNCNAME[0]} - No installed games found!"
		fi
	fi
}
function getGridsForNonSteamGames {
	if ! haveAnySteamShortcuts ; then
		writelog "SKIP" "${FUNCNAME[0]} - No Non-Steam Games found, skipping"
		echo "No Non-Steam Games found, not downloading grids"

		return
	fi

	if checkSGDbApi; then
		# Get Non-Steam Game Name + ID
		writelog "INFO" "${FUNCNAME[0]} - Fetching artwork for all Non-Steam Games"

		# Back up shortcuts.vdf in case something goes wrong...
		SCPATH="$STUIDPATH/config/$SCVDF"
		cp "$SCPATH" "${SCPATH//.vdf}_${PROGNAME}_backup.vdf" 2>/dev/null

		while read -r SCVDFE; do
			SVDFEAID="$( parseSteamShortcutEntryAppID "$SCVDFE" )"
			SVDFENAME="$( parseSteamShortcutEntryAppName "$SCVDFE" )"

			writelog "INFO" "${FUNCNAME[0]} - Updating artwork for game '$SVDFENAME ('$SVDFEAID')'"
			echo "Updating artwork for game '$SVDFENAME ('$SVDFEAID')'"

			commandlineGetSteamGridDBArtwork --search-name="$SVDFENAME" --filename-appid="$SVDFEAID" --nonsteam

			CMDLINEGETSGDBARTAID="$( cat "$NOSTSGDBIDSHMFILE" )"
			getSteamGridDBNonSteamIcon "$SVDFEAID" "$CMDLINEGETSGDBARTAID"
			SVDFEICON="$( findNonSteamGameIcon )"  # Return icon path )"
			if [ -n "$SVDFEICON" ]; then  # Need this check because sometimes we don't get anything back from SGDB i.e. unknown name
				writelog "INFO" "${FUNCNAME[0]} - Found icon for game '${SVDFENAME} (${SVDFEAID})' at '$SVDFEICON'"
				editSteamShortcutEntry "$SVDFEAID" "icon" "$SVDFEICON"
			fi
		done <<< "$( getSteamShortcutHex )"
	fi
}

# Search SteamGridDB endpoint using game title and return the first (best match) Game ID
function getSGDBGameIDFromTitle {
	SGDBSEARCHNAME="$1"

	if [ -n "$SGDBSEARCHNAME" ]; then
		SGDBSEARCHENDPOINT="${BASESTEAMGRIDDBAPI}/search/autocomplete/${SGDBSEARCHNAME}"
		if checkSGDbApi; then
			SGDBSEARCHNAMERESP="$( "$WGET" --timeout="${SGDBTIMEOUT}" --tries="${SGDBRETRIES}" --content-on-error --header="Authorization: Bearer $SGDBAPIKEY" -q "$SGDBSEARCHENDPOINT" -O - 2>  >(grep -v "SSL_INIT") )"
			if "$JQ" -e '.success' 1> /dev/null <<< "$SGDBSEARCHNAMERESP"; then
				if [ "$( "$JQ" '.data | length' <<< "$SGDBSEARCHNAMERESP" )" -gt 0 ]; then
					SGDBSEARCH_FOUNDNAME="$( "$JQ" '.data[0].name' <<< "$SGDBSEARCHNAMERESP" )"
					SGDBSEARCH_FOUNDGAID="$( "$JQ" '.data[0].id' <<< "$SGDBSEARCHNAMERESP" )"

					writelog "INFO" "${FUNCNAME[0]} - Searched SteamGridDB for name '$SGDBSEARCHNAME'"
					writelog "INFO" "${FUNCNAME[0]} - SteamGridDB return Game ID '$SGDBSEARCH_FOUNDGAID' and name '$SGDBSEARCH_FOUNDNAME'."
					echo "$SGDBSEARCH_FOUNDGAID"
				else
					writelog "WARN" "${FUNCNAME[0]} - No game name was returned for this request -- Check if this game name works on SteamGridDB's website search"
				fi
			else
				writelog "WARN" "${FUNCNAME[0]} - The server response wasn't 'success' for this request."
			fi
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - No game name given."
		echo "No game name given."
	fi
}

# Remove artwork for single game based on AppID, or all grids
function removeSteamGrids {
	RMGAMEGRID="${1,,}"  # Should be Steam AppID or "all"
	SGGRIDDIR="${STUIDPATH}/config/grid"

	if [ -z "$1" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - No parameter given, cannot remove artwork, skipping"
		echo "You must provide either a Steam AppID to remove artwork for, or specify 'all' to remove all game artwork"
	fi

	if [ "$1" == "all" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Removing grid artwork for all Steam games"
		echo "Removing grid artwork for all Steam games..."
		rmDirIfExists "${SGGRIDDIR}"
		mkdir "${SGGRIDDIR}"
		writelog "INFO" "${FUNCNAME[0]} - Finished removing grid artwork for all Steam games"
	else
		# Find any grid artwork for AppID -- Have to use find and use it on each artwork name because we don't want to match AppIDs which contain other AppIDs
		# i.e. searching for '140*' would return matches with '1402750' as well
		writelog "INFO" "${FUNCNAME[0]} - Removing any grid artwork for game with AppID '$1'"
		find "${SGGRIDDIR}" -name "${RMGAMEGRID}_hero.*" -exec rm {} \;  # Hero
		find "${SGGRIDDIR}" -name "${RMGAMEGRID}_logo.*" -exec rm {} \;  # Logo
		find "${SGGRIDDIR}" -name "${RMGAMEGRID}p.*" -exec rm {} \;  # Boxart
		find "${SGGRIDDIR}" -name "${RMGAMEGRID}.*" -exec rm {} \;  # Tenfoot
		find "${SGGRIDDIR}" -name "${RMGAMEGRID}_icon.*" -exec rm {} \;  # Icon (custom STL name for Non-Steam Games)
		writelog "INFO" "${FUNCNAME[0]} - Finishedd removing grid artwork for game with AppID '$1' -- Assuming 'find' found any artwork in the first place"
	fi

	echo "Finished removing grid artwork, restart Steam for the changes to fully take effect."
}

function getDataForAllGamesinSharedConfig {
	while read -r CATAID; do
		getGameData "$CATAID"
	done <<< "$(getParsableGameList | cut -d '+' -f1 | sed "s:\"::g" | grep "[0-9]" | sort -n)"
}

function getActiveSteamCollections {
	getParsableGameList | grep "\"tags\"" | awk -F '{+' '{print $NF}' | sed 's/\"/'$'\\\n/g' | sort -u | grep -i "^[a-z]"
}

function createCollectionMenus {
	# create launcher menu for all installed games
	DFIDIR="$DFDIR/installed"
	mkProjDir "$DFIDIR"

	if [ "$(listInstalledGameIDs | wc -l)" -eq 0 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - No installed games found!"
	else
		while read -r CATGAME; do
			if [ -n "$CATGAME" ] && [ ! -h "$DFIDIR/$CATGAME.desktop" ] && [ -f "$STLGDESKD/$CATGAME.desktop" ]; then
				ln -s "$STLGDESKD/$CATGAME.desktop" "$DFIDIR"
			fi
		done <<< "$(listInstalledGameIDs)"
	fi

	# create launcher menu for collection '$1'
	if [ -n "$1" ] && [ "$1" == "update" ] && [ "$(find "$DFDIR" -name "*.desktop" | wc -l)" -gt 0 ]; then
		find "$DFDIR" -name "*.desktop" -exec rm {} \;
	fi

	if [ "$(find "$DFDIR" -name "*.desktop" | wc -l)" -eq 0 ]; then
		while read -r CAT; do
			DFCDIR="$DFDIR/$CAT"
			mkProjDir "$DFCDIR"
			while read -r CATGAME; do
				if [ -f "$STLGDESKD/$CATGAME.desktop" ]; then
					if [ ! -h "$DFCDIR/$CATGAME.desktop" ]; then
						ln -s "$STLGDESKD/$CATGAME.desktop" "$DFCDIR"
					fi
				fi
			done <<< "$(getInstalledGamesFromCollection "$CAT")"
		done < <(getActiveSteamCollections)
	fi
}

function listSteamLibraries {
	function getBIF {
		local REGEX='"(BaseInstallFolder[^"]*|path)"\s+"(.*)"\s*$'
		in="$1"
		if [[ $in =~ $REGEX ]] && [ -n "${BASH_REMATCH[2]}" ]; then
			echo "${BASH_REMATCH[2]}/$SA"
		else
			writelog "WARN" "${FUNCNAME[0]} - Failed to parse Base Install Folder from '$in'"
		fi
	}

	function listSLs {
		if [ -f "$CFGVDF" ] || [ -f "$LFVDF" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Searching appmanifest files in '$CFGVDF' and '$LFVDF'" "X" "$APPMALOG"
			while read -r BIF; do
				getBIF "$BIF"
			done <<< "$(grep "\"BaseInstallFolder\|\"path\"" "$CFGVDF" "$LFVDF" 2>/dev/null)" | sort -u
		else
			writelog "SKIP" "${FUNCNAME[0]} - Neither file CFGVDF '$CFGVDF' nor file LFVDF '$LFVDF' found - this should not happen! - skipping"
		fi
	}

	MAXAGE=360
	if [ ! -f "$STELILIST" ] || test "$(find "$STELILIST" -mmin +"$MAXAGE")"; then
		writelog "INFO" "${FUNCNAME[0]} - (Re-)creating '$STELILIST'"
		rm "$STELILIST" 2>/dev/null
		listSLs | sort -u > "$STELILIST"
	else
		writelog "SKIP" "${FUNCNAME[0]} - not recreating already available '$STELILIST'"
	fi
}

function setSteamLibraryPaths {
	while read -r lpath; do
		# Ignores library folders if they are not valid directories -- This var comes from Steam but apparently can still have invalid library folders, maybe Steam bug?
		if [ ! -d "$lpath" ]; then
			writelog "WARN" "${FUNCNAME[0]} - Library folder '$lpath' does not seem to be a valid directory, even though this comes from Steam itself - Ignoring, but please report if this is invalid or causes issues"
			continue
		fi

		if [ -z "$STEAM_COMPAT_LIBRARY_PATHS" ]; then
			STEAM_COMPAT_LIBRARY_PATHS="$lpath"  # This var should come from Steam, even the Proton script uses it
		else
			if ! grep -q "$lpath" <<< "$STEAM_COMPAT_LIBRARY_PATHS" ; then
				STEAM_COMPAT_LIBRARY_PATHS="$STEAM_COMPAT_LIBRARY_PATHS:$lpath"
			fi
		fi

		while read -r cmpath; do
			if [ -n "$cmpath" ]; then
				if [ -z "$STEAM_COMPAT_MOUNTS" ]; then
					STEAM_COMPAT_MOUNTS="$cmpath"
				else
					if ! grep -q "$cmpath" <<< "$STEAM_COMPAT_MOUNTS" ; then
						STEAM_COMPAT_MOUNTS="$STEAM_COMPAT_MOUNTS:$cmpath"
					fi
				fi

				if [ -z "$STEAM_COMPAT_TOOL_PATHS" ]; then
					STEAM_COMPAT_TOOL_PATHS="$cmpath"
				else
					if ! grep -q "$cmpath" <<< "$STEAM_COMPAT_TOOL_PATHS" ; then
						STEAM_COMPAT_TOOL_PATHS="$STEAM_COMPAT_TOOL_PATHS:$cmpath"
					fi
				fi
			fi
		done <<< "$(find "$lpath" -mindepth 2 -maxdepth 2 -type d \( -name "Proton" -o -name "$STEWOS" -o -name "${SLR}*" \))"
	done < "$STELILIST"

	export STEAM_COMPAT_LIBRARY_PATHS
	export STEAM_COMPAT_MOUNTS
	export STEAM_COMPAT_TOOL_PATHS

	writelog "INFO" "${FUNCNAME[0]} - STEAM_COMPAT_LIBRARY_PATHS set to '$STEAM_COMPAT_LIBRARY_PATHS'"
	writelog "INFO" "${FUNCNAME[0]} - STEAM_COMPAT_MOUNTS set to '$STEAM_COMPAT_MOUNTS'"
	writelog "INFO" "${FUNCNAME[0]} - STEAM_COMPAT_TOOL_PATHS set to '$STEAM_COMPAT_TOOL_PATHS'"
}

function listAppManifests {
	function findAppMa {
		if [ -d "$1" ]; then
			find "$1" -mindepth 1 -maxdepth 1 -type f -name "appmanifest_*.acf"
		fi
	}

	# getBIF takes a string containing a BaseInstallFolder or path and returns the
	function getBIF {
		# REGEX needs to be a variable, quoted string literals are not treated as regexps by test
		# BASH_REMATCH[1] will be the key (BaseInstallFolder* or path)
		# BASH_REMATCH[2] will be the value (the actual steam library folder)
		local REGEX='"(BaseInstallFolder[^"]*|path)"\s+"(.*)"\s*$'
		in="$1"

		# Test the regex against input, then print the extracted path to stdout
		if [[ $in =~ $REGEX ]] && [ -n "${BASH_REMATCH[2]}" ]; then
			echo "${BASH_REMATCH[2]}/$SA"
		else
			writelog "WARN" "${FUNCNAME[0]} - Failed to parse Base Install Folder from '$in'"
		fi
	}

	function listAllAppMas {
		if [ -d "$DEFSTEAMAPPS" ]; then
			findAppMa "$DEFSTEAMAPPS"
		else
			writelog "SKIP" "${FUNCNAME[0]} - '$DEFSTEAMAPPS' not found - this should not happen! - skipping"
		fi

		if [ -f "$CFGVDF" ] || [ -f "$LFVDF" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Searching appmanifest files in '$CFGVDF' and '$LFVDF'" "X" "$APPMALOG"
			while read -r BIF; do
				findAppMa "$(getBIF "$BIF")"
			done <<< "$(grep "\"BaseInstallFolder\|\"path\"" "$CFGVDF" "$LFVDF" 2>/dev/null)" | sort -u
		else
			writelog "SKIP" "${FUNCNAME[0]} - Neither file CFGVDF '$CFGVDF' nor file LFVDF '$LFVDF' found - this should not happen! - skipping"
		fi
	}

	listAllAppMas | sort -u
}

function createCollectionList {
	function listCAT {
		while read -r CATMENU; do
			echo "${CATMENU##*/}"
		done <<< "$(find "$DFDIR" -mindepth 1 -maxdepth 1 -type d)"
	}
	CATLIST="$(listCAT | sort -u | tr '\n' '!' | sed "s:^!::" | sed "s:!$::")"
}

