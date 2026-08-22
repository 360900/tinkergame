#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

# settings search: find menu entries by option name, GUI label or description
# text and present the matches as a regular editable settings form, so the
# standard save path (saveMenuEntries) keeps working without any changes.

function tgSearchEntries {
	# $1 = search query, $2 = result file
	# writes every raw settings entry line matching the query to $2
	QUERY="$1"
	OUTFILE="$2"

	: > "$OUTFILE"

	if [ -z "$QUERY" ] || [ ! -f "$STLRAWENTRIES" ]; then
		return
	fi

	QUERYLC="${QUERY,,}"

	while IFS= read -r RAWENT; do
		# only editable fields - plain headings have no ('VAR') reference
		VAR="$(grep -oP "\('\K[^')]+" <<< "$RAWENT")" || true
		if [ -z "$VAR" ]; then
			continue
		fi

		if [[ "${VAR,,}" == *"$QUERYLC"* ]]; then
			printf '%s\n' "$RAWENT" >> "$OUTFILE"
			continue
		fi

		# also match the expanded label and description texts
		MATCHED=0
		# shellcheck disable=SC2016 # the $ must stay literal - the pattern matches the unexpanded template tokens
		while IFS= read -r TOKEN; do
			if [ -z "$TOKEN" ]; then
				continue
			fi
			TOKVAL="${!TOKEN}"
			if [[ "${TOKVAL,,}" == *"$QUERYLC"* ]]; then
				MATCHED=1
				break
			fi
		done <<< "$(grep -oP '\$\K(GUI|DESC)_[A-Z0-9_]+' <<< "$RAWENT")"

		if [ "$MATCHED" -eq 1 ]; then
			printf '%s\n' "$RAWENT" >> "$OUTFILE"
		fi
	done < "$STLRAWENTRIES"
}

