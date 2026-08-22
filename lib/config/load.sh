#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function loadCfg {
	CFGFILE="$1"

	if [ -f "$CFGFILE" ]; then

		# disable logging here when the program just started (cosmetics)
		if [ -z "$2" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$CFGFILE' START"
		fi

		if [ "$CFGFILE" == "$STLGAMECFG" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Loading game config '$CFGFILE'"
		fi

		while read -r line; do
			if [ -n "$line" ]; then
				EXPORTLINE="${line//\"/}"
				EXPORTLINE="${EXPORTLINE//STLCFGDIR/$STLCFGDIR}"
				export "${EXPORTLINE?}"
			fi
		done <<< "$(grep -v "^#\|^$" "$CFGFILE")"

		# config migration #XXXXXXXXXXXXXX
		migrateCfgOption "$CFGFILE"

		# disable logging here when the program just started (cosmetics)
		if [ -z "$2" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$CFGFILE' STOP"
		fi
	fi
}

