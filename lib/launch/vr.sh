#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function getWindowHeight {
	WINID="$1"
	"$XWININFO" -id "$WINID" -stats | awk '$1=="-geometry" {print $2}' | cut -d '+' -f1 | cut -d 'x' -f2
}

function getLatestGeoElf {
	GEOELFDLURL="$("$WGET" -q "$GEOELFURL" -O - 2> >(grep -v "SSL_INIT") | sed $'s/<a href=/\\\n/g' | grep "^\"https" | grep "\.zip" | grep -oP '"\K[^"]+' | grep -m1 https)" # maybe make less fragile later :)
	GEOELFFILE="${GEOELFDLURL##*/}"
	CURGEOELF="${GEOELFDLURL##*+v}"
	CURGEOELF="${CURGEOELF%.*}";

	CURGEOELFDIR="$GEOELFDLDIR/$CURGEOELF"
	mkProjDir "$CURGEOELFDIR"

	GEODSTD="$CURGEOELFDIR"
	GEODSTF="$GEODSTD/$GEOELFFILE"

	if [ -f "$GEODSTF" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Already have '$GEODSTF' - skipping download"
	else
		writelog "INFO" "${FUNCNAME[0]} - Downloading '$GEOELFDLURL' to '$GEODSTF'"
		dlCheck "$GEOELFDLURL" "$GEODSTF" "X" "Downloading '$GEOELFFILE'"
		"$UNZIP" -q "$GEODSTF" -d "$GEODSTD" 2>/dev/null
		writelog "INFO" "${FUNCNAME[0]} - Extracted '$GEODSTF' to '$GEODSTD'"
		if [ -L "$LGEOELFSYM" ]; then
			rm "$LGEOELFSYM"
			writelog "INFO" "${FUNCNAME[0]} - Updating symlink '$LGEOELFSYM' pointing to '$CURGEOELFDIR'"
		else
			writelog "INFO" "${FUNCNAME[0]} - Creating symlink '$LGEOELFSYM' pointing to '$CURGEOELFDIR'"
		fi
		ln -s "$CURGEOELFDIR" "$LGEOELFSYM"
		cp "$(find "$GEODSTD" -name "*Version*")" "$GEODSTD/${GEOELF}-version.txt"
	fi
}

