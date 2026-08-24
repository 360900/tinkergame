#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function yadSupportsOption {
	grep -q -- "$1" <<< "$YADHELP"
}

# Convert a font DPI value to a GDK font scaling factor (dpi / 96), printed
# as a two-decimal number. Prints nothing when the value is missing, not a
# number, or outside [TG_GUI_SCALE_MIN..TG_GUI_SCALE_MAX] (default 1.25..4.00),
# so junk from xrdb can never shrink or blow up the GUI.
function tgGuiScaleFromDpi {
	if [ -z "$1" ]; then
		return 0
	fi
	local DPIRE='^[0-9]+([.][0-9]+)?$'
	if ! [[ "$1" =~ $DPIRE ]]; then
		return 0
	fi
	awk -v dpi="$1" -v min="${TG_GUI_SCALE_MIN:-1.25}" -v max="${TG_GUI_SCALE_MAX:-4.00}" \
		'BEGIN {
			f = dpi / 96;
			if (f >= min && f <= max) {
				printf "%.2f\n", f;
			}
		}'
}

# Clamp a GUI scale factor so that a window of the reference size
# (TG_GUI_FIT_WIDTH x TG_GUI_FIT_HEIGHT, default 2560x1440 - the largest
# 96-dpi size the TinkerGame windows are laid out for) still fits the given
# screen. Prints the clamped factor (floored to two decimals), or nothing
# when the screen is too small for any scaling at all. Missing or invalid
# screen dimensions leave the factor untouched - a font DPI says how big
# fonts should be, but only the screen size says how much room there is.
function tgClampScaleToScreen {
	local NUMRE='^[0-9]+([.][0-9]+)?$'
	if [ -z "$1" ] || ! [[ "$1" =~ $NUMRE ]]; then
		return 0
	fi
	if ! [[ "$2" =~ ^[0-9]+$ ]] || ! [[ "$3" =~ ^[0-9]+$ ]]; then
		printf '%s\n' "$1"
		return 0
	fi
	awk -v s="$1" -v sw="$2" -v sh="$3" -v fw="${TG_GUI_FIT_WIDTH:-2560}" -v fh="${TG_GUI_FIT_HEIGHT:-1440}" -v min="${TG_GUI_SCALE_MIN:-1.25}" \
		'BEGIN {
			f = s;
			if (fw > 0 && sw / fw < f) f = sw / fw;
			if (fh > 0 && sh / fh < f) f = sh / fh;
			f = int(f * 100) / 100;
			if (f >= min) {
				printf "%.2f\n", f;
			}
		}'
}