function openSearchMenu {
	# $1 = AID, $2 = previous function (for the back button), $3 = optional query
	ARGPCMD="$2"
	QUERY="$3"

	if [ -z "$ARGPCMD" ]; then
		ARGPCMD="$NON"
	fi

	if [ -z "$QUERY" ]; then
		ENTRYRC=0
		QUERY="$("$YAD" --entry --title="${PROGNAME}-SearchSettings" --text="$(spanFont "$GUI_SEARCHBOX" "H")" \
			--window-icon="$STLICON" --center "${WINDECO[@]}" --button="$BUT_SEL":0 --button="$BUT_EXIT":1)" || ENTRYRC=$?
		if [ "$ENTRYRC" -ne 0 ] || [ -z "$QUERY" ]; then
			return
		fi
	fi

	prepareMenu "$1"

	SEARCHMENU="$MTEMP/searchmenu"
	MYTMPL="${SEARCHMENU}-${TMPL}"
	SEARCHFUNC="TGSearchMenu"

	# the search template is rebuilt for every query - no caching here
	tgSearchEntries "$QUERY" "$MYTMPL"

	if [ ! -s "$MYTMPL" ]; then
		writelog "INFO" "${FUNCNAME[0]} - No settings found for query '$QUERY'"
		"$YAD" --info --title="${PROGNAME}-SearchSettings" --text="$GUI_SEARCHNORESULTS" \
			--window-icon="$STLICON" --center "${WINDECO[@]}" || true
		openSearchMenu "$1" "$ARGPCMD"
		return
	fi

	mkCfgTemp "${FUNCNAME[0]}"

	TITLE="${PROGNAME}-SearchSettings"
	pollWinRes "$TITLE" 1

	if [ "$ARGPCMD" == "$NON" ]; then
		QBUT0="$BUT_EXIT"
	else
		QBUT0="$BUT_BACK"
	fi

	# the query is user input embedded into generated code - strip everything
	# that could break out of the quoted --text argument
	TGSRCTEXT="$(strFix "$GUI_SEARCHRESULTS" "$QUERY")"
	TGSRCTEXT="${TGSRCTEXT//\\/}"
	TGSRCTEXT="${TGSRCTEXT//\`/}"
	TGSRCTEXT="${TGSRCTEXT//\$/}"
	TGSRCTEXT="${TGSRCTEXT//\"/}"

	echo "" > "$SEARCHMENU"
	# shellcheck disable=SC2028 # doesn't like the newline seperator, but it is valid
	{
		echo "function $SEARCHFUNC {"
		echo "\"$YAD\" --columns=\"$COLCOUNT\" --f1-action=\"$F1ACTIONCG\" --text=\"$(spanFont "$TGSRCTEXT" "H")\" \\"
		echo "--title=\"$TITLE\" --image \"$NOICON\" ${YADIMGTOP[*]} --window-icon=\"$STLICON\" --center ${WINDECO[*]} --form --separator=\"\\n\" --quoted-output \\"
		echo "--button=\"$QBUT0\":0 --button=\"$BUT_MAINMENU\":2 --button=\"$BUT_RELOAD\":4 --button=\"$BUT_SAVERELOAD\":6 --button=\"$BUT_SAVEPLAY\":8 --button=\"$BUT_PLAY\":10 $GEOM \\"
		cat "$MYTMPL"
		echo "--scroll"
		echo "}"
	} >> "$SEARCHMENU"

	source "$SEARCHMENU"
	writelog "INFO" "${FUNCNAME[0]} - Currently used tempfile is '$MKCFG'"

	SEARCHRC=0
	"$SEARCHFUNC" > "$MKCFG" || SEARCHRC=$?

	case "$SEARCHRC" in
	0)	{
			if [ "$ARGPCMD" == "$NON" ]; then
				clickInfo "${FUNCNAME[0]}" "$SEARCHRC" "$QBUT0" "$GAMMENU" "Exit"
				GOBACK=0
				closeSTL " ######### STOP EARLY $PROGNAME $PROGVERS #########"
				exit
			else
				clickInfo "${FUNCNAME[0]}" "$SEARCHRC" "$QBUT0" "$GAMMENU" "$ARGPCMD"
				"$ARGPCMD" "$1" "${FUNCNAME[0]}"
			fi
		}
	;;
	2)	{
			clickInfo "${FUNCNAME[0]}" "$SEARCHRC" "$BUT_MAINMENU" "$FAVOMENU" "$SETMENU"
			MainMenu "$1" "${FUNCNAME[0]}"
		}
	;;
	4)	{
			GOBACK=0
			clickInfo "${FUNCNAME[0]}" "$SEARCHRC" "$BUT_RELOAD" "$FAVOMENU" "${FUNCNAME[0]}"
			if [ "$SAVESETSIZE" -eq 1 ]; then	sleep 1;	fi
			openSearchMenu "$1" "$ARGPCMD" "$QUERY"
		}
	;;
	6)	{
			GOBACK=0
			clickInfo "${FUNCNAME[0]}" "$SEARCHRC" "$BUT_SAVERELOAD" "$FAVOMENU" "${FUNCNAME[0]}"
			writelog "INFO" "${FUNCNAME[0]} - Saving settings and restarting the search results"
			saveMenuEntries "$SEARCHMENU"
			if [ "$SAVESETSIZE" -eq 1 ]; then	sleep 1;	fi
			openSearchMenu "$1" "$ARGPCMD" "$QUERY"
		}
	;;
	8)	{
			clickInfo "${FUNCNAME[0]}" "$SEARCHRC" "$BUT_SAVEPLAY" "$FAVOMENU" "Game Start"
			GOBACK=0
			saveMenuEntries "$SEARCHMENU"
			startSteamGame
		}
	;;
	10)	{
			clickInfo "${FUNCNAME[0]}" "$SEARCHRC" "$BUT_PLAY" "$FAVOMENU" "Game Start"
			GOBACK=0
			startSteamGame
		}
	;;
	esac
}
