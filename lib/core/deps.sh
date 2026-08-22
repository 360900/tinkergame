#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function checkIntDeps {

	if [ "$SKIPINTDEPCHECK" -eq 1 ] || [ "$1" == "yad" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Skipping dependency check for internally used programs"
	else
		DEPSMISSING=0

		while read -r INTDEP; do
			if [ ! -x "$(command -v "${!INTDEP}")" ]; then
				writelog "ERROR" "${FUNCNAME[0]} - ${!INTDEP} not found!" "E"
				notiShow "$(strFix "$NOTY_NOTFOUND" "${!INTDEP}")"
				DEPSMISSING=1
			fi
		done <<< "$(sed -n "/^#STARTINTDEPS/,/^#ENDINTDEPS/p;/^#ENDINTDEPS/q" "$TGSRC_COMMON" | grep -v "^#" | cut -d '=' -f1)"

		if [ -z "$YAD" ]; then
			YAD="$(command -v "yad")"
		fi

		if [ -n "$YAD" ] && [ ! -f "$YAD" ]; then
			OYAD="$YAD"
			writelog "WARN" "${FUNCNAME[0]} - Configured YAD '$YAD' was not found!  Trying to find in in a new location" "E"
			NYAD="$(command -v "yad")"
			if [ -n "$NYAD" ] && [ "$NYAD" != "$OYAD" ];then
				writelog "INFO" "${FUNCNAME[0]} - Updating YAD from '$OYAD' to '$NYAD'" "E"
				YAD="$NYAD"
				touch "$FUPDATE"
				updateConfigEntry "YAD" "$NYAD" "$STLDEFGLOBALCFG"
			else
				writelog "WARN" "${FUNCNAME[0]} - Could not find a new $YAD version" "E"
			fi
		fi

		if [ ! -x "$(command -v "$YAD")" ]; then
			DEPSMISSING=1
			writelog "ERROR" "${FUNCNAME[0]} - Yad dependency ('$YAD') was not found! Check '${PROGCMD} --help' for alternatives and/or read '$PROJECTPAGE/wiki/Yad'" "E"
			notiShow "$(strFix "$NOTY_NOTFOUND" "$YAD")"
		fi


		if [ ! -x "$(command -v "steam")" ] && [ "$INFLATPAK" -eq 0 ]; then
			DEPSMISSING=1
			writelog "ERROR" "${FUNCNAME[0]} - Steam not found" "E"
		fi

		setAwkBin

		if [ "$ONSTEAMDECK" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Skipping yad version check on SteamDeck"
		else
			MINYAD="7.2"
			YADVER="0"

			if [ -f "$YAD" ]; then
				YADVER="$("$YAD" --version | tail -n1 | cut -d ' ' -f1)"
				writelog "INFO" "${FUNCNAME[0]} - Result of version check for yad binary '$YAD' is '$YADVER'"
			fi

			if [ "$(printf '%s\n' "$MINYAD" "$YADVER" | sort -V | head -n1)" != "$MINYAD" ]; then
				writelog "ERROR" "${FUNCNAME[0]} - Yad version '$YADVER' is too old. You need to update to at least '$MINYAD'" "E"
				notiShow "$(strFix "$NOTY_NOTFOUND2" "$YADVER" "$MINYAD")"
				if ! isHelpOrVersionArg "$1"; then
					exit
				fi
			else
				# If the Yad version is valid, and if we don't have Yad in the config file currently, write it out
				if [ -f "$YAD" ] && grep -q "YAD=\"\"" "$STLDEFGLOBALCFG"; then
					writelog "INFO" "${FUNCNAME[0]} - Internal Yad variable is '$YAD' but Yad is not defined in the Global Config, updating with Yad variable value..."

					touch "$FUPDATE"
					updateConfigEntry "YAD" "$YAD" "$STLDEFGLOBALCFG"
				else
					writelog "INFO" "${FUNCNAME[0]} - Yad is set correctly in the Global Config, nothing to do."
				fi
			fi
		fi

		if [ "$DEPSMISSING" -eq 1 ]; then
			writelog "ERROR" "${FUNCNAME[0]} - Above programs need to be installed to use '${PROGNAME,,}'" "E"
			writelog "ERROR" "${FUNCNAME[0]} The dependency check can be disabled by enabling 'SKIPINTDEPCHECK' - exiting now" "E"
			if ! isHelpOrVersionArg "$1"; then
				exit
			fi
		fi
	fi
}

#####################################################
### CORE LAUNCH START ###

