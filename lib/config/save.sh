#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.
#
# Config writers. The set of keys, their order and their description comments
# come from the option schema (data/options.def, loaded via lib/config/schema.sh).

function saveCfg {

	# write a complete fresh config for scope $1 into file $2 (which must not exist yet):
	function tgWriteNewConfig {
		local key desc
		{
			echo "## config Version: $PROGVERS"
			if [ "$1" = "url" ]; then
				echo "##########################"
				echo "## Url Config:"
				echo "##########################"
			fi
			while IFS= read -r key; do
				[ -n "$key" ] || continue
				desc="$(tgSchemaDesc "$1" "$key")"
				if [ -n "$desc" ]; then
					echo "## $(tgExpandDesc "$desc")"
				fi
				echo "${key}=\"${!key}\""
			done <<< "$(tgSchemaKeys "$1")"
		} >> "$2"
	}

	# create or update the config file $2 for scope $1 (url|gui|global|default_template):
	function tgSaveScope {
		case "$1" in
			url|global|default_template) setDefaultCfgValues "$1" ;;
		esac

		if [ -f "$2" ]; then
			updateConfigFile "$2" "$1" "$3"
		else
			tgWriteNewConfig "$1" "$2"
		fi

		if [ "$1" = "global" ]; then
			updateEditor "$2"
		fi
	}

	SCFG="$(basename "${1//.conf/}")"
	if tgSchemaKeys "$SCFG" | grep -q .; then
		tgSaveScope "$SCFG" "$1" "$2"
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$1' does not resolve to a known config scope ('$SCFG') - skipping"
	fi

	if [ -f "$1" ] && grep "$STLCFGDIR" "$1" >/dev/null ; then
		writelog "UPDATE" "${FUNCNAME[0]} - Replacing '$STLCFGDIR' with 'STLCFGDIR' in '$1'"
		sed "s:$STLCFGDIR:STLCFGDIR:g" -i "$1"
	fi
}
