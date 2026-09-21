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

function tgSgdbArtworkMissing {
	# Prints the artwork types a Non-Steam AppID has no file for, one per line.
	# No output means everything is there.
	local TGSN_AID="$1"
	local TGSN_DIR
	local TGSN_SUFFIX TGSN_LABEL

	if [ -z "$TGSN_AID" ]; then
		return 0
	fi

	if [ -z "$STUIDPATH" ]; then
		setSteamPaths
	fi
	TGSN_DIR="${STUIDPATH}/config/grid"

	# The extension varies, hence the glob. The '.' anchors it, so "1234.*" cannot
	# match "1234p.png" or "1234_hero.png" -- each type is checked on its own.
	for TGSN_SUFFIX in "p:boxart" ":tenfoot" "_hero:hero" "_logo:logo" "_icon:icon"; do
		TGSN_LABEL="${TGSN_SUFFIX#*:}"
		TGSN_SUFFIX="${TGSN_SUFFIX%%:*}"
		if ! compgen -G "${TGSN_DIR}/${TGSN_AID}${TGSN_SUFFIX}.*" > /dev/null; then
			printf '%s\n' "$TGSN_LABEL"
		fi
	done
}

function tgSgdbUndecidedEntries {
	# Non-Steam entry names that have never been decided on. Used to tell the user
	# there is something to do without asking about entries already settled.
	local TGSN_ENTRY
	local TGSN_NAME
	local TGSN_ALL="$1"

	if ! haveAnySteamShortcuts ; then
		return 0
	fi

	local TGSN_AID
	while read -r TGSN_ENTRY; do
		TGSN_NAME="$( parseSteamShortcutEntryAppName "$TGSN_ENTRY" )"
		TGSN_AID="$( parseSteamShortcutEntryAppID "$TGSN_ENTRY" )"
		if [ -z "$TGSN_NAME" ] || tgSgdbDecision "$TGSN_NAME" > /dev/null; then
			continue
		fi

		# Default to the entries that actually lack artwork. An entry that already
		# has all five types is not worth asking about, and an entry settled as
		# "never look this up" is deliberately empty and must never come back.
		if [ "$TGSN_ALL" != "1" ] && [ -z "$( tgSgdbArtworkMissing "$TGSN_AID" )" ]; then
			continue
		fi

		printf '%s\t%s\n' "$TGSN_AID" "$TGSN_NAME"
	done <<< "$( getSteamShortcutHex )"
}

function tgSgdbSplitCamelCase {
	# "EmulationStationDE" -> "Emulation Station DE". SteamGridDB's search matches
	# on words, so a run-together shortcut name reaches fewer titles: "HollowKnight"
	# ranks "Hollow Knight: Silksong" first, "Hollow Knight" ranks the right one.
	# Names that already contain a space are left alone.
	local TGSN_IN="$1"

	case "$TGSN_IN" in
		*" "*) printf '%s' "$TGSN_IN" ; return 0 ;;
	esac

	# lower/digit followed by upper, and an acronym run followed by a word
	sed -E 's/([a-z0-9])([A-Z])/\1 \2/g; s/([A-Z]+)([A-Z][a-z])/\1 \2/g' <<< "$TGSN_IN"
}

