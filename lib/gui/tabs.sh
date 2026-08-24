#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

# Tabbed settings menus and shared notebook launcher (yad --notebook + --plug).
#
# The classic menu (createMenu in menus.sh) renders every field of a settings
# template in one long scrolling form. This module renders the same template
# as one notebook tab per #CAT_ category instead: a "notebook" yad process
# owns the window and each tab is a separate "plug" yad process embedding its
# own --form. Notebook and plugs talk over a SysV shared memory segment keyed
# by an integer (--key): the notebook creates the segment during startup and
# swallows every declared tab once its plug has registered. On any even button
# response code the notebook tells the plugs (SIGUSR1) to print their field
# values, which is exactly what the single form does on its own stdout.
#
# tgNotebookLaunch() is the generic notebook+plug machinery; it is also used
# by openMainMenuTabs() in menus.sh to group the Main Menu tool buttons into
# notebook tabs.
#
# The per-tab outputs are concatenated in tab order into $MKCFG while the
# category-chunked template is concatenated the same way, so the existing
# line-N-to-line-N mapping of saveMenuEntries() keeps working unchanged.
#
# Whenever tabs are not available (option disabled, no X11, yad without
# notebook support, only one category, a plug dying during setup) this module
# steps aside with return code 3 and the caller falls back to the classic
# single-form menu.

function tgTabsSupported {
	# notebook/plug are X11-only in yad and need a yad build that knows them
	if [ -z "$DISPLAY" ]; then
		return 1
	fi
	yadSupportsOption "--notebook" && yadSupportsOption "--plug" && yadSupportsOption "--tab"
}

