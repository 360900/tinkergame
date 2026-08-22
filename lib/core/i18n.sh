#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function loadLangFile {
	local SCRIPTDIR
	local LOCALLANGFILE

	if [ -n "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Language from command line is '$1'" "P"

		LANGFILENAME="$1"
		if [ -z "$GLOBALSTLLANGDIR" ]; then
			GLOBLANG="$SYSTEMSTLCFGDIR/lang/"
			writelog "INFO" "${FUNCNAME[0]} - SYSTEMSTLCFGDIR is '$SYSTEMSTLCFGDIR'" "P"
		else
			GLOBLANG="$GLOBALSTLLANGDIR"
			writelog "INFO" "${FUNCNAME[0]} - GLOBALSTLLANGDIR is '$GLOBALSTLLANGDIR'" "P"
		fi

		if [ -f "$LANGFILENAME" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Loading command line langfile '$LANGFILENAME'" "P"
			source "$LANGFILENAME"
			STLLANG="$(cut -d '.' -f1 <<< "${LANGFILENAME##*/}")"
			LAFI="$STLLANGDIR/${STLLANG}.txt"
			if [ ! -f "$LAFI" ]; then
				mkProjDir "$STLLANGDIR"
				cp "$LANGFILENAME" "$LAFI"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Command line language '$LANGFILENAME' is no file - trying to find its absolute path" "P"

			LAFI="$STLLANGDIR/${LANGFILENAME}.txt"

			SCRIPTDIR="$( realpath "$0" )"
			SCRIPTDIR="${SCRIPTDIR%/*}"
			LOCALLANGFILE="$SCRIPTDIR/lang/${LANGFILENAME}.txt"

			if [ -f "$LAFI" ]; then
				# If langfile in ~/.config/tinkergame/lang exists, and we have a langfile installed globally or in the scriptdir, update the user-installed langfile
				writelog "INFO" "${FUNCNAME[0]} - Found user-installed $LAFI, attempting to update it"
				UPDATELANGFILEPATH=""
				if [ -f "$SYSTEMSTLCFGDIR/lang/${LANGFILENAME}.txt" ]; then
					UPDATELANGFILEPATH="$SYSTEMSTLCFGDIR/lang/${LANGFILENAME}.txt"  # Globally installed langfile (or stlprefix langfile on steam deck) - This one takes priority as it is assumed to be the most up to date
				elif [ -f "$LOCALLANGFILE" ]; then
					UPDATELANGFILEPATH="$LOCALLANGFILE" # langfile from scriptdir (on steam deck first-time install this would be the install directory)
				fi

				if [ -n "$UPDATELANGFILEPATH" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Found lang file to replace the existing user-installed file with under '$UPDATELANGFILEPATH'"
					chmod +w "$LAFI" #Ensure write permissions before removing
					rm "$LAFI"
					cp "$UPDATELANGFILEPATH" "$LAFI"
					chmod -R +w "$STLLANGDIR" #Ensure write permissions for next update!
				else
					writelog "INFO" "${FUNCNAME[0]} - No lang file to replace existing user-installed file with, not updating langfile"
				fi

				writelog "INFO" "${FUNCNAME[0]} - Loading found user-installed $LAFI" "P"
				source "$LAFI"
				STLLANG="$(cut -d '.' -f1 <<< "${LANGFILENAME##*/}")"
			elif [ -f "$LOCALLANGFILE" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Loading language file from script directory '$LOCALLANGFILE'"
				source "$LOCALLANGFILE"
				STLLANG="$(cut -d '.' -f1 <<< "${LOCALLANGFILE##*/}")"
			else
				LAFI="$GLOBLANG/${LANGFILENAME}.txt"

				if [ -f "$LAFI" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Loading found system wide $LAFI" "P"
					source "$LAFI"
				else
					writelog "ERROR" "${FUNCNAME[0]} - Language file '$LAFI' could not be found" "P"
				fi
			fi
		fi
	fi
}

function loadLanguage {
	writelog "INFO" "${FUNCNAME[0]} - First load the default language '$STLDEFLANG' to make sure all variables are filled"
	loadLangFile "$STLDEFLANG"

	# Prevents loadLanguage from creating the global.conf too early when it may be missing values
	# i.e. loadLanguage may be called before setSteamPaths, which can result in creating paths without the required Steam path variables set yet
	#      This can happen with Luxtorpead, where the LUXTORPEDACMD may be written out before `setSteamPaths` has been called to set `STEAMCOMPATTOOL`
	if [ -f "$STLDEFGLOBALCFG" ]; then
		saveCfg "$STLDEFGLOBALCFG" X
		loadCfg "$STLDEFGLOBALCFG" X
	fi

	writelog "INFO" "${FUNCNAME[0]} - Loading STLLANG from '$STLDEFGLOBALCFG'"

	ARGSLANG="$(awk -F 'lang=' '{print $2}' <<< "$@" | cut -d ' ' -f1)"
	if [ -n "$ARGSLANG" ]; then
		STLLANG="$ARGSLANG"
		writelog "INFO" "${FUNCNAME[0]} - STLLANG from command line' is '$STLLANG'"

	elif [ -f "$STLDEFGLOBALCFG" ]; then
		STLLRAW="$(grep "^STLLANG" "$STLDEFGLOBALCFG" | cut -d '=' -f2)"
		STLLANG="${STLLRAW//\"/}"
		writelog "INFO" "${FUNCNAME[0]} - STLLANG from '$STLDEFGLOBALCFG' is '$STLLANG'"
	else
		writelog "WARN" "${FUNCNAME[0]} - Could not determine STLLANG"
	fi

	if [ -n "$STLLANG" ] && [ "$STLLANG" != "$STLDEFLANG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Now load the language file '$STLLANG'"
		loadLangFile "$STLLANG"
		touch "$FUPDATE"
		updateConfigEntry "STLLANG" "$STLLANG" "$STLDEFGLOBALCFG"
	fi

	if [ -z "$DESC_STLLANG" ]; then # example variable, if it is empty it means no language file was loaded above
		writelog "ERROR" "${FUNCNAME[0]} - ###############################" "E"
		writelog "ERROR" "${FUNCNAME[0]} - No language file could be loaded! For the initial setup at least one file (default english) is required" "E"
		writelog "ERROR" "${FUNCNAME[0]} - You can ether copy a valid file to '$STLLANGDIR' or '$SYSTEMSTLCFGDIR/lang' or provide an absolute path via command line using the lang= option" "E"
		writelog "ERROR" "${FUNCNAME[0]} - ###############################" "E"
		exit
	fi
}