function tgSgdbSelectKeys {
	# Arrow-key selection: up/down and Enter, no letter keys. The actions are rows
	# in the same list, bracketed so they do not read as search results.
	# Prints the chosen token on stdout: a 1-based candidate number, or s/x/t/q.
	local -a TGSN_OPTS=("$@")
	local TGSN_COUNT="${#TGSN_OPTS[@]}"
	local -a TGSN_ACTKEY=("s" "x" "t" "q")
	local -a TGSN_ACTLBL=("skip for now" "never look this up" "search under a different name" "quit")
	local TGSN_CUR=0
	local TGSN_ROWS=$(( TGSN_COUNT + ${#TGSN_ACTKEY[@]} ))
	local TGSN_KEY TGSN_SEQ TGSN_I TGSN_MARK

	printf '\e[?25l' >&2   # hide the cursor while the list is being redrawn

	while : ; do
		for TGSN_I in $( seq 0 $(( TGSN_ROWS - 1 )) ); do
			if [ "$TGSN_I" -eq "$TGSN_CUR" ]; then
				TGSN_MARK="> "
			else
				TGSN_MARK="  "
			fi
			if [ "$TGSN_I" -lt "$TGSN_COUNT" ]; then
				printf '\e[2K\r  %s%s\n' "$TGSN_MARK" "${TGSN_OPTS[$TGSN_I]}" >&2
			else
				# Bracketed on both sides: these are choices, not titles from SteamGridDB
				printf '\e[2K\r  %s-- %s --\n' "$TGSN_MARK" "${TGSN_ACTLBL[$(( TGSN_I - TGSN_COUNT ))]}" >&2
			fi
		done
		printf '\e[2K\r  %s\n' "up/down to move, Enter to choose" >&2

		if ! IFS= read -rsn1 TGSN_KEY; then
			printf '\e[?25h' >&2
			printf 'q'
			return 0
		fi

		case "$TGSN_KEY" in
			"")   # Enter
				printf '\e[?25h' >&2
				if [ "$TGSN_CUR" -lt "$TGSN_COUNT" ]; then
					printf '%s' "$(( TGSN_CUR + 1 ))"
				else
					printf '%s' "${TGSN_ACTKEY[$(( TGSN_CUR - TGSN_COUNT ))]}"
				fi
				return 0 ;;
			$'\e')
				# Arrow keys arrive as ESC [ A / ESC [ B; a bare Escape just redraws
				IFS= read -rsn2 -t 0.05 TGSN_SEQ
				case "$TGSN_SEQ" in
					"[A") [ "$TGSN_CUR" -gt 0 ] && TGSN_CUR=$(( TGSN_CUR - 1 )) ;;
					"[B") [ "$TGSN_CUR" -lt $(( TGSN_ROWS - 1 )) ] && TGSN_CUR=$(( TGSN_CUR + 1 )) ;;
				esac ;;
		esac

		# Step back over the list and the hint line to draw them again in place
		printf '\e[%dA' "$(( TGSN_ROWS + 1 ))" >&2
	done
}

function tgSgdbSelectLine {
	# Fallback for runs without a terminal (pipes, scripts): numbered list, one
	# line of input. Same token vocabulary as tgSgdbSelectKeys.
	local -a TGSN_OPTS=("$@")
	local TGSN_REPLY TGSN_I

	for TGSN_I in "${!TGSN_OPTS[@]}"; do
		printf '  %2d) %s\n' "$(( TGSN_I + 1 ))" "${TGSN_OPTS[$TGSN_I]}" >&2
	done
	printf '%s\n' "  [number] pick  s) skip  x) never look this up  t) another search term  q) quit" >&2
	printf '%s' "  > " >&2

	if ! read -r TGSN_REPLY; then
		printf 'q'
		return 0
	fi

	case "$TGSN_REPLY" in
		q|Q)        printf 'q' ;;
		s|S|"")     printf 's' ;;
		x|X)        printf 'x' ;;
		t|T)        printf 't' ;;
		*[!0-9]*)   printf '!' ;;
		*)
			if [ "$TGSN_REPLY" -lt 1 ] || [ "$TGSN_REPLY" -gt "${#TGSN_OPTS[@]}" ]; then
				printf '!'
			else
				printf '%s' "$TGSN_REPLY"
			fi ;;
	esac
	return 0
}