function tgSplitTemplateByCat {
	# splits a settings template ($1) into one chunk file per #CAT_ category.
	# chunk files are written as "<prefix>-tab-<n>" (n = tab order starting
	# at 1) and the category names are printed to stdout in the same order.
	# lines without any category tag (there are none in the shipped template,
	# but hand-edited cache files could have them) are kept in the category of
	# the preceding line, so no template line is ever lost - the 1:1 mapping
	# between template lines and result lines must not break.
	awk -v prefix="$2" '
		{
			if (match($0, /#CAT_[^`]*`/)) {
				c = substr($0, RSTART + 5, RLENGTH - 6)
				if (!(c in idx)) {
					idx[c] = ++n
					order[n] = c
				}
				cur = c
			}
			if (cur == "") {
				if (!("__untagged" in idx)) {
					idx["__untagged"] = ++n
					order[n] = "Misc"
				}
				cur = "__untagged"
			}
			chunk[idx[cur]] = chunk[idx[cur]] $0 "\n"
		}
		END {
			for (i = 1; i <= n; i++) {
				print order[i]
				printf "%s", chunk[i] > (prefix "-tab-" i)
			}
		}
	' "$1"
}

# Escape Pango markup special characters for yad label contexts that parse
# markup. Tab labels are rendered with gtk_label_set_markup_with_mnemonic -
# a bare '&' (or '<') makes markup parsing fail and the label come out
# EMPTY, which is how "Wine & Proton" showed up as a nameless tab.
function tgMarkupEscape {
	local s="$1"
	s="${s//&/&amp;}"
	s="${s//</&lt;}"
	s="${s//>/&gt;}"
	printf '%s' "$s"
}

function tgNotebookLaunch {
	# generic yad --notebook + --plug launcher shared by the tabbed settings
	# menus (openTabbedMenu) and the tabbed Main Menu (openMainMenuTabs).
	# Globals coming in:
	#   TGNB_TABS      - array of tab labels
	#   TGNB_FUNCS     - array of plug function names (one per tab), each is
	#                    called with its tab number (1..N) as $1 and with its
	#                    stdout redirected to "${TGNB_OUTPREFIX}-tab-out-<n>"
	#   TGNB_TITLE     - window title
	#   TGNB_TEXT      - header text (already composed, Pango markup allowed)
	#   TGNB_IMAGE     - image path
	#   TGNB_BUTTONS   - array of complete --button=... arguments
	#   TGNB_F1ACTION  - f1 action (omitted when empty)
	#   TGNB_OUTPREFIX - plug stdout file prefix
	# Returns the notebook exit code, or 3 when the setup failed and the
	# caller should fall back to a single form.

	if ! tgTabsSupported; then
		return 3
	fi

	if [ "${#TGNB_TABS[@]}" -ne "${#TGNB_FUNCS[@]}" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - ${#TGNB_TABS[@]} tabs but ${#TGNB_FUNCS[@]} plug functions - falling back"
		return 3
	fi

	# SysV shm key has to be a positive integer, unique among running notebooks
	TGKEY=$(( RANDOM * 32768 + RANDOM + 1 ))

	TGNBARGS=()
	for TGNBTAB in "${TGNB_TABS[@]}"; do
		TGNBARGS+=(--tab="$(tgMarkupEscape "$TGNBTAB")")
	done

	TGNBF1=()
	if [ -n "$TGNB_F1ACTION" ]; then
		TGNBF1=(--f1-action="$TGNB_F1ACTION")
	fi

	GDK_BACKEND=x11 "${YAD:-yad}" --notebook --key="$TGKEY" "${TGNBARGS[@]}" \
		--title="$TGNB_TITLE" --text="$TGNB_TEXT" --image="$TGNB_IMAGE" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" \
		"${TGNBF1[@]}" \
		"${TGNB_BUTTONS[@]}" "$GEOM" >/dev/null &
	TGNBPID=$!

	# the notebook creates the shared memory segment during startup -
	# plugs can only attach afterwards
	sleep 1

	unset TGNBPIDS
	TGNBN=1
	for TGNBFUNC in "${TGNB_FUNCS[@]}"; do
		"$TGNBFUNC" "$TGNBN" > "${TGNB_OUTPREFIX}-tab-out-$TGNBN" &
		TGNBPIDS+=("$!")
		TGNBN=$((TGNBN + 1))
	done

	# every plug should be up by now - a dead one means the notebook would wait
	# for its tab forever, so bail out and let the caller fall back
	sleep 1
	TGNBDEAD=0
	for TGNBPIDV in "${TGNBPIDS[@]}"; do
		if ! kill -0 "$TGNBPIDV" 2>/dev/null; then
			TGNBDEAD=1
		fi
	done

	if [ "$TGNBDEAD" -eq 1 ]; then
		writelog "SKIP" "${FUNCNAME[0]} - a tab plug died during setup"
		kill "$TGNBPID" 2>/dev/null || true
		wait "$TGNBPID" 2>/dev/null || true
		for TGNBPIDV in "${TGNBPIDS[@]}"; do
			kill "$TGNBPIDV" 2>/dev/null || true
		done
		return 3
	fi

	TGNBRC=0
	wait "$TGNBPID" || TGNBRC=$?

	# the notebook closes the plugs on exit (SIGUSR2); kill stragglers and reap
	for TGNBPIDV in "${TGNBPIDS[@]}"; do
		kill "$TGNBPIDV" 2>/dev/null || true
	done
	for TGNBPIDV in "${TGNBPIDS[@]}"; do
		wait "$TGNBPIDV" 2>/dev/null || true
	done

	return "$TGNBRC"
}

function openTabbedMenu {
	ARGSPLIT="$1"	# ignored: the tabbed menu always shows the whole template
	ARGMENU="$2"
	ARGFUNC="$3"
	ARGPIC="$4"
	UNUSED="$5"
	ARGCOLS="$6"
	ARGTITLE="$7"
	ARGPCMD="$8"
	ARGSPAT="$9"

	# only an explicit "0" disables the tabs - unset means default (enabled)
	if [ -n "$USETABBEDMENU" ] && [ "$USETABBEDMENU" -eq 0 ]; then
		return 3
	fi

	if ! tgTabsSupported; then
		writelog "SKIP" "${FUNCNAME[0]} - no Yad notebook support - using the classic single form menu"
		return 3
	fi

	MYTMPL="${ARGMENU}-${TMPL}"

	if [ ! -f "$MYTMPL" ] || [ ! -s "$MYTMPL" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating menu template '$MYTMPL'"
		getFilteredEntries "$STLRAWENTRIES" | grep "$ARGSPAT" > "$MYTMPL" || true
		rmDupLines "$MYTMPL"
	fi

	mapfile -t TGTABCATS < <(tgSplitTemplateByCat "$MYTMPL" "$ARGMENU")

	if [ "${#TGTABCATS[@]}" -le 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - '${#TGTABCATS[@]}' categories found - not worth a notebook"
		return 3
	fi

	if [ "$ARGPCMD" == "$NON" ]; then
		QBUT0="$BUT_EXIT"
	else
		QBUT0="$BUT_BACK"
	fi

	TITLE="${PROGNAME}-$ARGFUNC"

	# SysV shm key has to be a positive integer, unique among running notebooks
	TGKEY=$(( RANDOM * 32768 + RANDOM + 1 ))

	# one generated function per tab, wrapping a --plug yad call with the
	# unexpanded field lines of that category (same codegen idea as createMenu).
	# $TGKEY and $COLCOUNT stay unexpanded here and are read when the generated
	# function runs - tgNotebookLaunch picks the key right before launching.
	TGTABFUNCFILE="${ARGMENU}-tabfuncs"
	{
		TGTABN=1
		while [ "$TGTABN" -le "${#TGTABCATS[@]}" ]; do
			echo "function TG_TAB_PLUG_$TGTABN {"
			# shellcheck disable=SC2028 # doesn't like the newline separator, but it is valid
			echo "GDK_BACKEND=x11 \"\${YAD:-yad}\" --plug=\"\$TGKEY\" --tabnum=$TGTABN --form --separator=\"\\n\" --quoted-output --columns=\"\$COLCOUNT\" \\"
			cat "${ARGMENU}-tab-$TGTABN"
			echo "--scroll"
			echo "}"
			TGTABN=$((TGTABN + 1))
		done
	} > "$TGTABFUNCFILE"
	source "$TGTABFUNCFILE"

	TGTABFUNCS=()
	TGTABN=1
	while [ "$TGTABN" -le "${#TGTABCATS[@]}" ]; do
		TGTABFUNCS+=("TG_TAB_PLUG_$TGTABN")
		TGTABN=$((TGTABN + 1))
	done

	TGNB_TABS=("${TGTABCATS[@]}")
	TGNB_FUNCS=("${TGTABFUNCS[@]}")
	TGNB_TITLE="$TITLE"
	TGNB_TEXT="$(spanFont "$ARGTITLE" "H")"
	TGNB_IMAGE="$ARGPIC"
	TGNB_OUTPREFIX="$ARGMENU"
	TGNB_F1ACTION="$F1ACTIONCG"
	TGNB_BUTTONS=(--button="$QBUT0":0 --button="$BUT_MAINMENU":2 --button="$BUT_RELOAD":4 --button="$BUT_SAVERELOAD":6 --button="$BUT_SAVEPLAY":8 --button="$BUT_PLAY":10)

	writelog "INFO" "${FUNCNAME[0]} - Opening notebook menu with '${#TGTABCATS[@]}' tabs ('$*')"

	TGTABRC=0
	tgNotebookLaunch || TGTABRC=$?

	if [ "$TGTABRC" -eq 3 ]; then
		return 3
	fi

	# concatenate the per-tab outputs in tab order - aligns 1:1 with the
	# category-chunked template lines for saveMenuEntries()
	: > "$MKCFG"
	TGTABN=1
	while [ "$TGTABN" -le "${#TGTABCATS[@]}" ]; do
		cat "${ARGMENU}-tab-out-$TGTABN" >> "$MKCFG" 2>/dev/null || true
		TGTABN=$((TGTABN + 1))
	done

	writelog "INFO" "${FUNCNAME[0]} - Notebook menu closed with '$TGTABRC'"
	return "$TGTABRC"
}
