#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function checkStartMode {
	if [ -n "${ORGGCMD[0]}" ]; then

		writelog "INFO" "${FUNCNAME[0]} - LoadCfg: $STLGAMECFG"
		loadCfg "$STLGAMECFG"

		if [ "$ISGAME" -eq 2 ]; then
			if [ -n "$USEWINE" ] && [ "$USEWINE" -eq 1 ]; then
				writelog "SKIP" "${FUNCNAME[0]} - USEWINE is enabled - skipping this function"
			elif grep -q "USEWINE=\"1\"" "$STLGAMECFG" ; then
				writelog "SKIP" "${FUNCNAME[0]} - USEWINE is enabled in the to-be-loaded gameconfig '$STLGAMECFG' - skipping this function"
				EARLYUSEWINE=1
				# could still be enabled via steamcollections, but this would be an overkill here, as ${FUNCNAME[0]} is non-fatal
			else
				if [ "$HAVEINPROTON" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - Game was started via '$SLO' ('$PROGCMD %command%'),"
					writelog "INFO" "${FUNCNAME[0]} - because a Proton path was found in the command line provided by steam"
					writelog "INFO" "${FUNCNAME[0]} - Override Proton is disabled, when using $PROGCMD as '$SLO', so using it as-is: '${INPROTCMD[*]}'"
					writelog "INFO" "${FUNCNAME[0]} - (ignoring USEPROTON '$USEPROTON' from game config)"
					RUNPROTON="${INPROTCMD[*]}"
					writelog "INFO" "${FUNCNAME[0]} - Set RUNPROTON to '$RUNPROTON'"

					USEPROTON="$INPROTV"
					writelog "INFO" "${FUNCNAME[0]} - Set USEPROTON to '$USEPROTON'"
				else
					writelog "INFO" "${FUNCNAME[0]} - Game was started as Steam Compatibility Tool - automatically enabling override Proton,"
					writelog "INFO" "${FUNCNAME[0]} - as proton doesn't appear in the command line here"
					setRunProtonFromUseProton
				fi

				writelog "INFO" "${FUNCNAME[0]} - Continuing with RUNPROTON='$RUNPROTON'"

				if [ -n "$RUNPROTON" ]; then
					CHECKWINE="$(dirname "$RUNPROTON")/$DBW"

					if [ -f "$CHECKWINE" ]; then
						RUNWINE="$CHECKWINE"
						writelog "INFO" "${FUNCNAME[0]} - Set the wine binary for proton in path '$RUNPROTON' to '$RUNWINE'"
					else
						writelog "WARN" "${FUNCNAME[0]} - Couldn't find the wine binary for the proton in path '$RUNPROTON'"
					fi

					PROTONVERSION="$(setProtonPathVersion "$RUNPROTON")"
				fi
			fi
		fi
	fi
}

function getDefaultProton {
	if [ -n "$INPROTV" ]; then
		echo "$INPROTV"
	else
		getNOP "v"
	fi
}

function rmFileIfExists {
	if [ -f "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Removing '$1'"
		rm "$1"
	fi
}

function rmDirIfExists {
	if [ -d "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Removing '$1'"
		rm -rf "$1"
	fi
}

function FUSEID {
	if [ -n "$1" ]; then
		USEID="$1"
	else
		USEID="$AID"
	fi

	if [ "$USEID" == "$PLACEHOLDERAID" ]; then
		if [ -f "$LASTRUN" ]; then
			PREVAID="$(grep "^PREVAID" "$LASTRUN" | cut -d '=' -f2)"
			if [ -n "$PREVAID" ]; then
				USEID="${PREVAID//\"}"
				PREVGAME="$(grep "^PREVGAME" "$LASTRUN" | cut -d '=' -f2)"
				if [ -n "$PREVGAME" ]; then
					GN="${PREVGAME//\"}"
				fi
			fi
		fi
	fi

	rmFileIfExists "$LOGDIR/$USEID.log"
	resetAID "$USEID"
	setGN "$USEID"
}


# waits until file $1 exists, polling every ${3:-1} seconds; gives up after
# $2 seconds (0 = wait forever) and returns 1 - bounded replacement for
# unbounded 'while [ ! -f ]' busy-waits
function tgWaitForFile {
	local WAITFILE="$1"
	local WAITMAX="$2"
	local WAITSTEP="${3:-1}"
	local WAITED=0

	while [ ! -e "$WAITFILE" ]; do
		if [ "$WAITMAX" -gt 0 ] && [ "$WAITED" -ge "$WAITMAX" ]; then
			writelog "WAIT" "${FUNCNAME[0]} - '$WAITFILE' did not appear within '$WAITMAX' seconds - giving up"
			return 1
		fi
		sleep "$WAITSTEP"
		WAITED=$(( WAITED + WAITSTEP ))
	done

	return 0
}
