#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function getUsedVars {
	while read -r line; do
		if grep -q -v "^#" <<< "$line"; then
			awk -F '=' '{print $1}' <<< "$line"
		fi
	done <"$1"
}

function getScreenRes {
	function widthList {
		"$XRANDR" --verbose 2>/dev/null | grep "\*" -A2 | grep -oP 'width\K[^start]+'
	}

	function heightList {
		"$XRANDR" --verbose 2>/dev/null | grep "\*" -A2 | grep -oP 'height\K[^start]+'
	}

	function getRes {
		if grep -q "^[0-9]*$" <<< "$FOUNDW" && grep -q "^[0-9]*$" <<< "$FOUNDH"; then
			FOUNDRES="${FOUNDW}x${FOUNDH}"
			writelog "INFO" "${FUNCNAME[0]} - Detected screen resolution '$FOUNDRES'" "X"
			echo "$FOUNDRES"
		else
			writelog "INFO" "${FUNCNAME[0]} - Screen resolution for width '$FOUNDW' and height '$FOUNDH' is invalid" "X"
		fi
	}

	HCNT="$(wc -l <<< "$(widthList)")"
	if [ "$HCNT" -eq 1 ] || [ "$HCNT" -gt 2 ]; then
		FOUNDW="$(widthList | head -n1 | tr -dc '0-9')"
		FOUNDH="$(heightList | head -n1 | tr -dc '0-9')"
	else
		XCUT="$("$XRANDR" --listactivemonitors 2>/dev/null | grep -Eo "\+[1-9][[:digit:]]*\+" | grep -Eo "[[:digit:]]*")"
		MPOS="$("$XDO" getmouselocation --shell | head -n1 | cut -d '=' -f2)"
		if [ "$MPOS" -gt "$XCUT" ]; then
			FOUNDW="$(widthList | tail -n1 | tr -dc '0-9')"
			FOUNDH="$(heightList | tail -n1 | tr -dc '0-9')"
		else
			FOUNDW="$(widthList | head -n1 | tr -dc '0-9')"
			FOUNDH="$(heightList | head -n1 | tr -dc '0-9')"
		fi
	fi

	if [ "$1" == "w" ]; then
		if grep -q "^[0-9]*$" <<< "$FOUNDW"; then
			writelog "INFO" "${FUNCNAME[0]} - Found screen width '$FOUNDW'" "X"
			echo "$FOUNDW"
		else
			writelog "INFO" "${FUNCNAME[0]} - Screen width '$FOUNDW' is invalid" "X"
		fi
	elif [ "$1" == "h" ]; then
		if grep -q "^[0-9]*$" <<< "$FOUNDH"; then
			writelog "INFO" "${FUNCNAME[0]} - Found screen height '$FOUNDH'" "X"
			echo "$FOUNDH"
		else
			writelog "INFO" "${FUNCNAME[0]} - Screen height '$FOUNDH' is invalid" "X"
		fi
	else
		getRes
	fi
}

function listScreenRes {
	while read -r lres; do
		echo "${lres%*[[:blank:]]}" | cut -d ' ' -f1
	done <<< "$("$XRANDR" --verbose 2>/dev/null | grep "+VSync$")" | sort -nur
}

function setInitWinXY {
	DEFRESSHM="$STLSHM/defres.txt"
	if [ -f "$DEFRESSHM" ] ; then
		loadCfg "$DEFRESSHM" X
		# a cached default from a session with a bigger screen must not be
		# reused on a smaller one - clamp it to the current screen
		TGCLAMPXY="$(tgClampWinXY "$WINX" "$WINY" "${TGSCRW:-}" "${TGSCRH:-}")"
		if [ -n "$TGCLAMPXY" ]; then
			read -r WINX WINY <<< "$TGCLAMPXY"
		fi
		writelog "INFO" "${FUNCNAME[0]} - Using '${WINX}x${WINY}' from config '$DEFRESSHM'"
	else
		if [ "$ONSTEAMDECK" -eq 1 ]; then
			WINX="1280"
			WINY="800"
		else
			SCRW="$(getScreenRes w)"
			SCRH="$(getScreenRes h)"
			WINX=$(( SCRW / 2))
			WINY=$(( SCRH / 2))
		fi

		{
		echo "WINX=\"$WINX\""
		echo "WINY=\"$WINY\""
		} >> "$DEFRESSHM"
		writelog "INFO" "${FUNCNAME[0]} - Using '${WINX}x${WINY}' as default resolution for all windows without a configured resolution"
	fi
}