function configureGeoElf {
	function installGeo {
		function copyGeo {
			rm "$GEOELFENA" 2>/dev/null
			while read -r file; do
				cp "$file" "$GEOELFDDIR"
				echo "${file##*/}" >> "$GEOELFENA"
			done <<< "$(find "$LGEOELFSYM/$1" -mindepth 1 -maxdepth 1 -type f)"

			# not sure yet if (ShaderFixes) subdirectory is even required - maybe implement later TODO?
			#			while read -r dir; do
			#				mkdir "$GEOELFDDIR/${dir##*/}"
			#			done <<< "$(find "$LGEOELFSYM/$1" -mindepth 1 -type d)"
			# ...

			cp "$LGEOELFSYM/${GEOELF}-version.txt" "$GEOELFDDIR"
			echo "${GEOELF}-version.txt" >> "$GEOELFENA"
		}

		if [ ! -d "$LGEOELFSYM/$1" ] || [ "$AUTOGEOELF" -eq 1 ]; then
			getLatestGeoElf
		fi

		if [ -d "$LGEOELFSYM/$1" ]; then
			if [ -f "$GEOELFENA" ]; then
				if [ "$AUTOGEOELF" -eq 1 ]; then
					GEOELFVI="$(cat "$GEOELFDDIR/${GEOELF}-version.txt")"
					GEOELFVA="$(cat "$LGEOELFSYM/${GEOELF}-version.txt")"
					writelog "INFO" "${FUNCNAME[0]} - Installed $GEOELF version is '$GEOELFVI', latest downloaded version is '$GEOELFVA'"
					# no need to check the newer version directly, because latest is either equal or newer
					if [ "$GEOELFVI" != "$GEOELFVA" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Installing new $GEOELF version '$GEOELFVA'"
						copyGeo "$1"
					else
						writelog "INFO" "${FUNCNAME[0]} - Installed $GEOELF version '$GEOELFVI' is identical to the latest downloaded version '$GEOELFVA' - nothing to do"
					fi
				else
					writelog "SKIP" "${FUNCNAME[0]} - $GEOELF is already installed in the game dir and autoupdate is disabled - nothing to do"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - Installing geo-11 drivers from '$LGEOELFSYM/$1' to '$GEOELFDDIR'"
				copyGeo "$1"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - '$LGEOELFSYM' could not be found - can't enable $GEOELF"
			USEGEOELF=0
		fi
	}

	GEOELFDDIR="$EFD"
	setFullGameExePath "GEOELFDDIR"
	GEOELFENA="$GEOELFDDIR/${GEOELF}_enabled.txt"

	if [ "$USEGEOELF" -eq 1 ]; then
		if [ "$USECUSTOMCMD" -eq 1 ] && [ -f "$CUSTOMCMD" ]; then
			ARCHEXE="$CUSTOMCMD"
		else
			ARCHEXE="$GP"
		fi

		if [ "$(getArch "$ARCHEXE")" == "32" ]; then
			installGeo "x32"
		elif [ "$(getArch "$ARCHEXE")" == "64" ]; then
			installGeo "x64"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Could not determine the architecture of '$GP' - not installing '$GEOELF'" "E"
		fi
	else
		if [ -f "$GEOELFENA" ]; then
			writelog "INFO" "${FUNCNAME[0]} - $GEOELF was previously enabled, so removing all its files from '$GEOELFDDIR'"
			while read -r file; do
				RMFILE="$GEOELFDDIR/$file"
				if [ -f "$RMFILE" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Removing '$RMFILE'"
					rm "$GEOELFDDIR/$file"
				else
					writelog "SKIP" "${FUNCNAME[0]} - '$RMFILE' missing - nothing to do" "E"
				fi
			done < "$GEOELFENA"
			rm "$GEOELFENA"
		fi
	fi
}

function initSteamVR {
	if [ "$RUNSBSVR" -eq 1 ]; then
		SVRJUSTSTARTED=0
		STEAMVRARGS=(-applaunch 250820)

		if "$PGREP" -a "vrcompositor" >/dev/null ; then
			writelog "INFO" "${FUNCNAME[0]} - Looks like SteamVR is already running - skipping this function"
		else
			writelog "WARN" "${FUNCNAME[0]} - This function might be removed as it blocks exiting the launched game"

			if ! "$PGREP" -a "vrcompositor" >/dev/null ; then
				writelog "INFO" "${FUNCNAME[0]} - Vrcompositor not running, so starting SteamVR now:"
				if ! "$STEAM" "${STEAMVRARGS[@]}" 2>/dev/null >/dev/null ; then
					writelog "SKIP" "${FUNCNAME[0]} - Starting SteamVR FAILED - skipping SBS-VR"
					echo "RUNSBSVR=\"0\"" > "$VRINITLOCK"
				else
					writelog "INFO" "${FUNCNAME[0]} - Started SteamVR"
					SVRJUSTSTARTED=1
				fi
			fi

			if ! "$PGREP" -a "vrstartup" >/dev/null ; then
				writelog "INFO" "${FUNCNAME[0]} - No vrstartup process running"
			else
				if [ "$SVRJUSTSTARTED" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - SteamVR initializing"
					while true; do
						writelog "INFO" "${FUNCNAME[0]} - Waiting for end of vrstartup"
						if ! "$PGREP" -a "vrstartup" >/dev/null ; then
							break
						fi
						if [ -f "$CLOSETMP" ]; then
							writelog "WAIT" "${FUNCNAME[0]} - ${PROGNAME,,} is just closing - leaving loop"
							break
						fi
					done
				else
					writelog "SKIP" "${FUNCNAME[0]} - Vrstartup found, but we didn't start SteamVR before! - skipping SBS-VR - just in case"
					echo "RUNSBSVR=\"0\"" > "$VRINITLOCK"
				fi
			fi

			if [ "$SVRJUSTSTARTED" -eq 1 ]; then
				while true; do
					if ! "$PGREP" -a "vrstartup" >/dev/null ; then
						writelog "WAIT" "${FUNCNAME[0]} - No vrstartup instance running"
						break
					fi
					if [ -f "$CLOSETMP" ]; then
						writelog "WAIT" "${FUNCNAME[0]} - ${PROGNAME,,} is just closing - leaving loop"
						break
					fi
					writelog "WAIT" "${FUNCNAME[0]} - Waiting for end of vrstartup"
				done
			fi

			if [ "$SVRJUSTSTARTED" -eq 1 ]; then
			MAXWAIT=10
			COUNTER=0
				while ! "$PGREP" -a "vrcompositor" >/dev/null; do
					if [ -f "$CLOSETMP" ]; then
						writelog "WAIT" "${FUNCNAME[0]} - ${PROGNAME,,} is just closing - leaving loop"
						break
					fi
					if [[ "$COUNTER" -ge "$MAXWAIT" ]]; then
						writelog "SKIP" "${FUNCNAME[0]} - ERROR - timeout waiting for SteamVR - exit"
						"$PKILL" -f "$VRVIDEOPLAYER"
						echo "RUNSBSVR=\"0\"" > "$VRINITLOCK"
						exit 1
					fi
					writelog "WAIT" "${FUNCNAME[0]} - Sec $COUNTER/$MAXWAIT waiting for vrcompositor"
					COUNTER=$((COUNTER+1))
					sleep 1
				done
			else
				writelog "INFO" "${FUNCNAME[0]} - we didn't start SteamVR before so no need to wait for vrcompositor"
			fi

			if "$PGREP" -a "vrcompositor" >/dev/null ; then
				while true; do
					if ! "$PGREP" -a "vrstartup" >/dev/null ; then
						writelog "WAIT" "${FUNCNAME[0]} - No vrstartup instance running - looks good"
						break
					fi
					sleep 1
					writelog "WAIT" "${FUNCNAME[0]} - Waiting for end of vrstartup"
				done

				writelog "INFO" "${FUNCNAME[0]} - Success - SteamVR running"
				sleep 1 # better safe than sorry

			else
				writelog "SKIP" "${FUNCNAME[0]} - SteamVR start failed - vrcompositor still not running - skipping SBS-VR!"
				echo "RUNSBSVR=\"0\"" > "$VRINITLOCK"
			fi
		fi
	fi
}

function dlOvrFSR {
	function getLatestOVRFSR {
		basename "$("$WGET" -q "$OVRFSRURL" -O - 2> >(grep -v "SSL_INIT") | grep -E 'releases.*download.*zip' | cut -d '"' -f2 | head -n1)"
	}

	DLDST="$STLDLDIR/$OVFS"
	mkProjDir "$DLDST"
	OVRFSRZIP="$(getLatestOVRFSR)"
	FSR1="${OVRFSRZIP//openvr_}"
	FSRV="${FSR1%.*}"

	if [ ! -f "$DLDST/$OVRFSRZIP" ]; then
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$OVRFSRZIP")" "S"
		dlCheck "${OVRFSRURL}/download/$FSRV/$OVRFSRZIP" "$DLDST/$OVRFSRZIP" "X" "Downloading '$OVRFSRZIP'"
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$OVRFSRZIP")" "S"
	fi

	if [ ! -s "$DLDST/$OVRFSRZIP" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Downloaded file '$DLDST/$OVRFSRZIP' is empty - removing"
		rm "$DLDST/$OVRFSRZIP" 2>/dev/null
	else
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON3" "$OVRFSRZIP")" "S"
		writelog "INFO" "${FUNCNAME[0]} - Download of '$OVRFSRZIP' to '$DLDST' was successful"
	 	OMSRC="$DLDST/$OVRMOD"
	 	if [ -f "$OMSRC" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Removing old '$OMSRC'"
			rm "$OMSRC" 2>/dev/null
	 	fi
	 	OASRC="$DLDST/$OVRA"
	 	if [ -f "$OASRC" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Removing old '$OASRC'"
			rm "$OASRC" 2>/dev/null
	 	fi

	 	"$UNZIP" -q "$DLDST/$OVRFSRZIP" -d "$DLDST" 2>/dev/null
		writelog "INFO" "${FUNCNAME[0]} - Extracted '$OVRFSRZIP' to '$DLDST'"
	fi
}

function checkOpenVRFSR {
	OVRFSENA="${OVFS}-${PROGNAME,,}-enabled.txt"
	OVRFP="$EFD/$OVRFSENA"
	OVRAO="openvr_api.orig.dll"

	if [ "$USEOPENVRFSR" -eq 1 ]; then
		OVRPATH="$(find "$EFD" -name "*$OVRA" | head -n1)"
		if [ -f "$OVRPATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found '$OVRA' under '$OVRPATH'"
			OVRASRC="$STLDLDIR/$OVFS/$OVRA"
			if [ ! -f "$OVRASRC" ]; then
				writelog "INFO" "${FUNCNAME[0]} - No $OVFS source dll found under '$OVRASRC' - Trying automatic download"
				StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "$OVRFSRZIP")" "dlOvrFSR" "DownloadOvrFSRStatus"
			fi

			if [ ! -f "$OVRASRC" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - Still no $OVFS source dll found under '$OVRASRC' - automatic download failed!"
			else
				OVRDIR="${OVRPATH%/*}"
				writelog "INFO" "${FUNCNAME[0]} - Moving original '$OVRPATH' to $OVRDIR/$OVRAO"
				mv "$OVRPATH" "$OVRDIR/$OVRAO"
				writelog "INFO" "${FUNCNAME[0]} - Copying '$OVRASRC' to '$OVRPATH'"
				cp "$OVRASRC" "$OVRPATH"
				echo "${OVRPATH//$EFD/}" > "$OVRFP"

				OVRMODSRC="$STLDLDIR/$OVFS/$OVRMOD"
				if [ -f "$OVRMODSRC" ]; then
					if [ ! -f "$OVRFP" ]; then
						writelog "WARN" "${FUNCNAME[0]} - No install 'log' found - should not happen here!"
					else
						OVRMODDST="${OVRPATH%/*}/$OVRMOD"
						if [ -f "$OVRMODDST" ]; then
							writelog "INFO" "${FUNCNAME[0]} - Moving '$OVRMODDST' to '${OVRMODDST}_old'"
							mv "$OVRMODDST" "${OVRMODDST}_old"
						fi
						writelog "INFO" "${FUNCNAME[0]} - Copying '$OVRMODSRC' to '$OVRMODDST'"
						cp "$OVRMODSRC" "$OVRMODDST"
						echo "${OVRMODDST//$EFD/}" >> "$OVRFP"
					fi
				fi

				if [ -f "$OVRFP" ]; then
					writelog "INFO" "${FUNCNAME[0]} - '$OVFS' installation (hopefully) succeeded!"
				fi
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - USEOPENVRFSR is enabled, but no OVRA found in '$EFD'"
		fi
	else
		if [ -f "$OVRFP" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found old '$OVFS' installation in '$EFD' - Removing"
			while read -r line; do
				if grep -q "$OVRA" <<< "$line"; then
					OVRAOP="$EFD/${line//$OVRA/$OVRAO}"
				if [ -f "$OVRAOP" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Restoring original $OVRA from '$OVRAOP'"
						mv "$OVRAOP" "$EFD/$line" 2>/dev/null
					else
						writelog "SKIP" "${FUNCNAME[0]} - No '$OVRAOP' found to restore"
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - Removing '$EFD/$line'"
					rm "$EDF/$line" 2>/dev/null
				fi
			done < "$OVRFP"
			rm "$OVRFP" 2>/dev/null
		fi
	fi
}

function getGamePidFromFile {
	if [ -z "$GAMEWINPID" ] && [ -f "$TEMPGPIDFILE" ]; then
		loadCfg "$TEMPGPIDFILE"
		rm "$TEMPGPIDFILE"
		writelog "INFO" "${FUNCNAME[0]} - Got GAMEWINPID '$GAMEWINPID' from temp file"
	fi
}

function getGamePidFromWindowName {
	if [ -n "$GAMEWINDOW" ] && [ "$GAMEWINDOW" != "$NON" ]; then
		# xdotool at least doesn't like '(' and ')', so cutting them out as a partial match should be enough
		writelog "INFO" "${FUNCNAME[0]} - Trying to get the PID of the window '$GAMEWINDOW'"
		TESTPID="$("$XWININFO" -name "${GAMEWINDOW//\"/}" -wm | grep "Process id:" | awk -F 'Process id: ' '{print $2}' | cut -d ' ' -f1)"
		if [ -n "$TESTPID" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found the PID '$TESTPID' for the window '$GAMEWINDOW'"
			echo "$TESTPID"
		fi
	fi
}

function GAMEPID {
	if	[ "$USECUSTOMCMD" -eq 1 ] && [ "$ONLY_CUSTOMCMD" -eq 1 ]; then
		"$PGREP" -a "" | grep "${CUSTOMCMD##*/}" | grep "Z:" | grep "\.exe" | grep -v "CrashHandler" | cut -d ' ' -f1 | tail -n1
	else
		if [ -n "$WAITFORTHISPID" ] && [ "$WAITFORTHISPID" != "$NON" ]; then
			GAMPI="$("$PIDOF" "$WAITFORTHISPID" | cut -d ' ' -f1)"
		else
			if [ -n "$GAMEWINDOW" ] && [ "$GAMEWINDOW" != "$NON" ]; then
				GAMPI="$("$XWININFO" -name "${GAMEWINDOW//\"/}" -wm | grep "Process id:" | awk -F 'Process id: ' '{print $2}' | cut -d ' ' -f1)"
				writelog "INFO" "${FUNCNAME[0]} - Found gamewindow '$GAMEWINDOW' PID $GAMPI"
			else
				# very likely this needs to be improved/changed
				GAMPI="$("$PGREP" -a "" | grep "$GE" | grep "Z:" | grep "\.exe" | grep -v "CrashHandler" | cut -d ' ' -f1 | tail -n1)"
			fi
		fi
		echo "$GAMPI"
	fi
}

function waitForGamePid {
	if [ -n "$WAITFORTHISPID" ] && [ "$WAITFORTHISPID" != "$NON" ]; then
		writelog "WAIT" "${FUNCNAME[0]} - Waiting for alternative process WAITFORTHISPID '$WAITFORTHISPID'"
	elif [ "$USECUSTOMCMD" -eq 1 ] && [ "$ONLY_CUSTOMCMD" -eq 1 ]; then
		writelog "WAIT" "${FUNCNAME[0]} - Waiting for custom process CUSTOMCMD '$CUSTOMCMD'"
	fi

	while [ -z "$(GAMEPID)" ]; do
		writelog "WAIT" "${FUNCNAME[0]} - Waiting for game process $(GAMEPID)"
		sleep 1
	done
	writelog "INFO" "${FUNCNAME[0]} - Game process found at $(GAMEPID)"
}

function getGameWinXIDFromPid {
	GPID="$1"
	while read -r WINS; do
		if [ "$("$XPROP" -id "$(printf 0x%x'\n' "$WINS")" | grep "_NET_WM_STATE(ATOM)" -c)" -ge 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found a controllable windowid"
			WSIZ="$(getWindowHeight "$WINS")"
			if [ "$WSIZ" -lt "$MINVRWINH" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - '$(printf 0x%x'\n' "$WINS")' height is less than $MINVRWINH - this is very likely not the game window - skipping"
			else
				writelog "INFO" "${FUNCNAME[0]} Found window id $(printf 0x%x'\n' "$WINS") for '$GE' running with PID '$GPID'"
				echo "$WINS"
				break
			fi
		fi
	done <<< "$("$XDO" search --pid "$GPID")"
}

function getGameWinNameFromXid {
	"$XDO" getwindowname "$1"
}

function getGameWindowPID {
	if [ "$MO2MODE" == "gui" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Skipping check for window pid, because MO2MODE is '$MO2MODE'"
	fi

	if [ -n "$GAMEWINPID" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Already have the GAMEWINPID '$GAMEWINPID'"
		echo "$GAMEWINPID"

		return
	fi

	MAXWAIT=20
	COUNTER=0
	TESTPID="$NON"
	WASCLOSED=0

	touch "$PIDLOCK"

	while [ "$COUNTER" -lt "$MAXWAIT" ]; do
		if [ -f "$CLOSETMP" ]; then
			writelog "WAIT" "${FUNCNAME[0]} - ${PROGNAME,,} is just closing - leaving loop"
			WASCLOSED=1
			break
		fi
		TESTPID="$("$XDO" getactivewindow getwindowpid)"
		SYMCWD="$(readlink "/proc/$TESTPID/cwd")"
		SYMEXE="$(readlink "/proc/$TESTPID/exe")"

		if [ -z "$TESTPID" ]; then
			continue
		fi

		if [ -n "$HAVPA" ]; then
			writelog "WAIT" "${FUNCNAME[0]} - Found PID '$TESTPID' for game 'HAVPA' '$HAVPA' - leaving loop"
			FOUNDWIN="$YES"
			break;
		elif [ -n "$EXECUTABLE" ] && [ "$EXECUTABLE" == "$(cat "/proc/$TESTPID/comm")" ]; then
			writelog "WAIT" "${FUNCNAME[0]} - Found PID '$TESTPID' for game 'EXECUTABLE' '$EXECUTABLE' - leaving loop"
			FOUNDWIN="$YES"
			break;
		elif [ -n "$GE" ] && [ "$GE" == "$(cut -d '.' -f1 < "/proc/$TESTPID/comm")" ]; then
			writelog "WAIT" "${FUNCNAME[0]} - Found PID '$TESTPID' for game executable 'GE' '$GE' - leaving loop"
			FOUNDWIN="$YES"
			break;
		else
			# might not even be required anymore - maybe remove later:
			if [[ "$SYMCWD" == "$EFD" ]] && [[ "$SYMEXE" != *"$YAD"* ]]; then
				writelog "WAIT" "${FUNCNAME[0]} - Found PID '$TESTPID' for CWD '$SYMCWD' with EXE '$SYMEXE' - leaving loop"
				FOUNDWIN="$YES"
				break;
			fi
			if [ -n "$STEAM_COMPAT_CLIENT_INSTALL_PATH" ] && [[ "$SYMCWD" == "$STEAM_COMPAT_CLIENT_INSTALL_PATH" ]] && [[ "$SYMEXE" != *"$YAD"* ]]; then
				writelog "WAIT" "${FUNCNAME[0]} - Found PID '$TESTPID' for STEAM_COMPAT_CLIENT_INSTALL_PATH '$SYMCWD' with EXE '$SYMEXE' - leaving loop"
				FOUNDWIN="$YES"
				break;
			fi
		fi

		writelog "WAIT" "${FUNCNAME[0]} - Sec $COUNTER/$MAXWAIT Game Window with pwd '$EFD' not yet in front"
		COUNTER=$((COUNTER+1))
		sleep 1
	done

	rm "$PIDLOCK" 2>/dev/null

	if [ "$FOUNDWIN" == "$YES" ]; then
		if [ "$TESTPID" == "$NON" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - FAIL - Found PID returned but it is empty: '$TESTPID'"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Found PID '$TESTPID' for running exe '$(readlink "/proc/$TESTPID/exe")'"
		echo "$TESTPID"
	elif [ "$WASCLOSED" -eq 0 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - ERROR - timeout waiting for '$EFD' window"
		echo "$NON"
	fi
}

function storeGameWindowNameMeta {
	GAMEWINDOW="$1"
	if [ -n "$GAMEWINDOW" ] && [ "$GAMEWINDOW" != "$NON" ] && [ "$STLPLAY" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Found game window name '$GAMEWINDOW' - saving into metadata file '$GEMETA/$AID.conf' for game '$MGNA ($AID)'"
		touch "$FUPDATE"
		touch "$GEMETA/$AID.conf"
		updateConfigEntry "GAMEWINDOW" "$GAMEWINDOW" "$GEMETA/$AID.conf"
	fi
}

function pickGameWindowNameMeta {
	if [ -n "$1" ]; then
		AID="$1"
	fi
	if [ -n "$2" ]; then
		GN="$2"
	fi
	fixShowGnAid
	writelog "INFO" "${FUNCNAME[0]} - Picking 'GAMEWINDOW' for '$SGNAID'"

	GAMEWINXID="$(printf 0x%x'\n' "$("$XDO" selectwindow)")"
	GAMEWINDOW="$("$XDO" getwindowname "$GAMEWINXID")"
	storeGameWindowNameMeta "$GAMEWINDOW"
	if [ -n "$AID" ]; then
		notiShow "$(strFix "$NOTY_PICKWINS" "$GAMEWINDOW" "$GN" "$AID")"
		writelog "INFO" "${FUNCNAME[0]} - Picked 'GAMEWINDOW $GAMEWINDOW' for '$SGNAID'"
	else
		notiShow "$(strFix "$NOTY_PICKWINN" "$GAMEWINDOW")"
	fi
}

# General function for the "tinkergame list <arg> function"
# Can take two types of commands:
# - `tinkergame list owned/installed/non-steam` - Returns "Game Name (AppID)"
# - `tinkergame list owned/installed/non-steam id/name/path/full` - Returns either AppID, Game Name, Game Paths, or all in the format "Game Name (AppID) -> /path/to/game"
#
# This function is not very efficient, Non-Steam Games in particular are inefficient because we read shortcuts.vdf each time we want to parse info
# We parse it once to get the IDs, then again in each `getTitleFromID` and `getGameDir` call. This makes it pretty slow
# It works for now, but in future we should enhance it
#
# One potential way to enhance this function is to split it out into a separate function for each filter type, but we would need
# to consider how this function is used by other parts of the codebase and if that could be disruptive.
function listSteamGames {
	function getGameCount {
		TOTALGAMESOWNEDPRINTFSTR=""

		if [ "$LSFILTER" == "owned" ] || [ "$LSFILTER" == "o" ]; then
			TOTALGAMESOWNEDPRINTFSTR="Total games owned"
		elif [ "$LSFILTER" == "non-steam" ] || [ "$LSFILTER" == "nsg" ]; then
			TOTALGAMESOWNEDPRINTFSTR="Total Non-Steam Games in library"
		else
			TOTALGAMESOWNEDPRINTFSTR="Total games installed"
		fi

		printf "${TOTALGAMESOWNEDPRINTFSTR}: %s\n" "${#LISTAIDSARR[@]}"
	}

	LSFILTER="$1"  # e.g. "owned", "installed", "non-steam"
	LSTYPE="$2"  # e.g. "id", "name", "path", "count", "full"
	LISTAIDS=""

	SEARCHSTEAMSHORTCUTS="0"

	if [ "$LSFILTER" == "owned" ] || [ "$LSFILTER" == "o" ]; then
		LISTAIDS="$( getOwnedAids )"
	elif [ "$LSFILTER" == "installed" ] || [ "$LSFILTER" == "i" ]; then
		LISTAIDS="$( listInstalledGameIDs )"
	elif [ "$LSFILTER" == "non-steam" ] || [ "$LSFILTER" == "nsg" ]; then
		LISTAIDS="$( listNonSteamGameIDs )"
		SEARCHSTEAMSHORTCUTS="1"  # Only search Steam Shortcuts if we passed that filter type
	else
		writelog "INFO" "${FUNCNAME[0]} - Unknown argument passed to 'list' command - '$LSFILTER'"
		echo "unknown argument passed to 'list' command - '$LSFILTER'"

		exit
	fi

	if [ -z "$LISTAIDS" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - No games found for given filter '$LSFILTER'"
		echo "No games found for filter '$LSFILTER'."

		exit
	fi

	readarray -t LISTAIDSARR <<<"$LISTAIDS"

	if [ "$LSTYPE" == "id" ]; then
		for AID in "${LISTAIDSARR[@]}"; do
			echo "$AID"
		done
	elif [ "$LSTYPE" == "name" ]; then
		for AID in "${LISTAIDSARR[@]}"; do
			getTitleFromID "${AID}" "${SEARCHSTEAMSHORTCUTS}"
		done
	elif [ "$LSTYPE" == "path" ]; then
		if [ "$LSFILTER" == "owned" ] || [ "$LSFILTER" == "o" ]; then
			echo "Cannot use 'path' option when returning 'owned' games, as not all owned games will have an installation path!"
			echo "Use another option instead, or leave blank to only return path for games which have an installation path."

			exit
		fi
		for AID in "${LISTAIDSARR[@]}"; do
			getGameDir "$AID" "1" "${SEARCHSTEAMSHORTCUTS}"
		done
	elif [ "$LSTYPE" == "count" ]; then
		printf "\n%s\n" "$( getGameCount )"
	elif [ "$LSTYPE" == "full" ] || [ -z "$LSTYPE" ]; then  # This is the default if id/name/path/full is not passed
		for AID in "${LISTAIDSARR[@]}"; do
			GAMDIR="$( getGameDir "$AID" "" "${SEARCHSTEAMSHORTCUTS}" )"
			GAMDIREXISTS=$?

			# Only display game dir if the game is installed, i.e. if getGameDir does not return 1
			# This means we won't return an error if we're returning OWNED games, as some owned games may not have paths
			if [ "$GAMDIREXISTS" -eq 1 ]; then
				GAMNAM="$( getTitleFromID "$AID" "${SEARCHSTEAMSHORTCUTS}" )"
				GAMNAMEXISTS=$?
				if [ "$GAMNAMEXISTS" -eq 1 ]; then
					echo "$AID"  # Game name unknown, probably never installed before? Just return AppID in this case
				else
					echo "$GAMNAM ($AID)"
				fi
			else
				echo "$GAMDIR"
			fi
		done

		printf "\n%s\n" "$( getGameCount )"  # Show total for "full"
	fi
}

# TODO do we want a way to specify that this function should only return Steam or Non-Steam AppIDs?
function getIDFromTitle {
	SEARCHSTEAMSHORTCUTS="${2:-0}"  # Default to not searching Steam shortcuts
	if [ -z "$1" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - No game title was provided to search on -- Nothing to do!"
		echo "A Game Title (part of it might be enough) is required as argument"

		return 1
	fi
	# Check installed game appmanifests for name matches
	FOUNDMATCHES=()

	# Steam games
	while read -r APPMA; do
		APPMATITLE="$( getValueFromAppManifest "name" "$APPMA" )"
		if [[ ${APPMATITLE,,} == *"${1,,}"* ]]; then
			APPMAAID="$( basename "${APPMA%.*}" | cut -d '_' -f2 )"
			FOUNDGAMNAM="$( printf "%s\t\t(%s)" "$APPMAAID" "$APPMATITLE" )"  # Doing it this way makes tabs even for some reason
			FOUNDMATCHES+=( "$FOUNDGAMNAM" )
		fi
	done <<< "$( listAppManifests )"

	# Steam shortcuts
	if [ "$SEARCHSTEAMSHORTCUTS" -eq "1" ] && haveAnySteamShortcuts ; then
		while read -r SCVDFE; do
			SVDFENAME="$( parseSteamShortcutEntryAppName "$SCVDFE" )"
			SVDFEAID="$( parseSteamShortcutEntryAppID "$SCVDFE" )"

			if [[ ${SVDFENAME,,} == *"${1,,}"* ]]; then
				FOUNDGAMNAM="$( printf "%s\t\t(%s)" "$SVDFEAID" "$SVDFENAME" )"
				FOUNDMATCHES+=( "$FOUNDGAMNAM" )
			fi
		done <<< "$( getSteamShortcutHex )"
	fi

	if [ "${#FOUNDMATCHES[@]}" -gt 0 ]; then
		printf "%s\n" "${FOUNDMATCHES[@]}"
	else
		echo "Could not find AppID for name '$1'."
	fi
}

function getTitleFromID {
	SEARCHSTEAMSHORTCUTS="${2:-0}"  # Default to not searching Steam shortcuts
	FOUNDGAMETITLE=""

	if [ -z "$1" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Did not get an AppID to search on -- Nothing to do!"
		echo "A Game ID is required as argument"

		return 1;
	fi

	# Search meta file if we have one for Game Title
	if [ -f "$GEMETA/${1}.conf" ]; then
		if grep -q "^NAME" "$GEMETA/${1}.conf"; then
			FOUNDGAMETITLE="$( grep "^NAME" "$GEMETA/${1}.conf" | cut -d '"' -f2 )"
		else
			FOUNDGAMETITLE="$( getAppInfoData "$1" "name" )"
		fi
	fi

	# Try to get title from Steam appmanifest if we didn't find Game Title in meta file
	if [ -z "$FOUNDGAMETITLE" ]; then
		GAMEMANIFEST="$( listAppManifests | grep -m1 "appmanifest_${1}.acf" )"

		if [ -n "$GAMEMANIFEST" ]; then
			FOUNDGAMETITLE="$( getValueFromAppManifest "name" "$GAMEMANIFEST" )"
		fi
	fi

	# If we still haven't found the Game Title in the game meta file or appmanifest, check Steam Shortcuts if the option is enabled and if we have any
	if [ -z "$FOUNDGAMETITLE" ] && [ "$SEARCHSTEAMSHORTCUTS" -eq "1" ] && haveAnySteamShortcuts ; then
		while read -r SCVDFE; do
			SVDFENAME="$( parseSteamShortcutEntryAppName "$SCVDFE" )"
			SVDFEAID="$( parseSteamShortcutEntryAppID "$SCVDFE" )"

			if [ "$SVDFEAID" -eq "$1" ]; then
				FOUNDGAMETITLE="$SVDFENAME"
				break
			fi
		done <<< "$( getSteamShortcutHex )"
	fi

	# If we didn't find the name in the STL meta file, Steam appmanifest, or shortcuts.vdf, give up
	if [ -z "$FOUNDGAMETITLE" ]; then
		echo "No Title found for '$1'"
		return 1
	fi

	echo "$FOUNDGAMETITLE"
}

# Relies on game executable existing in STL meta file (i.e. any game launched before with STL)
function getGameExe {
	SEARCHSTEAMSHORTCUTS="${2:-0}"  # Default to not searching Steam shortcuts

	if [ -z "$1" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Called getGameExe without AppID -- Nothing to do!"
		echo "A Game ID is required as argument"

		return 1
	fi

	INAID="$1"
	EXE=""
	NOTFOUNDSTR="No Executable or TinkerGame file found for '$1'"

	# Try to get appid from game name -- If multiple values, just pick first one
	if ! [ "$INAID" -eq "$INAID" ] 2>/dev/null; then
		INAID="$( getIDFromTitle "$INAID" | head -n1 )"
		INAID="$( trimWhitespaces "${INAID%(*}")"
	fi

	EXEGAMNAM="$( getTitleFromID "$INAID" )"

	# Try to get game EXE from STL meta file
	if [ -n "$INAID" ] && [ -f "$GEMETA/${INAID}.conf" ]; then
		# Some games might only have "EXECUTABLE" in their meta conf file
		EXE="$(grep "^EXECUTABLE" "$GEMETA/${INAID}.conf" | cut -d '"' -f2)"
		if [ -z "${EXE}" ]; then
			EXE="$(grep "^GAMEEXE" "$GEMETA/${INAID}.conf" | cut -d '"' -f2)"
		fi

		if [ -n "$EXE" ]; then
			EXE="$EXEGAMNAM ($INAID) -> $( getGameDir "$INAID" "only" )/$EXE"
		fi
	fi

	# Search on game shortcuts if EXE still not found
	if [ -z "$EXE" ] && [ "$SEARCHSTEAMSHORTCUTS" -eq 1 ] && haveAnySteamShortcuts ; then
		# Have to search on all shortcuts because we need to check game name as fallback
		while read -r SCVDFE; do
			SCVDFEAID="$( parseSteamShortcutEntryAppID "$SCVDFE" )"
			SCVDFENAME="$( parseSteamShortcutEntryAppName "$SCVDFE" )"
			SCVDFEEXE="$( parseSteamShortcutEntryExe "$SCVDFE" )"

			if [ "$SCVDFEAID" -eq "$1" ] 2>/dev/null || [[ ${SCVDFENAME,,} == *"${1,,}"* ]]; then
				SCVDFEEXE="${SCVDFEEXE#\"}"
				EXE="$SCVDFENAME ($SCVDFEAID) -> ${SCVDFEEXE%\"}"
				break
			fi
		done <<< "$( getSteamShortcutHex )"
	fi

	echo "${EXE:-$NOTFOUNDSTR}"
}

function getCompatData {
	SEARCHSTEAMSHORTCUTS="${2:-0}"  # Default to not searching Steam shortcuts

	if [ -z "$1" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - No AppID or Game Title provided -- Nothing to do!"
		echo "A Game ID or Game Title is required as argument"

		return 1
	fi

	# TinkerGame stores a symlinkk to the prefix of each game launched with it,
	# so if we have this folder we can try to find if we have a symlink to the desired game's prefix as it may be faster
	if [ -d "$STLCOMPDAT" ]; then
		# Skips games which have ';' in the name (i.e. "ROBOTICS;NOTES"), as this throws off the 'cut' command, and instead we fall back to the getGameDir check
		if [ "$1" -eq "$1" ] 2>/dev/null; then  # This is for AppID check (-eq will fail if not integer expression)
			while read -r "complink"; do
				TEST="$(readlink "$complink" | grep "/$1$")"
				if [ -d "$TEST" ] && ! [[ "${complink##*/}" == *";"* ]]; then
					FCOMPDAT="${complink##*/};$TEST"
					break
				fi
			done <<< "$(find "$STLCOMPDAT")"
		else  # This is for Game Name checks
			TEST="$(find "$STLCOMPDAT" -iname "*${1}*" | head -n1)"
			if [ -n "$TEST" ] && ! [[ "${TEST##*/}" == *";"* ]]; then
				FCOMPDAT="${TEST##*/};$(readlink "$TEST")"
			fi
		fi

		# If we found a matching compatdata, return it here
		if [ -n "$FCOMPDAT" ]; then
			COMPATGAMENAME="$( echo "$FCOMPDAT" | cut -d ";" -f 1 )"
			COMPATGAMEPATH="$( echo "$FCOMPDAT" | cut -d ";" -f 2 )"
			COMPATGAMEAID="$( basename "$COMPATGAMEPATH" )"

			echo "${COMPATGAMENAME} (${COMPATGAMEAID}) -> ${COMPATGAMEPATH}"

			return 0
		fi
	fi

	unset FCOMPDAT

	# If no symlink found in STL dir, check the game's library folder, with fallback to the Steam root library folder (i.e. Non-Steam Games)
	writelog "INFO" "${FUNCNAME[0]} - Could not find compatdata named in STL symlink dir, searching with getGameLibraryFolder..."
	SEARCHGAMEDIR="$( getGameDir "$1" )"

	COMPATGAMESTR=""  # Final output string
	NOTFOUNDSTR="No $CODA dir found for '$1'"
	COMPATGAMEPATH="${SEARCHGAMEDIR##*-> }"
	if [ -d "$COMPATGAMEPATH" ]; then
		COMPATGAMENAME="$( echo "${SEARCHGAMEDIR%(*}" | xargs )" # e.g. TEKKEN 7
		COMPATGAMEAID="$( echo "$SEARCHGAMEDIR" | grep -oE '\([^)]+\)' | tail -n1 | sed 's:(::g;s:)::g' )"  # e.g. 389730

		LIFOCOMPATDIR="$( realpath "$COMPATGAMEPATH/../../$CODA/$COMPATGAMEAID" )"
		SROOTCOMPATDIR="$SROOT/$SA/$CODA/$COMPATGAMEAID"

		COMPATDATADIR="$( [ -d "$LIFOCOMPATDIR" ] && echo "$LIFOCOMPATDIR" || echo "$SROOTCOMPATDIR" )"
		if [ -d "$COMPATDATADIR" ]; then
			COMPATGAMESTR="$COMPATGAMENAME ($COMPATGAMEAID) -> $COMPATDATADIR"
		fi
	fi

	# Check Steam Shortcuts for games never launched with STL
	if [ ! -d "$SEARCHGAMEDIR" ] && [ "$SEARCHSTEAMSHORTCUTS" -eq 1 ] && haveAnySteamShortcuts ; then
		while read -r SCVDFE; do
			SCVDFEAID="$( parseSteamShortcutEntryAppID "$SCVDFE" )"
			SCVDFENAME="$( parseSteamShortcutEntryAppName "$SCVDFE" )"

			## If we have a match, build a hardcoded compatdata pointing at the Steam Root compatdata dir and if it exists, return that
			## Seems like this is always where Steam generates compatdata for Non-Steam Games
			## may instead be primary drive which defaults to Steam Root, but for now looks like Steam Root is the main place, so should work most of the time
			if [ "$SCVDFEAID" -eq "$1" ] 2>/dev/null || [[ ${SCVDFENAME,,} == *"${1,,}"* ]]; then
				SCVDFECODA="$SROOT/$SA/$CODA/${SCVDFEAID}"
				if [ -d "$SCVDFECODA" ]; then
					COMPATGAMESTR="$SCVDFENAME ($SCVDFEAID) -> $SCVDFECODA"
				fi
				break
			fi
		done <<< "$( getSteamShortcutHex )"
	fi

	echo "${COMPATGAMESTR:-$NOTFOUNDSTR}"
}

# Credit to StackOverflow community wiki
function trimWhitespaces {
	INSTR="$*"
	INSTR="${INSTR#"${INSTR%%[![:space:]]*}"}"  # remove leading whitespace characters
	INSTR="${INSTR%"${INSTR##*[![:space:]]}"}"  # remove trailing whitespace characters
	echo "$INSTR"
}

# Extracts a value from a given App Manifest file path
function getValueFromAppManifest {
	KEY="$1"
	APPMA="$2"
	EXTVAL="$( grep -m1 "$KEY" "$APPMA" | sed "s-\t- -g;s-\"${KEY}\"--g;s-\"--g" )"  # xargs gets angry when names have single quotes, e.g. "Shantae and the Pirate's Curse"

	trimWhitespaces "$EXTVAL"
}

# Returns game install directory in the format "Game (AppID) -> /path/to/gamefolder"
function getGameDir {
	ONLYPATH="$2"
	SEARCHSTEAMSHORTCUTS="${3:-0}"  # Default to not searching Steam shortcuts
	FOUNDINSTEAMSHORTCUTS=0

	# Exit early if no search name/appid is given
	if [ -z "$1" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Missing GameID or Game Title to search on -- Nothing to do!"
		echo "A Game ID or Game Title is required as argument"

		return 1
	fi

	# First assume user entered AppID, then if no AppManifest found, try get AppID from name and search on that
	SEARCHMANIFEST="$( listAppManifests | grep -m1 "appmanifest_${1}.acf" )"
	if [ -z "$SEARCHMANIFEST" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Could not find App Manifest with entered argument '$1' - Assuming it is a game title and trying to find its AppID from title"
		SEARCHGETIDFROMTITLE="$( getIDFromTitle "$1" | head -n1 )"

		writelog "INFO" "${FUNCNAME[0]} - called 'getIDFromTitle' for argument '$1', it returned '$SEARCHGETIDFROMTITLE'"
		SEARCHAID="$( echo "$SEARCHGETIDFROMTITLE" | cut -d "(" -f 1 | xargs)"

		writelog "INFO" "${FUNCNAME[0]} - Extracted AppID from 'getIDFromTitle' result is '$SEARCHAID' - Searching for App Manifest with this AppID"

		SEARCHMANIFEST="$( listAppManifests | grep -m1 "appmanifest_${SEARCHAID}.acf" )"

		# This nesting is ugly, but only exists for logging purposes
		if [ -z "$SEARCHMANIFEST" ]; then
			if [ "$SEARCHSTEAMSHORTCUTS" -eq 0 ]; then
				writelog "ERROR" "${FUNCNAME[0]} - Could not find game directory for '$1' - Maybe it is not installed"
			else
				writelog "WARN" "${FUNCNAME[0]} - Could not find game directory for '$1' - Will search on Steam Shortcuts next"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Found matching App Manifest '$SEARCHMANIFEST'"
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - Found matching App Manifest file for presumed entered AppID '$1' - Manifest file is '$SEARCHMANIFEST'"
	fi

	APPMAINSTDIR="$( getValueFromAppManifest "installdir" "$SEARCHMANIFEST" 2>/dev/null )"
	APPMALIBFLDR="$( dirname "$SEARCHMANIFEST" )"
	GAMINSTDIR="$APPMALIBFLDR/common/$APPMAINSTDIR"
	MUSINSTDIR="$APPMALIBFLDR/music/$APPMAINSTDIR"  # Fixes a not found error for installed soundtracks

	# If still not found, optionally search Steam shortcuts
	if [ ! -d "$GAMINSTDIR" ] && [ "$SEARCHSTEAMSHORTCUTS" -eq 1 ] && haveAnySteamShortcuts ; then
		while read -r SCVDFE; do
			SCVDFEAID="$( parseSteamShortcutEntryAppID "$SCVDFE" )"
			SCVDFENAME="$( parseSteamShortcutEntryAppName "$SCVDFE" )"
			SCVDFEEXE="$( parseSteamShortcutEntryExe "$SCVDFE" )"

			## If we have a match, build a hardcoded compatdata pointing at the Steam Root compatdata dir and if it exists, return that
			## Seems like this is always where Steam generates compatdata for Non-Steam Games
			## may instead be primary drive which defaults to Steam Root, but for now looks like Steam Root is the main place, so should work most of the time
			if [ "$SCVDFEAID" -eq "$1" ] 2>/dev/null || [[ ${SCVDFENAME,,} == *"${1,,}"* ]]; then
				APPMAGN="${SCVDFENAME}"
				APPMAAID="${SCVDFEAID}"
				GAMINSTDIR="$( dirname "${SCVDFEEXE}" )"  # Could still fail if EXE dir no longer exists, but edge case

				# TODO make this a function later, we use this a lot
				GAMINSTDIR="${GAMINSTDIR#\"}"
				GAMINSTDIR="${GAMINSTDIR%\"}"

				FOUNDINSTEAMSHORTCUTS=1
				break
			fi
		done <<< "$( getSteamShortcutHex )"
	fi

	# Exit now if we didn't find the game directory
	if [ ! -d "${GAMINSTDIR}" ] && [ ! -d "${MUSINSTDIR}" ]; then
		echo "Could not find install directory for '$1'"
		return 1
	fi

	# Don't fetch these if we found and set the information already from a Steam shortcuts, since we already set these variables if we found a Steam shortcut
	# We don't get here if we didn't find a game dir for either a Steam game or shortcut
	if [ "$FOUNDINSTEAMSHORTCUTS" -eq 0 ]; then
		APPMAGN="$( getValueFromAppManifest "name" "$SEARCHMANIFEST" )"
		APPMAAID="$( getValueFromAppManifest "appid" "$SEARCHMANIFEST" )"
	fi

	if [ -z "$ONLYPATH" ]; then
		printf "%s (%s) -> %s\n" "$APPMAGN" "$APPMAAID" "$GAMINSTDIR"
	else
		printf "%s\n" "$GAMINSTDIR"  # Only output path, used by "listSteamGames"
	fi
}

### BEGIN BINARY VDF FUNCTIONS ###

# Convert Steam Shortcut AppID from hex to 32bit unsigned integer
function convertSteamShortcutAppID {
    SHORTCUTAPPIDHEX="$1"
    SHORTCUTAPPIDLITTLEENDIAN="$( echo "$SHORTCUTAPPIDHEX" | tac -rs .. | tr -d '\n' )"
    echo "$((16#${SHORTCUTAPPIDLITTLEENDIAN}))"
}

# Convert shortcuts.vdf hex to text with nullbyte stripped
function convertSteamShortcutHex {
	printf "%s" "$1" | xxd -r -p | tr -d '\0'
}

# Get the raw, unparsed hex for an entry from shortcuts.vdf
function getSteamShortcutEntryHex {
	SHORTCUTSVDFINPUTHEX="$1"  # The hex block representing the shortcut
	SHORTCUTSVDFMATCHPATTERN="$2"  # The pattern to match against in the block

	printf "%s" "$SHORTCUTSVDFINPUTHEX" | grep -oP "${SHORTCUTSVDFMATCHPATTERN}\K.*?(?=${SHORTCUTVDFENDPAT})"
}

# Parse a hex shortcuts.vdf entry based on a start pattern and convert to text - Unfortunately does not work for appid
function parseSteamShortcutEntryHex {
	SHORTCUTSVDFINPUTHEX="$1"  # The hex block representing the shortcut
	SHORTCUTSVDFMATCHPATTERN="$2"  # The pattern to match against in the block

	convertSteamShortcutHex "$( getSteamShortcutEntryHex "$SHORTCUTSVDFINPUTHEX" "$SHORTCUTSVDFMATCHPATTERN" )"
}

# Find shortcut entry by AppID and return the hex
function findSteamShortcutByAppID {
	SHORTCUTENTRYAID="$1"

	writelog "INFO" "${FUNCNAME[0]} - Searching for shortcut entry with AppID '$SHORTCUTENTRYAID'"
	while read -r SCVDFE; do
		SVDFEAID="$( parseSteamShortcutEntryAppID "$SCVDFE" )"
		if [ "$SVDFEAID" -eq "$SHORTCUTENTRYAID" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found shortcut entry with AppID '$SHORTCUTENTRYAID'"  # Updating it how?
			echo "$SCVDFE"
			break
		fi
	done <<< "$( getSteamShortcutHex )"
}

function replaceSteamShortcutEntryValue {
	SHORTCUTSVDFENTRY="$1"
	SHORTCUTSVDFMATCHPATTERN="$2"
	SHORTCUTSVDFNEWVAL="$3"

	SHORTCUTSVDFOLDVAL="$( getSteamShortcutEntryHex "$SHORTCUTSVDFENTRY" "$SHORTCUTSVDFMATCHPATTERN" )"  # Get the value without start and end bytes
	SHORTCUTSVDFOLDCOL="$( printf "%s" "$SHORTCUTSVDFENTRY" | grep -oP "${SHORTCUTSVDFMATCHPATTERN}.*?${SHORTCUTVDFENDPAT}" )"  # Get value with start and end bytes
	SHORTCUTSVDFNEWCOL="${SHORTCUTSVDFOLDCOL//"$SHORTCUTSVDFOLDVAL"/"$SHORTCUTSVDFNEWVAL"}"

	# Handle blank entries by simply hardcoding old entry and building new entry
	if [ -z "$SHORTCUTSVDFOLDVAL" ]; then
		SHORTCUTSVDFOLDCOL="${SHORTCUTSVDFMATCHPATTERN}${SHORTCUTVDFENDPAT}"
		SHORTCUTSVDFNEWCOL="${SHORTCUTSVDFMATCHPATTERN}${SHORTCUTSVDFNEWVAL}${SHORTCUTVDFENDPAT}"
	fi

	SHORTCUTNEWENTRY="${SHORTCUTSVDFENTRY//"$SHORTCUTSVDFOLDCOL"/"$SHORTCUTSVDFNEWCOL"}"

	printf "%s" "$SHORTCUTNEWENTRY" | tr -d '\0'
}

## Takes a shortcut appid, finds the shortcut entry, updates the given column value, replaces the hex for that section in the hex for the shortcuts.vdf file, writes out updated hex to new file
function editSteamShortcutEntry {
	SCPATH="$STUIDPATH/config/$SCVDF"  # TODO make this a globally accessible path instead of hardcoding it everywhere

	SHORTCUTENTRYAID="$1"  # i.e. 23435463
	SHORTCUTCOLUMN="$2"  # i.e. "appname"
	SHORTCUTNEWVAL="$( xxd -p -c 0 <<< "$3" )"  # i.e. "New Name" but in hex

	SHORTCUTSCONTENT="$( getSteamShortcutsVdfFileHex )"
	SHORTCUTSENTRY="$( findSteamShortcutByAppID "$SHORTCUTENTRYAID" )"

	## Find bytes that represent the column in shortcuts.vdf
	SHORTCUTEDITSTARTBYTES=""
	case $SHORTCUTCOLUMN in
		"appid")
			writelog "WARN" "${FUNCNAME[0]} - AppID not supported, skipping"
			shift ;;
		"appname")
			SHORTCUTEDITSTARTBYTES="${SHORTCUTVDFNAMEHEXPAT}"
			shift ;;
		"Exe")
			SHORTCUTEDITSTARTBYTES="${SHORTCUTVDFEXEHEXPAT}"
			shift;;
		"StartDir")
			SHORTCUTEDITSTARTBYTES="${SHORTCUTVDFSTARTDIRHEXPAT}"
			shift ;;
		"icon")
			SHORTCUTEDITSTARTBYTES="${SHORTCUTVDFICONHEXPAT}"
			shift ;;
	esac

	if [ -z "$SHORTCUTEDITSTARTBYTES" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Unknown or unsupported column name '$SHORTCUTCOLUMN', skipping"
		return
	fi

	writelog "INFO" "${FUNCNAME[0]} - Proceeding to edit '$SHORTCUTCOLUMN' field of shortcut '$SHORTCUTENTRYAID'"

	# Replace original entry's value bytes with new bytes, then replace the old bytes in the entire shortcuts file with the new bytes and write it out
	SHORTCUTNEWENTRY="$( replaceSteamShortcutEntryValue "$SHORTCUTSENTRY" "$SHORTCUTEDITSTARTBYTES" "$SHORTCUTNEWVAL" )"
	SHORTCUTSCONTENT="${SHORTCUTSCONTENT//"$SHORTCUTSENTRY"/"$SHORTCUTNEWENTRY"}"

	# Write out new bytes with bad 0a byte removed (causes issues when reading paths etc, so strip it out)
	echo "$SHORTCUTSCONTENT" | sed 's/0a//g' | xxd -r -p > "$SCPATH"
}

# Get shortcuts.vdf hex and grep each entry using start and end patterns (including a special case for the beginning of shortcuts.vdf)
function getSteamShortcutHex {
	SCPATH="$STUIDPATH/config/$SCVDF"
	getSteamShortcutsVdfFileHex | grep -oP "(${SHORTCUTVDFFILESTARTHEXPAT}|${SHORTCUTVDFENTRYBEGINHEXPAT})\K.*?(?=${SHORTCUTSVDFENTRYENDHEXPAT})"  # Get entire shortcuts.vdf as hex, then grep each entry using the begin and end patterns for each block
}

# Get full shortcuts.vdf hex including all start and end bytes -- Used for editing shortcuts.vdf
function getSteamShortcutsVdfFileHex {
	SCPATH="$STUIDPATH/config/$SCVDF"
	xxd -p -c 0 "$SCPATH"
}

function listNonSteamGameIDs {
	writelog "INFO" "${FUNCNAME[0]} - Reading all Non-Steam AppIDs from shortcuts.vdf"
	while read -r SCVDFE; do
		parseSteamShortcutEntryAppID "$SCVDFE"
	done <<< "$( getSteamShortcutHex )"
}

function haveAnySteamShortcuts {
	if [ "$( getSteamShortcutHex | wc -c )" -gt 0 ]; then
		return 0
	else
		return 1
	fi
}

# Grep and convert AppID from a given block of hex representing a shortcut entry in shortcuts.vdf by taking the first 8 bytes
function parseSteamShortcutEntryAppID {
	convertSteamShortcutAppID "$( printf "%s" "$1" | grep -oP "${SHORTCUTVDFAPPIDHEXPAT}\K.{8}" )"
}

### Functions to get information from specific parts of the shortcuts VDF ###
function parseSteamShortcutEntryAppName {
	parseSteamShortcutEntryHex "$1" "${SHORTCUTVDFNAMEHEXPAT}"
}

function parseSteamShortcutEntryExe {
	parseSteamShortcutEntryHex "$1" "${SHORTCUTVDFEXEHEXPAT}"
}

function parseSteamShortcutEntryStartDir {
	parseSteamShortcutEntryHex "$1" "${SHORTCUTVDFSTARTDIRHEXPAT}"
}

function parseSteamShortcutEntryIcon {
	parseSteamShortcutEntryHex "$1" "${SHORTCUTVDFICONHEXPAT}"
}

### END BINARY VDF FUNCTIONS ###

function getGameWindowName {
	if [ -n "$GAMEWINDOW" ] && [ "$GAMEWINDOW" != "$NON" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Already have the gamewindow name: '$GAMEWINDOW' - skipping"
		rm "$PIDLOCK" 2>/dev/null
	else
		rm "$TEMPGPIDFILE" 2>/dev/null

		if [ -n "$GPFX" ]; then
			SYSREG="$GPFX/$SREG"
			if [ ! -f "$SYSREG" ] ; then
				writelog "WAIT" "${FUNCNAME[0]} - Waiting for the pfx '$GPFX' to be full created"
			fi

			SYSREGWAITED=0
			while [ ! -f "$SYSREG" ]; do
				if [ -f "$CLOSETMP" ]; then
					break
				fi
				if [ "$SYSREGWAITED" -ge 300 ]; then
					writelog "WAIT" "${FUNCNAME[0]} - Gave up waiting for '$SYSREG' to appear after '$SYSREGWAITED' seconds"
					break
				fi
				SYSREGWAITED=$(( SYSREGWAITED + 1 ))
				sleep 1
			done
		fi

		writelog "INFO" "${FUNCNAME[0]} - No gamewindow name stored in metadata '$GEMETA/$AID.conf' yet. Trying to find it now"
		FOUNDWIN="$NON"
		GAMEWINPID="$(getGameWindowPID)"
		if [ -n "$GAMEWINPID" ] ; then
			if [[ "$GAMEWINPID" == "$NON" ]] ; then
				writelog "SKIP" "${FUNCNAME[0]} - No valid game window PID found"
			else
				writelog "INFO" "${FUNCNAME[0]} - Found valid game window PID '$GAMEWINPID'"
				echo "GAMEWINPID=\"$GAMEWINPID\"" > "$TEMPGPIDFILE"

				GAMEWINXID="$(getGameWinXIDFromPid "$GAMEWINPID")"
				if [ -n "$GAMEWINXID" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Found game window XID '$GAMEWINXID'"
					storeGameWindowNameMeta "$(getGameWinNameFromXid "$GAMEWINXID")"
				fi
			fi
		fi
	fi
}

function getCfgHeader {
	echo "#########"
	echo "#GAMENAME=\"$GAMENAME\""
	echo "#GAMEEXE=\"$GAMEEXE\""
	echo "#GAMEID=\"$AID\""
	echo "#PROTONVERSION=\"$PROTONVERSION\""
	echo "#########"
}

function SBSrunVRVideoPlayer {
	SBSVRWINNAME="vr-video-player"

	if [ "$RUNSBSVR" -eq 1 ]; then
		if [ -z "$GAMEWINXID" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - ERROR - GAMEWINXID is empty"
			writelog "SKIP" "${FUNCNAME[0]} - ERROR - forcefully killing game with $PKILL -9 '$GAMEWINPID' - should exit this script as well"
			getGamePidFromFile
			"$PKILL" -9 "$GAMEWINPID"
		else
			if [ -z "$VRVIDEOPLAYERARGS" ];	then
				writelog "SKIP" "${FUNCNAME[0]} - ERROR - no VRVIDEOPLAYERARGS '$VRVIDEOPLAYERARGS'"
			fi

			mapfile -d " " -t -O "${#RUNVRVIDEOPLAYERARGS[@]}" RUNVRVIDEOPLAYERARGS < <(printf '%s' "$VRVIDEOPLAYERARGS")

			writelog "INFO" "${FUNCNAME[0]} - Starting '$VRVIDEOPLAYER' with args '${RUNVRVIDEOPLAYERARGS[*]}' for windowid '$GAMEWINXID'"

			GWIDDEC="$(("$GAMEWINXID"))"
			echo "GWIDDEC=$GWIDDEC" > "$GWIDFILE"

			sleep 1	# ugly, but it might need a bit...

			if [ -z "$SBSZOOM" ]; then
				"$VRVIDEOPLAYER" "${RUNVRVIDEOPLAYERARGS[@]}" "$GAMEWINXID" 2>/dev/null &
			else
				"$VRVIDEOPLAYER" "${RUNVRVIDEOPLAYERARGS[@]}" --zoom "$SBSZOOM" "$GAMEWINXID" 2>/dev/null &
			fi

			writelog "INFO" "${FUNCNAME[0]} - Waiting for '$VRVIDEOPLAYER' window '$SBSVRWINNAME' for GAMEWINXID '$GAMEWINXID'"

			MAXWAIT=20
			COUNTER=0

			while ! "$XWININFO" -name "$SBSVRWINNAME" -stats >/dev/null 2>/dev/null; do
				if [ -f "$CLOSETMP" ]; then
					writelog "WAIT" "${FUNCNAME[0]} - ${PROGNAME,,} is just closing - leaving loop"
					break
				fi
				if [[ "$COUNTER" -ge "$MAXWAIT" ]]; then
					writelog "SKIP" "${FUNCNAME[0]} - ERROR - timeout waiting for '$VRVIDEOPLAYER' - exit"
					"$PKILL" -f "$VRVIDEOPLAYER"
					RUNSBSVR=0
					exit 1
				fi
				if ! "$PGREP" -f "$VRVIDEOPLAYER" ; then
					if [ "$COUNTER" -ge 3 ]; then
						writelog "SKIP" "${FUNCNAME[0]} - ERROR - '$VRVIDEOPLAYER' not running (crashed?) no need to wait for its window to appear - exit"
						RUNSBSVR=0
						exit 1
					else
						writelog "WARN" "${FUNCNAME[0]} - '$VRVIDEOPLAYER' not running yet - waiting a bit longer"
					fi
				fi

				writelog "WAIT" "${FUNCNAME[0]} - WAIT - '$COUNTER/$MAXWAIT' sec waiting for '$VRVIDEOPLAYER' window '$SBSVRWINNAME'"
				COUNTER=$((COUNTER+1))
				sleep 1
			done

			# player windowid:
			SBSVRWID=$("$XWININFO" -name "$SBSVRWINNAME" -stats | grep "^$XWININFO" | awk -F 'id: ' '{print $2}' | cut -d ' ' -f1)

			if [ -n "$SBSVRWID" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Pressing w in '$VRVIDEOPLAYER' window '$SBSVRWINNAME' to adjust view: '$XDO windowactivate --sync $SBSVRWID key w'"
				"$XDO" windowactivate --sync "$SBSVRWID" key w

				writelog "INFO" "${FUNCNAME[0]} - Activating game window with id '$GAMEWINXID' for input"
				"$XDO" windowactivate --sync "$GAMEWINXID" click 1
			else
				writelog "SKIP" "${FUNCNAME[0]} - WARN - SBSVRWID '$SBSVRWID' is empty!"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Skipping because RUNSBSVR was set to 0"
	fi
}

function SBSinitVRVideoPlayer {
	if [ "$RUNSBSVR" -eq 0 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Skipping because RUNSBSVR was set to 0"
		return
	fi

	if [ -z "$GAMEWINXID" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Could not find GAMEWINXID -- Skipping"
		return
	fi

	if [ "$GAMEWINXID" == "0x0" ]; then
		writelog "SKIP" "${FUNCNAME[0]} GAMEWINXID '$GAMEWINXID' is invalid - skipping VR"
		RUNSBSVR=0
		return
	fi

	writelog "INFO" "${FUNCNAME[0]} Using the gamewindow id '$GAMEWINXID' for stereoscopic 3D VR"
	SBSrunVRVideoPlayer	"$GAMEWINXID" 2>/dev/null &
}

function SBSstopVRVideoPlayer {
	if [ "$RUNSBSVR" -eq 1 ]; then

		MAXWAIT=20
		COUNTER=0
		while [ -z "$GAMEWINPID" ]; do
			if [ -f "$CLOSETMP" ]; then
				writelog "WAIT" "${FUNCNAME[0]} - ${PROGNAME,,} is just closing - leaving loop"
				break
			fi
			if [[ "$COUNTER" -ge "$MAXWAIT" ]]; then
				writelog "SKIP" "${FUNCNAME[0]} - ERROR - timeout waiting for Game process - exit"
				break
			fi

			writelog "INFO" "${FUNCNAME[0]} - Don't have a Game process GAMEWINPID yet - waiting"
			getGamePidFromFile
			GAMEWINPID="$(getGamePidFromWindowName)"
			COUNTER=$((COUNTER+1))
			sleep 1
		done

		writelog "INFO" "${FUNCNAME[0]} - Waiting for game process '$GAMEWINPID' to finish..."

		if ! "$PGREP" -a "vrcompositor" >/dev/null ; then
			writelog "SKIP" "${FUNCNAME[0]} - ERROR - vrcompositor not running but it should - bailing out DRYRUN"
		fi

		tail --pid="$GAMEWINPID" -f /dev/null
		writelog "INFO" "${FUNCNAME[0]} - Game process '$GAMEWINPID' finished - closing '$VRVIDEOPLAYER'"

		if [ -f "$GWIDFILE" ]; then
			source "$GWIDFILE"
			GWIDTXT="/tmp/${VRVIDEOPLAYER##*/}_${GWIDDEC}"

			if [ -f "$GWIDTXT" ]; then
				writelog "INFO" "${FUNCNAME[0]} - '$GWIDTXT' found"
				updateConfigEntry "SBSZOOM" "$(cat "$GWIDTXT")" "$SBSTWEAKCFG"
				rm "$GWIDTXT" >/dev/null 2>/dev/null
			else
				writelog "SKIP" "${FUNCNAME[0]} - GWIDTXT '$GWIDTXT' not found - skipping"
			fi
			rm "$GWIDFILE" >/dev/null 2>/dev/null
		else
			writelog "SKIP" "${FUNCNAME[0]} - GWIDFILE '$GWIDFILE' not found - skipping"
		fi

		"$PKILL" -f "$VRVIDEOPLAYER"

		writelog "INFO" "${FUNCNAME[0]} - -------- finished SBS-VR --------"
	else
		writelog "SKIP" "${FUNCNAME[0]} - Skipping because RUNSBSVR was set to 0"
	fi
}

function waitForGameWindowName {
	if [ -n "$GAMEWINDOW" ] && [ "$GAMEWINDOW" != "$NON" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Already have a Game Window '$GAMEWINDOW'"
	else
		MAXWAIT=20
		COUNTER=0
		writelog "INFO" "${FUNCNAME[0]} - Waiting for parallel process to find the Game Window"

		while [ -f "$PIDLOCK" ]; do
			if [ -f "$CLOSETMP" ] || [[ "$COUNTER" -ge "$MAXWAIT" ]]; then
				break
			fi
			COUNTER=$((COUNTER+1))
			sleep 1
		done

		COUNTER=0

		while ! grep -q "^GAMEWINDOW" "$GEMETA/$AID.conf"; do
			if [ -f "$CLOSETMP" ]; then
				writelog "WAIT" "${FUNCNAME[0]} - ${PROGNAME,,} is just closing - leaving loop"
				break
			fi
			if [[ "$COUNTER" -ge "$MAXWAIT" ]]; then
				writelog "SKIP" "${FUNCNAME[0]} - Giving up waiting for GAMEWINDOW to appear in the game metadata '$GEMETA/$AID.conf'"
				break
			fi

			writelog "WAIT" "${FUNCNAME[0]} - WAIT - '$COUNTER/$MAXWAIT' sec waiting for GAMEWINDOW to appear in game metadata '$GEMETA/$AID.conf'"
			COUNTER=$((COUNTER+1))
			sleep 1
		done
		loadCfg "$GEMETA/$AID.conf" X

		if [ -n "$GAMEWINDOW" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Parallel process found Game Window '$GAMEWINDOW'"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Parallel process didn't find a Game Window GAMEWINDOW"
		fi
	fi
}

function getGameWindowXID {
	if [ -n "$GAMEWINXID" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Already have the windowid '$GAMEWINXID'"
	else
		if [ -n "$GAMEWINDOW" ] && [ "$GAMEWINDOW" != "$NON" ]; then
			GAMEWINXID="$("$XWININFO" -name "${GAMEWINDOW//\"/}" -stats | grep "^$XWININFO" | awk -F 'id: ' '{print $2}' | cut -d ' ' -f1)"
			if [ -n "$GAMEWINXID" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found windowid '$GAMEWINXID' for the windowname '$GAMEWINDOW'"
			fi
		fi
		if [ -z "$GAMEWINXID" ]; then
			if [ -n "$GAMEWINPID" ]; then
				GAMEWINXID="$(getGameWinXIDFromPid "$GAMEWINPID")"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Don't have a game pid '$GAMEWINPID' to detect the windowid GAMEWINXID"
			fi
			if [ -n "$GAMEWINXID" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found windowid '$GAMEWINXID' for the game pid '$GAMEWINPID'"
			fi
		fi
	fi
	if [ -n "$GAMEWINPID" ]; then
		echo "$GAMEWINPID"
	else
		writelog "SKIP" "${FUNCNAME[0]} - Failed to detect the windowid GAMEWINXID"
	fi
}

function waitForGameWindowXid {
	if [ -n "$GAMEWINXID" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Already have the game window XID '$GAMEWINXID'"
	else
		if [ -n "$GAMEWINDOW" ] && [ "$GAMEWINDOW" != "$NON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Waiting for a window GAMEWINXID of the game window '$GAMEWINDOW'"
			MAXWAIT=20
			COUNTER=0
			while ! "$XWININFO" -name "${GAMEWINDOW//\"/}"; do
				if [ -f "$CLOSETMP" ]; then
					writelog "WAIT" "${FUNCNAME[0]} - ${PROGNAME,,} is just closing - leaving loop"
					break
				fi
				if [[ "$COUNTER" -ge "$MAXWAIT" ]]; then
					writelog "SKIP" "${FUNCNAME[0]} - Giving up waiting for GAMEWINXID"
					break
				fi

				writelog "WAIT" "${FUNCNAME[0]} - WAIT '$COUNTER/$MAXWAIT'"
				sleep 1
				COUNTER=$((COUNTER+1))
			done
		elif [ -n "$GAMEWINPID" ]; then
			GAMEWINXID="$(getGameWinXIDFromPid "$GAMEWINPID")"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Can't wait for the windowid GAMEWINXID without either a valid GAMEWINDOW or GAMEWINPID"
		fi

		GAMEWINXID="$("$XWININFO" -name "${GAMEWINDOW//\"/}" -stats | grep "^$XWININFO" | awk -F 'id: ' '{print $2}' | cut -d ' ' -f1)"

		if [ -n "$GAMEWINXID" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found the game window id '$GAMEWINXID'"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Didn't find a game window id GAMEWINXID"
		fi
	fi
}

function initSBSVR {
	if [ "$RUNSBSVR" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Checking if VR is available"
		touch "$VRINITLOCK"
		checkHMDPresent
		initSteamVR
		mv "$VRINITLOCK" "$VRINITRESULT"
	fi
}

function startSBSVR {
	if [ "$RUNSBSVR" -eq 0 ]; then
		return
	fi

	MAXWAIT=20
	COUNTER=0

	writelog "INFO" "${FUNCNAME[0]} - Waiting for parallel process to detect VR HMD presence"

	while [ -f "$VRINITLOCK" ]; do
		if [ -f "$CLOSETMP" ] || [[ "$COUNTER" -ge "$MAXWAIT" ]]; then
			break
		fi
		COUNTER=$((COUNTER+1))
		sleep 1
	done

	loadCfg "$VRINITRESULT"
	rm "$VRINITRESULT"

	if [ "$RUNSBSVR" -eq 0 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - VR mode was cancelled, because the parallel process could not initialize VR"
		return
	fi

	if [ -f "$SBSTWEAKCFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Loading SBS configfile '$SBSTWEAKCFG' to get current values"
		loadCfg "$SBSTWEAKCFG"
	fi
	writelog "INFO" "${FUNCNAME[0]} - Preparing VR launch for '$AID'"
	waitForGameWindowName
	waitForGameWindowXid
	SBSinitVRVideoPlayer
	SBSstopVRVideoPlayer


}

function checkHMDPresent {
	if "$PGREP" -a "vrcompositor" >/dev/null ; then
		writelog "INFO" "${FUNCNAME[0]} - Looks like SteamVR is already running - skipping this function"
		return
	fi

	if [ "$CHECKHMD" -eq 0 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Skipping, as '$LSUSB' was not found"
		return
	fi

	UUDEV="/lib/udev/rules.d"
	EUDEV="/etc/udev/rules.d"
	SVR="steam-vr"
	NOVRP="1142"
	FOUNDHMD=0

	SVRRULE="$(find "$UUDEV" -name "*$SVR*")"
	if [ -z "$SVRRULE" ]; then
		SVRRULE="$(find "$EUDEV" -name "*$SVR*")"
	fi

	if [ -n "$SVRRULE" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Found $SVR udev rule - trying to find one of the VR devices before starting SteamVR"

		while read -r line; do
			IDV="$(cut -d ',' -f3 <<< "$line" | grep -oP '"\K[^"]+')"
			IDP="$(cut -d ',' -f4 <<< "$line" | grep -v "$NOVRP" | grep -oP '"\K[^"]+')"
			if [ -n "$IDV" ] && [ -n "$IDP" ]; then
				IDVP="$IDV:$IDP"
				if "$LSUSB" | grep -q "$IDVP"; then
					FOUNDHMD=1
				fi
			fi
		done < "$SVRRULE"
	else
		echo "no $SVR udev rule found"
		writelog "WARN" "${FUNCNAME[0]} - No $SVR udev rule found. As it might be stored under a different name, this is just a warning"
	fi

	if [ "$FOUNDHMD" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Found $SVR hardware using '$LSUSB' - continuing"
	else
		writelog "SKIP" "${FUNCNAME[0]} - No $SVR hardware found using '$LSUSB' - cancelling the SteamVR start"
		RUNSBSVR=0
		echo "RUNSBSVR=\"0\"" > "$VRINITLOCK"
	fi

}

# start game in side-by-side VR:
function checkSBSVRLaunch {
	if [ "$1" != "$NON" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Incoming gamewindow name is '$1'"
		RUNSBSVR=1
	fi

	if [ -z "$RUNSBSVR" ] || [ "$RUNSBSVR" -eq 0 ]; then
		return
	fi
	# override game configs with a sbs-tweak config if available:
	# first look for a global tweak:
	if [ -f "$GLOBALSBSTWEAKCFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - VR using overrides found in '$GLOBALSBSTWEAKCFG'"
		loadCfg "$GLOBALSBSTWEAKCFG"
	fi

	# then for a user tweak - (overriding the global one):
	if [ -f "$SBSTWEAKCFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - VR using overrides found in '$SBSTWEAKCFG'"
		loadCfg "$SBSTWEAKCFG"
	fi

	# start the whole side-by-side process:
	if [ "$1" != "$NON" ]; then
		writelog "INFO" "${FUNCNAME[0]} - ${FUNCNAME[0]} - Using argument 1 as GAMEWINDOW '$GAMEWINDOW'"
		export GAMEWINDOW="$1"
	fi

	writelog "INFO" "${FUNCNAME[0]} - ${FUNCNAME[0]} - Starting VRlaunch for '$AID'"
	if [ "$RUNSBSVR" -eq 1 ]; then
		initSBSVR &
	else
		writelog "SKIP" "${FUNCNAME[0]} - ERROR - RUNSBSVR is '$RUNSBSVR' which is invalid - setting to 0"
		RUNSBSVR=0
	fi

}

function checkSBSLaunch {
	if [ "$RUNSBS" -eq 0 ]; then
		return
	fi

	# first look for a global tweak:
	if [ -f "$GLOBALSBSTWEAKCFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using SBS overrides found in '$GLOBALSBSTWEAKCFG'"
		loadCfg "$GLOBALSBSTWEAKCFG"
	fi

	# then for a user tweak - (overriding the global one):
	if [ -f "$SBSTWEAKCFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using SBS overrides found in '$SBSTWEAKCFG'"
		loadCfg "$SBSTWEAKCFG"
	fi

}

