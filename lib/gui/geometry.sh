#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function setGeom {
	GEOM="--geometry=${WINX}x${WINY}+${POSX}+${POSY}"
}

function pollWinRes {
	TITLE="$1"
	POSX=0
	POSY=0
	unset COLCOUNT

	if [ "$ONSTEAMDECK" -eq 1 ]; then
		SCREENRES="1280x800"
		WINX=1280
		WINY=800
		setGeom
	else
		SCREENRES="$(getScreenRes r)"
	fi

	if [ -z "$SCREENRES" ]; then  SCREENRES="any"; fi

	if [ "$FIXGAMESCOPE" -eq 0 ]; then  # skip this if FIXGAMESCOPE is 1 - so for now only if running in GameMode on the Steam Deck
		TEMPL="template"
		GAMEGUICFG="$STLGUIDIR/$SCREENRES/${AID}/${TITLE}.conf"
		TEMPLGUICFG="$STLGUIDIR/$SCREENRES/${TEMPL}/${TITLE}.conf"
		GLOBTEMPLGUICFG="$GLOBALSTLGUIDIR/$SCREENRES/${TEMPL}/${TITLE}.conf"

		mkProjDir "${GAMEGUICFG%/*}"
		mkProjDir "${TEMPLGUICFG%/*}"

		if [ -f "$TEMPLGUICFG" ] && [ ! -f "$GAMEGUICFG" ]; then
			loadCfg "$TEMPLGUICFG" X
			setGeom
			writelog "INFO" "${FUNCNAME[0]} - Using GEOM '$GEOM' from '$TEMPLGUICFG'" "$WINRESLOG"
		elif [ -f "$GLOBTEMPLGUICFG" ] && [ ! -f "$GAMEGUICFG" ]; then
			loadCfg "$GLOBTEMPLGUICFG" X
			setGeom
			writelog "INFO" "${FUNCNAME[0]} - Using GEOM '$GEOM' from '$GLOBTEMPLGUICFG'" "$WINRESLOG"
		elif [ -f "$GAMEGUICFG" ]; then
			loadCfg "$GAMEGUICFG" X
			setGeom
			writelog "INFO" "${FUNCNAME[0]} - Using GEOM '$GEOM' from '$GAMEGUICFG'" "$WINRESLOG"
		else
			touch "$GAMEGUICFG"
			echo "WINX=\"$WINX\"" > "$GAMEGUICFG"
			echo "WINY=\"$WINY\"" >> "$GAMEGUICFG"

			if [ -z "$GEOM" ]; then
				setGeom
				writelog "INFO" "${FUNCNAME[0]} - Setting '$GEOM' as initial window geometry"
			fi

			writelog "INFO" "${FUNCNAME[0]} - Creating initial '$GAMEGUICFG' with unused default values" "$WINRESLOG"
		fi
	fi

	if [ -n "$2" ]; then
		DEFCOL="$2"
	else
		DEFCOL=1
	fi

	if [ -z "$COLCOUNT" ]; then
		if [ "$ONSTEAMDECK" -eq 0 ]; then
			updateConfigEntry "COLCOUNT" "$DEFCOL" "$GAMEGUICFG"
		fi
		COLCOUNT="$DEFCOL"
	fi

	CURGUICFG="$GAMEGUICFG"
	export CURGUICFG="$CURGUICFG"

	if [ "$FIXGAMESCOPE" -eq 0 ]; then
		updateWinRes "$TITLE" "$GAMEGUICFG" "$TEMPLGUICFG" &
	fi
}

function openGameLauncher {
	function GLgui {
		LISTDIR="$DFDIR/$1"
		if [ -d "$LISTDIR" ] && [ "$(find "$LISTDIR" -name "*.desktop" | wc -l)" -ge 1 ]; then
			"$YAD" --f1-action="$F1ACTION" --icons --window-icon="$STLICON" --read-dir="$LISTDIR" "${WINDECO[@]}" --title="$TITLE" --single-click --keep-icon-size --center --compact --sort-by-name "$GEOM"
		else
			writelog "SKIP" "${FUNCNAME[0]} - No games found in '$LISTDIR' or directory itself not found"
		fi
	}

	if grep -q "update" <<< "$@"; then
		createCollectionMenus "update"
	else
		createCollectionMenus "dummy"
	fi

	if [ "$(find "$DFDIR" -name "*.desktop" | wc -l)" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - No desktop file found in '$DFDIR'"
		if [ "$1" == "auto" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found argument 'auto'. Automatically creating/downloading required data for all installed games found"
			getGameDataForInstalledGames
			if [ -n "$2" ] && [ "$2" == "update" ]; then
				createCollectionMenus "$2"
			else
				createCollectionMenus "dummy"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Either add argument 'auto' to automatically create/download required data or check '$PROGCMD --help'"
			exit
		fi
	fi

	export CURWIKI="$PPW/Game-Launcher"
	TITLE="${PROGNAME}-Launcher"
	pollWinRes "$TITLE"

	if [ -z "$1" ] || [ "$1" == "auto" ] || [ "$1" == "update" ]; then
		GLgui "installed"
	else
		if [ "$1" == "menu" ]; then
			createCollectionList
			CATMENU="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --center "${WINDECO[@]}" --form --scroll --separator="\n" --quoted-output \
			--text="$(spanFont "$GUI_CHOOSECAT" "H")" \
			--field="$GUI_CHOOSECATS":CB "$(cleanDropDown "installed" "$CATLIST")" \
			--title="$TITLE" "$GEOM"
			)"

			if [ -n "${CATMENU//\'}" ]; then
				GLgui "${CATMENU//\'}"
			fi
		elif [ "$1" == "last" ]; then
			if [ -f "$LASTRUN" ]; then
				PREVAID="$(grep "^PREVAID" "$LASTRUN" | cut -d '=' -f2)"
				if [ -n "$PREVAID" ]; then
					AID="${PREVAID//\"}"
					if [ -f "$STLGDESKD/$AID.desktop" ]; then
						writelog "INFO" "${FUNCNAME[0]} - '$1' selected, so opening splash for '$STLGDESKD/$AID.desktop'"
						DFCDIR="$DFDIR/last"
						mkProjDir "$DFCDIR"
						cp "$STLGDESKD/$AID.desktop" "$DFCDIR"
						GLgui "$1"
					else
						writelog "SKIP" "${FUNCNAME[0]} - '$1' selected, but file '$STLGDESKD/$AID.desktop' not found"
					fi
				fi
			fi
		elif [ -d "$DFDIR/$1" ]; then
			GLgui "$1"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Steam Collection '$1' not found in '$DFDIR'"
			writelog "SKIP" "${FUNCNAME[0]} - Only found '$(ls "$DFDIR")'"
		fi
	fi
}

