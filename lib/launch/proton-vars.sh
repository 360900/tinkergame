#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function getProtPathFromCSV {
	delEmptyFile "$PROTONCSV"
	if [ ! -f "$PROTONCSV" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating '$PROTONCSV'"
		getAvailableProtonVersions "up" X
	fi

	if [ -f "$PROTONCSV" ]; then
		grep "^$1" "$PROTONCSV" | sort -nr | head -n1 | cut -d ';' -f2
	fi
}

function setRunWineServer {
	if [ "$ISGAME" -eq 2 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Initiated from '$1'"

		if [ -n "$USEPROTON" ] && [ ! -f "$(getProtPathFromCSV "$USEPROTON")" ] && [ "$HAVEINPROTON" -eq 0 ]; then
			fixProtonVersionMismatch "USEPROTON" "$STLGAMECFG"
		fi

		if [ -z "$RUNPROTON" ] && [ "$HAVEINPROTON" -eq 1 ]; then
			RUNPROTON="${INPROTCMD[*]}"
		fi

		if [ -z "$RUNPROTON" ]; then
			setRunProtonFromUseProton
		fi

		CHECKWINED="$(dirname "$RUNPROTON")/$DBW"
		CHECKWINEF="$(dirname "$RUNPROTON")/$FBW"
		if [ -f "$CHECKWINED" ]; then
			RUNWINE="$CHECKWINED"
			RUNWINESERVER="${RUNWINE}server"
			writelog "INFO" "${FUNCNAME[0]} - Set the wine binary for proton in path '$RUNPROTON'"
			writelog "INFO" "${FUNCNAME[0]} - to '$RUNWINE'"
			writelog "INFO" "${FUNCNAME[0]} - and wineserver to '$RUNWINESERVER'"
		elif [ -f "$CHECKWINEF" ]; then
			RUNWINE="$CHECKWINEF"
			RUNWINESERVER="${RUNWINE}server"
			writelog "INFO" "${FUNCNAME[0]} - Set the wine binary for proton in path '$RUNPROTON'"
			writelog "INFO" "${FUNCNAME[0]} - to '$RUNWINE'"
			writelog "INFO" "${FUNCNAME[0]} - and wineserver to '$RUNWINESERVER'"
		else
			writelog "WARN" "${FUNCNAME[0]} - Couldn't find the wine binary for the proton in path '$RUNPROTON' - falling back to 'wine' for plain RUNWINE and 'wineserver' for RUNWINESERVER"
		fi
	fi
}

function setNewProtVars {
	if [ "$ISGAME" -eq 2 ] && [ "$USEWINE" -eq 0 ]; then
		if [ "$HAVEINPROTON" -eq 1 ]; then
			if [ -z "$RUNWINESERVER" ]; then
				setRunWineServer "${FUNCNAME[0]}"
			fi
		else
			# arg1 is absolute proton path
			if [ "$HAVEINPROTON" -eq 0 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Setting new Proton Variables based on '$1'"
				RUNPROTON="$1"
				CHECKWINED="$(dirname "$RUNPROTON")/$DBW"
				CHECKWINEF="$(dirname "$RUNPROTON")/$FBW"

				writelog "INFO" "${FUNCNAME[0]} - Continuing with RUNPROTON='$RUNPROTON'"

				PDTGZ="proton_dist.tar.gz"
				if [ ! -f "$CHECKWINED" ] && [ ! -f "$CHECKWINEF" ] && [ -f "$(dirname "$RUNPROTON")/$PDTGZ" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Wine binary not found, but a proton archive '$PDTGZ' - extracting now"
					mkProjDir "$(dirname "$RUNPROTON")/dist"
					"$TAR" xf "$(dirname "$RUNPROTON")/$PDTGZ" -C "$(dirname "$RUNPROTON")/dist" 2>/dev/null
				fi

				PROTONVERSION="$(setProtonPathVersion "$RUNPROTON")"
				USEPROTON="$PROTONVERSION"

				setRunWineServer "${FUNCNAME[0]}"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Using Steam Proton '$FIRSTUSEPROTON' instead of ${PROGNAME,,} Proton '$USEPROTON', because '$PROGCMD' was used as '$SLO'"
				notiShow "$(strFix "$NOTY_SETNEWPROTVARS" "$FIRSTUSEPROTON")"
			fi
		fi

		if [ "$USEWINEDEBUGPROTON" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using '$STLWINEDEBUG' as Proton 'WINEDEBUG' parameters, because 'USEWINEDEBUGPROTON' is enabled"
			export WINEDEBUG="$STLWINEDEBUG"
		fi

		if [ -n "$STLWINEDLLOVERRIDES" ] && [ "$STLWINEDLLOVERRIDES" != "$NON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using '$STLWINEDLLOVERRIDES' as 'WINEDLLOVERRIDES' parameter"
			export WINEDLLOVERRIDES="$WINEDLLOVERRIDES;$STLWINEDLLOVERRIDES"
		fi
	fi
}

# in case you wonder NOP='Newest Official Proton'
function getNOP {
	createProtonList
	NEWESTPROTRAW="$(printProtonArr | grep "^proton-[0-9]." | sort -nr | head -n1)"

	if [ "$1" == "p" ]; then
		cut -d ';' -f2 <<< "$NEWESTPROTRAW"
	elif [ "$1" == "v" ]; then
		cut -d ';' -f1 <<< "$NEWESTPROTRAW"
	fi
}

function setNOP {
	writelog "INFO" "${FUNCNAME[0]} - Selecting newest official Proton available"
	NOPPATH="$(getNOP "p")"
	if [ -n "$NOPPATH" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Selected '$NOPPATH'"
		NEWPROPA="$( dirname "$NOPPATH" )"
		NEWPROPA="${NEWPROPA%*/}"
		NEWPROPA="${NEWPROPA##*/}"
		notiShow "$(strFix "$NOTY_WANTPROTON2" "$NEWPROPA" "$USEPROTON")"

		setNewProtVars "$NOPPATH"
	else
		writelog "SKIP" "${FUNCNAME[0]} - Haven't found anything"
	fi
}

function needNewProton {
	if [ "$HAVEINPROTON" -eq 0 ]; then
		getAvailableProtonVersions "up"
		export CURWIKI="$PPW/Proton-Versions"
		TITLE="${PROGNAME}-NeedNewProtonVersion"
		pollWinRes "$TITLE"
		writelog "INFO" "${FUNCNAME[0]} - No Proton Version was found - opening a requester to choose from one"
		createProtonList

		PICKPROTON="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --center "${WINDECO[@]}" --form --scroll --separator="\n" --quoted-output \
		--text="$(spanFont "$GUI_NEEDNEWPROTON" "H")" \
		--field="$GUI_NEEDNEWPROTON2":CB "$(cleanDropDown "${USEPROTON/#-/ -}" "$PROTYADLIST")" \
		--title="$TITLE" "$GEOM")"

		if [ -n "$PICKPROTON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Selected Proton Version $PICKPROTON"
			setNewProtVars "$(getProtPathFromCSV "$PICKPROTON")"
		else
			writelog "INFO" "${FUNCNAME[0]} - No Proton Version was selected - try again"
			"${FUNCNAME[0]}"
		fi
	fi
}