function setNewRes {
	SCREENRES="$(getScreenRes r)"
	if [ "$GAMESCREENRES" != "$NON" ] && [ "$GAMESCREENRES" != "$SCREENRES" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Setting screen resolution to '$GAMESCREENRES' using '$XRANDR'" "X"
		"$XRANDR" -s "$GAMESCREENRES"
	fi
}

function setPrevRes {
	if [ "$GAMESCREENRES" != "$NON" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Returning to previous screen resolution via '$XRANDR -s 0'" "X"
		"$XRANDR" -s 0
	fi
}

function customUserScriptStart {
	if [ -n "$USERSTART" ] && [[ ! "$USERSTART" =~ ${DUMMYBIN}$ ]]; then
		if [ -x "$USERSTART" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Starting custom user startscript '$USERSTART'"
			if [ "$USEWINE" -eq 0 ]; then
				"$USERSTART" "1" "$AID" "$GP" "$GPFX" &
			else
				"$USERSTART" "1" "$AID" "$GP" "$GWFX" &
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Custom user startscript '$USERSTART' not found or not executable"
		fi
	fi
}

function customUserScriptStop {
	if [ -n "$USERSTOP" ] && [[ ! "$USERSTOP" =~ ${DUMMYBIN}$ ]]; then
		if [ -x "$USERSTOP" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Starting custom user stopscript '$USERSTOP'"
			if [ "$USEWINE" -eq 0 ]; then
				"$USERSTOP" "0" "$AID" "$GP" "$GPFX" &
			else
				"$USERSTOP" "0" "$AID" "$GP" "$GWFX" &
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Custom user stopscript '$USERSTOP' not found or not executable"
		fi
	fi
}

function editorSkipped {
	if [ -z "$MAXASK" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Maximal editor requester count MAXASK not defined - skipping"
	else
		if ! grep -q "^ASKCNT" "$STLGAMECFG"; then
			SETASKCNT=1
			updateConfigEntry "ASKCNT" "$SETASKCNT" "$STLGAMECFG"
		else
			SETASKCNT=$(($(grep "ASKCNT" "$STLGAMECFG" | cut -d '=' -f2 | sed 's/\"//g') +1))
			updateConfigEntry "ASKCNT" "$SETASKCNT" "$STLGAMECFG"
		fi

		ASKCNT="$SETASKCNT"

		if [ "$ASKCNT" -ge "$MAXASK" ]; then
			notiShow "$(strFix "$NOTY_CANCELREQ1" "$ASKCNT" "$GN" "$AID")"
			writelog "INFO" "${FUNCNAME[0]} - 'ASKCNT $ASKCNT' reached 'MAXASK $MAXASK' - suggesting to disable the requester via the '$BUT_SKIPCG' button"
		else
			notiShow "$(strFix "$NOTY_CANCELREQ2" "$ASKCNT" "$GN" "$AID")"
		fi
	fi
}

function editorDontAskAgain {
	writelog "INFO" "${FUNCNAME[0]} - Disabling Wait Requester for '$GN ($AID)' in '$STLGAMECFG'"
	updateConfigEntry "WAITEDITOR" "0" "$STLGAMECFG"
	updateConfigEntry "ASKCNT" "0" "$STLGAMECFG"
	notiShow "$(strFix "$NOTY_DONTASK" "$GN" "$AID")"
}

function checkWaitRequester {
	if [ -f "$EWRF" ] ; then
		if grep -q "^WAITEDITOR=\"0\"" "$STLGAMECFG"; then
			writelog "INFO" "${FUNCNAME[0]} - Re-enabling Wait Requester in '$STLGAMECFG', because '$EWRF' was found"
			updateConfigEntry "WAITEDITOR" "2" "$STLGAMECFG"
		fi
		rm "$EWRF"
	fi

	if [ -f "$UWRF" ] ; then
		if [ -f "$SWRF" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Stop skipping Wait Requester, because '$UWRF' was found"
			rm "$SWRF"
		fi
		rm "$UWRF"
	fi
}

function askSettings {
	if ! grep -q "^WAITEDITOR=\"0\"" "$STLGAMECFG"; then
		if [ -f "$SWRF" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Skipping the start menu because skip file was found under '$SWRF'"
		else
			if grep -q "^WAITEDITOR" "$STLGAMECFG"; then
				WEDGAME="$(grep "^WAITEDITOR" "$STLGAMECFG"| cut -d '=' -f2)"
				WAITEDITOR="${WEDGAME//\"/}"
				writelog "INFO" "${FUNCNAME[0]} - Using game specific requester setting '$WAITEDITOR'"
			fi

			writeAllAIMeta "$AID" &

			if [ "$WAITEDITOR" -gt 0 ]; then
				# WAITEDITOR used to show a requester asking whether the menu
				# should be opened before the game starts - the menu is now
				# opened directly, without the extra question
				if [ "$STARTMENU" == "Editor" ]; then
					LAUNCHMENU="EditorDialog"
				elif [ "$STARTMENU" == "Favorites" ]; then
					LAUNCHMENU="favoritesMenu"
				elif [ "$STARTMENU" == "Game" ]; then
					LAUNCHMENU="openGameMenu"
				else
					LAUNCHMENU="MainMenu"
				fi

				writelog "INFO" "${FUNCNAME[0]} - WAITEDITOR is '$WAITEDITOR' - opening the '$LAUNCHMENU' start menu directly"
				"$LAUNCHMENU" "$AID"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Skipping the start menu because WAITEDITOR is 0 in '$STLGAMECFG'"
	fi
}

# create project dir $1 - no idea what the former arg2 was good for :)
