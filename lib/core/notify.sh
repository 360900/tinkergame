#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function notiShow {
	if [ "$ONSTEAMDECK" -eq 1 ] && [ "$FIXGAMESCOPE" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Skipping notifier on SteamDeck Game Mode"
		USENOTIFIER=0 # might avoid a 2nd try during this session
	elif [ "$STLQUIET" -eq 1 ]; then
		USENOTIFIER=0
	else
		if [ -n "$2" ] && [ "$2" == "X" ]; then
			if [ -z "$NOTY" ]; then
				NOTY="$(command -v "notify-send")"
			fi
		fi

		if [ -n "$USENOTIFIER" ] && [ "$USENOTIFIER" -eq 1 ] && { [ -z "$2" ] || { [ -n "$2" ] && [ "$2" != "S" ]; };} || { [ -n "$2" ] && [ "$2" == "X" ]; }; then
			if [ -x "$(command -v "$NOTY")" ]; then
				if [ -z "${NOTYARGSARR[0]}" ]; then
					mapfile -d " " -t -O "${#NOTYARGSARR[@]}" NOTYARGSARR < <(printf '%s' "$NOTYARGS")
				fi
				"$NOTY" "${NOTYARGSARR[@]}" "$1"
			else
				writelog "INFO" "${FUNCNAME[0]} - Warning - '$NOTY' not found - disabling notifier"
				USENOTIFIER=0
			fi
		fi

		if [ -n "$2" ] && [ "$2" == "S" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Message '$1' should go to StatusWindow"
			echo "$1"
		fi
	fi
}

function strFix {
	STRIN="$1"
	if [ -z "$2" ]; then
		echo "$STRIN"
	else
		STRIN2="${STRIN//XXX/$2}"
		STRIN3="${STRIN2//YYY/$3}"
		STRIN4="${STRIN3//ZZZ/$4}"
		echo "${STRIN4//QQQ/$5}"
	fi
}

