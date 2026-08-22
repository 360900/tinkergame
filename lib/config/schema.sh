#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.
#
# Runtime access to the option schema (data/options.def). The schema is the
# single source of truth for which config keys exist in which scope, their
# order, and the description comments written into config files.

# NOTE: the arrays are declared with 'declare -gA' inside tgSchemaInit (not at
# the top level of this file) so they stay global even when the entry point is
# sourced from within a function (as the test harness does).

# load data/options.def once (no-op on subsequent calls):
function tgSchemaInit {
	if [ "$TG_SCHEMA_LOADED" = 1 ]; then
		return 0
	fi

	if [ -z "${TGOPTDEF:-}" ] || [ ! -f "$TGOPTDEF" ]; then
		if declare -F writelog >/dev/null 2>&1; then
			writelog "ERROR" "${FUNCNAME[0]} - Option schema '$TGOPTDEF' not found - cannot initialize config system"
		fi
		return 1
	fi

	declare -gA TG_OPT_DESC    # "scope:key" -> desc template
	declare -gA TG_OPT_KEYS    # "scope"     -> newline-separated ordered key list

	# NOTE: deliberately NOT a "while read ... done < file" loop: read is a
	# per-line builtin and test frameworks install per-command DEBUG traps,
	# which makes that construct grind to a halt here (one trap per command
	# and ~5 commands per schema line). mapfile slurps the file in one go.
	local -a rows
	mapfile -t rows < "$TGOPTDEF"

	local scope key dflt desc row
	for row in "${rows[@]}"; do
		IFS=$'\t' read -r scope key dflt desc <<< "$row"
		case "$scope" in
			"#"*|"") continue ;;
		esac
		TG_OPT_KEYS[$scope]+="${key}"$'\n'
		TG_OPT_DESC[$scope:$key]="$desc"
	done

	TG_SCHEMA_LOADED=1
	return 0
}

# print all keys of $1 (url|gui|global|default_template), one per line, in schema order:
function tgSchemaKeys {
	if ! tgSchemaInit; then
		return 1
	fi
	printf '%s' "${TG_OPT_KEYS[$1]:-}"
}

# check if $2 is a valid key in scope $1:
function tgSchemaHasKey {
	if ! tgSchemaInit; then
		return 1
	fi
	[ -n "${TG_OPT_DESC[$1:$2]:-}" ]
}

# print the raw desc template of key $2 in scope $1 (may be empty):
function tgSchemaDesc {
	if ! tgSchemaInit; then
		return 1
	fi
	printf '%s\n' "${TG_OPT_DESC[$1:$2]:-}"
}

# expand a desc template: '$VAR'/'${VAR}' references and a full
# '$(strFix "$VAR1" "$VAR2")' form are resolved; anything else stays literal:
function tgExpandDesc {
	local d="$1"

	# whole-string strFix form: $(strFix "$A" "$B")
	# shellcheck disable=SC2016  # regex, not an expandable string
	local resf='^\$\(strFix "\$([A-Za-z_][A-Za-z0-9_]*)" "\$([A-Za-z_][A-Za-z0-9_]*)"\)$'
	if [[ "$d" =~ $resf ]]; then
		strFix "${!BASH_REMATCH[1]}" "${!BASH_REMATCH[2]}"
		return 0
	fi

	# expand $VAR / ${VAR} tokens (first occurrence per loop iteration)
	local out="" rest="$d" m var pre post
	local retok='\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?'
	while [[ "$rest" =~ $retok ]]; do
		m="${BASH_REMATCH[0]}"
		var="${BASH_REMATCH[1]}"
		pre="${rest%%"$m"*}"
		post="${rest#*"$m"}"
		out+="$pre${!var}"
		rest="$post"
	done
	out+="$rest"
	printf '%s\n' "$out"
}

# Load the schema eagerly when this module is sourced: the entry point defines
# TGOPTDEF before sourcing us, so the arrays are populated exactly once in the
# main shell. This matters because command substitutions (used heavily by the
# config writers) fork subshells which cannot propagate TG_SCHEMA_LOADED back,
# and re-parsing the schema per subshell call is prohibitively slow when DEBUG
# traps are active (e.g. under the test framework).
# The lazy init inside the accessors stays as a fallback.
tgSchemaInit || :
