#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function getLatestX64dbgSnap {
	# TODO this could be improved, PR welcome!

	# wget the expanded assets page and get the first link contents
	# could be prettier and more robust but should work for now, despite being a little flimsy
	NEWX64DBGURL="https://github.com/x64dbg/x64dbg"  # global config one is a bit busted and can't be easily migrated
	X64DSNAPPATH="$( "$WGET" -q "${NEWX64DBGURL}/releases/expanded_assets/snapshot" -O - 2> >(grep -v "SSL_INIT") | grep -E "releases/download" | grep -oP '".*?"' | head -n1 | cut -d '"' -f2 )"  # doesn't return full path, only /x64dbg/x64dbg/releases/download/snapshot/snapshot_<date>.zip
	echo "${GHURL}${X64DSNAPPATH}"
}

function dlX64Dbg {
	DLDST="$X64DBGDLDIR"
	DLCH="$DLDST/commithash.txt"
	if [ -f "$DLCH" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - '$X64D' is already ready"
		return
	fi

	mkProjDir "$DLDST"
	X64ZIP="$(getLatestX64dbgSnap)"
	X64ZIPBASE="$( basename "$X64ZIP" )"

	# Download x64dbg
	if [ ! -f "$DLDST/$X64ZIPBASE" ]; then
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$X64ZIP")" "S"
		dlCheck "$X64ZIP"  "$DLDST/$X64ZIPBASE" "X" "Downloading 'x64dbg'"
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$X64ZIP")" "S"
	fi

	DLDST="$X64DBGDLDIR"
	if [ ! -s "$DLDST" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Downloaded file '$DLDST/$X64ZIPBASE' is empty - removing"
		rm "$DLDST/$X64ZIPBASE" 2>/dev/null
		return
	fi

	# Extract x64dbg
	notiShow "$(strFix "$NOTY_DLCUSTOMPROTON3" "$X64ZIPBASE")" "S"
	writelog "INFO" "${FUNCNAME[0]} - Download of '$X64ZIPBASE' to '$DLDST' was successful"
	"$UNZIP" -q "$DLDST/$X64ZIPBASE" -d "$DLDST" 2>/dev/null
	notiShow "$GUI_DONE" "S"
	if [ -f "$DLCH" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Extracted '$X64ZIPBASE' to '$DLDST'"
	else
		writelog "SKIP" "${FUNCNAME[0]} - Extracting of file '$DLDST/$X64ZIPBASE' failed"
	fi
}

# start x64dbg
function checkX64dbgLaunch {
	if [ "$RUN_X64DBG" -eq 1 ] && [ "$ISGAME" -eq 2 ] && [ "$USEWINE" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Starting '$X64D' for '$GE ($AID)'"

		if [ "$(getArch "$GP")" == "32" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using '$X32D' as '$GE' is 32bit"
			XDBGEXE="$X32D"
		elif [ "$(getArch "$GP")" == "64" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using '$X64D' as '$GE' is 64bit"
			XDBGEXE="$X64D"
		else
			writelog "INFO" "${FUNCNAME[0]} - Could not get architecture of '$GP' - using '$X64D'"
			XDBGEXE="$X64D"
		fi

		XDBFPATH="$X64DBGDLDIR/release/${XDBGEXE//dbg/}/${XDBGEXE}.exe"

		if [ ! -f "$XDBFPATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - File '$X64EXE' does not exit - starting installer"
			StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "$X64D")" "dlX64Dbg" "DownloadX64DbgStatus"
		fi

		if [ ! -f "$XDBFPATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Installing failed - can't start '$XDBFPATH' - skipping"
			RUN_X64DBG=0
		else
			writelog "INFO" "${FUNCNAME[0]} - Applying registry '${X64D}.reg'"
			regEdit "$GLOBALMISCDIR/${X64D}.reg"

			DISPPROTVER="$( setProtonPathVersion "$RUNPROTON" )"
			if [ "$X64DBG_ATTACHONSTARTUP" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Attaching game '$GE' running with '$RUNWINE' to x64dbg"
				writelog "INFO" "${FUNCNAME[0]} - Game execution will be handled by x64dbg from here"
				notiShow "$( strFix "$NOTY_X64DBG_ATTACHONSTARTUP" "$DISPPROTVER" "$GE" "$AID" )"

				WGP="$(extWine64Run "$RUNWINE" winepath -w "$GP" | tail -n1)"
				extWine64Run "$RUNWINE" "$XDBFPATH" "$WGP"  # Start x64dbg with game attached, but do NOT start the game
			else
				writelog "INFO" "${FUNCNAME[0]} - Launching x64dbg standalone with no process attached -- Game execution will continue normally"
				notiShow "$( strFix "$NOTY_RUN_X64DBG" "$DISPPROTVER" "$GE" "$AID" )"
				# does sleep 5 work on all systems with all games? May need changed/better solution in future!
				(sleep 5; "$RUNPROTON" run "$XDBFPATH" ) &  # Start x64dbg standalone with no process attached, and then launch game
			fi
		fi
	fi
}

function prepareGdb {
	GDBOPTS="$STLSHM/gdb.conf"
	WIREPY="WineReload.py"
	WINEREL="$STLSHM/$WIREPY"
	WIREURL="$WINERELOADURL/$WIREPY"
	GST10="gstreamer-1.0"

	if [ ! -f "$WINEREL" ]; then
		dlCheck "$WIREURL" "$WINEREL" "X" "Downloading '$DLSRC' to '$DLDST'"
	fi

	if [ ! -f "$GDBOPTS" ]; then
		{
		echo "set confirm off"
		echo "set pagination off"
		echo "handle SIGUSR1 noprint nostop"
		echo "handle SIGSYS noprint nostop"
		echo "source $WINEREL"
		} > "$GDBOPTS"
	fi

	if [ -z "$RUNPROTON" ]; then
		setRunProtonFromUseProton
	fi

	PROTONBASEPATH="$(dirname "$RUNPROTON")/files"
	if [ ! -d "$PROTONBASEPATH" ]; then
		PROTONBASEPATH="$(dirname "$RUNPROTON")/dist"
	fi

	setRunWineServer "${FUNCNAME[0]}"

	PBIPA="$PROTONBASEPATH/bin"
	PLIPA="$PROTONBASEPATH/lib"
	PLIPA64="$PROTONBASEPATH/lib64"


	if [ -n "$(GETALTEXEPATH)" ]; then
		WORKDIR="$(GETALTEXEPATH)"
	else
		WORKDIR="$EFD"
	fi

	{
	head -n1 "$0"
	echo "PATH=\"$PATH=:$PBIPA\" WINEDEBUG=\"-all\" WINEDLLPATH=\"${PLIPA64}/wine:${PLIPA}/wine:$WINEDLLPATH\" LD_LIBRARY_PATH=\"$LD_LIBRARY_PATH:${PLIPA64}:${PLIPA}:$WORKDIR\" \
	WINEPREFIX=\"$GPFX\" WINEESYNC=1 WINEFSYNC=1 WINEDLLOVERRIDES=\"$WINEDLLOVERRIDES;steam.exe=b;dotnetfx35.exe=b;dxvk_config=n;d3d11=n;d3d10=n;d3d10core=n;d3d10_1=n;d3d9=n;dxgi=n\" \
	WINE_LARGE_ADDRESS_AWARE=1 GST_PLUGIN_SYSTEM_PATH_1_0=\"${PLIPA64}/${GST10}:${PLIPA}/${GST10}:$GST_PLUGIN_SYSTEM_PATH_1_0\" WINE_GST_REGISTRY_DIR=\"${WINEPREFIX}/${GST10}/\" \
	\"$RUNWINE\" \"steam.exe\" \"${GDBGAMESTARTCMD[*]}\""
	} > "$GDBGAMERUN"
	chmod +x "$GDBGAMERUN"
}

#start gdb
function injectGdb {
	function setgampi {
		GAMPI="$("$PGREP" -a "" | grep -i "${GP##*/}"  | grep "Z:" | grep -v "$PROGCMD" | cut -d ' ' -f1 | tail -n1)"
	}

	MAXWAIT=5
	COUNTER=0

	while ! [ "$GAMPI" -eq "$GAMPI" ] 2>/dev/null; do
		writelog "INFO" "${FUNCNAME[0]} - setgampi"
		setgampi
		if [[ "$COUNTER" -ge "$MAXWAIT" ]]; then
			writelog "ERROR" "${FUNCNAME[0]} - Timeout waiting for game pid $GAMPI - Skipping '$GDB'"
			return
		fi
		COUNTER=$((COUNTER+1))
		sleep 1
	done

	if [ -n "$GAMPI" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Found GamePid '$GAMPI' - Starting '$GDB'"
		{
		head -n1 "$0"
		echo "\"$GDB\" \"-x\" \"$GDBOPTS\" \"-p\" \"$GAMPI\""
		} > "$GDBRUN"
		chmod +x "$GDBRUN"
		"$USETERM" "$TERMARGS" "bash -c \"$GDBRUN\""
	fi
}

### BEGIN TEXT-BASED VDF INTERACTION FUNCTIONS
##
## This was written for Blush (https://github.com/sonic2kk/blush/) as part of the research on how to implement #905
## The code is pretty much the same but with variable names adapted to the TinkerGame "convention"
## The code on Blush exists so this code can be used by others outside of TinkerGame more easily

