#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

# CLI command registry: loads data/commands.def
# (TSV: group<TAB>verb<TAB>argstring<TAB>summary) and exposes ordered
# per-group verb lists plus per-verb arg strings and summaries.
# Consumed by the help text (lib/cli/help.sh); the dispatch handlers
# themselves live in lib/cli/dispatch.sh.

TG_CMD_REGISTRY_LOADED=0

function tgCmdRegistryInit {
	if [ "$TG_CMD_REGISTRY_LOADED" -eq 1 ]; then
		return 0
	fi

	if [ -z "$TGCOMMANDSDEF" ] || [ ! -r "$TGCOMMANDSDEF" ]; then
		if declare -F writelog >/dev/null 2>&1; then
			writelog "SKIP" "tgCmdRegistryInit - command registry '${TGCOMMANDSDEF:-unset}' not found or not readable - help falls back to built-in text"
		fi
		return 0
	fi

	declare -gA TG_CMD_VERBS
	declare -gA TG_CMD_ARGS
	declare -gA TG_CMD_SUMMARY
	declare -ga TG_CMD_GROUPS=()

	local row group verb argstr summary
	# mapfile instead of a while-read loop: per-line read combined with
	# per-command DEBUG traps (test frameworks) performs pathologically.
	local -a rows=()
	mapfile -t rows < "$TGCOMMANDSDEF"

	for row in "${rows[@]}"; do
		IFS=$'\t' read -r group verb argstr summary <<< "$row"
		case "$group" in
			"#"*) continue ;;
			"")   continue ;;
		esac
		if [ -z "$verb" ]; then
			continue
		fi

		if [ -n "${TG_CMD_ARGS[$group+$verb]+x}" ]; then
			if declare -F writelog >/dev/null 2>&1; then
				writelog "SKIP" "tgCmdRegistryInit - duplicate verb '$verb' in group '$group' in '$TGCOMMANDSDEF' - ignoring"
			fi
			continue
		fi

		# remember group order of first appearance
		if [ -z "${TG_CMD_VERBS[$group]+x}" ]; then
			TG_CMD_GROUPS+=("$group")
			TG_CMD_VERBS[$group]=""
		fi
		TG_CMD_VERBS[$group]+="${verb}"$'\n'
		TG_CMD_ARGS[$group+$verb]="$argstr"
		TG_CMD_SUMMARY[$group+$verb]="$summary"
	done

	TG_CMD_REGISTRY_LOADED=1
	return 0
}

function tgCmdGroups {
	printf '%s\n' "${TG_CMD_GROUPS[@]}"
}

function tgCmdGroupVerbs {
	local g
	for g in "${TG_CMD_GROUPS[@]}"; do
		if [ "$g" == "$1" ]; then
			printf '%s' "${TG_CMD_VERBS[$g]}"
			return 0
		fi
	done
	return 1
}

function tgCmdHas {
	[ -n "${TG_CMD_ARGS[$1+$2]+x}" ]
}

function tgCmdArgs {
	printf '%s' "${TG_CMD_ARGS[$1+$2]:-}"
}

function tgCmdSummary {
	printf '%s' "${TG_CMD_SUMMARY[$1+$2]:-}"
}

# Eagerly load at source time: command substitution subshells would otherwise
# re-parse the registry on every access (same pattern as lib/config/schema.sh).
tgCmdRegistryInit || :
