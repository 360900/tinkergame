#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function extWine64Run {
	if [ "$USEWINE" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Command in Proton WINEPREFIX is: WINE=\"$RUNWINE\" WINEARCH=win64 WINEDEBUG=\"$STLWINEDEBUG\" WINEPREFIX=\"$GPFX\" $*"
		WINE="$RUNWINE" WINEARCH=win64 WINEDEBUG="$STLWINEDEBUG" WINEPREFIX="$GPFX" "$@" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
	else
		writelog "INFO" "${FUNCNAME[0]} - Command in Wine WINEPREFIX is: WINE=\"$RUNWINE\" WINEARCH=\"$RUNWINEARCH\" WINEDEBUG=\"$STLWINEDEBUG\" WINEPREFIX=\"$GWFX\" $*"
		WINE="$RUNWINE" WINEARCH="$RUNWINEARCH" WINEDEBUG="$STLWINEDEBUG" WINEPREFIX="$GWFX" "$@" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
	fi
}

function extProtonRun {
	MODE="$1"
	PROGRAM="$2"
	PROGARGS="$3"
	EXTPROGRAMARGS="$4"  # e.g. args like GameScope/GameMode taken from `buildCustomCmdLaunch` for ONLY_CUSTOMCMD
	EXTWINERUN=0
	EXTPROTUSESLR="${5:-0}"  # Should extProtonRun fetch and use SLR (default to 0 -- turned off)

	if [ "$USEWINE" -eq 1 ] && [[ ! "$WINEVERSION" =~ ${DUMMYBIN}$ ]] && [ "$WINEVERSION" != "$NON" ]; then
		EXTWINERUN=1
	fi

	setRunProtonFromUseProton

	# could help here:
	if [ ! -f "${RUNPROTON//\"/}" ]; then
		writelog "WARN" "${FUNCNAME[0]} - '$USEPROTON' seems outdated as the executable ${RUNPROTON//\"/} wasn't found"
		fixProtonVersionMismatch "USEPROTON" "$STLGAMECFG"
	fi

	writelog "INFO" "${FUNCNAME[0]} - Continuing with RUNPROTON='$RUNPROTON'"

	if [ ! -f "$RUNPROTON" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - When this error occurs, probably the configured Proton (or a similar) version is no longer available."
		writelog "ERROR" "${FUNCNAME[0]} - Because the RUNPROTON '$RUNPROTON' isn't ready here yet - please open an issue when you made sure it is set to an existing one and the error persists"
	else
		if [ -z "$PROGARGS" ] || [ "$PROGARGS" == "$NON" ]; then
			RUNPROGARGS=""
		else
			mapfile -d " " -t -O "${#TMP_RUNPROGARGS[@]}" TMP_RUNPROGARGS < <( printf "%q" "$PROGARGS" )

			# Basically check for and join paths that contain spaces because above mapfile will strip them
			# TODO: This does NOT work with paths that use forward slashes
			for i in "${!TMP_RUNPROGARGS[@]}"; do
				# Remove trailing backslash, i.e. turn `--launch\` into `--launch`
				TMP_RUNPROGARGS[i]="${TMP_RUNPROGARGS[i]%\\}"

				# If the last seen element in the array ended with a backslash, assume
				# this is an incomplete path and join them
				#
				# This is not perfect as valid paths that just end with backslashes will not work,
				# but we can document this on the wiki
				#
				# i.e. "Z:\this\is\a\path\ MY_VAR=2" will not work, but "Z:\this\is\a\path MY_VAR=2" will work
				if [[ $LASTRUNPROGARG = *"\\" ]]; then
					# Remove 'i-1' (previous element), because 'i' (current element) will contain 'i-1'
					unset "TMP_RUNPROGARGS[i-1]"
					TMP_RUNPROGARGS[i]="${LASTRUNPROGARG} ${TMP_RUNPROGARGS[i]}"
				fi
				LASTRUNPROGARG="${TMP_RUNPROGARGS[i]}"
			done

			# Generate new array with null strings removed.
			mapfile -t -O "${#RUNPROGARGS[@]}" RUNPROGARGS < <( printf "%s\n" "${TMP_RUNPROGARGS[@]}" | grep -v "^$" )
		fi

		FWAIT=2

		# mirrors above RUNPROGARGS
		# TODO what if we try to pass paths with spaces? This could be problematic here...
		if [ -z "$EXTPROGRAMARGS" ]; then
			writelog "INFO" "${FUNCNAME[0]} - No external program args here it seems"
			RUNEXTPROGRAMARGS=( "" )
		else
			writelog "INFO" "${FUNCNAME[0]} - Looks like we got some external program args, '${EXTPROGRAMARGS}'"
			mapfile -d " " -t -O "${#RUNEXTPROGRAMARGS[@]}" RUNEXTPROGRAMARGS < <(printf '%s' "$EXTPROGRAMARGS")
		fi

		# Have to set SLR in extProtonRun because we can't pass the array to the function
		# Hopefully unsetting is safe and doesn't mean places that need the SLR will lose it from this 'unset'
		if [ "$EXTPROTUSESLR" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - EXTPROTUSESLR is '$EXTPROTUSESLR' -- Attempting to find and use SLR with extProtonRun"

			unset "${SLRCMD[@]}"
			setSLRReap
		fi

		# append SLR to beginning of RUNEXTPROGRAMARGS, if SLR is defined
		# TODO this is the exact same logic as in launchCustomProg (except the log messages are slightly different), is there any way to share it?
		if [ -n "${SLRCMD[*]}" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Gotten Steam Linux Runtime for Proton launch, using RUNEXTPROGRAMARGS array to contain it and add it to launch command"

			OLDRUNEXTPROGRAMARGS=( "${RUNEXTPROGRAMARGS[@]}" )

			unset "${RUNEXTPROGRAMARGS[@]}"
			RUNEXTPROGRAMARGS=( "${SLRCMD[@]}" )

			# OLDRUNEXTPROGRAMARGS should only contain one item, the passed args for the custom command
			# if the first item here is not empty, assume we have to include the old pass args in the new array
			#
			# if blank, it means OLDRUNEXTPROGRAMARGS was most likely empty (or started with a blank element, which would cause a crash anyway)
			# so we can just create RUNEXTPROGRAMARGS with the SLR as the only element
			if [ -n "${OLDRUNEXTPROGRAMARGS[0]}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Seems like some arguments were given to the custom command, including them alongside the Steam Linux Runtime arguments"
				RUNEXTPROGRAMARGS+=( "${OLDRUNEXTPROGRAMARGS[@]}" )
			fi
		elif [ -z "${SLRCMD[*]}" ] && [ "$CUSTOMCMD_USESLR" -eq 1 ]; then
			writelog "WARN" "${FUNCNAME[0]} - Attempted to fetch Steam Linux Runtime but failed to find one!"
		fi
		unset "${SLRCMD[@]}"

		# TODO pass "$EXTPROGRAMARGS" to programs running with Wine as well(?)
		# TODO refactor a bit to be a little cleaner if possible
		# TODO it should be possible to pass PROTON_LOG to these Proton commands, however this also requries SteamGameId to be set -- This is not defined outside of Steam AND inside of Steam it would conflict with an actual Game ID if used
		#      if we want to use PROTON_LOG we need the ability to pass in PROTON_LOG=? and a custom SteamGameId that is only set for these program runs
		#      i.e. a default SteamGameId could be `extProtonRun`, but launchCustomProg could pass `customcommand`.
		#
		#      This would be tricky to add, but would be nice to have!
		CUSTPROGNAME="$( basename "$PROGRAM" )"
		if [ "$MODE" == "F" ]; then  # Forked Proton/Wine 'normal' custom program
			if [ -n "${RUNPROGARGS[0]}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Starting '$PROGRAM' with arguments '${RUNPROGARGS[*]}' forked into the background"
				restoreOrgVars
				if [ "$EXTWINERUN" -eq 1 ]; then
					(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_ARGS_WINE" "$CUSTPROGNAME" )"; extWine64Run "$PROGRAM" "${RUNPROGARGS[@]}") &
				else
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_ARGS" "$CUSTPROGNAME" )"; "${RUNEXTPROGRAMARGS[@]}" "$RUNPROTON" run "$PROGRAM" "${RUNPROGARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					else
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_ARGS" "$CUSTPROGNAME" )"; "$RUNPROTON" run "$PROGRAM" "${RUNPROGARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					fi
				fi
				emptyVars "O" "X"
			else
				writelog "INFO" "${FUNCNAME[0]} - Starting '$PROGRAM' forked into the background"
				restoreOrgVars
				if [ "$EXTWINERUN" -eq 1 ]; then
					(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_WINE" "$CUSTPROGNAME" )"; extWine64Run "$PROGRAM") &
				else
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED" "$CUSTPROGNAME" )"; "${RUNEXTPROGRAMARGS[@]}" "$RUNPROTON" run "$PROGRAM" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					else
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED" "$CUSTPROGNAME" )"; "$RUNPROTON" run "$PROGRAM" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					fi
				fi
				emptyVars "O" "X"
			fi
		elif [ "$MODE" == "FC" ]; then  # Forked Proton/Wine 'command line' custom program
			if [ -n "${RUNPROGARGS[0]}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Starting '$WICO $PROGRAM' with arguments '${RUNPROGARGS[*]}' forked into the background"
				restoreOrgVars
				if [ "$EXTWINERUN" -eq 1 ]; then
					(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_ARGS_WINE" "$CUSTPROGNAME" )"; extWine64Run "$RUNWICO" "$PROGRAM" "${RUNPROGARGS[@]}") &
				else
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_ARGS" "$CUSTPROGNAME" )"; "${RUNEXTPROGRAMARGS[@]}" "$RUNPROTON" run "$WICO" "$PROGRAM" "${RUNPROGARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					else
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_ARGS" "$CUSTPROGNAME" )"; "$RUNPROTON" run "$WICO" "$PROGRAM" "${RUNPROGARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					fi
				fi
				emptyVars "O" "X"
			else
				writelog "INFO" "${FUNCNAME[0]} - Starting '$WICO $PROGRAM' forked into the background"
				restoreOrgVars
				if [ "$EXTWINERUN" -eq 1 ]; then
					(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED_WINE" "$CUSTPROGNAME" )"; extWine64Run "$RUNWICO" "$PROGRAM") &
				else
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED" "$CUSTPROGNAME" )"; "${RUNEXTPROGRAMARGS[@]}" "$RUNPROTON" run "$WICO" "$PROGRAM" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					else
						(sleep "$FWAIT"; notiShow "$( strFix "$NOTY_CUSTPROG_FORKED" "$CUSTPROGNAME" )"; "$RUNPROTON" run "$WICO" "$PROGRAM" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log") &
					fi
				fi
				emptyVars "O" "X"
			fi
		elif [ "$MODE" == "R" ]; then  # Regular (no fork/wait/etc) Proton/Wine custom program
			if [ -n "${RUNPROGARGS[0]}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Starting '$PROGRAM' with arguments '${RUNPROGARGS[*]}' regularly"
				restoreOrgVars
				if [ "$EXTWINERUN" -eq 1 ]; then
					notiShow "$( strFix "$NOTY_CUSTPROG_REG_ARGS_WINE" "$CUSTPROGNAME" )"
					extWine64Run "$PROGRAM" "${RUNPROGARGS[@]}"
				else
					notiShow "$( strFix "$NOTY_CUSTPROG_REG_ARGS" "$CUSTPROGNAME" )"
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						"${RUNEXTPROGRAMARGS[@]}" "$RUNPROTON" run "$PROGRAM" "${RUNPROGARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					else
						"$RUNPROTON" run "$PROGRAM" "${RUNPROGARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					fi
				fi
				emptyVars "O" "X"
			else
				writelog "INFO" "${FUNCNAME[0]} - Starting '$PROGRAM' regularly"
				restoreOrgVars
				if [ "$EXTWINERUN" -eq 1 ]; then
					notiShow "$( strFix "$NOTY_CUSTPROG_REG_WINE" "$CUSTPROGNAME" )"
					extWine64Run "$PROGRAM"
				else
					notiShow "$( strFix "$NOTY_CUSTPROG_REG" "$CUSTPROGNAME" )"
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						writelog "INFO" "${FUNCNAME[0]} - \"${RUNEXTPROGRAMARGS[*]}\" \"$RUNPROTON\" run \"$PROGRAM\""
						"${RUNEXTPROGRAMARGS[@]}" "$RUNPROTON" waitforexitandrun "$PROGRAM" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					else
						"$RUNPROTON" run "$PROGRAM" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					fi
				fi
				emptyVars "O" "X"
			fi
		elif [ "$MODE" == "RC" ]; then  # Regular (no fork/wait/etc) Proton/Wine 'command line' custom program
			if [ -n "${RUNPROGARGS[0]}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Starting '$WICO $PROGRAM' with arguments '${RUNPROGARGS[*]}' regularly"
				restoreOrgVars
				if [ "$EXTWINERUN" -eq 1 ]; then
					notiShow "$( strFix "$NOTY_CUSTPROG_REG_ARGS_WINE" "$CUSTPROGNAME" )"
					extWine64Run "$RUNWICO" "$PROGRAM" "${RUNPROGARGS[@]}"
				else
					notiShow "$( strFix "$NOTY_CUSTPROG_REG_ARGS" "$CUSTPROGNAME" )"
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						"${RUNEXTPROGRAMARGS[@]}" "$RUNPROTON" run "$WICO" "$PROGRAM" "${RUNPROGARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					else
						"$RUNPROTON" run "$WICO" "$PROGRAM" "${RUNPROGARGS[@]}" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					fi
				fi
				emptyVars "O" "X"
			else
				writelog "INFO" "${FUNCNAME[0]} - Starting '$WICO $PROGRAM' regularly"
				restoreOrgVars
				if [ "$EXTWINERUN" -eq 1 ]; then
					notiShow "$( strFix "$NOTY_CUSTPROG_REG_WINE" "$CUSTPROGNAME" )"
					extWine64Run "$RUNWICO" "$PROGRAM"
				else
					notiShow "$( strFix "$NOTY_CUSTPROG_REG" "$CUSTPROGNAME" )"
					if [ -n "${RUNEXTPROGRAMARGS[0]}" ]; then
						"${RUNEXTPROGRAMARGS[@]}" "$RUNPROTON" run "$WICO" "$PROGRAM" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					else
						"$RUNPROTON" run "$WICO" "$PROGRAM" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
					fi
				fi
				emptyVars "O" "X"
			fi
		fi
	fi
}

