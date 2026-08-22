#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function yadSupportsOption {
	grep -q -- "$1" <<< "$YADHELP"
}

function prepareGUI {
	# Yad 15.0 dropped '--image-on-top' and '--decorated'. Yad refuses to start at
	# all when it is handed an option it does not know, exiting with
	# "Unable to parse command line: Unknown option ...", so passing these
	# unconditionally makes every TinkerGame window close the instant it is
	# opened on Yad 15.0 and newer.
	#
	# We ask Yad what it supports instead of comparing version strings, so this
	# also behaves for distro patches, forks and future Yad releases. If the query
	# fails for any reason both options are simply left out, which costs nothing
	# but cosmetics and never prevents a window from opening.
	YADHELP="$("${YAD:-yad}" --help-all 2>/dev/null)"

	# These are arrays on purpose. An unsupported option has to vanish from the
	# command line completely: passing an empty string instead would hand Yad an
	# empty positional argument, which it consumes as the first '--field' value
	# and shifts every following field value by one.
	YADIMGTOP=()
	if yadSupportsOption "--image-on-top"; then
		YADIMGTOP=( "--image-on-top" )
	else
		writelog "INFO" "${FUNCNAME[0]} - Yad has no '--image-on-top' option (removed in Yad 15.0) - omitting it"
	fi

	WINDECO=( "--undecorated" )
	if [ -n "$USEWINDECO" ]; then
		if [ "$USEWINDECO" -eq 1 ]; then
			if yadSupportsOption "--decorated"; then
				WINDECO=( "--decorated" )
			else
				# Decorated windows are the Yad 15.0 default, so passing no
				# option at all is equivalent to the old '--decorated'.
				WINDECO=()
				writelog "INFO" "${FUNCNAME[0]} - Yad has no '--decorated' option (removed in Yad 15.0) - using the Yad default instead"
			fi
		elif [ "$USEWINDECO" -eq 0 ] && [ "$XDG_SESSION_TYPE" == "wayland" ]; then
			writelog "WARN" "${FUNCNAME[0]} - Disabling Yad window decorations does nothing on Wayland!"
		fi
	fi
}

function createLanguageList {
	function listLANG {
		while read -r RSPF; do
			TLANG="${RSPF//.txt/}"
			TLANG="${TLANG##*/}"
			printf '%s!' "$TLANG"
		done <<< "$(find "$STLLANGDIR" -name "*.txt")"

		while read -r RSPF; do
			TLANG="${RSPF//.txt/}"
			TLANG="${TLANG##*/}"
			printf '%s!' "$TLANG"
		done <<< "$(find "$GLOBALSTLLANGDIR" -name "*.txt")"
	}
	LANGYADLIST="$(listLANG)"
}

