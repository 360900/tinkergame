#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function CompatTool {

	SCTS="$STEAMCOMPATOOLS/$PROGNAME"

	if [ "$1" == "add" ] ; then
		if [ -d "$SROOT" ]; then
			if [ ! -d "$STEAMCOMPATOOLS" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Initially creating dir '$STEAMCOMPATOOLS'"
				mkProjDir "$STEAMCOMPATOOLS"
				if [ ! -d "$STEAMCOMPATOOLS" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - Failed to create the directory '$STEAMCOMPATOOLS'"
				fi
			fi

			if [ "$ONSTEAMDECK" -eq 1 ]; then
				if [ -n "$2" ]; then
					STLBIN="$2"
				else
					STLBIN="$PREFIX/$PROGCMD"
				fi
			else
				STLBIN="$0"
			fi

			if [ ! -d "$SCTS" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Creating dir '$SCTS'"
				mkProjDir "$SCTS"

				if [ ! -d "$SCTS" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - Failed to create the directory '$SCTS' - check your write priviledges on '$STEAMCOMPATOOLS'"
				fi

				CVDF="$SCTS/$CTVDF"
				writelog "INFO" "${FUNCNAME[0]} - Creating file '$CVDF'"
				{
				echo "\"compatibilitytools\""
				echo "{"
				echo "  \"compat_tools\""
				echo "  {"
				echo "	\"Proton-${SHOSTL}\" // Internal name of this tool"
				echo "	{"
				echo "	  \"install_path\" \".\""
				echo "	  \"display_name\" \"$NICEPROGNAME\""
				echo ""
				echo "	  \"from_oslist\"  \"windows\""
				echo "	  \"to_oslist\"    \"linux\""
				echo "	}"
				echo "  }"
				echo "}"
				} >> "$CVDF"

				if [ ! -f "$CVDF" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - Failed to create the file '$CVDF' - check your write priviledges on '$SCTS'"
				fi

				TVDF="$SCTS/toolmanifest.vdf"
				writelog "INFO" "${FUNCNAME[0]} - Creating file '$TVDF'"
				{
				echo "\"manifest\""
				echo "{"
				echo "  \"commandline\" \"/$PROGCMD run\""
				echo "  \"commandline_$WFEAR\" \"/$PROGCMD $WFEAR\""
				echo "}"
				} >> "$TVDF"

				if [ ! -f "$TVDF" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - Failed to create the file '$TVDF' - check your write priviledges on '$SCTS'"
				fi

				writelog "INFO" "${FUNCNAME[0]} - Creating symlink '$SCTS/$PROGCMD' pointing to '$STLBIN'" "E"
				ln -s "$(realpath "$STLBIN")" "$SCTS/$PROGCMD"

				if [ ! -L "$SCTS/$PROGCMD" ]; then
					writelog "ERROR" "${FUNCNAME[0]} - Failed to create the symlink '$SCTS/$PROGCMD' - check your write priviledges on '$SCTS'"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - '$SCTS' already exists - checking if '$PROGCMD' symlink needs to be updated"
				if [ "$(readlink "$SCTS/$PROGCMD")" == "$(realpath "$STLBIN")" ]; then
					writelog "SKIP" "${FUNCNAME[0]} - Nothing to do the '$SCTS/$PROGCMD' symlink still points to '$STLBIN'" "E"
				else
					rm "$SCTS/$PROGCMD"
					ln -s "$(realpath "$STLBIN")" "$SCTS/$PROGCMD"
					writelog "SKIP" "${FUNCNAME[0]} - Updated the '$SCTS/$PROGCMD' symlink to '$STLBIN'" "E"
				fi
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Steam Home Dir '$SROOT' not found!"
		fi
	elif [ "$1" == "del" ]; then
		if [ ! -d "$SCTS" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Selected '$1' but '$SCTS' doesn't exist"
			return
		fi

		rm "$SCTS/$PROGCMD" 2>/dev/null
		# *.vdf is usually 'compatibilitytool.vdf', *.txt is usually 'VERSION.txt' created by ProtonUp-Qt
		find "$SCTS" -maxdepth 1 -type f \( -name "*.vdf" -o -name "*.txt" \) -exec rm {} \;
		rmdir "$SCTS"
		if [ ! -d "$SCTS" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Removed '$SCTS' successfully" "E"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Tried to carefully remove '$SCTS', but it still exists - any files inside '$SCTS'?" "E"
		fi
	else
		if [ ! -d "$SCTS" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$PROGNAME' is not installed as Steam Compatibility Tool in '$STEAMCOMPATOOLS'" "E"
		else
			writelog "INFO" "${FUNCNAME[0]} - '$PROGNAME' is installed as Steam Compatibility Tool in '$STEAMCOMPATOOLS' and points to '$(readlink "$SCTS/$PROGCMD")'" "E"
		fi
	fi
}

function setRunProtonFromUseProton {
	if [ -n "$USEPROTON" ]; then
		NRUNPROTON="$(getProtPathFromCSV "$USEPROTON")"

		if [ -n "$RUNPROTON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Setting ORUNPROTON to '$RUNPROTON'"
			ORUNPROTON="$RUNPROTON"
		fi

		if [ -n "$ORUNPROTON" ] && [ "$ORUNPROTON" == "$NRUNPROTON" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - RUNPROTON '$RUNPROTON' hasn't changed"
		elif [ -n "$NRUNPROTON" ]; then
			if [ -z "$ORUNPROTON" ] || [ "$ORUNPROTON" == "" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Initially setting RUNPROTON for USEPROTON '$USEPROTON' to '$NRUNPROTON'"
			else
				writelog "INFO" "${FUNCNAME[0]} - Updating RUNPROTON for USEPROTON '$USEPROTON' from '$ORUNPROTON' to '$NRUNPROTON'"
			fi
			RUNPROTON="$NRUNPROTON"
			writelog "INFO" "${FUNCNAME[0]} - Set RUNPROTON to '$RUNPROTON'"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - USEPROTON is empty"
	fi
}

