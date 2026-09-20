#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

# Which SteamGridDB game a Non-Steam entry belongs to, decided once by the user.
#
# SteamGridDB's autocomplete is already fuzzy and returns a ranked list, but it
# reports no confidence, and an exact name match is not a reliable signal either:
# a shortcut called "Eden" matches a SteamGridDB game called "Eden" that is a
# different title entirely. No rule separates "right" from "plausibly wrong", so
# the user decides -- once per entry, never again.
#
# Format is the usual TinkerGame conf layout, one "<Steam entry name>=<value>"
# per line, where the value is a SteamGridDB game ID, or empty for "never look
# this one up" (a shortcut with no artwork anywhere must not keep asking).

function tgSgdbDecision {
	# Prints the stored decision for a Non-Steam entry name, empty for "never".
	# Returns 1 when the entry has not been decided yet, which is what separates
	# "the user chose to skip this forever" from "we have not asked yet".
	local TGSN_NAME="$1"
	local TGSN_LINE

	if [ -z "$TGSN_NAME" ] || [ ! -f "$STLSGDBNAMESCFG" ]; then
		return 1
	fi

	while IFS= read -r TGSN_LINE || [ -n "$TGSN_LINE" ]; do
		case "$TGSN_LINE" in
			"#"*) continue ;;
			"")   continue ;;
		esac
		# Compared literally rather than with grep: entry names are free text and
		# routinely contain characters that would be read as a regex
		if [ "${TGSN_LINE%%=*}" == "$TGSN_NAME" ]; then
			printf '%s' "${TGSN_LINE#*=}"
			return 0
		fi
	done < "$STLSGDBNAMESCFG"

	return 1
}

function tgSgdbSetDecision {
	local TGSN_NAME="$1"
	local TGSN_VALUE="$2"
	local TGSN_TMP
	local TGSN_LINE

	if [ -z "$TGSN_NAME" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - No entry name given - not storing a decision" "E"
		return 1
	fi

	mkProjDir "$STLCFGDIR"
	if [ ! -d "$STLCFGDIR" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Cannot create config directory '$STLCFGDIR'" "E"
		return 1
	fi

	TGSN_TMP="${STLSGDBNAMESCFG}.tmp"
	if [ -f "$STLSGDBNAMESCFG" ]; then
		# Rewrite without the old entry instead of appending, so re-deciding does
		# not leave a stale line that tgSgdbDecision would find first
		: > "$TGSN_TMP"
		while IFS= read -r TGSN_LINE || [ -n "$TGSN_LINE" ]; do
			case "$TGSN_LINE" in
				"#"*) printf '%s\n' "$TGSN_LINE" >> "$TGSN_TMP" ; continue ;;
				"")   continue ;;
			esac
			if [ "${TGSN_LINE%%=*}" != "$TGSN_NAME" ]; then
				printf '%s\n' "$TGSN_LINE" >> "$TGSN_TMP"
			fi
		done < "$STLSGDBNAMESCFG"
	else
		printf '%s\n' "# $PROGNAME - which SteamGridDB game each Non-Steam entry belongs to" > "$TGSN_TMP"
		printf '%s\n' "# <Steam entry name>=<SteamGridDB game ID>, empty value means 'never look this one up'" >> "$TGSN_TMP"
		printf '%s\n' "# Written by '${PROGNAME,,} artwork resolve' - safe to edit by hand" >> "$TGSN_TMP"
	fi

	printf '%s=%s\n' "$TGSN_NAME" "$TGSN_VALUE" >> "$TGSN_TMP"

	if ! mv -f "$TGSN_TMP" "$STLSGDBNAMESCFG"; then
		writelog "ERROR" "${FUNCNAME[0]} - Could not update '$STLSGDBNAMESCFG'" "E"
		rm -f "$TGSN_TMP"
		return 1
	fi

	writelog "INFO" "${FUNCNAME[0]} - Stored decision '$TGSN_NAME' -> '${TGSN_VALUE:-(never)}'"
	return 0
}

function tgSgdbCandidates {
	# Emits "<game id><TAB><game name>" per candidate. This is the same
	# autocomplete request getSGDBGameIDFromTitle already makes; it just keeps the
	# whole ranked list instead of throwing everything but .data[0] away.
	local TGSN_TERM="$1"
	local TGSN_RESP

	if [ -z "$TGSN_TERM" ] || ! checkSGDbApi; then
		return 1
	fi

	TGSN_RESP="$( "$WGET" --timeout="${SGDBTIMEOUT}" --tries="${SGDBRETRIES}" --content-on-error --header="Authorization: Bearer $SGDBAPIKEY" -q "${BASESTEAMGRIDDBAPI}/search/autocomplete/${TGSN_TERM}" -O - 2> >(grep -v "SSL_INIT") )"

	if ! "$JQ" -e '.success' 1> /dev/null 2>&1 <<< "$TGSN_RESP"; then
		writelog "WARN" "${FUNCNAME[0]} - SteamGridDB did not report success for '$TGSN_TERM'"
		return 1
	fi

	"$JQ" -r '.data[]? | "\(.id)\t\(.name)"' <<< "$TGSN_RESP"
}