function tgSgdbPrompt {
	# One entry, one decision. Returns 2 when the user wants to stop the whole run,
	# so a long backlog does not have to be worked through in one sitting.
	local TGSN_NAME="$1"
	local TGSN_AID="$2"
	local TGSN_TERM="${3:-$1}"
	local -a TGSN_IDS=()
	local -a TGSN_NAMES=()
	local TGSN_LINE TGSN_TOKEN TGSN_IDX TGSN_SPLIT TGSN_SEEN TGSN_MISS

	while IFS=$'\t' read -r TGSN_IDX TGSN_LINE; do
		[ -z "$TGSN_IDX" ] && continue
		TGSN_IDS+=("$TGSN_IDX")
		TGSN_NAMES+=("$TGSN_LINE")
	done <<< "$( tgSgdbCandidates "$TGSN_TERM" )"

	# A run-together name reaches fewer titles, so also offer what the spaced
	# spelling finds. Appended rather than merged by rank: the literal spelling
	# sometimes ranks better, and dropping its order would bury the right answer.
	TGSN_SPLIT="$( tgSgdbSplitCamelCase "$TGSN_TERM" )"
	if [ "$TGSN_SPLIT" != "$TGSN_TERM" ]; then
		while IFS=$'\t' read -r TGSN_IDX TGSN_LINE; do
			[ -z "$TGSN_IDX" ] && continue
			for TGSN_SEEN in "${TGSN_IDS[@]}"; do
				if [ "$TGSN_SEEN" == "$TGSN_IDX" ]; then
					continue 2
				fi
			done
			TGSN_IDS+=("$TGSN_IDX")
			TGSN_NAMES+=("$TGSN_LINE")
		done <<< "$( tgSgdbCandidates "$TGSN_SPLIT" )"
	fi

	printf '\n%s\n' "Non-Steam entry: $TGSN_NAME"
	if [ "$TGSN_TERM" != "$TGSN_NAME" ]; then
		printf '%s\n' "  searched for: $TGSN_TERM"
	fi

	# Say what is already on disk, so it is obvious whether this entry needs
	# anything at all and which of the five types is actually missing
	if [ -n "$TGSN_AID" ]; then
		TGSN_MISS="$( tgSgdbArtworkMissing "$TGSN_AID" | tr '\n' ' ' )"
		TGSN_MISS="${TGSN_MISS% }"
		if [ -z "$TGSN_MISS" ]; then
			printf '%s\n' "  artwork: all five types present"
		else
			printf '%s\n' "  artwork missing: $TGSN_MISS"
		fi
	fi
	if [ "${#TGSN_IDS[@]}" -eq 0 ]; then
		printf '%s\n' "  no matches on SteamGridDB"
	fi

	# Redrawing a list only works on a terminal; anything else gets the numbered prompt
	if [ -t 0 ]; then
		TGSN_TOKEN="$( tgSgdbSelectKeys "${TGSN_NAMES[@]}" )"
	else
		TGSN_TOKEN="$( tgSgdbSelectLine "${TGSN_NAMES[@]}" )"
	fi

	case "$TGSN_TOKEN" in
		q)
			return 2 ;;
		s)
			writelog "INFO" "${FUNCNAME[0]} - '$TGSN_NAME' skipped for now - will be asked again"
			return 1 ;;
		x)
			# Stored as an empty value, so the entry counts as decided and stops
			# coming back -- this is the 'there simply is no artwork' case
			tgSgdbSetDecision "$TGSN_NAME" ""
			printf '%s\n' "  -> never looking this one up again"
			return 0 ;;
		t)
			printf '%s' "  search term: "
			read -r TGSN_LINE || return 2
			if [ -z "$TGSN_LINE" ]; then
				return 1
			fi
			tgSgdbPrompt "$TGSN_NAME" "$TGSN_AID" "$TGSN_LINE"
			return $? ;;
		"!"|"")
			printf '%s\n' "  not one of the options - skipping for now"
			return 1 ;;
	esac

	TGSN_IDX="$(( TGSN_TOKEN - 1 ))"
	tgSgdbSetDecision "$TGSN_NAME" "${TGSN_IDS[$TGSN_IDX]}"
	printf '%s\n' "  -> ${TGSN_NAMES[$TGSN_IDX]} (SteamGridDB ID ${TGSN_IDS[$TGSN_IDX]})"
	return 0
}