# Clamp a window size to the screen so no TinkerGame window can ever be
# launched larger than the visible screen. Prints "<winx> <winy>" with both
# dimensions capped at the screen size, or nothing when the window size is
# missing or not a number. A missing or invalid screen size passes the window
# size through unchanged, so a broken probe degrades to the old behaviour
# instead of breaking window launching entirely.
function tgClampWinXY {
	local NUMRE='^[0-9]+$'
	if [ -z "$1" ] || [ -z "$2" ]; then
		return 0
	fi
	if ! [[ "$1" =~ $NUMRE ]] || ! [[ "$2" =~ $NUMRE ]]; then
		return 0
	fi
	if ! [[ "$3" =~ $NUMRE ]] || ! [[ "$4" =~ $NUMRE ]] || [ "$3" -eq 0 ] || [ "$4" -eq 0 ]; then
		printf '%s %s\n' "$1" "$2"
		return 0
	fi
	awk -v w="$1" -v h="$2" -v sw="$3" -v sh="$4" \
		'BEGIN {
			if (w > sw) w = sw;
			if (h > sh) h = sh;
			printf "%d %d\n", w, h;
		}'
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

	# Theming: request a GTK theme for every TinkerGame window. GTK_THEME is read
	# by GTK itself, '$NON' (or empty) keeps the system default, and a ':dark'
	# suffix picks the dark variant of a theme (for example 'Adwaita:dark').
	# emptyVars later removes $GTK_THEME again before the game is started.
	if [ -n "$YADTHEME" ] && [ "$YADTHEME" != "$NON" ]; then
		export GTK_THEME="$YADTHEME"
		writelog "INFO" "${FUNCNAME[0]} - requesting GTK theme '$YADTHEME' for all TinkerGame windows"
	fi

	# Theming: load extra CSS rules from a user file into every Yad window.
	# YAD_OPTIONS is parsed by Yad itself (split on whitespace and prepended to
	# the command line), so '--css' reaches every '$YAD' call without touching
	# each invocation site. An existing $YAD_OPTIONS value is preserved. Yad
	# splits on plain spaces, so the file path must not contain any.
	if [ -n "$YADCSS" ] && [ "$YADCSS" != "$NON" ]; then
		if [ -r "$YADCSS" ]; then
			export YAD_OPTIONS="${YAD_OPTIONS:+$YAD_OPTIONS }--css=$YADCSS"
			writelog "INFO" "${FUNCNAME[0]} - loading custom CSS '$YADCSS' for all TinkerGame windows"
		else
			writelog "SKIP" "${FUNCNAME[0]} - YADCSS '$YADCSS' is not a readable file - ignoring it"
		fi
	else
		# no user CSS: fall back to the shipped default, which outlines
		# notebook tabs so they are visually separated from each other
		TGDEFCSS="$SYSTEMSTLCFGDIR/misc/tg-tabs.css"
		if [ -r "$TGDEFCSS" ]; then
			export YAD_OPTIONS="${YAD_OPTIONS:+$YAD_OPTIONS }--css=$TGDEFCSS"
			writelog "INFO" "${FUNCNAME[0]} - loading default tab CSS '$TGDEFCSS' for all TinkerGame windows"
		fi
	fi

	# Screen size, measured once per invocation: the DPI factor below and
	# every window geometry (setGeom in geometry.sh) are clamped against it,
	# so no TinkerGame window can ever be launched larger than the screen.
	# The EWMH workarea (panel/taskbar excluded) is preferred, the root
	# window size is the fallback.
	TGSCRW=""
	TGSCRH=""
	# 'read' returns 1 on empty input (no workarea property), so both reads
	# are failure-safe
	read -r TGSCRW TGSCRH < <("$XPROP" -root _NET_WORKAREA 2>/dev/null | awk '{ gsub(/,/, ""); if (NF >= 6) { print $5, $6; exit } }') || true
	if [ -z "$TGSCRW" ] || [ -z "$TGSCRH" ] || [ "$TGSCRW" -eq 0 ] || [ "$TGSCRH" -eq 0 ]; then
		TGSCRW=""
		TGSCRH=""
		read -r TGSCRW TGSCRH < <("$XWININFO" -root 2>/dev/null | awk '$1 == "Width:" || $1 == "Height:" { printf "%s ", $2 }') || true
	fi
	export TGSCRW TGSCRH

	# DPI scaling: a font DPI set via xrdb (Xft.dpi) is one common way to ask
	# for bigger GUI fonts on HiDPI screens. GTK only honours it on X11 and
	# only when an XSETTINGS daemon propagates it - Wayland-native GTK ignores
	# it entirely, and without a daemon even X11 GTK ignores it. So when no
	# XSETTINGS daemon is running, read the DPI ourselves and hand the
	# resulting factor to GTK as GDK_DPI_SCALE, which scales fonts reliably.
	# The factor is then clamped to what fits the screen, so windows stay
	# fully visible instead of scaling past the panel edges.
	# TG_GUI_SCALE=<factor> overrides the detection with a fixed factor
	# (also clamped to the screen unless TG_GUI_FIT_WIDTH/HEIGHT disable it).
	if [ -n "${TG_GUI_SCALE:-}" ]; then
		TGCLAMPED="$(tgClampScaleToScreen "$TG_GUI_SCALE" "$TGSCRW" "$TGSCRH")"
		if [ -z "$TGCLAMPED" ]; then
			writelog "INFO" "${FUNCNAME[0]} - TG_GUI_SCALE override '$TG_GUI_SCALE' does not fit the '${TGSCRW:-?}x${TGSCRH:-?}' screen - not scaling TinkerGame windows"
		else
			export GDK_DPI_SCALE="$TGCLAMPED"
			if [ "$TGCLAMPED" != "$TG_GUI_SCALE" ]; then
				writelog "INFO" "${FUNCNAME[0]} - TG_GUI_SCALE override '$TG_GUI_SCALE' clamped to '$TGCLAMPED' so TinkerGame windows fit the '${TGSCRW}x${TGSCRH}' screen"
			else
				writelog "INFO" "${FUNCNAME[0]} - TG_GUI_SCALE override - using GDK_DPI_SCALE '$TG_GUI_SCALE' for TinkerGame windows"
			fi
		fi
	# note: xprop exits 0 even for a missing property, so the daemon is
	# detected by looking at its output instead of its exit code
	elif "$XPROP" -root _XSETTINGS_SETTINGS 2>/dev/null | grep -qv "not found"; then
		writelog "INFO" "${FUNCNAME[0]} - An XSETTINGS daemon is running - letting the session handle GUI scaling"
	else
		XFTDPI="$(xrdb -query 2>/dev/null | awk '$1 == "Xft.dpi:" { print $2; exit }')"
		TGGUISCALE="$(tgGuiScaleFromDpi "$XFTDPI")"
		if [ -n "$TGGUISCALE" ]; then
			# The full font-DPI factor can be larger than the screen allows
			# (a 2.75 factor on a 4K panel makes windows wider than the
			# screen), so it is clamped to what still fits.
			TGCLAMPED="$(tgClampScaleToScreen "$TGGUISCALE" "$TGSCRW" "$TGSCRH")"
			if [ -z "$TGCLAMPED" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Xft.dpi is '$XFTDPI' but the '${TGSCRW:-?}x${TGSCRH:-?}' screen is too small to scale TinkerGame windows - not scaling"
			elif [ "$TGCLAMPED" != "$TGGUISCALE" ]; then
				export GDK_DPI_SCALE="$TGCLAMPED"
				writelog "INFO" "${FUNCNAME[0]} - Xft.dpi is '$XFTDPI' but no XSETTINGS daemon is running and scale '$TGGUISCALE' would not fit the '${TGSCRW}x${TGSCRH}' screen - exporting GDK_DPI_SCALE '$TGCLAMPED' for readable TinkerGame windows"
			else
				export GDK_DPI_SCALE="$TGGUISCALE"
				writelog "INFO" "${FUNCNAME[0]} - Xft.dpi is '$XFTDPI' but no XSETTINGS daemon is running - exporting GDK_DPI_SCALE '$TGGUISCALE' for readable TinkerGame windows"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Xft.dpi is '${XFTDPI:-unset}' outside the scaling range - not scaling TinkerGame windows"
		fi
	fi

	# Run every TinkerGame window on the X11 backend by pointing $YAD at a
	# tiny wrapper that sets GDK_BACKEND=x11:
	#  * the tabbed menus embed their pages via the GtkSocket/GtkPlug protocol,
	#    which only exists on X11 (TinkerGame already forces x11 for those
	#    windows - mixing one Wayland window into an otherwise X11 notebook
	#    breaks the embedding)
	#  * updateWinRes/pollWinRes measure windows with xwininfo, which cannot
	#    see Wayland-native windows at all
	#  * the GDK_DPI_SCALE font scaling above behaves deterministically on X11
	# GDK_SCALE=1 pins the window scale: external scale sources (gsettings
	# scaling-factor, an xsettings daemon, kwin's Xwayland scale) otherwise
	# multiply every requested geometry and silently change between sessions.
	# The wrapper only affects yad - the game itself keeps the session backend.
	YADX11WRAPPER="$STLSHM/yad-x11"
	if YADX11TMP="$(mktemp "${YADX11WRAPPER}.XXXXXX")"; then
		{
			printf '#!/usr/bin/env bash\n'
			printf 'export GDK_BACKEND=x11\n'
			printf 'export GDK_SCALE=1\n'
			printf 'exec %q "$@"\n' "$YAD"
		} > "$YADX11TMP"
		chmod +x "$YADX11TMP"
		mv -f "$YADX11TMP" "$YADX11WRAPPER"
		YAD="$YADX11WRAPPER"
		writelog "INFO" "${FUNCNAME[0]} - Using X11-backed yad wrapper '$YAD'"
	else
		writelog "WARN" "${FUNCNAME[0]} - Could not create '$YADX11WRAPPER' - using yad directly"
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