function tgSgdbUndecidedEntries {
	# Non-Steam entry names that have never been decided on. Used to tell the user
	# there is something to do without asking about entries already settled.
	local TGSN_ENTRY
	local TGSN_NAME

	if ! haveAnySteamShortcuts ; then
		return 0
	fi

	while read -r TGSN_ENTRY; do
		TGSN_NAME="$( parseSteamShortcutEntryAppName "$TGSN_ENTRY" )"
		if [ -n "$TGSN_NAME" ] && ! tgSgdbDecision "$TGSN_NAME" > /dev/null; then
			printf '%s\n' "$TGSN_NAME"
		fi
	done <<< "$( getSteamShortcutHex )"
}

function tgSgdbPrompt {
	# One entry, one decision. Returns 2 when the user wants to stop the whole run,
	# so a long backlog does not have to be worked through in one sitting.
	local TGSN_NAME="$1"
	local TGSN_TERM="${2:-$1}"
	local -a TGSN_IDS=()
	local -a TGSN_NAMES=()
	local TGSN_LINE TGSN_REPLY TGSN_IDX

	while IFS=$'\t' read -r TGSN_IDX TGSN_LINE; do
		[ -z "$TGSN_IDX" ] && continue
		TGSN_IDS+=("$TGSN_IDX")
		TGSN_NAMES+=("$TGSN_LINE")
	done <<< "$( tgSgdbCandidates "$TGSN_TERM" )"

	printf '\n%s\n' "Non-Steam entry: $TGSN_NAME"
	if [ "$TGSN_TERM" != "$TGSN_NAME" ]; then
		printf '%s\n' "  searched for: $TGSN_TERM"
	fi

	if [ "${#TGSN_IDS[@]}" -eq 0 ]; then
		printf '%s\n' "  no matches on SteamGridDB"
	else
		for TGSN_IDX in "${!TGSN_IDS[@]}"; do
			printf '  %2d) %s\n' "$(( TGSN_IDX + 1 ))" "${TGSN_NAMES[$TGSN_IDX]}"
		done
	fi

	printf '%s\n' "  [number] pick  s) skip for now  x) never look this up  t) type another search term  q) quit"
	printf '%s' "  > "
	read -r TGSN_REPLY || return 2

	case "$TGSN_REPLY" in
		q|Q)
			return 2 ;;
		s|S|"")
			writelog "INFO" "${FUNCNAME[0]} - '$TGSN_NAME' skipped for now - will be asked again"
			return 1 ;;
		x|X)
			# Stored as an empty value, so the entry counts as decided and stops
			# coming back -- this is the 'there simply is no artwork' case
			tgSgdbSetDecision "$TGSN_NAME" ""
			printf '%s\n' "  -> never looking this one up again"
			return 0 ;;
		t|T)
			printf '%s' "  search term: "
			read -r TGSN_REPLY || return 2
			if [ -z "$TGSN_REPLY" ]; then
				return 1
			fi
			tgSgdbPrompt "$TGSN_NAME" "$TGSN_REPLY"
			return $? ;;
		*[!0-9]*|"")
			printf '%s\n' "  '$TGSN_REPLY' is not one of the options - skipping for now"
			return 1 ;;
	esac

	if [ "$TGSN_REPLY" -lt 1 ] || [ "$TGSN_REPLY" -gt "${#TGSN_IDS[@]}" ]; then
		printf '%s\n' "  '$TGSN_REPLY' is out of range - skipping for now"
		return 1
	fi

	TGSN_IDX="$(( TGSN_REPLY - 1 ))"
	tgSgdbSetDecision "$TGSN_NAME" "${TGSN_IDS[$TGSN_IDX]}"
	printf '%s\n' "  -> ${TGSN_NAMES[$TGSN_IDX]} (SteamGridDB ID ${TGSN_IDS[$TGSN_IDX]})"
	return 0
}

function tgSgdbResolve {
	# With a name, re-decide that one entry even if it was settled before -- a
	# wrong match looks like a success, so the user must be able to come back to it.
	# Without one, work through everything not yet decided.
	local TGSN_TARGET="$1"
	local -a TGSN_TODO=()
	local TGSN_NAME TGSN_RC
	local TGSN_DONE=0

	if ! checkSGDbApi; then
		return 1
	fi

	if [ -n "$TGSN_TARGET" ]; then
		TGSN_TODO=("$TGSN_TARGET")
	else
		while IFS= read -r TGSN_NAME; do
			[ -n "$TGSN_NAME" ] && TGSN_TODO+=("$TGSN_NAME")
		done <<< "$( tgSgdbUndecidedEntries )"
	fi

	if [ "${#TGSN_TODO[@]}" -eq 0 ]; then
		printf '%s\n' "Every Non-Steam entry has been decided on - nothing to do."
		return 0
	fi

	printf '%s\n' "${#TGSN_TODO[@]} Non-Steam entry/entries to decide on."

	for TGSN_NAME in "${TGSN_TODO[@]}"; do
		tgSgdbPrompt "$TGSN_NAME"
		TGSN_RC=$?
		if [ "$TGSN_RC" -eq 2 ]; then
			printf '\n%s\n' "Stopped. The rest stays on the list."
			break
		fi
		[ "$TGSN_RC" -eq 0 ] && TGSN_DONE=$(( TGSN_DONE + 1 ))
	done

	printf '\n%s\n' "$TGSN_DONE decision(s) stored in '$STLSGDBNAMESCFG'."
	if [ "$TGSN_DONE" -gt 0 ]; then
		printf '%s\n' "Run '${PROGNAME,,} update grid nonsteam' to fetch artwork with them."
	fi
	return 0
}