function tgSgdbResolve {
	# With a name, re-decide that one entry even if it was settled before -- a
	# wrong match looks like a success, so the user must be able to come back to it.
	# With "all", walk every undecided entry including those that already have
	# artwork. Otherwise only the undecided entries that are actually missing
	# something, which is the list worth working through.
	local TGSN_TARGET="$1"
	local TGSN_ALL=""
	local -a TGSN_TODO=()
	local TGSN_NAME TGSN_AID TGSN_RC TGSN_LINE
	local TGSN_DONE=0

	if ! tgSgdbEnsureApiKey; then
		return 1
	fi

	if [ "$TGSN_TARGET" == "all" ]; then
		TGSN_ALL="1"
		TGSN_TARGET=""
	fi

	if [ -n "$TGSN_TARGET" ]; then
		# A single named entry: look up its AppID so the artwork status still shows
		TGSN_AID=""
		if haveAnySteamShortcuts ; then
			while read -r TGSN_LINE; do
				if [ "$( parseSteamShortcutEntryAppName "$TGSN_LINE" )" == "$TGSN_TARGET" ]; then
					TGSN_AID="$( parseSteamShortcutEntryAppID "$TGSN_LINE" )"
					break
				fi
			done <<< "$( getSteamShortcutHex )"
		fi
		TGSN_TODO=("${TGSN_AID}"$'\t'"${TGSN_TARGET}")
	else
		while IFS= read -r TGSN_LINE; do
			[ -n "$TGSN_LINE" ] && TGSN_TODO+=("$TGSN_LINE")
		done <<< "$( tgSgdbUndecidedEntries "$TGSN_ALL" )"
	fi

	if [ "${#TGSN_TODO[@]}" -eq 0 ]; then
		if [ -n "$TGSN_ALL" ]; then
			printf '%s\n' "Every Non-Steam entry has been decided on - nothing to do."
		else
			printf '%s\n' "Every Non-Steam entry either has its artwork or has been decided on - nothing to do."
			printf '%s\n' "Use '${PROGNAME,,} artwork resolve all' to go through the ones that already have artwork too."
		fi
		return 0
	fi

	printf '%s\n' "${#TGSN_TODO[@]} Non-Steam entry/entries to decide on."

	for TGSN_LINE in "${TGSN_TODO[@]}"; do
		TGSN_AID="${TGSN_LINE%%$'\t'*}"
		TGSN_NAME="${TGSN_LINE#*$'\t'}"

		tgSgdbPrompt "$TGSN_NAME" "$TGSN_AID"
		TGSN_RC=$?
		if [ "$TGSN_RC" -eq 2 ]; then
			printf '\n%s\n' "Stopped. The rest stays on the list."
			break
		fi
		[ "$TGSN_RC" -eq 0 ] && TGSN_DONE=$(( TGSN_DONE + 1 ))
	done

	printf '\n%s\n' "$TGSN_DONE decision(s) stored in '$STLSGDBNAMESCFG'."

	if [ "$TGSN_DONE" -gt 0 ]; then
		# Deciding and then having to run a second command by hand is a step for
		# nothing. Fetching everything rather than just the entries just decided
		# is deliberate and cheap: artwork already on disk is not requested again,
		# so the rest of the library costs a few file checks and no API calls.
		# "ask": an entry the user just chose to skip must not be guessed at
		# one second later by the fetch that follows
		printf '%s\n' "Fetching artwork with them..."
		getGridsForNonSteamGames "ask"
	fi

	return 0
}

