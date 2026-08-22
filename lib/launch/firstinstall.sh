#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function CreateCustomEvaluatorScript {
	# create temporary '$TEVALSC'
	function createTempEvals {

		# first the correct install order:
		OCNT=0

		echo "\"$EVALSC\"" > "$TEVALSC"
		echo "{" >> "$TEVALSC"
		while read -r ordline; do
			if grep -q "$ordline" <<< "$EVALSCFILES"; then
				echo "	\"$OCNT\"" >> "$TEVALSC"
				if [ -f "${GLOBSTLEVPACKS}/$ordline" ]; then
					cat "${GLOBSTLEVPACKS}/$ordline" >> "$TEVALSC"
				else
					cat "${GLOBEVPACKS}/$ordline" >> "$TEVALSC"
				fi
				OCNT=$((OCNT+1))
			fi
		done < "$GLOBEVPACKORDER"

		# then append those packages which are not in the order list:
		while read -r wantevascs; do
			if ! grep -q "$wantevascs" "$GLOBEVPACKORDER"; then
				echo "	\"$OCNT\"" >> "$TEVALSC"
				if [ -f "${GLOBSTLEVPACKS}/$wantevascs" ]; then
					cat "${GLOBSTLEVPACKS}/$wantevascs" >> "$TEVALSC"
				else
					cat "${GLOBEVPACKS}/$wantevascs" >> "$TEVALSC"
				fi
				OCNT=$((OCNT+1))
			fi
		done <<< "$EVALSCFILES"

		while read -r intpak; do
			if [ -n "$intpak" ] ; then
				IPFDIR="$(awk -F'"' '{print $4}' <<< "$intpak")"
				IPDIR="${IPFDIR##*/}"
				INTPAKWA="$STLSHM/intpak"
				# dirty workaround - proper fix?
				echo "tac \"$OEVALSC\" | awk '/$IPDIR/,/appid/' | tac" > "$INTPAKWA"
				chmod +x "$INTPAKWA"
				{
					echo "	\"$OCNT\""
					echo "	{"
					"$INTPAKWA"
					echo "	}"
				} >> "$TEVALSC"
				OCNT=$((OCNT+1))
				rm "$INTPAKWA" 2>/dev/null
			fi
		done <<< "$(grep "$LIINPA" "$OEVALSC" | grep -v "${STEWOS}\|${STLDLDIR}\|STESHA\|STLDLDIR")"

		echo "}" >> "$TEVALSC"
		writelog "INFO" "${FUNCNAME[0]} - Created temporary '$TEVALSC'"
	}

	mkProjDir "$EVMETACUSTOMID"
	mkProjDir "$EVMETAADDONID"

	writelog "INFO" "${FUNCNAME[0]} - Starting Gui for Creating a custom '$EVALSC'"
	export CURWIKI="$PPW/Steam-First-Time-Setup"
	TITLE="${PROGNAME}-${FUNCNAME[0]}"
	pollWinRes "$TITLE"
	setShowPic

	EUNID="$1"

	REVALSC="$EVMETAID/${EVALSC}_${EUNID}.vdf"
	CEVALSC="$EVMETACUSTOMID/${EVALSC}_${EUNID}.vdf"
	AEVALSC="$EVMETAADDONID/${EVALSC}_${EUNID}.vdf"
	TEVALSC="${STLSHM}/${EVALSC}_${EUNID}_temp.vdf"

	REVP="packages"
	SEVP="stlpackages"
	GLOBEVPACKS="${GLOBALEVALDIR}/$REVP"
	GLOBSTLEVPACKS="${GLOBALEVALDIR}/$SEVP"

	GLOBEVPACKORDER="${GLOBALEVALDIR}/order.txt"
	TEVALSCSEL="$NON"

	if [ -f "$REVALSC" ]; then
		FOUNDEVALSC="Original"
		OEVALSC="$REVALSC"
		TEVALSCSEL="Original"
	fi

	if [ -f "$CEVALSC" ]; then
		if [ -n "$FOUNDEVALSC" ]; then
			FOUNDEVALSC="${FOUNDEVALSC}, Custom"
		else
			FOUNDEVALSC="Custom"
		fi
		OEVALSC="$CEVALSC"
		TEVALSCSEL="Custom"
	fi

	if [ -f "$AEVALSC" ]; then
		if [ -n "$FOUNDEVALSC" ]; then
			FOUNDEVALSC="${FOUNDEVALSC}, Addon"
		else
			FOUNDEVALSC="Addon"
		fi
		OEVALSC="$AEVALSC"
		TEVALSCSEL="Addon"
	fi

	if [ -f "$OEVALSC" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Pre-Selection is based on packages enabled in '$OEVALSC'"
	else
		TEVALSCSEL="$NON"
	fi

	GUITEXT1="$(strFix "$GUI_FOUNDEVALSC" "$FOUNDEVALSC")"
	GUITEXT2="$(strFix "$GUI_TEVALSCSEL" "$TEVALSCSEL")"
	GUITEXT3="$(strFix "$GUI_ADDEVALSC" "$SHADDESTDIR")"

	EVALSCFILES="$(
	while read -r EPACK; do
		if [ -f "$OEVALSC" ]; then
			PACKPROC="$(grep "process 1" "$EPACK")"
			if [ -n "$PACKPROC" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Searching in '$PACKPROC' '$OEVALSC'"
				if grep -Fq "$PACKPROC" "$OEVALSC"; then
					echo TRUE ; echo "${EPACK##*/}"
				else
					echo FALSE ; echo "${EPACK##*/}"
				fi
			else
				echo FALSE ; echo "${EPACK##*/}"
			fi
		else
			echo FALSE ; echo "${EPACK##*/}"
		fi
	done <<< "$(find "${GLOBALEVALDIR}" \( -type f -and -path "*/$REVP/*" -or -path "*/$SEVP/*" \))" | \
		"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" \
		--list --checklist --column="$GUI_ADD" --column=Script --separator="" --print-column="2" \
		--text="${GUITEXT1}\n$GUITEXT2\n$GUITEXT3" \
		--title="$TITLE" \
		--button="$BUT_SAEVALSC":2 --button="$BUT_SCEVALSC":4 --button="$BUT_ONLYINSTALL":6 --button="$BUT_CAN":8 \
		"$GEOM"
	)"
	case $? in
		2) 	{
				createTempEvals
				writelog "INFO" "${FUNCNAME[0]} - Selected Saving as Addon '$EVALSC': '$AEVALSC'"
				if [ -f "$AEVALSC" ]; then
					mv "$AEVALSC" "${AEVALSC//.vdf/_back.vdf}"
				fi
				mv "$TEVALSC" "$AEVALSC"
			}
		;;
		4)	{
				createTempEvals
				writelog "INFO" "${FUNCNAME[0]} - Selected Saving as Custom '$EVALSC': '$CEVALSC'"
				if [ -f "$CEVALSC" ]; then
					mv "$CEVALSC" "${CEVALSC//.vdf/_back.vdf}"
				fi
				mv "$TEVALSC" "$CEVALSC"
			}
		;;
		6)	{
				writelog "INFO" "${FUNCNAME[0]} - Selected to only install the packages without saving"
				createTempEvals
				writelog "INFO" "${FUNCNAME[0]} - Starting Install via command: reCreateCompatdata \"$EUNID\" \"${FUNCNAME[0]}\" \"$TEVALSC\""
				reCreateCompatdata "$EUNID" "${FUNCNAME[0]}" "$TEVALSC"
			}
		;;
		8)	{
				writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL"
			}
		;;
	esac
}

function reCreateCompatdata {
	function runEvalsc {
		unset LEV
		mapfile -d " " -t -O "${#LEV[@]}" LEV <<< "run ${ISCEXE} ${LECO}\\${EVALSC}_${1}.vdf"
		rm "$EVALISRUN" 2>/dev/null
		touch "$EVALISRUN"
		checkFirstTimeRun "${LEV[@]}" >/dev/null 2>/dev/null
		rm "$EVALISRUN"	"$FRSTATE" "${FRSTATE}-prev" 2>/dev/null
		doneEvacInstall
	}

	function getCurStep {
		unset GCS
		mapfile -d " " -t -O "${#GCS[@]}" GCS <<< "run ${ISCEXE} --${GECUST} ${1}"
		checkFirstTimeRun "${GCS[@]}" >/dev/null 2>/dev/null
		PRFRSTATE="${FRSTATE}-prev"

		if [ -f "$FRSTATE" ]; then
			if ! cmp -s -- "$FRSTATE" "$PRFRSTATE"; then
				cp "$FRSTATE" "$PRFRSTATE"
				notiShow "$(strFix "$NOTY_FRSTATE" "$(cat "$FRSTATE")")" "X"
				writelog "INFO" "${FUNCNAME[0]} - $(strFix "$NOTY_FRSTATE" "$(cat "$FRSTATE")")"
			fi
		fi
	}

	WANTGUI=0
	if [ "$1" == "ccd" ] || [ "$1" == "createcompatdata" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Started from command-line"
		EUNID="$2"
		if [ -n "$3" ]; then
			WANTGUI=1
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - Started from gui"
		EUNID="$1"
		WANTGUI=1
		BACKFUNC="$2"
	fi

	SCCILECO="$STEAM_COMPAT_CLIENT_INSTALL_PATH/$LECO"
	ISCEXE="$SCCILECO/$ISCRI.exe"

	if [ -n "$EUNID" ]; then
		SRCORIGEVSC="$EVMETAID/${EVALSC}_${EUNID}.vdf"
		SRCCUSTEVSC="$EVMETACUSTOMID/${EVALSC}_${EUNID}.vdf"

		if [ "$EUNID" == "$DPRS" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Starting '$DPRS' Installation"
			SRCORIGEVSC="${GLOBALEVALDIR}/sets/${EVALSC}_${DPRS,}.vdf"
			SRCEVSC="$SRCORIGEVSC"
			DESTCODA="$DPRSCOMPDATA"
			EARLYPROT="$DPRSPROTON"
			export STEAM_COMPAT_APP_ID="$DPRS"
			STEAM_COMPAT_INSTALL_PATH="$DPRSCOMPDATA"
		fi

		if [ ! -f "$ISCEXE" ]; then
			writelog "ERROR" "${FUNCNAME[0]} - '$ISCEXE' not found"
		else
			if [ ! -f "$SRCORIGEVSC" ] && [ ! -f "$SRCCUSTEVSC" ]; then
				if [ "$WANTGUI" -eq 0 ]; then
					writelog "ERROR" "${FUNCNAME[0]} - Neither '$SRCORIGEVSC' nor '$SRCCUSTEVSC' found (see wiki if the reason for not being able to continue is unknown)"
					writelog "ERROR" "${FUNCNAME[0]} - Alternatively start the same command with an additional 'gui' parameter, to create a '$SRCCUSTEVSC' via gui"
					HAVEEVSC=0
				else
					writelog "INFO" "${FUNCNAME[0]} - Requester to create a custom Install file via Gui"
					CreateCustomEvaluatorScript "$EUNID"
					if [ -f "$SRCCUSTEVSC" ]; then
						HAVEEVSC=1
					else
						HAVEEVSC=0
					fi
				fi
			else
				HAVEEVSC=1
			fi

			if [ "$HAVEEVSC" -eq 1 ]; then
				if [ -f "$CUMETA/${EUNID}.conf" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Loading Metadata '$CUMETA/${EUNID}.conf'"
					loadCfg "$CUMETA/${EUNID}.conf"
				fi

				if [ -z "$DESTCODA" ]; then
					if [ -n "$WINEPREFIX" ]; then
						DESTCODA="${WINEPREFIX%/*}"
					elif [ -n "$STEAM_COMPAT_DATA_PATH" ]; then
						DESTCODA="$STEAM_COMPAT_DATA_PATH"
					elif [ -n "$GPFX" ]; then
						DESTCODA="${GPFX%/*}"
					else
						getCompatData "${EUNID}" >/dev/null
						DESTCODA="$(cut -d ';' -f2 <<< "$FCOMPDAT")"
					fi
				fi

				if [ -n "$DESTCODA" ]; then
					export STEAM_COMPAT_DATA_PATH="$DESTCODA"
					writelog "INFO" "${FUNCNAME[0]} - Destination $CODA is '$STEAM_COMPAT_DATA_PATH'"

					if [ -z "$STEAM_COMPAT_INSTALL_PATH" ]; then
						if [ -n "$MEGAMEDIR" ]; then
							export STEAM_COMPAT_INSTALL_PATH="$MEGAMEDIR"
						elif [ -n "$EFD" ]; then
							export STEAM_COMPAT_INSTALL_PATH="$EFD"
						else
							writelog "INFO" "${FUNCNAME[0]} - STEAM_COMPAT_INSTALL_PATH (game dir) is unknown - setting it at least to '${STLDLDIR}'"
							export STEAM_COMPAT_INSTALL_PATH="$STLDLDIR"
						fi
					fi

					RECRECODA=1

					find "$DESTCODA" -maxdepth 0 -empty -exec rmdir {} \; 2>/dev/null

					if [ -d "$DESTCODA" ]; then
						if [ "$3" == "s" ]; then
							RCSEL="$(confirmReq "Ask_Recreate_Compatdata" "$(strFix "$GUI_RECRECODA" "$EUNID" "${EUNID}_${PROGNAME,,}")")"
							if [ "$RCSEL" -eq 0 ]; then
							{
								writelog "INFO" "${FUNCNAME[0]} - Confirmed recreating the wineprefix"
								RECRECODA=1
							}
							else
								writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL - Not recreating the wineprefix"
								RECRECODA=0
							fi
						fi

						if [ "$RECRECODA" -eq 1 ]; then
							if [ -d "${DESTCODA}_${PROGNAME,,}" ]; then
								writelog "INFO" "${FUNCNAME[0]} - Removing previous backup $CODA backup '${DESTCODA}_${PROGNAME,,}'"
								rm -rf "${DESTCODA}_${PROGNAME,,}" 2>/dev/null
							fi

							find "$DESTCODA" -maxdepth 0 -empty -exec rmdir {} \;

							if [ -d "$DESTCODA" ]; then
								writelog "INFO" "${FUNCNAME[0]} - Moving existing $CODA to '${DESTCODA}_${PROGNAME,,}'"
								mv "$DESTCODA" "${DESTCODA}_${PROGNAME,,}"
							fi
						fi
					fi

					if [ "$RECRECODA" -eq 1 ]; then
						if [ -z "$STEAM_COMPAT_APP_ID" ]; then
							export STEAM_COMPAT_APP_ID="${EUNID}"
						fi

						mkProjDir "$DESTCODA"
						EVALISRUN="$STLSHM/evalisrun.txt"

						cd "$STEAM_COMPAT_CLIENT_INSTALL_PATH" >/dev/null || return

						writelog "INFO" "${FUNCNAME[0]} - Launching First Run Installer"

						runEvalsc "${EUNID}" &

						while [ ! -f "$EVALISRUN" ];do
							sleep 0.1
						done

						while [ -f "$EVALISRUN" ];do
							getCurStep "${EUNID}"
							sleep 1
						done

						cd - >/dev/null || return
					fi
				else
					writelog "SKIP" "${FUNCNAME[0]} - No destination $CODA determined"
				fi
			fi

			if [ -n "$BACKFUNC" ]; then
				"$BACKFUNC" "$AID" "${FUNCNAME[0]}"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Need SteamAppId as argument"
	fi
}

function createModifiedEvalsc {
	if [ -z "$ISCRILOG" ]; then
		ISCRILOG="$STLSHM/${PROGNAME,,}-${ISCRI}-temp_$RANDOM.log"
	fi

	STESHA="$STEAM_COMPAT_CLIENT_INSTALL_PATH/$SAC/$STEWOS"
	if [ ! -d "$STESHA" ]; then
		writelog "WARN" "${FUNCNAME[0]} - '$STESHA' not found - packages expected there won't be found" "X" "$ISCRILOG"
		writelog "WARN" "${FUNCNAME[0]} - '$STESHA' is concatenated from '$STEAM_COMPAT_CLIENT_INSTALL_PATH', '$SAC', '$STEWOS'" "X" "$ISCRILOG"
	fi

	SOURCEEVALSC="$1"
	DSTEVALSC="$2"

	if [ ! -f "$SOURCEEVALSC" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - '$SOURCEEVALSC' does not exists" "X" "$ISCRILOG"
	elif [ ! -f "$DSTEVALSC" ]; then
		SCCILECO="$STEAM_COMPAT_CLIENT_INSTALL_PATH/$LECO"

		# creating a temporary copy of the evaluatorscript in $SCCILECO:
		writelog "INFO" "${FUNCNAME[0]} - Copying '$SOURCEEVALSC' to '$SCCILECO'" "X" "$ISCRILOG"
		cp "$SOURCEEVALSC" "$DSTEVALSC"

		# replace placeholders with real paths
		writelog "INFO" "${FUNCNAME[0]} - Replacing placeholders with real paths in '$DSTEVALSC'" "X" "$ISCRILOG"
		sed "s:STESHA:$STESHA:g" -i "$DSTEVALSC"
		sed "s:STLDLDIR:$STLDLDIR:g" -i "$DSTEVALSC"
	else
		writelog "SKIP" "${FUNCNAME[0]} - '$DSTEVALSC' already exists" "X" "$ISCRILOG"
	fi
}

function cleanupOutdatedEvals {
	writelog "INFO" "${FUNCNAME[0]} - Cleaning up outdated files in '$EVMETAID'"

	mkProjDir "$EVMETAOLD"
	while read -r oldfile; do
		if [ -f "$oldfile" ]; then
			mv "$oldfile" "$EVMETAOLD"
		fi
	done <<< "$(grep -Rl "foreign_install_path" "$EVMETAID")"

	while read -r oldfile; do
		if [ -f "$oldfile" ]; then
			while read -r lipent; do
				ABSLIINPA="$(cut -d \" -f4 <<< "$lipent")" # too weak?
				if [ ! -d "${ABSLIINPA//\"}" ] && [ "${ABSLIINPA//\"}" != "STLDLDIR" ] && [ "${ABSLIINPA//\"}" != "STESHA" ]; then
					mv "$oldfile" "$EVMETAOLD"
				fi
			done <<< "$(grep "$LIINPA" "$oldfile")"
		fi
	done <<< "$(grep -Rl "$LIINPA" "$EVMETAID")"
	writelog "INFO" "${FUNCNAME[0]} - Finished cleaning up '$EVMETAID'"
}

function doneEvacInstall {
	notiShow "$(strFix "$NOTY_FRDONE" "$EUNID")" "X"
	writelog "INFO" "${FUNCNAME[0]} - $(strFix "$NOTY_FRDONE" "$EUNID")" "E"
}

function runEvacInstall {
	INSTPROT="$1"
	# call $ISCRI via proton with the modified evaluatorscript as parameter:
	writelog "INFO" "${FUNCNAME[0]} - '$EVALSC' - START - STEAM_COMPAT_DATA_PATH=\"$STEAM_COMPAT_DATA_PATH\" '$INSTPROT run $ISCEXE $EVSC'" "X" "$ISCRILOG"
	STEAM_COMPAT_DATA_PATH="$STEAM_COMPAT_DATA_PATH" "$INSTPROT" run "$ISCEXE" "$EVSC"
	# move the temporary modified evaluatorscript into '$STMSHM'
	mv "$DSTEVSC" "$STLSHM/${DSTEVSC##*/}_$RANDOM"
}