function tgSgdbResolveTerminal {
	# Opens the interactive resolver in the terminal the user configured.
	# USETERM/TERMARGS is the same pair TinkerGame already uses to run GDB.
	local TGSN_CMD

	if [ -z "$USETERM" ] || ! command -v "$USETERM" > /dev/null 2>&1; then
		writelog "WARN" "${FUNCNAME[0]} - Configured terminal '${USETERM:-unset}' not found - cannot open the resolver" "E"
		return 1
	fi

	if [ -z "$TG_ENTRYPOINT" ] || [ ! -x "$TG_ENTRYPOINT" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Cannot resolve the TinkerGame executable - not opening a terminal" "E"
		return 1
	fi

	# The trailing read keeps the window up after the last entry, so the summary
	# does not vanish together with the terminal
	TGSN_CMD="'$TG_ENTRYPOINT' artwork resolve; printf '\n%s' 'Press Enter to close'; read -r"
	"$USETERM" "$TERMARGS" "bash -c \"$TGSN_CMD\""
}

function tgSgdbNotifyUndecided {
	# Tells the user that new entries need a decision and offers to open the
	# resolver. Only for runs without a terminal (i.e. the systemd watcher) --
	# an interactive run has already printed the same thing to stdout.
	local TGSN_COUNT="$1"
	local -a TGSN_NARGS=()

	if [ -z "$TGSN_COUNT" ] || [ "$TGSN_COUNT" -eq 0 ]; then
		return 0
	fi

	if [ -t 1 ]; then
		return 0
	fi

	# Honour the same suppressions as notiShow. Game Mode has no desktop to show
	# a notification on and no terminal to open, and '-q' is a request for silence
	# that a second notification path must not quietly ignore.
	if [ "${ONSTEAMDECK:-0}" -eq 1 ] && [ "${FIXGAMESCOPE:-0}" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Skipping notifier on SteamDeck Game Mode - '$TGSN_COUNT' entries stay on the list"
		return 0
	fi

	if [ "${STLQUIET:-0}" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Quiet mode - '$TGSN_COUNT' entries stay on the list"
		return 0
	fi

	if [ -z "$USENOTIFIER" ] || [ "$USENOTIFIER" -ne 1 ] || [ ! -x "$(command -v "$NOTY")" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Notifier unavailable - '$TGSN_COUNT' entries stay on the list for '${PROGNAME,,} artwork resolve'"
		return 0
	fi

	mapfile -d " " -t TGSN_NARGS < <(printf '%s' "$NOTYARGS")

	# '-A' implies '--wait': notify-send stays alive until the notification is
	# acted on or dismissed. Detached, so the (oneshot) caller can finish now --
	# the generated service uses KillMode=process so this survives its exit.
	(
		if [ "$( "$NOTY" "${TGSN_NARGS[@]}" -A "resolve=$GUI_SGDBRESOLVENOW" "$( strFix "$NOTY_SGDBUNDECIDED" "$TGSN_COUNT" )" 2>/dev/null )" == "resolve" ]; then
			tgSgdbResolveTerminal
		fi
	) &
	disown 2>/dev/null

	return 0
}

function tgSgdbPromptApiKey {
	# Asks for a key, verifies it against SteamGridDB and stores it. Split from
	# tgSgdbEnsureApiKey so the prompt itself can be exercised without a terminal.
	local TGSN_KEY TGSN_PROBE

	printf '\n%s\n' "No SteamGridDB API key is configured, so artwork cannot be looked up."
	printf '%s\n' "Create one here (free, needs a SteamGridDB account):"
	printf '\n    %s\n\n' "$SGDBAPIKEYURL"
	printf '%s' "Paste the key here (or press Enter to cancel): "

	# Read silently: a key echoed into the terminal ends up in the scrollback, in
	# any session transcript and in whatever is recording the terminal. A mistyped
	# paste is caught by the check below rather than by reading it back.
	if ! read -rs TGSN_KEY || [ -z "$TGSN_KEY" ]; then
		printf '\n%s\n' "No key entered - nothing was changed."
		return 1
	fi
	printf '\n'

	# Trim stray whitespace from copy/paste rather than storing a key that
	# silently fails on every request afterwards
	TGSN_KEY="${TGSN_KEY#"${TGSN_KEY%%[![:space:]]*}"}"
	TGSN_KEY="${TGSN_KEY%"${TGSN_KEY##*[![:space:]]}"}"

	# Try it before storing it: a typo here is otherwise only visible as
	# "no artwork found" much later on
	printf '%s\n' "Checking the key..."
	TGSN_PROBE="$( "$WGET" --timeout="${SGDBTIMEOUT}" --tries=1 --content-on-error --header="Authorization: Bearer $TGSN_KEY" -q "${BASESTEAMGRIDDBAPI}/search/autocomplete/portal" -O - 2> >(grep -v "SSL_INIT") )"

	if ! "$JQ" -e '.success' 1> /dev/null 2>&1 <<< "$TGSN_PROBE"; then
		printf '%s\n' "SteamGridDB did not accept that key - nothing was stored."
		writelog "SKIP" "${FUNCNAME[0]} - SteamGridDB rejected the supplied API key"
		return 1
	fi

	mkProjDir "$STLCFGDIR"
	if [ ! -f "$STLDEFGLOBALCFG" ]; then
		printf '%s\n' "SGDBAPIKEY=\"$TGSN_KEY\"" > "$STLDEFGLOBALCFG"
	else
		updateConfigEntry "SGDBAPIKEY" "$TGSN_KEY" "$STLDEFGLOBALCFG"
	fi

	SGDBAPIKEY="$TGSN_KEY"
	printf '%s\n' "Key accepted and saved in '$STLDEFGLOBALCFG'."
	writelog "INFO" "${FUNCNAME[0]} - Stored a working SteamGridDB API key in the global config"
	return 0
}

function tgSgdbEnsureApiKey {
	# Everything here needs a SteamGridDB API key. Without one checkSGDbApi only
	# writes to the log, so an interactive run used to end silently with no hint
	# of what went wrong.
	if checkSGDbApi; then
		return 0
	fi

	if [ ! -t 0 ]; then
		# The watcher runs without a terminal and must never block on input
		writelog "SKIP" "${FUNCNAME[0]} - No SteamGridDB API key - run '${PROGNAME,,} artwork resolve' in a terminal to set one up" "E"
		printf '%s\n' "No SteamGridDB API key is configured - run '${PROGNAME,,} artwork resolve' in a terminal to set one up."
		return 1
	fi

	tgSgdbPromptApiKey
}