function findEarlyProt {
	FEPLOG="$2"
	writelog "INFO" "${FUNCNAME[0]} - Trying to get a proton version from '$1'" "X" "$FEPLOG"
	if grep -q "^USEPROTON" "$1"; then
		CONFPROTRAW="$(grep "^USEPROTON" "$1" | cut -d '=' -f2)"
		CONFPROT="${CONFPROTRAW//\"}"

		if [ -z "$SUSDA" ]; then
			setSteamPaths
		fi

		createProtonList

		if [ -f "$PROTONCSV" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Searching '$CONFPROT' in '$PROTONCSV'" "X" "$FEPLOG"

			if grep -q "^${CONFPROT}" "$PROTONCSV"; then
				writelog "INFO" "${FUNCNAME[0]} - Found '$CONFPROT' in '$PROTONCSV'" "X" "$FEPLOG"
				EARLYPROT="$(grep "^${CONFPROT}" "$PROTONCSV" | cut -d ';' -f2)"
				export EARLYPROT
			else
				writelog "INFO" "${FUNCNAME[0]} - '$CONFPROT' not found in '$PROTONCSV'" "X" "$FEPLOG"
				# if configured USEPROTON proton binary was not found, try to find a minor version bump instead:
				TESTEARLYPROT="$(fixProtonVersionMismatch "CONFPROT" "$STLGAMECFG" "X")"
				if [ -f "$TESTEARLYPROT" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Found a minor version mismatch binary for '$CONFPROT':'$TESTEARLYPROT'" "X" "$FEPLOG"
					EARLYPROT="$TESTEARLYPROT"
					export EARLYPROT
				else
					if [ -n "$TESTEARLYPROT" ]; then
						writelog "SKIP" "${FUNCNAME[0]} - Found '$TESTEARLYPROT' does not exist" "X" "$FEPLOG"
					else
						writelog "SKIP" "${FUNCNAME[0]} - No minor version mismatch binary for '$CONFPROT' found'" "X" "$FEPLOG"
					fi
				fi
			fi
		else
			writelog "ERROR" "${FUNCNAME[0]} - Could not create '$PROTONCSV'" "X" "$FEPLOG"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - No USEPROTON entry found in '$1'" "X" "$FEPLOG"
	fi
}

function checkFirstTimeRun {
	ISCRILOG="$STLSHM/${PROGNAME,,}-${ISCRI}-${STEAM_COMPAT_APP_ID}.log"
	GPFX="$STEAM_COMPAT_DATA_PATH/pfx"
	SCCILECO="$STEAM_COMPAT_CLIENT_INSTALL_PATH/$LECO"
	ISCEXE="$SCCILECO/$ISCRI.exe"
	EVALPROTCONF="$STLSHM/evalprot-${STEAM_COMPAT_APP_ID}.conf"

	function waitForEvaluatorscript {
		mkProjDir "$EVMETAID"
		mkProjDir "$EVMETATITLE"

		ISCRILOG="$2"
		EVALVDF="$SCCILECO/$1"
		writelog "INFO" "${FUNCNAME[0]} - Waiting for '$EVALVDF' to appear" "X" "$ISCRILOG"
		while [ ! -f "$EVALVDF" ]; do
			sleep 0.1
		done
		cp "$EVALVDF" "$EVMETAID"
		writelog "INFO" "${FUNCNAME[0]} - Copied '$EVALVDF' to '$EVMETAID/$1'" "X" "$ISCRILOG"
	}

	rmOldLog

	if [ -n "$STEAM_RUNTIME_LIBRARY_PATH" ]; then
		touch "$STLSHM/SteamStart_${STEAM_COMPAT_APP_ID}.txt"
	fi

	if [ -f "$(find "$LOGFILE" -not -newermt '-5 seconds' 2>/dev/null)" ]; then
		if ! grep -q "$ISCRI" <<< "$(tail -n1 "$LOGFILE")"; then
			writelog "START" "######### '$ISCRI' #########" "X" "$ISCRILOG"
		fi
	fi
	# skip $ISCRI completely if a SKIP file exists for $STEAM_COMPAT_APP_ID
	if [ -f "$EVMETASKIPID/${EVALSC}_${STEAM_COMPAT_APP_ID}.vdf" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Skipping '$ISCRI' line '$*' because '$EVMETASKIPID/${EVALSC}_${STEAM_COMPAT_APP_ID}.vdf' exists" "X" "$ISCRILOG"
	else
		# filter evaluatorscript command
		if grep -q "$EVALSC" <<< "$@"; then
			# shellcheck disable=SC1003
			EVSC="$(awk -F 'legacycompat\\\' '{print $NF}' <<< "$@")"
		fi

		if [ -d "$EVMETAID" ]; then
			cleanupOutdatedEvals
		fi

		# check if evaluatorscript should be started:
		if [ ! -d "$GPFX" ] || [ ! -f "$EVMETAID/$EVSC" ]; then
			# get a proton version for the install process:
			if grep -q "$EVALSC" <<< "$@"; then

				# first check if the game has a ${PROGNAME,,} config and use the corresponding proton version:
				if [ -z "$EARLYPROT" ] && [ ! -f "$EVALPROTCONF" ] && [ -f "$STLGAMEDIRID/$STEAM_COMPAT_APP_ID.conf" ]; then
					findEarlyProt "$STLGAMEDIRID/$STEAM_COMPAT_APP_ID.conf" "$ISCRILOG"
				fi
				# as fallback check if the game template ${PROGNAME,,} config has a usable proton version:
				if [ -z "$EARLYPROT" ] && [ ! -f "$EVALPROTCONF" ] && [ -f "$STLDEFGAMECFG" ]; then
					findEarlyProt "$STLDEFGAMECFG" "$ISCRILOG"
				fi

				# if everything else failed, check for a "static proton version" just for the base install - either from file or from system variable:
				if [ -z "$EARLYPROT" ] && [ ! -f "$EVALPROTCONF" ] && [ -f "$STLEARLYPROTCONF" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Trying to get a proton version from '$STLEARLYPROTCONF'" "X" "$ISCRILOG"
					source "$STLEARLYPROTCONF"
				fi

				# fallback if for whatever reason USEPROTON is empty everywhere - trying to get NOP
				if [ -z "$EARLYPROT" ]; then
					if [ -z "$SUSDA" ]; then
						setSteamPaths
					fi
					writelog "INFO" "${FUNCNAME[0]} - Last try - trying to get Newest Official Proton" "X" "$ISCRILOG"
					CONFPROT="$(getDefaultProton)"
					createProtonList
					EARLYPROT="$(grep "^${CONFPROT}" "$PROTONCSV" | cut -d ';' -f2)"
				fi

				# write found protonversion into temp config, so below GECUST runs can use it as well:
				if [ -n "$EARLYPROT" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Writing 'EARLYPROT=$EARLYPROT' into '$EVALPROTCONF'" "X" "$ISCRILOG"
					echo "EARLYPROT=\"$EARLYPROT\"" > "$EVALPROTCONF"
					echo "TEVSC=\"$EVSC\"" >> "$EVALPROTCONF"
				fi
			fi

			# reload proton version from above EVALSC run:
			TEVSC="$NON"
			if [ -z "$EARLYPROT" ] && [ -f "$EVALPROTCONF" ]; then
				source "$EVALPROTCONF"
			fi
			# only continue with proton being available:
			if [ -n "$EARLYPROT" ] && [ -f "$EARLYPROT" ]; then
					# filter evaluatorscript command
					if grep -q "$EVALSC" <<< "$@"; then
						mapfile -d " " -t -O "${#RUNISCCMD[@]}" RUNISCCMD < <(printf '%s' "$(awk -F 'run ' '{print $NF}' <<< "$*")")
						# no evaluatorscript for the started game yet in the metadata - so starting the collector:

						SRCCUSTEVSC="$EVMETACUSTOMID/$EVSC"
						SRCORIGEVSC="$EVMETAID/$EVSC"

						TEVALSC="${STLSHM}/${EVALSC}_${STEAM_COMPAT_APP_ID}_temp.vdf"
						if [ -f "$TEVALSC" ]; then
							SRCEVSC="$TEVALSC"
							writelog "INFO" "${FUNCNAME[0]} - Using '$SRCEVSC' as source" "X" "$ISCRILOG"
						fi

						if [ -z "$SRCEVSC" ]; then
							if [ ! -f "$SRCORIGEVSC" ] && [ ! -f "$SRCCUSTEVSC" ]; then
								SRCEVSC="$SRCORIGEVSC"
								writelog "INFO" "${FUNCNAME[0]} - Both the copy '$SRCORIGEVSC' of the original and a custom '$SRCCUSTEVSC' are missing - trying to get the original'" "X" "$ISCRILOG"
							elif [ -f "$SRCORIGEVSC" ] && [ ! -f "$SRCCUSTEVSC" ]; then
								SRCEVSC="$SRCORIGEVSC"
								writelog "INFO" "${FUNCNAME[0]} - Using '$SRCEVSC' as source" "X" "$ISCRILOG"
							elif [ -f "$SRCORIGEVSC" ] && [ -f "$SRCCUSTEVSC" ]; then
								SRCEVSC="$SRCCUSTEVSC"
								writelog "INFO" "${FUNCNAME[0]} - Using custom '$SRCCUSTEVSC' as source, as it overrides the original '$SRCORIGEVSC' which also does exist" "X" "$ISCRILOG"
							elif [ ! -f "$SRCORIGEVSC" ] && [ -f "$SRCCUSTEVSC" ]; then
								SRCEVSC="$SRCCUSTEVSC"
								writelog "INFO" "${FUNCNAME[0]} - Using custom '$SRCCUSTEVSC' as source, and the original '$SRCORIGEVSC' does not exist" "X" "$ISCRILOG"
							fi
						fi

						if [ -n "$EVSC" ] && [ ! -f "$SRCEVSC" ] && [ "$SRCEVSC" == "$SRCORIGEVSC" ]; then
							waitForEvaluatorscript "$EVSC" "$ISCRILOG" &
							writelog "INFO" "${FUNCNAME[0]} - '$EVALSC' START - '$EARLYPROT run ${RUNISCCMD[*]}'" "X" "$ISCRILOG"
							"$EARLYPROT" run "${RUNISCCMD[@]}"
							while [ ! -f "$SRCEVSC" ]; do
								sleep 0.1
							done
						fi

						# have a evaluatorscript to work with:
						if [ -f "$SRCEVSC" ]; then
							DSTEVSC="$STEAM_COMPAT_CLIENT_INSTALL_PATH/$EVSC"
							createModifiedEvalsc "$SRCEVSC" "$DSTEVSC"

							if grep -q "$EVMETACUSTOMID" <<< "$SRCEVSC" ; then
								notiShow "$(strFix "$NOTY_FRSTART" "Custom")" "X"
							elif grep -q "$STLSHM" <<< "$SRCEVSC" ; then
								notiShow "$(strFix "$NOTY_FRSTART" "Live")" "X"
							else
								notiShow "$(strFix "$NOTY_FRSTART" "Regular")" "X"
							fi

							runEvacInstall "$EARLYPROT"
							SRCADDONEVSC="$EVMETAADDONID/$EVSC"
							if [ -f "$SRCADDONEVSC" ]; then
								writelog "INFO" "${FUNCNAME[0]} - Found additional install script in '$SRCADDONEVSC'" "X" "$ISCRILOG"

								DSTEVSC="$STEAM_COMPAT_CLIENT_INSTALL_PATH/$EVSC"
								createModifiedEvalsc "$SRCADDONEVSC" "$DSTEVSC"
								notiShow "$(strFix "$NOTY_FRSTART" "Addon")" "X"
								runEvacInstall "$EARLYPROT"
							fi

							if [ "$SRCEVSC" == "$TEVALSC" ]; then
								rm "$TEVALSC" 2>/dev/null
								writelog "INFO" "${FUNCNAME[0]} - Removed temporary '$TEVALSC'" "X" "$ISCRILOG"
							fi

							writelog "INFO" "${FUNCNAME[0]} - '$EVALSC' - STOP - '$EARLYPROT run $ISCEXE $EVSC'" "X" "$ISCRILOG"
						else
							writelog "INFO" "${FUNCNAME[0]} - '$EVALSC' - SKIP - '$SRCEVSC' not found" "X" "$ISCRILOG"
						fi
					# filter get-current-step command - this only updates the steam install gui process.
					elif grep -q "$GECUST" <<< "$@"; then
						"$EARLYPROT" "$@" | tee "$FRSTATE" | tee -a "$ISCRILOG"
						echo "" >> "$ISCRILOG"
						STINFO="$(date +%H:%M:%S) $NICEPROGNAME running"
						if [ -f "$TEVSC" ]; then
							# shellcheck disable=SC1003
							while read -r COMRED; do
								if "$PGREP" -a "" | grep "$STEWOS" | grep -v "runasadmin" | grep "${COMRED//\"}" >/dev/null ; then
										writelog "INFO" "${FUNCNAME[0]} - Installation of '${COMRED//\"}' running" | tee -a "$ISCRILOG"
									STINFO="$(date +%H:%M:%S) $NICEPROGNAME sees ${COMRED//\"}"
									break
								fi
							done <<< "$(grep "process 1" "$TEVSC" | awk -F'\\' '{print $NF}')"
						fi
						printf '\n%s\n' "$STINFO"	# heh, hello Steam Gui
					# should not happen, but better log it anyway just in case:
					else
						writelog "SKIP" "${FUNCNAME[0]} - Skipping '$ISCRI' command '$*' - Neither '$EVALSC' nor '$GECUST' found in command exiting" "X" "$ISCRILOG"
					fi
			else
				if ! grep -q "$GECUST" <<< "$@"; then
					writelog "SKIP" "${FUNCNAME[0]} - No usable Proton version found - ignoring '$ISCRI' command '$*' - Exiting" "X" "$ISCRILOG"
				fi
			fi
		else
			if [ -d "$GPFX" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - Skipping '$ISCRI' command '$*', because '$GPFX' already exists - Exiting" "X" "$ISCRILOG"
			elif [ -f "$EVMETAID/$EVSC" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - Skipping '$ISCRI' command '$*', because '$EVMETAID/$EVSC' already exists - Exiting" "X" "$ISCRILOG"
			fi
		fi
	fi
}

function verbRun {
	VERBLOG="$STLSHM/${PROGNAME,,}-VERB-${STEAM_COMPAT_APP_ID}.log"
	GPFX="$STEAM_COMPAT_DATA_PATH/pfx"
	SCCILECO="$STEAM_COMPAT_CLIENT_INSTALL_PATH/$LECO"
	EVALPROTCONF="$STLSHM/evalprot-${STEAM_COMPAT_APP_ID}.conf"

	writelog "INFO" "${FUNCNAME[0]} - 'verb' command detected '${*}'" "X" "$VERBLOG"
	writelog "INFO" "${FUNCNAME[0]} - Settings variable SteamAppId to '$STEAM_COMPAT_APP_ID' to make verb command happy"
	export SteamAppId="$STEAM_COMPAT_APP_ID"

	# first check if the game has a ${PROGNAME,,} config and use the corresponding proton version:
	if [ -z "$EARLYPROT" ] && [ -f "$STLGAMEDIRID/$STEAM_COMPAT_APP_ID.conf" ]; then
		findEarlyProt "$STLGAMEDIRID/$STEAM_COMPAT_APP_ID.conf" "$VERBLOG"
	fi
	# as fallback check if the game template ${PROGNAME,,} config has a usable proton version:
	if [ -z "$EARLYPROT" ] && [ -f "$STLDEFGAMECFG" ]; then
		findEarlyProt "$STLDEFGAMECFG" "$VERBLOG"
	fi

	# if everything else failed, check for a "static proton version" just for the base install - either from file or from system variable:
	if [ -z "$EARLYPROT" ] && [ -f "$STLEARLYPROTCONF" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Trying to get a proton version from '$STLEARLYPROTCONF'" "X" "$VERBLOG"
		source "$STLEARLYPROTCONF"
	fi

	# fallback if for whatever reason USEPROTON is empty everywhere - trying to get NOP
	if [ -z "$EARLYPROT" ]; then
		if [ -z "$SUSDA" ]; then
			setSteamPaths
		fi
		writelog "INFO" "${FUNCNAME[0]} - Last try - trying to get Newest Official Proton" "X" "$VERBLOG"
		CONFPROT="$(getDefaultProton)"
		createProtonList
		if [ -n "$CONFPROT" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Picking '^${CONFPROT}' from '$PROTONCSV'" "X" "$VERBLOG"
			EARLYPROT="$(grep "^${CONFPROT}" "$PROTONCSV" | cut -d ';' -f2)"
		else
			writelog "WARN" "${FUNCNAME[0]} - Could not determine default Proton" "X" "$VERBLOG"
		fi
	fi

	# write found protonversion into temp config, so below GECUST runs can use it as well:
	if [ -f "$EARLYPROT" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Running verb command '${*}' using proton '$EARLYPROT'" "X" "$VERBLOG"
		"$EARLYPROT" "$WFEAR" "$@" >> "$VERBLOG" 2>&1
	else
		writelog "INFO" "${FUNCNAME[0]} - Skipping verb command '${*}', because no usable proton '$EARLYPROT' was found" "X" "$VERBLOG"
	fi
}

function getCurrentCommandline {
	echo "$@" >> "${STLSHM}/cmdline.txt"
	# filter $ISCRI commands
	if grep -q "$ISCRI" <<< "$@"; then
		while read -r IARG; do
			mapfile -t -O "${#ISCRICMD[@]}" ISCRICMD <<< "$IARG"
		done <<< "$(printf "%s\n" "$@")"
		if [ "${ISCRICMD[0]}" == "%verb%" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Cutting '%verb%' from arguments '${*}'" "P"
			ISCRICMD=( "${ISCRICMD[@]:1}" )
		fi
		writelog "INFO" "${FUNCNAME[0]} - Running checkFirstTimeRun with arguments '${ISCRICMD[*]}'" "P"
		checkFirstTimeRun "${ISCRICMD[@]}"
	elif grep -q "%verb%" <<< "$@"; then
		echo "${FUNCNAME[0]} - Found '%verb%' in the command line '${*}'" >> "$STLSHM/DEBUG-verb.txt"
		while read -r IARG; do
			IARG="${IARG//steamservice.exe/SteamService.exe}"
			mapfile -t -O "${#VERBCMD[@]}" VERBCMD <<< "$IARG"
		done <<< "$(printf "%s\n" "$@")"
		VERBCMD=( "${VERBCMD[@]:1}" )
		echo "${FUNCNAME[0]} - Executing 'verb' command '${VERBCMD[*]}' through verbRun" >> "$STLSHM/DEBUG-verb.txt"
		verbRun "${VERBCMD[@]}" # >> "$STLSHM/DEBUG-verb.txt" 2>&1
		exit
	else
		INPROSTR="proton $WFEAR"
		if grep -q "$INPROSTR" <<< "$@"; then
			HAVEINPROTON=1
			writelog "INFO" "${FUNCNAME[0]} - Found Proton in command line arguments '${*}'" "P"
		else
			HAVEINPROTON=0
			writelog "INFO" "${FUNCNAME[0]} - No Proton in command line arguments '${*}'" "P"
		fi
	fi
}

function initShmStl {  # TODO can shorten?
	mkProjDir "$MTEMP"
	SHMVERS="$STLSHM/version"

	if [ -f "$SHMVERS" ]; then
		if [ "$PROGVERS" != "$(cat "$SHMVERS")" ]; then
			mv "${STLSHM}" "${STLSHM}-$((100 + RANDOM % 100))"
			mkProjDir "$MTEMP"
			echo "$PROGVERS" > "$SHMVERS"
		fi
	else
		echo "$PROGVERS" > "$SHMVERS"
	fi
}

### STEAM DECK BEGIN

