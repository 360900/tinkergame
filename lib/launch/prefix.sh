#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function symlinkSteamUser {

	SteamUserDir="$GPFX/$DRCU/$STUS"
	PublicUserDir="$GPFX/$DRCU/$PUBUS"

	if [ "$1" -eq 1 ]; then
		mkProjDir "$STLPROTSTUSDIR"
		mkProjDir "$STLPROTPUBUSDIR"

		if [ "$USEGLOBSUSYM" -eq 1 ]; then
			SUSYD="$STLPROTSTUSDIR/global"
            PUBUSYD="$STLPROTPUBUSDIR/global"

		else
			SUSYD="$STLPROTSTUSDIR/$AID"
            PUBUSYD="$STLPROTPUBUSDIR/$AID"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Testing if creating a symlink '$SteamUserDir' pointing to '$SUSYD' is required"

		if [ ! -d "$SUSYD" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$SUSYD' does not yet exists"
			if [ -d "$SteamUserDir" ]; then
				mv "$SteamUserDir" "$SUSYD"
			else
				mkProjDir "$SUSYD"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - '$SUSYD' does already exists"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Testing if creating a symlink '$PublicUserDir' pointing to '$PUBUSYD' is required"

		if [ ! -d "$PUBUSYD" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$PUBUSYD' does not yet exists"
			if [ -d "$PublicUserDir" ]; then
				mv "$PublicUserDir" "$PUBUSYD"
			else
				mkProjDir "$PUBUSYD"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - '$PUBUSYD' does already exists"
		fi


		if [ -L "$SteamUserDir" ]; then
			if [ "$(readlink "$SteamUserDir")" == "$SUSYD" ]; then
				writelog "INFO" "${FUNCNAME[0]} - '$SteamUserDir' is already a symlink pointing to '$SUSYD' - nothing to do"
			else
				writelog "INFO" "${FUNCNAME[0]} - '$SteamUserDir' is already a symlink pointing to the unexpected directory '$(readlink "$SteamUserDir")' instead of '$SUSYD' - nothing to do"
			fi
		else
			if [ -d "$SteamUserDir" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Syncing files from '$SteamUserDir' to '$SUSYD'"
				"$RSYNC" -amu "$SteamUserDir" "$SUSYD"
				BACKSUD="${SteamUserDir}_${PROGNAME,,}_$((900 + RANDOM % 100))"
				mv "$SteamUserDir" "$BACKSUD"
				writelog "INFO" "${FUNCNAME[0]} - Backing up '$SteamUserDir' to '$BACKSUD'"
			fi

			if [ ! -d "$SteamUserDir" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Creating '$SteamUserDir' symlink pointing to '$SUSYD' using command:"
				writelog "INFO" "${FUNCNAME[0]} - 'ln -s \"$SUSYD\" \"$SteamUserDir\"'"

				ln -s "$SUSYD" "$SteamUserDir"
			else
				writelog "SKIP" "${FUNCNAME[0]} - '$SteamUserDir' still exists - can't create a symlink pointing to '$SUSYD'"
			fi
		fi

        # Symlinking Public user directory

		if [ -L "$PublicUserDir" ]; then
			if [ "$(readlink "$PublicUserDir")" == "$PUBUSYD" ]; then
				writelog "INFO" "${FUNCNAME[0]} - '$PublicUserDir' is already a symlink pointing to '$PUBUSYD' - nothing to do"
			else
				writelog "INFO" "${FUNCNAME[0]} - '$PublicUserDir' is already a symlink pointing to the unexpected directory '$(readlink "$PublicUserDir")' instead of '$PUBUSYD' - nothing to do"
			fi
		else
			if [ -d "$PublicUserDir" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Syncing files from '$PublicUserDir' to '$PUBUSYD'"
				"$RSYNC" -amu "$PublicUserDir" "$PUBUSYD"
				BACKSUD="${PublicUserDir}_${PROGNAME,,}_$((900 + RANDOM % 100))"
				mv "$PublicUserDir" "$BACKSUD"
				writelog "INFO" "${FUNCNAME[0]} - Backing up '$PublicUserDir' to '$BACKSUD'"
			fi

			if [ ! -d "$PublicUserDir" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Creating '$PublicUserDir' symlink pointing to '$PUBUSYD' using command:"
				writelog "INFO" "${FUNCNAME[0]} - 'ln -s \"$PUBUSYD\" \"$PublicUserDir\"'"

				ln -s "$PUBUSYD" "$PublicUserDir"
			else
				writelog "SKIP" "${FUNCNAME[0]} - '$PublicUserDir' still exists - can't create a symlink pointing to '$PUBUSYD'"
			fi
		fi

		if [ "$(readlink "$SteamUserDir")" == "$SUSYD" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Pulling files from backup if existing and '$SteamUserDir' is empty and a symlink to '$SUSYD'"
			restoreSteamUser "restore-if-dst-is-empty"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Symlinking $STUS is disabled - Checking if a symlink needs to be reverted"

		if [ -L "$SteamUserDir" ]; then
			SUSYD="$(readlink "$SteamUserDir")"
			writelog "INFO" "${FUNCNAME[0]} - '$SteamUserDir' points to '$SUSYD'"
			if [ -d "$SUSYD" ]; then
				rm "$SteamUserDir"
				mkProjDir "$SteamUserDir"
				if grep -q "$AID" <<< "$SUSYD"; then
					writelog "INFO" "${FUNCNAME[0]} - The directory '$SUSYD' where the symlink '$SteamUserDir' points to is game specific - "
					writelog "INFO" "${FUNCNAME[0]} - Migrating all files into the freshly created '$SteamUserDir' from it"
					"$RSYNC" -amu "$SUSYD" "$SteamUserDir"
				else
					writelog "INFO" "${FUNCNAME[0]} - The directory '$SUSYD' where the symlink '$SteamUserDir' points to is not game specific - "
					writelog "INFO" "${FUNCNAME[0]} - Not migrating any files into the freshly created '$SteamUserDir' from it - "
					writelog "INFO" "${FUNCNAME[0]} - Pulling files from backup if existing instead"
					restoreSteamUser "restore-if-dst-is-empty"
				fi
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - '$SteamUserDir' is no symlink - nothing to do"
		fi
	fi
}

function redirectSCDP {
	function checkCompatdataSteamUser {
		if [ "$REDIRSTEAMUSER" == "symlink" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Checking creation of a '$STUS' symlink, as REDIRSTEAMUSER is '$REDIRSTEAMUSER'"
			symlinkSteamUser 1
		elif [ "$REDIRSTEAMUSER" == "restore-backup" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Calling restoreSteamUser to migrate '$STUS', as REDIRSTEAMUSER is '$REDIRSTEAMUSER'"
			restoreSteamUser
		else
			writelog "INFO" "${FUNCNAME[0]} - Leaving '$STUS' directory untouched, as REDIRSTEAMUSER is '$REDIRSTEAMUSER'"
		fi
	}

	function SetCompatdataSymlink {
		DIR="$1"
		SYM="$2"
		writelog "INFO" "${FUNCNAME[0]} - Using '$DIR' as new $CODA dir and '$SYM' as symlink pointing to it"

		if [ ! -f "${DIR}/version" ]; then
			writelog "INFO" "${FUNCNAME[0]} - New $CODA '$DIR' does not exist yet"
			if [ -d "${STEAM_COMPAT_DATA_PATH}_SAC" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Moving found backed autocloud $CODA '${STEAM_COMPAT_DATA_PATH}_SAC' to '$DIR'"
				mkProjDir "${DIR%/*}"
				mv "${STEAM_COMPAT_DATA_PATH}_SAC" "$DIR"
			else
				writelog "INFO" "${FUNCNAME[0]} - Creating new $CODA dir '$DIR'"
				mkProjDir "$DIR"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - Using existing $CODA '$DIR'"
			if [ -d "${STEAM_COMPAT_DATA_PATH}_SAC" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found backed autocloud $CODA '${STEAM_COMPAT_DATA_PATH}_SAC'"
			fi
		fi

		if [ -L "$SYM" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Removing old symlink '$SYM'"
			rm "$SYM" 2>/dev/null #remove old symlink
		elif [ -d "$SYM" ]; then
			BACKSCDP="${SYM}-BAK$((100 + RANDOM % 100))"
			writelog "WARN" "${FUNCNAME[0]} - '$SYM' does still exist as directory - renaming to '$BACKSCDP'"
			mv "$SYM" "$BACKSCDP"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Creating symlink via 'ln -s \"$DIR\" \"$SYM\"'"
		ln -s "$DIR" "$SYM"
		notiShow "$(strFix "$NOTY_GLOBALTWEAK" "$DIR")"

		SPVF="$STEAM_COMPAT_DATA_PATH/${SHOSTL}-version"
		if [ ! -f "$SPVF" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Creating '$SPVF' with version '$DESTPROT'"
			echo "$DESTPROT" > "$SPVF"
		else
			SCDPSPV="$(cat "$SPVF")"
			if [ "$SCDPSPV" == "$DESTPROT" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found '$SPVF' with version '$DESTPROT'"
			else
				writelog "INFO" "${FUNCNAME[0]} - Proton version '$SCDPSPV' in '$SPVF' doesn't match expected version '$DESTPROT' DEBUG"
			fi
		fi

		if [ "$REDIRCOMPDATA" == "global-proton" ]; then
			UBAID="${STEAM_COMPAT_DATA_PATH}/used_by-$AID"
			if [ ! -f "$UBAID" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Creating '$UBAID'" # and trying to trigger Steam First Time Setup"
				touch "$UBAID"
			fi
		fi

		checkCompatdataSteamUser
	}

	function checkCompatdataSymlink {
		if [ -L "$STEAM_COMPAT_DATA_PATH" ] || [ -d "$STEAM_COMPAT_DATA_PATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using $CODA '$REDIRCOMPDATA' mode"

			PVF="$STEAM_COMPAT_DATA_PATH/version"
			SCDPPV="$(cat "$PVF")"

			SPVF="$STEAM_COMPAT_DATA_PATH/${PROGNAME,,}-version"
			SCDPSPV="$(cat "$SPVF")"

			if [ -f "$SPVF" ]; then
				if [ "$SCDPSPV" == "$DESTPROT" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Proton version '$SCDPSPV' in '$SPVF' matches expected version '$DESTPROT' (allowing minor version mismatch)"
					CDPVOK=1
				else
					writelog "INFO" "${FUNCNAME[0]} - Proton version '$SCDPSPV' in '$SPVF' is not the expected version '$DESTPROT'"
					CDPVOK=0
				fi
			else
				if [ ! -f "$PVF" ] && [ -d "$STEAM_COMPAT_DATA_PATH" ]; then
					writelog "INFO" "${FUNCNAME[0]} - STEAM_COMPAT_DATA_PATH doesn't have a proton version file '$PVF'"
					writelog "INFO" "${FUNCNAME[0]} - Steam probably just re-created the $CODA by creating the steam_autocloud.vdf"
					writelog "INFO" "${FUNCNAME[0]} - Moving the $CODA out of the way"
					mv "$STEAM_COMPAT_DATA_PATH" "${STEAM_COMPAT_DATA_PATH}_SAC"
					SCDPPV=0
				elif [ ! -f "$PVF" ] && [ -L "$STEAM_COMPAT_DATA_PATH" ]; then
					writelog "INFO" "${FUNCNAME[0]} - STEAM_COMPAT_DATA_PATH is a symlink - it should have a '$PVF' though - $(ls -la "$PVF") DEBUG"
					SCDPPV=0
				fi

				if [ "$SCDPPV" == "$DESTPROT" ] || [ "$SCDPPV" == "${ORGUSEPROTON//proton-}" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Proton in $CODA '$STEAM_COMPAT_DATA_PATH' matches the expected version '$DESTPROT' (allowing minor version mismatch)"
					CDPVOK=1
				else
					writelog "INFO" "${FUNCNAME[0]} - Proton in $CODA '$STEAM_COMPAT_DATA_PATH' has not the expected version '$DESTPROT' but '$SCDPPV'"
					CDPVOK=0
				fi
			fi
		fi

		if [ -L "$STEAM_COMPAT_DATA_PATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$STEAM_COMPAT_DATA_PATH' is already a symbolic link - comparing versions"

			if [ "$(readlink "$STEAM_COMPAT_DATA_PATH")" == "$DESTCOMPDATA" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Symlink '$STEAM_COMPAT_DATA_PATH' points correctly to the expected directory '$DESTCOMPDATA'"
				CDSYMOK=1
			else
				writelog "WARN" "${FUNCNAME[0]} - Symlink '$STEAM_COMPAT_DATA_PATH' does not point correctly to the expected directory '$DESTCOMPDATA', but instead to '$(readlink "$STEAM_COMPAT_DATA_PATH")'"
				CDSYMOK=0
			fi

			if [ "$CDSYMOK" -eq 1 ] && [ "$CDPVOK" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Both $CODA symlink '$STEAM_COMPAT_DATA_PATH' and Proton version are correct - nothing to do here"
			elif [ "$CDSYMOK" -eq 1 ] && [ "$CDPVOK" -eq 0 ]; then
				writelog "INFO" "${FUNCNAME[0]} - $CODA symlink '$STEAM_COMPAT_DATA_PATH' is correct, but Proton version is not - this is unusual but continuing anyway"
			elif [ "$CDSYMOK" -eq 0 ] && [ "$CDPVOK" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - $CODA symlink '$STEAM_COMPAT_DATA_PATH' is not the expected one, but Proton version matches - assuming manual configuration from the user and using it"
			elif [ "$CDSYMOK" -eq 0 ] && [ "$CDPVOK" -eq 0 ]; then
				writelog "INFO" "${FUNCNAME[0]} - $CODA symlink '$STEAM_COMPAT_DATA_PATH' is not the expected one and Proton version doesn't match as well, assuming the Proton version was changed - redirecting $CODA to '$DESTCOMPDATA'"
				SetCompatdataSymlink "$DESTCOMPDATA" "$STEAM_COMPAT_DATA_PATH"
			fi
		elif [ -d "$STEAM_COMPAT_DATA_PATH" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$STEAM_COMPAT_DATA_PATH' is the original directory"
			if [ -d "$DESTCOMPDATA" ]; then # probably not worth to check the proton version in $DESTCOMPDATA here as well(?)
				BACKSCDP="${STEAM_COMPAT_DATA_PATH}-BAK$((100 + RANDOM % 100))"
				writelog "INFO" "${FUNCNAME[0]} - '$DESTCOMPDATA' does already exist - moving '$STEAM_COMPAT_DATA_PATH' to '$BACKSCDP' and setting symlink"
				mv "$STEAM_COMPAT_DATA_PATH" "$BACKSCDP"
				SetCompatdataSymlink "$DESTCOMPDATA" "$STEAM_COMPAT_DATA_PATH"
			else
				if [ "$CDPVOK" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - '$DESTCOMPDATA' does not yet exist, moving '$STEAM_COMPAT_DATA_PATH' as the Proton version is correct and creating symlink"
					mv "$STEAM_COMPAT_DATA_PATH" "$DESTCOMPDATA"
					SetCompatdataSymlink "$DESTCOMPDATA" "$STEAM_COMPAT_DATA_PATH"
				else
					writelog "INFO" "${FUNCNAME[0]} - '$DESTCOMPDATA' does not yet exist, creating a new one, because '$STEAM_COMPAT_DATA_PATH' uses an incorrect Proton version"
					BACKSCDP="${STEAM_COMPAT_DATA_PATH}-BAK$((100 + RANDOM % 100))"
					writelog "INFO" "${FUNCNAME[0]} - Renaming '$STEAM_COMPAT_DATA_PATH' to '$BACKSCDP' and setting symlink"
					mv "$STEAM_COMPAT_DATA_PATH" "$BACKSCDP"
					SetCompatdataSymlink "$DESTCOMPDATA" "$STEAM_COMPAT_DATA_PATH"
				fi
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - '$STEAM_COMPAT_DATA_PATH' is neither a directory nor a symbolic link - creating it"
			SetCompatdataSymlink "$DESTCOMPDATA" "$STEAM_COMPAT_DATA_PATH"
		fi
	}

	function fixDestCompat {
		DESTCOMPDATA2="${DESTCOMPDATA//--/-}"
		if [ -d "$DESTCOMPDATA" ] && [ ! -d "$DESTCOMPDATA2" ] && [ "$DESTCOMPDATA" != "$DESTCOMPDATA2" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Renaming old '${DESTCOMPDATA##*/}' to '${DESTCOMPDATA2##*/}'"
			mv "$DESTCOMPDATA" "$DESTCOMPDATA2"
			DESTCOMPDATA="$DESTCOMPDATA2"
		fi
	}

	## There is room for improvement here, community contributions welcome!
	if [ -n "$STEAM_COMPAT_DATA_PATH" ]; then # should be enough
		VERSPROTMAJOR="$( printf '%s' "${USEPROTON}" | sed -e 's/-\(rc\|beta\)[0-9]\+$//' \
															-e 's/-[0-9A-Za-z_]\+$//' )"
		# Above first removes -beta# and -rc# from Proton names. Then turns the Proton name from "proton-8.0-3c" to "proton-8.0"
		VERSFIX="$(grep "${PROTVERSNOMINOR}" "$PROTONCSV" | cut -d ';' -f1 | sort -nr | head -n1)"

		if [ "${ONLYPROTMAJORREDIRECT}" -eq 1 ]; then  # Only create redirect folders for major Proton version bumps, such as GE-Proton7 -> GE-Proton8, or Proton 7.0 -> Proton 8.0 (IGNORING minor fix versions)
			DESTPROT1="${VERSPROTMAJOR//proton-}"
			writelog "INFO" "${FUNCNAME[0]} - Using major Proton version without minor version fix '$DESTPROT1' for $CODA directory name, because ONLYPROTMAJORREDIRECT is '$ONLYPROTMAJORREDIRECT'"
		elif [ -n "$VERSFIX" ]; then  # Create a compat directory lile 'proton-8.0-3c', WITH the minor fix version
			DESTPROT1="${VERSFIX//proton-}"
			writelog "INFO" "${FUNCNAME[0]} - Using Proton version with minor version fix '$DESTPROT1' for $CODA directory name"
		else  # ???
			DESTPROT1="${USEPROTON//proton-}"
			writelog "INFO" "${FUNCNAME[0]} - Using Proton version '$DESTPROT1' for '$CODA' directory name"
		fi

		DESTPROT="${DESTPROT1//Proton}"
		# above might have to be expanded later, depending on proton names

		if [ "$REDIRCOMPDATA" == "single-proton" ]; then
			DESTCOMPDATA="${STEAM_COMPAT_DATA_PATH//${STEAM_COMPAT_DATA_PATH##*/}/${PROGNAME,,}\/${STEAM_COMPAT_DATA_PATH##*/}-proton-${DESTPROT}}"
			fixDestCompat
			checkCompatdataSymlink
		elif [ "$REDIRCOMPDATA" == "global-proton" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using global 'STEAM_COMPAT_DATA_PATH'"
			DESTCOMPDATA="$STLPROTCOMPDATDIR/${CODA}-proton-${DESTPROT}"
			fixDestCompat
			checkCompatdataSymlink
		else
			writelog "INFO" "${FUNCNAME[0]} - Using regular $CODA '$STEAM_COMPAT_DATA_PATH'"
			if [ -L "$STEAM_COMPAT_DATA_PATH" ]; then
				if [ -f "${STEAM_COMPAT_DATA_PATH}/used_by-$AID" ]; then
					rm "${STEAM_COMPAT_DATA_PATH}/used_by-$AID" 2>/dev/null
					writelog "INFO" "${FUNCNAME[0]} - '$STEAM_COMPAT_DATA_PATH' is a symlink. Removing it, as REDIRCOMPDATA is $REDIRCOMPDATA"
					rm "$STEAM_COMPAT_DATA_PATH"
					mkProjDir "$STEAM_COMPAT_DATA_PATH"
				else
					# See STL issue #692 for background on the above removing logic removing valid user prefixes
					writelog "INFO" "${FUNCNAME[0]} - '$STEAM_COMPAT_DATA_PATH' is a symlink, but we don't have a 'used_by-$AID' file in this game's prefix -- Assuming this is a user-created symlink and not removing"
					writelog "INFO" "${FUNCNAME[0]} - User-created symlinks are valid on Steam Deck to work around some Steam Client bugs"
				fi
			fi
		fi
	fi
}

function launchIGCS {
	IGCSPROCESS="$(grep "^Process=" "$IGCSINI" | cut -d '=' -f2)"
	writelog "INFO" "${FUNCNAME[0]} - Injecting '$IGCSDLL' into exe '${IGCSPROCESS%.*}' using '$IGCS'"
	writelog "INFO" "${FUNCNAME[0]} - IGCSDST '$IGCSDST'"
	rm "$IGCSINITLOCK" 2>/dev/null
	extProtonRun "R" "$IGCSDST"
}

function injectIGCS {
	writelog "INFO" "${FUNCNAME[0]} - Starting '$IGCS'"
	waitForGamePid
	writelog "INFO" "${FUNCNAME[0]} - Game is running, starting '$IGCS' in '$IGCSWAIT' seconds"
	touch "$IGCSINITLOCK"
	sleep "$IGCSWAIT"
	launchIGCS
}

function postIGCS {
	COUNTER=0

	while [ ! -f "$IGCSINITLOCK" ]; do
		writelog "INFO" "${FUNCNAME[0]} - Waiting for $IGCSINITLOCK to appear"
		if [ -f "$CLOSETMP" ] || [[ "$COUNTER" -ge "$IGCSWAIT" ]]; then
			break
		fi
		COUNTER=$((COUNTER+1))
		sleep 1
	done

	writelog "INFO" "${FUNCNAME[0]} - Waited '$COUNTER/$IGCSWAIT' seconds"

	IGCSWAITLEFT=$((IGCSWAIT - COUNTER + 2))
	writelog "INFO" "${FUNCNAME[0]} - Waiting (max $IGCSWAITLEFT more seconds) for $IGCS to initialize"
	COUNTER=0

	while [ -f "$IGCSINITLOCK" ]; do
		if [ -f "$CLOSETMP" ] || [[ "$COUNTER" -ge "$IGCSWAITLEFT" ]]; then
			break
		fi
		COUNTER=$((COUNTER+1))
		sleep 1
	done

	COUNTER=0
	if [ -f "$IGCSINITLOCK" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Lock file $IGCSINITLOCK still exists - giving up"
	else
		COUNTER=0
		WAITWIN=3
		writelog "INFO" "${FUNCNAME[0]} - $IGCS just started, now waiting a bit for its window"

		IGCSWIN="$("$XDO" search --name "$IGCS")"
		# use if $IGCS alone also matches games window:
		# IGCSWIN="$("$XDO" search --name "$SA.*.$IGCS")" # =+ steamapps
		while ! [ "$IGCSWIN" -eq "$IGCSWIN" ] 2>/dev/null; do
			if [[ "$COUNTER" -ge "$WAITWIN" ]]; then
				break
			fi
			COUNTER=$((COUNTER+1))
			sleep 1
		done

		writelog "INFO" "${FUNCNAME[0]} - Closing '$IGCS' window '$IGCSWIN'"
		"$XDO" windowactivate --sync "$IGCSWIN"	key "KP_Enter"

		writelog "INFO" "${FUNCNAME[0]} - And minimize false-positive UUU warn window"
		IGCSPROCESS="$(grep "^Process=" "$IGCSINI" | cut -d '=' -f2)"
		"$XDO" windowminimize "$("$XDO" search --name "${IGCSPROCESS%.*}")"

		if [ -f "$GWXTEMP" ]; then
			WIFO="$(cat "$GWXTEMP")"
			writelog "INFO" "${FUNCNAME[0]} - Setting focus on window '$WIFO'"
			"$XDO" windowactivate "$WIFO"
		else
			writelog "INFO" "${FUNCNAME[0]} - No '$GWXTEMP' found"
		fi
	fi
}

function selectIGCSdll {
	if [ -d "$EFD" ]; then
		fixShowGnAid
		export CURWIKI="$PPW/$IGCS"
		TITLE="${PROGNAME}-Select-IGCS-dll"
		pollWinRes "$TITLE"
		setShowPic

		PICKIGCSDLL="$("$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--separator="" --title="$TITLE" \
		--text="$(spanFont "$SGNAID - $GUI_SELECTIGCSDLL" "H")" \
		--field=" ":LBL " " \
		--field="$GUI_SELECTDLL":FL "${EFD}" --file-filter="$GUI_DLLFILES (*.dll)| *.dll" "$GEOM")"
		if [ -f "$PICKIGCSDLL" ]; then
			IGCSDLL="${PICKIGCSDLL##*/}"
			if [ ! -f "$EFD/$IGCSDLL" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Copying selected dll '$PICKIGCSDLL' to '$EFD'"
				cp "$PICKIGCSDLL" "$EFD"
			fi
			IGCSINI="$EFD/${IGCS}.ini"
			writelog "INFO" "${FUNCNAME[0]} - Inserting '$IGCSDLL' into '$IGCSINI'"
			sed "/^Dll=/d" -i "$IGCSINI"
			echo "Dll=$IGCSDLL" >> "$IGCSINI"
		else
			writelog "SKIP" "${FUNCNAME[0]} - No dll selected - skipping"
		fi
	fi
}

function createUUUPatchCommand {
	echo "$XDO windowactivate \"GAMEWINXID\" && sleep 1 && $XDO key \"grave\" && $XDO type \"exec $UUUPATCH\" && $XDO key \"KP_Enter\"" > "$UUUPATCHCOMMAND"
	chmod +x "$UUUPATCHCOMMAND"
}

function getGameWXID {
	if [ -n "$VRPGWINXIS" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using found variable VRPGWINXIS '$VRPGWINXIS' as GAMEWINXID"
		GAMEWINXID="$VRPGWINXIS"
	fi

	if [ -n "$GAMEWINXID" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Already have the windowid '$GAMEWINXID'"
	else
		GAMEWINPID="$(getGameWindowPID)"
		writelog "INFO" "${FUNCNAME[0]} - Determining GAMEWINXID via GAMEWINPID '$GAMEWINPID'"
		GAMEWINXID="$(getGameWinXIDFromPid "$GAMEWINPID")"
 	fi

	if [ -n "$GAMEWINXID" ]; then
		export VRPGWINXIS="$GAMEWINXID"
	fi
}

function injectUUUPatch {
	if [ "$(find "$EFD" -name "$UUUPATCH" | wc -l)" -ge 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - starting UUU patch command auto executing '$UUUPATCH'"
		waitForGamePid
		getGameWXID

		if [ -n "$GAMEWINXID" ]; then
			echo "$GAMEWINXID" > "$GWXTEMP"

			sed "s:GAMEWINXID:$GAMEWINXID:g" -i "$UUUPATCHCOMMAND"
			writelog "INFO" "${FUNCNAME[0]} - starting patch command auto executing '$UUUPATCH'"

			if [ "$UUUPATCHWAIT" -ge 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Game is running, starting UUU patch command '$UUUPATCHCOMMAND' in '$UUUPATCHWAIT' seconds"
				if [ ! -f "$TRAYCUSC" ] || grep -q "$UUUPATCH" "$TRAYCUSC"; then
					cp "$UUUPATCHCOMMAND" "$TRAYCUSC"
				fi
				sleep "$UUUPATCHWAIT"
				"$UUUPATCHCOMMAND"
			else
				writelog "INFO" "${FUNCNAME[0]} - UUUPATCHWAIT is '$UUUPATCHWAIT', so placing the UUU patch command behind the TrayIcon command '$TRAY_LCS' for manual execution"
				cp "$UUUPATCHCOMMAND" "$TRAYCUSC"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - game window id could not be found - can't start the UUU patch command"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - UE4 console script '$UUUPATCH' not found in game directory '$EFD'"
	fi
}

function checkUUUPatchLaunch {
	if [ "$UUUSEPATCH" -eq 1 ] || [ "$UUUSEVR" -eq 1 ]; then
		createUUUPatchCommand
		injectUUUPatch &
	fi
}

function prepareUEVRpatch {
	if [ "$UUUSEVR" -eq 1 ]; then
		UUUPATCHFILE="$1"

		if [ ! -f "$UUUPATCHFILE" ]; then
			if [ -f "$GLOBALMISCDIR/${UUUPATCH}-${AID}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Copying game specific '$GLOBALMISCDIR/${UUUPATCH}-${AID}' to '$UUUPATCHFILE'"
				cp "$GLOBALMISCDIR/$UUUPATCH-${AID}" "$UUUPATCHFILE"
			elif [ -f "$GLOBALMISCDIR/${UUUPATCH}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Copying generic '$GLOBALMISCDIR/${UUUPATCH}' to '$UUUPATCHFILE'"
				cp "$GLOBALMISCDIR/$UUUPATCH" "$UUUPATCHFILE"
			else
				writelog "WARN" "${FUNCNAME[0]} - No source '$UUUPATCH' file found in '$GLOBALMISCDIR'"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - '$UUUPATCHFILE' already available"
		fi
	fi
}

function checkIGCSInjector {

	if [ "$UUUSEPATCH" -eq 1 ] || [ "$UUUSEVR" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Enabling '$UUU' with '$IGCS' as UUU patch mode is enabled"
		UUUSEIGCS=1
	fi

	if [ "$UUUSEIGCS" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using '$UUU' with '$IGCS' is enabled"
		USEIGCS=1
	fi

	if [ "$USEIGCS" -eq 1 ]; then
		IGCSEXE="${IGCS}.exe"
		IGCSDST="$EFD/$IGCSEXE"
		if [ ! -f "$IGCSDST" ]; then
			writelog "INFO" "${FUNCNAME[0]} - '$IGCSDST' not found"
			IGCSDL="$STLDLDIR/igcs/"
			IGCSSRC="$IGCSDL/$IGCSEXE"
			mkProjDir "$IGCSDL"

			if [ ! -f "$IGCSSRC" ]; then
				IGCSDST="$IGCSDL/${IGCSZIP##*/}"
				if [ ! -f "$IGCSDST" ]; then
					dlCheck "$IGCSZIP" "$IGCSDST" "X" "'$IGCSDST' not found - downloading automatically from '$IGCSZIP'"
				fi
				"$UNZIP" "$IGCSDST" -d "$IGCSDL"
			fi

			if [ -f "$IGCSSRC" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Copying '$IGCSSRC' to '$IGCSDST'"
				cp "$IGCSSRC" "$IGCSDST"
			fi
		else
			writelog "INFO" "${FUNCNAME[0]} - '$IGCSDST' found"
		fi

		if [ -f "$IGCSDST" ]; then
			IGCSINI="$EFD/${IGCS}.ini"
			WSE="$(find "$EFD" -name "*-Win64-Shipping.exe" | head -n1)"

			if [ -n "$WSE" ]; then
				prepareUEVRpatch "${WSE%/*}/../$UUUPATCH"
			fi

			if [ ! -f "$IGCSINI" ]; then
				writelog "INFO" "${FUNCNAME[0]} - '$IGCSINI' not found - creating it"
				echo "[InjectionData]" > "$IGCSINI"
				echo "Process=$GAMEEXE" >> "$IGCSINI"
				if [ "$UUUSEIGCS" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - WSE is '$WSE'"

					if [ -n "$WSE" ]; then
						echo "Process=${WSE##*/}" >> "$IGCSINI"
					else
						echo "Process=$GAMEEXE" >> "$IGCSINI"
					fi
					writelog "INFO" "${FUNCNAME[0]} - Using '${UUU}.dll' as dll in '$IGCSINI'"
					echo "Dll=${UUU}.dll" >> "$IGCSINI"
				else
					echo "Process=$GAMEEXE" >> "$IGCSINI"
				fi
			fi

			IGCSDLL="$(grep "^Dll=" "$IGCSINI" | cut -d '=' -f2)"
			if [ "$UUUSEIGCS" -eq 1 ]; then
				if [ "$IGCSDLL" != "${UUU}.dll" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Updating dll in '$IGCSINI' to '${UUU}.dll' because 'UUUSEIGCS' is enabled"
					sed "/^Dll=/d" -i "$IGCSINI"
					echo "Dll=${UUU}.dll" >> "$IGCSINI"
				fi
			fi

			IGCSDLL="$(grep "^Dll=" "$IGCSINI" | cut -d '=' -f2)"
			if [ ! -f "$EFD/$IGCSDLL" ]; then
				if [ "$UUUSEIGCS" -eq 1 ]; then
					UUUDL="$STLDLDIR/uuu"
					UUUSRC="$UUUDL/$IGCSDLL"
					mkProjDir "$UUUDL"
					writelog "INFO" "${FUNCNAME[0]} - 'UUUSEIGCS' is enabled, but '$EFD/$IGCSDLL' is not available - checking if '$UUUSRC' is available"
					if [ ! -f "$UUUSRC" ]; then
						if [ -x "$(command -v "$XDGO" 2>/dev/null)" ]; then
							writelog "WARN" "${FUNCNAME[0]} - '$UUUSRC' was not found - opening Info requester, because it needs to be downloaded manually from '$UUUURL' and extracted to '$UUUDL'"
							export CURWIKI="$PPW/$UUU"
							TITLE="${PROGNAME}-$UUU-Info"
							pollWinRes "$TITLE"
							setShowPic

							"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
							--title="$TITLE" --text="$(spanFont "$(strFix "$GUI_UUUINFO1" "$UUU")" "H")" \
							--field="Url: :RW" "$UUUURL" \
							--field="$GUI_UUUINFO2:LBL" " " \
							--field="$UUUDL":FBTN "$XDGO $UUUDL" "$GEOM"
						else
							writelog "SKIP" "${FUNCNAME[0]} - '$UUUSRC' was not found, but can't open the Info requester, because '$XDGO' was not found"
						fi
					fi

					if [ -f "$UUUSRC" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Copying '$UUUSRC' to '$EFD'"
						cp "$UUUSRC" "$EFD"
					else
						writelog "SKIP" "${FUNCNAME[0]} -'$UUUSRC' could not be found - skipping"
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - No valid dll found in '$IGCSINI' - Choose one"
					selectIGCSdll
				fi
			fi

			IGCSDLL="$(grep "^Dll=" "$IGCSINI" | cut -d '=' -f2)"
			if [ -f "$EFD/$IGCSDLL" ]; then
				injectIGCS &
				postIGCS &
			else
				writelog "SKIP" "${FUNCNAME[0]} - Still no valid dll found in '$IGCSINI' - giving up"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - '$IGCSDST' not found and could not be created - skipping '$IGCS'"
		fi
	fi
}

function injectCustomProg {
	writelog "INFO" "${FUNCNAME[0]} - 'Injecting' custom command - i.e. starting delayed"
	waitForGamePid
	writelog "INFO" "${FUNCNAME[0]} - Game is running, starting custom command in '$INJECTWAIT' seconds"
	sleep "$INJECTWAIT"
	launchCustomProg
}

function delayGameForCustomLaunch {
	if [ "$USECUSTOMCMD" -eq 1 ] && [ "$FORK_CUSTOMCMD" -eq 1 ] && [ "$ONLY_CUSTOMCMD" -eq 0 ] && [ "$WAITFORCUSTOMCMD" -ge 1 ]; then
		COUNTER=0
		MAXTRY="$WAITFORCUSTOMCMD"

		function CUCOPID {
			"$PGREP" -a "" | grep "${CUSTOMCMD##*/}" | grep "Z:" | grep "\.exe" | grep -v "CrashHandler" | cut -d ' ' -f1 | tail -n1
		}

		function waitforCustomPid {
				while [ -z "$(CUCOPID)" ]; do
					if [[ "$COUNTER" -ge "$MAXTRY" ]]; then
						writelog "SKIP" "${FUNCNAME[0]} - Giving up waiting for custom program pid"
						break
					else
						writelog "WAIT" "${FUNCNAME[0]} - Waiting for custom program process $(CUCOPID)"
						COUNTER=$((COUNTER+1))
						sleep 1
					fi
				done

				if [ -n "$(CUCOPID)" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Custom program process found at $(CUCOPID) after $COUNTER seconds"
				fi
		}

		waitforCustomPid

		if [ "$WAITFORCUSTOMCMD" -gt 1 ]; then
			RESTWAIT=$((WAITFORCUSTOMCMD - COUNTER))
			if [ "$RESTWAIT" -gt 0 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Waiting $RESTWAIT more seconds before proceeding with loading the game"
				sleep "$RESTWAIT"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Nothing to do"
	fi
}

function checkCustomLaunch {
	if [ "$ONLYWICO" -eq 1 ]; then
		# only start $WICO
		writelog "INFO" "${FUNCNAME[0]} - 'ONLYWICO' is enabled - starting only $WICO"
		launchCustomProg "ONLYWICO"
	else
		# start a custom program:
		if [ -n "$USECUSTOMCMD" ] ; then
			if [ "$USECUSTOMCMD" -eq 1 ] ; then
				writelog "INFO" "${FUNCNAME[0]} - USECUSTOMCMD is set to '$USECUSTOMCMD' - trying to start custom program '$CUSTOMCMD'"

				if [ "$INJECT_CUSTOMCMD" -eq 1 ]; then
					injectCustomProg &
				else
					# fork in background and continue
					if [ "$ONLY_CUSTOMCMD" -eq 1 ]; then
						SECONDS=0
					fi

					if [ "$FORK_CUSTOMCMD" -eq 1 ]; then
						writelog "INFO" "${FUNCNAME[0]} - FORK_CUSTOMCMD is set to 1 - forking the custom program in background and continue"
						launchCustomProg
					# or wait
					else
						writelog "INFO" "${FUNCNAME[0]} - FORK_CUSTOMCMD is set to 0 - starting the custom program regularly"
						launchCustomProg
					fi

					if [ "$ONLY_CUSTOMCMD" -eq 1 ]; then
						writelog "INFO" "${FUNCNAME[0]} - ONLY_CUSTOMCMD is set to 1 means only custom program '$CUSTOMCMD' is supposed to start - exiting here"
						duration=$SECONDS
						logPlayTime "$duration"
						writelog "INFO" "${FUNCNAME[0]} - ## CUSTOMCMD STOPPED after '$duration' seconds playtime"
						closeSTL " ######### STOP EARLY $PROGNAME $PROGVERS #########"
						exit
					fi
				fi
			else
				if [ -n "$CUSTOMCMD" ] && [[ ! "$CUSTOMCMD" =~ ${DUMMYBIN}$ ]]; then
					writelog "SKIP" "${FUNCNAME[0]} - USECUSTOMCMD is '$USECUSTOMCMD' therefore skipping the custom program '$CUSTOMCMD'"
				fi
			fi
		fi
	fi
}

function setFWSArch {
	if [ -z "$FWSARCH" ]; then
		FWSARCH="64"
		if [ -n "$GP" ] && [ -f "$GP" ]; then
			if [ "$(getArch "$GP")" == "32" ]; then
				FWSARCH="32"
			fi
		fi
	fi
}

function dlFWS {
	setFWSArch
	mkProjDir "$FWSDLDIR/$FWSARCH"
	DSTFILE="${FWS,,}_x64.zip"

	if [ "$FWSARCH" == "32" ]; then
		DSTFILE="${DSTFILE//_x64}"
		SPAT="86"
	else
		SPAT="64"
	fi
	DLCHK="md5sum"

	INCHK="$("$WGET" -q "${FWSURL%%/fws*}" -O - 2> >(grep -v "SSL_INIT") | grep -A1 "x${SPAT} ZIP Package" | grep MD5 | grep -oP '> \K[^<]+')"
	DLDST="$FWSDLDIR/$FWSARCH/$DSTFILE"

	if [ ! -f "$DLDST" ]; then
		notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$DSTFILE")"
		dlCheck "$FWSURL/$DSTFILE" "$DLDST" "$DLCHK" "Downloading '$DSTFILE'" "$INCHK"
	fi

	FWSEXE="$FWSDLDIR/$FWSARCH/${FWS}.exe"
	if [ ! -f "$FWSEXE" ]; then
		if [ -f "$DLDST" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Extracting $DSTFILE in '$FWSDLDIR/$FWSARCH'"
			"$UNZIP" -q "$DLDST" -d "$FWSDLDIR/$FWSARCH"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Downloading '$FWS' failed! Disabling '$FWS'"
			USEFWS=0
		fi
	fi

	if [ ! -f "$FWSEXE" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Extracting '$FWS' failed! Disabling '$FWS'"
		USEFWS=0
	fi
}

function checkFWS {
	if [ "$USEFWS" -eq 1 ]; then
		dlFWS
		if [ "$USEFWS" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - 'USEFWS' is enabled - starting '$FWS' exe '$FWSEXE'"
			setFWSArch
			writelog "INFO" "${FUNCNAME[0]} - Starting '$FWSEXE' forked into the background"
			restoreOrgVars
			(sleep 5; "$RUNPROTON" run "$FWSEXE") &
			emptyVars "O" "X"
		fi
	fi
}

function togWindows {
	function windowminimize {
		rm "$STLMINWIN" 2>/dev/null
		while read -r WN; do
			WINNAME="${WN##*[[:blank:]]}"
			if "$XPROP" -id "$WINNAME" | grep "_NET_WM_ACTION_MINIMIZE" -q ; then
				if "$XPROP" -id "$WINNAME" | grep "_NET_WM_STATE_HIDDEN" -q ; then
					writelog "SKIP" "${FUNCNAME[1]} ${FUNCNAME[0]} - Skipping minimized '$WINNAME'"
				else
					writelog "INFO" "${FUNCNAME[1]} ${FUNCNAME[0]} - Minimizing '$WINNAME'"
					echo "$WINNAME" >> "$STLMINWIN"
					"$XDO" "${FUNCNAME[0]}" "$WINNAME"
				fi
			fi
		done <<< "$("$XPROP" -root | grep "_NET_CLIENT_LIST(WINDOW)" | cut -d '#' -f2 | tr ',' '\n')"
	}

	function windowraise {
		if [ ! -f "$STLMINWIN" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Skipping, because no minimized window file STLMINWIN found"
		else
			while read -r WN; do
				WINNAME="${WN##*[[:blank:]]}"
				writelog "INFO" "${FUNCNAME[0]} - Raising '$WINNAME'"
				"$XDO" "${FUNCNAME[0]}" "$WINNAME"
				COUNTER=0
				MAXTRY=3
				while grep -q "_NET_WM_STATE_HIDDEN" -q <<< "$("$XPROP" -id "$WINNAME")"; do
					if [[ "$COUNTER" -ge "$MAXTRY" ]]; then
						echo "$WINNAME" >> "${STLMINWIN}_lazy"
						break
					else
						writelog "INFO" "${FUNCNAME[0]} - '$WINNAME' minimized after $COUNTER tries - raising again"
						"$XDO" "${FUNCNAME[0]}" "$WINNAME"
						COUNTER=$((COUNTER+1))
					fi
				done

			done < "$STLMINWIN"

			if [ -f "${STLMINWIN}_lazy" ]; then
				while read -r WN; do
					WINNAME="${WN##*[[:blank:]]}"
					writelog "INFO" "${FUNCNAME[0]} - Raising lazy '$WINNAME'"
					"$XDO" "${FUNCNAME[0]}" "$WINNAME"
				done < "${STLMINWIN}_lazy"
			fi

			rm "$STLMINWIN" "${STLMINWIN}_lazy" 2>/dev/null
		fi
	}

	if [ "$TOGGLEWINDOWS" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Setting windows to $1"
		"$1"
	fi
}

function installWinetricksPaks {
	WTPAKS="$1"
	WTWINE="$2"
	WTRUN="$3"

	WTSHMLOG="$STLSHM/WINETRICKS.log"

	if [ "$WTRUN" == "wineVortexRun" ]; then
		WTPFX="$VORTEXPFX"
	else
		WTPFX="$GPFX"
	fi

	if [ "$USEWINE" -eq 1 ]; then
		 WTPFX="$GWFX"
	fi

	if [ -n "$WTPAKS" ] && [ "$WTPAKS" != "$NON" ] && [ "$WTPAKS" != "0" ]; then
		chooseWinetricks
		mapfile -d " " -t -O "${#INSTPAKS[@]}" INSTPAKS < <(printf '%s' "$WTPAKS")

		WTLOG="$WTPFX/winetricks.log"

		if [ ! -f "$WTLOG" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Installing '$WTPAKS' silently with $WINETRICKS"
			notiShow "$(strFix "$NOTY_WTINST" "$WTPAKS" "$("$WINETRICKS" -V | cut -d ' ' -f1)" "$("$WTWINE" --version)")"
			restoreOrgVars
			if [ -n "$4" ] && [ "$4" == "F" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Using 'force' mode as argument '$4' was given"
				"$WTRUN" "$WINETRICKS" --force --unattended "${INSTPAKS[@]}" >> "$WTSHMLOG" 2>/dev/null
			else
				"$WTRUN" "$WINETRICKS" --unattended "${INSTPAKS[@]}" >> "$WTSHMLOG" 2>/dev/null
			fi
			notiShow "$NOTY_WTFIN"
			emptyVars "O" "X"
			writelog "INFO" "${FUNCNAME[0]} - '$WINETRICKS' Installation of '$WTPAKS' exited"
		fi

		if [ -f "$WTLOG" ]; then
			rmDupLines "$WTLOG"
			if [ ! -f "${WTLOG//.log/.checked}" ]; then
				mapfile -t -O "${#NOTINSTALLED[@]}" NOTINSTALLED <<< "$(comm -23 <(echo "${INSTPAKS[*]}" | tr ' ' '\n' | sort) <(sort < "$WTLOG"))"
				if [ -n "${NOTINSTALLED[0]}" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Trying to installing following new or previously missed packages now: '${NOTINSTALLED[*]}'"
					notiShow "$(strFix "$NOTY_WTINST" "${NOTINSTALLED[*]}" "$("$WINETRICKS" -V | cut -d ' ' -f1)" "$("$WTWINE" --version)")"
					"$WTRUN" "$WINETRICKS" --force --unattended "${NOTINSTALLED[@]}" >> "$WTSHMLOG" 2>/dev/null
					notiShow "$NOTY_WTFIN"
				else
					writelog "INFO" "${FUNCNAME[0]} - All packages of '$WTPAKS' are already installed - nothing to do"
					touch "${WTLOG//.log/.checked}"
				fi
				unset NOTINSTALLED
			else
				writelog "INFO" "${FUNCNAME[0]} - Found ${WTLOG//.log/.checked} - Nothing to do"
			fi
		fi
		unset INSTPAKS
	fi
}

# start winetricks before game launch:
function checkWinetricksLaunch {
	# gui:
	if [ -n "$RUN_WINETRICKS" ]; then
		if [ "$RUN_WINETRICKS" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Launching '$WINETRICKS' before game start"
			extWine64Run "$WINETRICKS" --gui  >> "$STLSHM/WINETRICKS_GUI.log" 2>/dev/null
		fi
	fi
	# silent:
	installWinetricksPaks "$WINETRICKSPAKS" "$RUNWINE" "extWine64Run"
}

function chooseWinetricks {
	if [ -n "$WINETRICKS" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - 'WINETRICKS variable' already exists and points to '$WINETRICKS'"
	else
		if [ "$DLWINETRICKS" -eq 1 ] || [ "$ONSTEAMDECK" -eq 1 ] || [ "$INFLATPAK" -eq 1 ] ; then
			WTDLLAST="${WTDLDIR}.txt"
			MAXAGE=1440

			if [ ! -f "$DLWT" ] || [ ! -f "$WTDLLAST" ] || test "$(find "$WTDLLAST" -mmin +"$MAXAGE")"; then
				gitUpdate "$WTDLDIR" "$WINETRICKSURL"
				echo "$(date) - ${FUNCNAME[0]}" > "$WTDLLAST"
			fi

			if [ -f "$DLWT" ]; then
				WINETRICKS="$DLWT"
				writelog "INFO" "${FUNCNAME[0]} - Using '$DLWT' with version '$($DLWT -V | cut -d ' ' -f1)'"
			else
				writelog "SKIP" "${FUNCNAME[0]} - DLWINETRICKS is set to '$DLWINETRICKS', but '$DLWT' was not found!"
			fi
		else
			if [ -x "$(command -v "$SYSWINETRICKS")" ]; then
				WINETRICKS="$SYSWINETRICKS"
				writelog "INFO" "${FUNCNAME[0]} - Using systemwide winetricks with version '$($SYSWINETRICKS -V | cut -d ' ' -f1)'"
			fi
		fi
	fi
}

## Manage setting the Wine DPI scale factor in the registry
function setWineDpiScaling {
	WINEDPIREGPATH="HKEY_CURRENT_USER\\Control Panel\\Desktop"
	WINEDPIREGKEY="LogPixels"
	WINEDPIUSEVAL=""

	## Didn't reuse updateWineRegistryKey because it can't handle the DWORD stuff we need to do here
	## Room for a potential refactor in future

	# If no Wine DPI option is enabled, skip
	if [ "$USEPERGAMEWINEDPI" -eq 0 ] && [ "$USEGLOBALWINEDPI" -eq 0 ]; then
		return
	fi

	WINEDPISCALEREGWINECMD="$( getWineBinFromProtPath "$( getProtPathFromCSV "$USEPROTON" )" )"  # Get the Wine binary to run regedit with
	# Per-Game Wine DPI takes priority over Global, so Global goes in elseif
	if [ "$USEPERGAMEWINEDPI" -eq 1 ]; then  # Per-Game
		if [ -z "$PERGAMEWINEDPI" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Per-Game Wine DPI was enabled, but its value was blank -- Overwriting it as '$DEFWINEDPI'"
			PERGAMEWINEDPI="$DEFWINEDPI"
		fi
		writelog "INFO" "${FUNCNAME[0]} - Setting Per-Game Wine DPI to '$PERGAMEWINEDPI' into prefix '$GPFX'"
		WINEDPIUSEVAL="$PERGAMEWINEDPI"
	elif [ "$USEGLOBALWINEDPI" -eq 1 ]; then  # Global
		if [ -z "$GLOBALWINEDPI" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Global Wine DPI was enabled, but its value was blank -- Overwriting it as '$DEFWINEDPI'"
			GLOBALWINEDPI="$DEFWINEDPI"
		fi
		writelog "INFO" "${FUNCNAME[0]} - Setting Global Wine DPI to '$GLOBALWINEDPI' into prefix '$GPFX'"
		WINEDPIUSEVAL="$GLOBALWINEDPI"
	fi

	# Make extra sure we only set the DPI scaling when we should
	if [ -n "$WINEDPIUSEVAL" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Updating '$WINEDPIREGKEY' with DPI value '$WINEDPIUSEVAL'"
		WINEPREFIX="$GPFX" "$WINEDPISCALEREGWINECMD" reg "add" "$WINEDPIREGPATH" "/v" "$WINEDPIREGKEY" "/t" "REG_DWORD" "/d" "${WINEDPIUSEVAL}" "/f"
	fi
}

function SetWineDebugChannels {
	if [ -n "$1" ]; then
		AID="$1"
		setAIDCfgs
	fi
	loadCfg "$STLGAMECFG"
	fixShowGnAid
	export CURWIKI="$PPW/Wine-Debug"
	TITLE="${PROGNAME}-${FUNCNAME[0]}"
	pollWinRes "$TITLE"
	setShowPic

	WDCTXT="winedebugchannels.txt"
	WDC="$GLOBALMISCDIR/$WDCTXT"

	WDCSEL="$(
	while read -r wtch; do
		if grep -q "\-${wtch}" <<< "$STLWINEDEBUG"; then
			echo TRUE
		else
			echo FALSE
		fi
		if grep -q "+${wtch}" <<< "$STLWINEDEBUG"; then
			echo TRUE
		else
			echo FALSE
		fi
		echo "$wtch"
	done < "$WDC" | \
	"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist --column="$GUI_MINUS":CHK --column="$GUI_PLUS":CHK --column="$GUI_WDCH" --separator=";" --print-all \
	--text="$(spanFont "$(strFix "$GUI_WDCDIALOG" "$SGNAID")" "H")" --title="$TITLE" --button="$BUT_CAN:0" --button="$BUT_SELECT:2" "$GEOM")"
	case $? in
		0)	{
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN' - Cancelling selection"
			}
		;;
		2)	{
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_SELECT' - Saving Debug Options"

				if [ -z "$WDCSEL" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Nothing selected"
				else
					unset STLWINEDEBUG
					while read -r chanline;do
						chan="$(cut -d ';' -f3 <<< "$chanline")"
						if grep -q "TRUE;FALSE" <<< "$chanline"; then
							STLWINEDEBUG="${STLWINEDEBUG},-${chan}"
						elif grep -q "FALSE;TRUE" <<< "$chanline"; then
							STLWINEDEBUG="${STLWINEDEBUG},+${chan}"
						elif grep -q "TRUE;TRUE" <<< "$chanline"; then
							STLWINEDEBUG="${STLWINEDEBUG},-${chan}"
						fi
					done <<< "$WDCSEL"
					touch "$FUPDATE"
					writelog "INFO" "${FUNCNAME[0]} - Saving following Wine Debug options: '$STLWINEDEBUG'"
					updateConfigEntry "STLWINEDEBUG" "${STLWINEDEBUG#,*}" "$STLGAMECFG"
				fi
			}
		;;
	esac
}

function WinetricksPick {
	WTPREF="$1"

	unset CURWTPAKS OTHERPAKS PAKSEL

	if [ "$WINETRICKSPAKS" == "$NON" ]; then
		declare -a CURWTPAKS
	else
		mapfile -d " " -t -O "${#CURWTPAKS[@]}" CURWTPAKS <<< "$(printf '%s\n' "$WINETRICKSPAKS" | sed '/^[[:space:]]*$/d')"
	fi

	while read -r line; do
		mapfile -d " " -t -O "${#PAKSEL[@]}" PAKSEL <<< "${line%% *}"
	done <<< "$(winetricks "$WTPREF" list)"

	while read -r curpak; do
	if [[ ! "${PAKSEL[*]}" =~ $curpak ]]; then
		mapfile -d " " -t -O "${#OTHERPAKS[@]}" OTHERPAKS <<< "${curpak%% *}"
	fi
	done <<< "$(printf "%s\n" "${CURWTPAKS[@]}")"

	fixShowGnAid
	export CURWIKI="$PPW/Winetricks"
	TITLE="${PROGNAME}-WinetricksPackageSelection-$WTPREF"
	pollWinRes "$TITLE"

	setShowPic
	# TODO? some yad/gtk warnings in WTPREF=apps DESCR:
	WTPICKS="$(
	while read -r packline; do
		PACKNAME="${packline%% *}"

		if [[ "${CURWTPAKS[*]}" =~ $PACKNAME ]]; then
			echo TRUE
		else
			echo FALSE
		fi

		echo "$PACKNAME"

		DESCRRAW="${packline#* }"
		DESCR1="${DESCRRAW//$(grep -oP '\(\K[^\)]+' <<< "$DESCRRAW")}";
		DESCR2="${DESCR1//\!}"
		DESCR="${DESCR2//&/&amp}"
		echo "${DESCR#"${DESCR%%[![:space:]]*}"}"
	done <<< "$("$WINETRICKS" "$WTPREF" list)"	 | \
	"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist --column="$GUI_ADD" --column="$GUI_WTPACK" --column="$GUI_WTDESC" --separator="" --print-column="2" \
	--text="$(spanFont "$(strFix "$GUI_WTPACKDIALOG" "$SGNAID")" "H")" --title="$TITLE" --button="$BUT_CAN:0" --button="$BUT_SELECT:2" "$GEOM")"
	case $? in
		0)	{
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN' - Cancelling selection"
			}
		;;
		2)	{
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_SELECT' - Saving Selection"

				if [ -z "$WTPICKS" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Nothing selected"
					WTPICKS=""
				fi

				unset WINETRICKSPAKS
				while read -r line; do
					WINETRICKSPAKS="$WINETRICKSPAKS $line"
				done <<< "$WTPICKS"

				while read -r line; do
					WINETRICKSPAKS="$WINETRICKSPAKS $line"
				done <<< "${OTHERPAKS[*]}"

				if [ -z "$WINETRICKSPAKS" ] || [ "$WINETRICKSPAKS" == "  " ]; then
					WINETRICKSPAKS="$NON"
				fi

				WINETRICKSPAKS="${WINETRICKSPAKS#*[[:blank:]]}"
				WINETRICKSPAKS="${WINETRICKSPAKS%*[[:blank:]]}"

				declare -A WTNODUPPAKS
				for i in $WINETRICKSPAKS; do
					WTNODUPPAKS[$i]=1
				done

				WINETRICKSPAKS="${!WTNODUPPAKS[*]}"

				touch "$FUPDATE"
				updateConfigEntry "WINETRICKSPAKS" "$WINETRICKSPAKS" "$STLGAMECFG"
			}
		;;
	esac
	if [ -n "$2" ]; then
		"$2" "$AID" "${FUNCNAME[0]}"
	fi
}

function cleanDropDown {
	CURSEL="$1"
	OPTIONS="$2"

	FILTOPTS="${OPTIONS//\!$CURSEL\!/\!}"
	FILTOPTS="!${FILTOPTS//$CURSEL\!/\!}"
	FILTOPTS="${FILTOPTS//\!\!/\!}"
	echo "$CURSEL$FILTOPTS"
}

function chooseWinetricksPrefix {
	if [ -n "$1" ]; then
		AID="$1"
		setAIDCfgs
	fi

	if [ ! -f "$STLGAMECFG" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Game config '$STLGAMECFG' not found - exiting"
	else
		chooseWinetricks
		loadCfg "$STLGAMECFG"
		ORGWINETRICKSPAKS="$WINETRICKSPAKS"

		writelog "INFO" "${FUNCNAME[0]} - Opening dialog to choose a winetricks prefix"
		export CURWIKI="$PPW/Winetricks"
		TITLE="${PROGNAME}-${FUNCNAME[0]}"
		pollWinRes "$TITLE"
		setShowPic

		WTLOG="$GPFX/winetricks.log"

		function WTPAKINSTLIST {
			unset WTLIST

			if [ -f "$WTLOG" ]; then
				rmDupLines "$WTLOG"
			fi

			while read -r line; do
				if [ -f "$WTLOG" ] && grep -q "^$line$" "$WTLOG"; then
					WTLIST="$WTLIST $line $GUI_WTAI,"
				else
					WTLIST="$WTLIST $line,"
				fi
			done <<< "$(tr ' ' '\n' <<< "$WINETRICKSPAKS")"
			WTLIST="${WTLIST/ /}"
			WTLIST="${WTLIST%,*}"
			echo "$WTLIST"
		}

		createProtonList X
		if [ -z "$WTPROTON" ]; then
			WTPROTON="$USEPROTON"
		fi

		WTCATPFX="$("$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--title="$TITLE" --separator=";" \
		--text="$(spanFont "$GUI_CHOOSEWTCATPFX" "H")" \
		--field=" ":LBL " " \
		--field="$GUI_WTCATPFX!$GUI_CHOOSEWTCATPFX":CB "dlls!apps!dlls!fonts" \
		--field="$GUI_WTPROTON!$(strFix "$DESC_WTPROTON" "$BUT_INSTALL")":CB "$(cleanDropDown "${WTPROTON//\"}" "$PROTYADLIST")" \
		--field="$GUI_WTPROTONSAVE!$(strFix "$DESC_WTPROTONSAVE" "$BUT_INSTALL")":CHK "FALSE" \
		--field=" ":LBL " " \
		--field="$(spanFont "$GUI_CURSELWTPACKS" "H")":LBL " " \
		--field="$(WTPAKINSTLIST)":LBL " " \
		--button="$BUT_SELECT:2" --button="$BUT_DONE:4" --button="$BUT_INSTALL:6" "$GEOM"
		)"
		case $? in
			2)	{
					WTPREF="$(cut -d ';' -f2 <<< "$WTCATPFX")" # WEAK - will be broken when adding fields
					writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_SELECT' - Opening '$WTPREF' list"
					WinetricksPick "$WTPREF" "${FUNCNAME[0]}"
				}
			;;
			4)	{
					writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_DONE'"
					if [ "$ORGWINETRICKSPAKS" != "$WINETRICKSPAKS" ]; then
						rm "${WTLOG//.log/.checked}" 2>/dev/null
						writelog "INFO" "${FUNCNAME[0]} - Changed will be installed before next game start"
					else
						writelog "INFO" "${FUNCNAME[0]} - Package list hasn't changed"
					fi
				}
			;;
			6)	{
					WTPROTON="$(cut -d ';' -f3 <<< "$WTCATPFX")"
					writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_INSTALL' - Installing '$WINETRICKSPAKS' using '$WTPROTON'"
					RUNWTPROTON="$(getProtPathFromCSV "$WTPROTON")"

					if [ ! -f "$RUNWTPROTON" ]; then
						RUNWTPROTON="$(fixProtonVersionMismatch "WTPROTON" "$STLGAMECFG" X)"
					fi

					writelog "INFO" "${FUNCNAME[0]} - using proton binary '$RUNWTPROTON' for '$WTPROTON'"

					if [ -f "$(dirname "$RUNWTPROTON")/$DBW" ]; then
						RUNWTWINE="$(dirname "$RUNWTPROTON")/$DBW"
					elif [ -f "$(dirname "$RUNWTPROTON")/$FBW" ]; then
						RUNWTWINE="$(dirname "$RUNWTPROTON")/$FBW"
					fi

					writelog "INFO" "${FUNCNAME[0]} - Using wine '$RUNWTWINE' for winetricks"

					WTPROTONSAVE="$(cut -d ';' -f4 <<< "$WTCATPFX")"
					if [ "$WTPROTONSAVE" == "TRUE" ];then
						writelog "INFO" "${FUNCNAME[0]} - Saving Winetricks Proton WTPROTON '$WTPROTON' into '$STLGAMECFG'"
						touch "$FUPDATE"
						updateConfigEntry "WTPROTON" "$WTPROTON" "$STLGAMECFG"
					fi

					if [ -f "$RUNWTWINE" ]; then
						rm "${WTLOG//.log/.checked}" 2>/dev/null
						installWinetricksPaks "$WINETRICKSPAKS" "$RUNWTWINE" "extWine64Run"
					else
						writelog "ERROR" "${FUNCNAME[0]} - Could not find wine binary for current proton '$WTPROTON'"
					fi
				}
			;;
		esac
	fi
}

# start $WINECFG before game launch:
function checkWineCfgLaunch {
	if [ -n "$RUN_WINECFG" ]; then
		if [ "$RUN_WINECFG" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Starting '$WINECFG' at prefix '$GPFX' with Wine '$RUNWINE':"
			if [ "$USEWINE" -eq 0 ]; then
				#513
				WINE="$RUNWINE" WINEARCH=win64 WINEDEBUG="$STLWINEDEBUG" WINEPREFIX="$GPFX" "$RUNWINE" "${WINECFG}.exe" 2>&1 | tee "$STLSHM/${FUNCNAME[0]}.log"
			else
				extWine64Run "$RUNWINECFG"
			fi
		else
			writelog "WARN" "${FUNCNAME[0]} - Function was called but RUN_WINECFG ('$RUN_WINECFG') was not enabled - skipping"
		fi
	else
		writelog "WARN" "${FUNCNAME[0]} - Function was called but RUN_WINECFG ('$RUN_WINECFG') was not defined - skipping"
	fi
}

function regEdit {
	REGEDIT="regedit"
	if [ -z "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Starting $REGEDIT without arguments"
		extWine64Run "$RUNWINE" "$REGEDIT"
	else
		writelog "INFO" "${FUNCNAME[0]} - Starting $REGEDIT with argument $1"
		if [ "$USEWINE" -eq 0 ]; then
			extWine64Run "$RUNWINE" "$REGEDIT" "$1"
		else
			extWine64Run "$RUNWINE" "$RUNREGEDIT" "$1"
		fi
		writelog "INFO" "${FUNCNAME[0]} - Applied '$1' using '$REGEDIT' - Setting REGEDIT to 0 now in '$STLGAMECFG'"
		updateConfigEntry "REGEDIT" "0" "$STLGAMECFG"
	fi
}

function customRegs {
	TEMPREG="$GPFX/VirtualDesktop.reg"

	if [ "$VIRTUALDESKTOP" -eq 1 ]; then
		SETVD=1
		if [ -z "$VDRES" ] || [ "$VDRES" == "$NON" ]; then
			VDRES="$(getScreenRes r)"
		fi

		if [ -f "$TEMPREG" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Looks like virtual desktop was already applied before"
			if grep -q "$VDRES" "$TEMPREG"; then
				writelog "SKIP" "${FUNCNAME[0]} - The configured resolution in '$TEMPREG' did not change - nothing to do"
				SETVD=0
			else
				writelog "INFO" "${FUNCNAME[0]} - The configured resolution in '$TEMPREG' changed - updating to '$VDRES'"
			fi
		fi

		if [ "$SETVD" -eq 1 ]; then
			if touch "$TEMPREG"; then
				writelog "INFO" "${FUNCNAME[0]} - VIRTUALDESKTOP is set to 1 - enabling virtual desktop"
				{
				echo "Windows Registry Editor Version 5.00"
				echo "[HKEY_CURRENT_USER\Software\Wine\Explorer]"
				echo "\"Desktop\"=\"Default\""
				echo "[HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops]"
				echo "\"Default\"=\"$VDRES\""
				} >> "$TEMPREG"
				if [ -f "$TEMPREG" ]; then
					regEdit "$TEMPREG"
				else
					writelog "SKIP" "${FUNCNAME[0]} - '$TEMPREG' should be here, but it isn't!"
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - Could not create '$TEMPREG' - skipping!"
			fi
		fi
	elif [ "$VIRTUALDESKTOP" -eq 0 ]; then
		if [ -f "$TEMPREG" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Virtual desktop is disabled, but was enabled before - removing the registry value"
			sed "s:\[:\[-:g" -i "$TEMPREG"
			regEdit "$TEMPREG"
			rm "$TEMPREG"
		fi
	fi

	if [ "$REGEDIT" -eq 1 ]; then
		mkProjDir "$STLREGDIR"
		if [ -f "$STLREGDIR/$AID.reg" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Applying registry file '$STLREGDIR/$AID.reg'"
			regEdit "$STLREGDIR/$AID.reg"
		else
			writelog "INFO" "${FUNCNAME[0]} - No game specific regfile found. Opening the regedit editor"
			regEdit
		fi
	fi
}

function useNyrna {
	if [ -n "$RUN_NYRNA" ]; then
		if [ "$RUN_NYRNA" -eq 1 ]; then
			if "$PGREP" -f "$NYRNA" >/dev/null; then
				writelog "SKIP" "${FUNCNAME[0]} - '$NYRNA' already running - skipping"
				RUN_NYRNA=0
			else
			writelog "INFO" "${FUNCNAME[0]} - Starting '$NYRNA'"
			"$NYRNA" &
			fi
		fi
	fi
}

function useReplay {
	if [ -n "$RUN_REPLAY" ]; then
		if [ "$RUN_REPLAY" -eq 1 ]; then
			if "$PGREP" -fx "$(command -v "$REPLAY")" >/dev/null; then
				writelog "SKIP" "${FUNCNAME[0]} - '$REPLAY' already running - skipping"
				RUN_REPLAY=0
			else
			writelog "INFO" "${FUNCNAME[0]} - Starting '$REPLAY'"
			"$REPLAY" &
			fi
		fi
	fi
}

function killPrefixOnGameExit {
	# the TinkerGame main process which backgrounded us: used to detect a
	# session which died without a regular close (f.e. killed by Steam), so
	# we never wait forever
	KPOGEMAINPID="$PPID"

	waitForGamePid
	GPID="$(GAMEPID)"
	if [ -n "$GPID" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Game pid '$GPID' found"
		writelog "INFO" "${FUNCNAME[0]} - Waiting for '$GPID' closing to kill Proton"
		tail --pid="$GPID" -f /dev/null
	else
		# the game pid could not be determined (f.e. the game exe is not found
		# in the process list): wait for the TinkerGame session to end instead,
		# so the prefix is still torn down and no orphaned wine processes
		# (f.e. wine-discord-ipc-bridge) keep the Steam session alive forever
		writelog "WAIT" "${FUNCNAME[0]} - No game pid found - waiting for the session to end instead"
		while [ ! -f "$CLOSETMP" ] && kill -0 "$KPOGEMAINPID" 2>/dev/null; do
			sleep 1
		done
	fi
	writelog "INFO" "${FUNCNAME[0]} - Game process '$GPID' finished - Force closing Proton"
	if [ "$USEWINE" -eq 0 ]; then
		WINEPREFIX="$GPFX" "$RUNWINESERVER" -k
	else
		WINEPREFIX="$GWFX" "$RUNWINESERVER" -k
	fi

	# only (re)create CLOSETMP when we had a game pid or a close was already
	# in progress: a session that finished cleaning up must not be left with
	# a stale closing marker
	if [ -n "$GPID" ] || [ -f "$CLOSETMP" ]; then
		touch "$CLOSETMP"
	fi
}

function StateSteamWebHelper {
	if [ "$TOGSTEAMWEBHELPER" -eq 1 ]; then
		SWH="steamwebhelper"

		if [ "$1" == "pause" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Stopping all '$SWH' processes"
			SIGVAL="-SIGSTOP"
		elif [ "$1" == "cont" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Continuing all '$SWH' processes"
			SIGVAL="-SIGCONT"
		else
			writelog "INFO" "${FUNCNAME[0]} - No argument - Toggling '$SWH' processes"
			TESTPID="$("$PGREP" "$SWH" | grep -v "$("$PGREP" "${SWH}\.")" | head -n1)"
			SWHSTATE="$(ps -q "$TESTPID" -o state --no-headers)"
			SIGVAL="-SIGSTOP"
			if [ "$SWHSTATE" = "T" ] ; then
				SIGVAL="-SIGCONT"
			fi
		fi

		while read -r swhpid; do
			if [ -n "$swhpid" ] && [ "$swhpid" -eq "$swhpid" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Executing 'kill \"$SIGVAL\" \"$swhpid\"' to '$1' the $SWH"
				kill "$SIGVAL" "$swhpid"
			fi
		done <<< "$("$PGREP" "$SWH")"
	fi
}

function dlWDIB {
	mkProjDir "$WDIBDLDIR"
	WDIBDSRC=$("$WGET" -q "$WDIBURL" -O - | "$JQ" -r '.assets[] | select(.name | test("exe$")) | .browser_download_url')

	if [ ! -f "$RUNWDIB" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Downloading '$WDIB' to '$WDIBDLDIR'"
		dlCheck "$WDIBDSRC" "$RUNWDIB" "X" "Downloading '$WDIB' to '$WDIBDLDIR'"
	fi

	if [ -f "$RUNWDIB" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Found $RUNWDIB - skipping download"
	fi
}

# start wine-discord-ipc-bridge
function checkWDIB {
	if [ "$ISGAME" -eq 2 ] && [ "$USE_WDIB" -eq 1 ] && [ "$ISGAME" -eq 2 ] && [ "$USEWINE" -eq 0 ]; then
		dlWDIB

		if [ ! -f "$RUNWDIB" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Download failed - can't start '$WDIB' - skipping"
			USE_WDIB=0
		else
			writelog "INFO" "${FUNCNAME[0]} - Starting '$RUNWDIB' in the backgound for '$AID'"
			extProtonRun "F" "$RUNWDIB"
			killPrefixOnGameExit &
		fi
	fi
}

function checkSteamAppIDFile {
	if [ -d "$EFD" ] && [ "$STLPLAY" -eq 0 ]; then
		GSAIT="$EFD/$SAIT"
		CSAIT="$EFD/check-$SAIT"

		if [ ! -f "$CSAIT" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Creating new control file '$CSAIT'"
			if [ ! -f "$GSAIT" ]; then
				echo "OWNSAIT=\"0\"" > "$CSAIT"
			else
				echo "OWNSAIT=\"1\"" > "$CSAIT"
			fi
		fi

		if [ "$STEAMAPPIDFILE" -eq 1 ]; then
			if [ ! -f "$GSAIT" ]; then
				if ! haveNonSteamGame; then
					writelog "INFO" "${FUNCNAME[0]} - Creating '$GSAIT' because STEAMAPPIDFILE is enabled"
					echo "$AID" > "$GSAIT"
				else
					# Can't create steam_appid.txt for Non-Steam Games because this causes crashes, see #941
					writelog "INFO" "${FUNCNAME[0]} - Looks like we have a Non-Steam Game, not creating '$GSAIT' because this would cause crashes, and forcing 'STEAMAPPIDFILE' to '0'"
					touch "$FUPDATE"
					STEAMAPPIDFILE=0
					updateConfigEntry "STEAMAPPIDFILE" "$STEAMAPPIDFILE" "$STLGAMECFG"
				fi
			else
				writelog "INFO" "${FUNCNAME[0]} - STEAMAPPIDFILE is enabled and '$GSAIT' already exists - nothing to do"
			fi
		else
			if [ ! -f "$GSAIT" ]; then
				writelog "INFO" "${FUNCNAME[0]} - STEAMAPPIDFILE is disabled and there's no '$GSAIT' - nothing to do"
			else
				if [ ! -f "$CSAIT" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Removing '$GSAIT' because STEAMAPPIDFILE is disabled"
					rm "$GSAIT" 2>/dev/null
				else
					loadCfg "$CSAIT" X
					if [ "$OWNSAIT" -eq 1 ]; then
						writelog "INFO" "${FUNCNAME[0]} - OWNSAIT is '$OWNSAIT', means the game ships an own '$SAIT'. Leaving untouched and enabling STEAMAPPIDFILE"
						touch "$FUPDATE"
						STEAMAPPIDFILE=1
						updateConfigEntry "STEAMAPPIDFILE" "$STEAMAPPIDFILE" "$STLGAMECFG"
					else
						writelog "INFO" "${FUNCNAME[0]} - Removing '$GSAIT' because the game doesn't own it and STEAMAPPIDFILE is disabled"
						rm "$GSAIT" 2>/dev/null
					fi
				fi
			fi
		fi
	fi
}

function checkPulse {
	if [ "$CHANGE_PULSE_LATENCY" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Setting PULSE_LATENCY_MSEC to '$STL_PULSE_LATENCY_MSEC'"
		export PULSE_LATENCY_MSEC="$STL_PULSE_LATENCY_MSEC"
	fi
}

function getProtWinePath {
	CHECKWINED="${1%/*}/$DBW"
	CHECKWINEF="${1%/*}/$FBW"
	if [ -f "$CHECKWINED" ]; then
		echo "$CHECKWINED"
	elif [ -f "$CHECKWINEF" ]; then
		echo "$CHECKWINEF"
	fi
}

function listSteWoShPaks {
	STSHT1="${STEWOS,,}"
	STSHTXT="${STSHT1//\ /-}.txt"
	STESHALIST="$GLOBALMISCDIR/$STSHTXT"
	cut -d ';' -f1 "$STESHALIST"
}

function getGameDirFromAM {
	APPMAFE="$1"
	GIRAW="$(grep "\"installdir\"" "$APPMAFE" | awk -F '"installdir"' '{print $NF}')"
	GINS="$(awk '{$1=$1};1' <<< "${GIRAW//\"/}")"
	OUTGD="${APPMAFE%/*}/common/$GINS"
	if [ -d "$OUTGD" ]; then
		echo "$OUTGD"
	fi
}

function getGameDirFromAID {
	APPMAFE="$(listAppManifests | grep -m1 "appmanifest_${1}.acf")"
	getGameDirFromAM "$APPMAFE"
}

function runExe {
	IFILE="$1"
	AIDORPFX="$2"
	INSTWINE="$3"
	INSTARGS="$4"

	mapfile -d " " -t -O "${#INSTARGSARR[@]}" INSTARGSARR < <(printf '%s' "${INSTARGS//\"}")

	if [ "$AIDORPFX" -eq "$AIDORPFX" ] 2>/dev/null; then
		writelog "INFO" "${FUNCNAME[0]} - '$AIDORPFX' seems to be a SteamAppId - determining its pfx" E
		setGPfxFromAppMa "$AIDORPFX"
		if [ -n "$GPFX" ]; then
			IPFX="$GPFX"
			IAID="$AIDORPFX"
		fi
	else
		IPFX="$AIDORPFX"
		IAID="$(grep -oP "$CODA/\K[^/pfx]+" <<< "$IPFX")"
	fi

	if [ "$INSTWINE" != "$NON" ]; then
		IWINE="$INSTWINE"
	else
		if [ "$IAID" -eq "$IAID" ] 2>/dev/null; then
			IAIDCFG="$STLGAMEDIRID/$IAID.conf"
			if [ -f "$IAIDCFG" ]; then
				IUSEPROT="$(grep "^USEPROTON=" "$IAIDCFG" | cut -d '=' -f2)"
				writelog "INFO" "${FUNCNAME[0]} - Searching for wine for '$IUSEPROT' defined in $IAIDCFG"
				IRUNPROT="$(getProtPathFromCSV "${IUSEPROT//\"}")"
				if [ -f "$IRUNPROT" ]; then
					IWINE="$(getProtWinePath "$IRUNPROT")"
					writelog "INFO" "${FUNCNAME[0]} - Using '$IWINE' for installing '$1'"
				else
					writelog "SKIP" "${FUNCNAME[0]} - Could not find path for proton '${IUSEPROT//\"}' in '$IAIDCFG'"
				fi
			fi
		fi

		if [ ! -f "$IAIDCFG" ] || [ ! -f "$IWINE" ]; then
			writelog "INFO" "${FUNCNAME[0]} - No wine binary found - falling back to wine from FIRSTUSEPROTON '$FIRSTUSEPROTON'"
			IRUNPROT="$(getProtPathFromCSV "$FIRSTUSEPROTON")"
			if [ -f "$IRUNPROT" ]; then
				IWINE="$(getProtWinePath "$IRUNPROT")"
				writelog "INFO" "${FUNCNAME[0]} - Using '$IWINE' for installing '$IFILE'"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Could not find path for proton '$FIRSTUSEPROTON' in '$IAIDCFG'"
			fi
		fi
	fi

	if [ -n "$IPFX" ] && [ -f "$IWINE" ] && [ -f "$IFILE" ]; then
		cd "${IFILE%/*}" >/dev/null || return
		if [ -n "$USEMSI" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Installing package via command 'WINEPREFIX=$IPFX $IWINE msiexec /i $IFILE ${INSTARGS//\"/}'"
			WINEDEBUG="-all" WINEPREFIX="$IPFX" "$IWINE" msiexec /i "$IFILE" "${INSTARGSARR[@]}" >"$STLSHM/${FUNCNAME[0]}_${IFILE##*/}.log" 2>"$STLSHM/${FUNCNAME[0]}_${IFILE##*/}.log"
		else
			if [[ "$1" =~ "dotnet" ]]; then
				MOGUID="$(WINEPREFIX="$IPFX" "$IWINE" uninstaller --list | grep "Wine Mono Windows Support" | cut -d '|' -f1)"
				if [ -n "$MOGUID" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Uninstalling Mono before installing '${IFILE##*/}'"
					WINEPREFIX="$IPFX" "$IWINE" uninstaller --remove "$MOGUID" >"$STLSHM/${FUNCNAME[0]}_mono-uninst.log" 2>"$STLSHM/${FUNCNAME[0]}_mono-uninst.log"
				fi
			fi
			WINEDEBUG="-all" WINEPREFIX="$IPFX" "$IWINE" "$IFILE" "${INSTARGSARR[@]}" >"$STLSHM/${FUNCNAME[0]}_${IFILE##*/}.log" 2>"$STLSHM/${FUNCNAME[0]}_${IFILE##*/}.log"
		fi
		cd - >/dev/null || return
	else
		writelog "SKIP" "${FUNCNAME[0]} - At least one component of the package installation is missing, check above logs"
	fi
}

# Install Steamworks Shared Package (package name mapping can be found at eval/packages/<name>)
function installSteWoShPak {
	AIDORPFX="$2"
	if [ -n "$3" ]; then
		INSTWINE="$3"
	else
		INSTWINE="$NON"
	fi

	STSHT1="${STEWOS,,}"
	STSHTXT="${STSHT1//\ /-}.txt"
	STESHALIST="$GLOBALMISCDIR/$STSHTXT"

	CORED="$STEAM_COMPAT_CLIENT_INSTALL_PATH/$SAC/$STEWOS/_CommonRedist/"

	if grep -q "^\"$1\";" "$STESHALIST"; then
		RELPATH="$(grep "^\"$1\";" "$STESHALIST" | cut -d ';' -f2)"
		INSTARGS="$(grep "^\"$1\";" "$STESHALIST" | cut -d ';' -f3)"
		USEMSI="$(grep "^\"$1\";" "$STESHALIST" | cut -d ';' -f4)"
		IFILE="$CORED/${RELPATH//\"/}"
		notiShow "$(strFix "$NOTY_INSTSTART" "$1")"
		writelog "INFO" "${FUNCNAME[0]} - 'runExe \"$IFILE\" \"$AIDORPFX\" \"$INSTWINE\" \"$INSTARGS\"'"
		runExe "$IFILE" "$AIDORPFX" "$INSTWINE" "$INSTARGS"
		notiShow "$(strFix "$NOTY_INSTSTOP" "$1")"
	else
		writelog "SKIP" "${FUNCNAME[0]} - Could not find '$1' in '$STESHALIST' - doesn't seem to be a valid '$STEWOS' name"
	fi
}

# generic Mod functions (Vortex + MO2):

function prepModGameSym {
	DSTL="$1"
	gdir="$2"
	if [ -n "$2" ]; then
		if [ ! -L "$DSTL" ] || [ "$(readlink "$DSTL")" != "$gdir" ]; then
			if [ -L "$DSTL" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Removing symlink '$DSTL' pointing to '$(readlink "$DSTL")'"
				rm "$DSTL" 2>/dev/null
			fi
			if [ -d "$DSTL" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - Not creating symlink from '$gdir' to '$DSTL', because '$DSTL' is a real directory"
			else
				writelog "INFO" "${FUNCNAME[0]} - Creating symlink from '$gdir' to '$DSTL'"
				ln -s "$gdir" "$DSTL"
			fi
		fi
	fi
}

function setModGameReg {
	DSTPFX="$1"
	MODWINE="$2"
	if [ -f "$MODGREG" ]; then
		WINEPREFIX="$DSTPFX" "$MODWINE" regedit "$MODGREG" 2>/dev/null
		WINEPREFIX="$DSTPFX" "${MODWINE}64" regedit "$MODGREG" 2>/dev/null
		rm "$MODGREG" 2>/dev/null
	fi
}

function setModGameSyms {
	SYMODE="$1" # MODE - either 'li' or 'set'
	SRCPFX="$2" # Game prefix
	MODGNA="$3" # Game name
	MODGID="$4" # Game Steam ID
	DSTPFX="$5" # Mod manager prefix
	CHKAPMA="$6" # Game app-manifest (.acf)

	if [ -f "$MO2INSTFAIL" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - '$MO2INSTFAIL' found - seems like installation failed previously - skipping ${FUNCNAME[0]}"
	elif [ ! -d "$SRCPFX" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - '$SRCPFX' missing - looks like the game was removed or never started yet"
	else
		if [ "$SYMODE" == "li" ]; then
			echo "$MODGID;$MODGNA;$SRCPFX;"
		else
			mkProjDir "$DSTPFX/$DRCU/$STUS/$DOCS/$MYGAMES"
			mkProjDir "$DSTPFX/$DRCU/$STUS/$ADLO/cache"

			MODLOOT="$DSTPFX/$DRCU/$STUS/$ADLO/LOOT"
			if [ -L "$MODLOOT" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Removing symlink '$MODLOOT' for creating a real directory instead - is it worth/useful to migrate the content to '$MODLOOT'?"
			fi
			mkProjDir "$MODLOOT"

			writelog "INFO" "${FUNCNAME[0]} - Found game '$MODGNA ($MODGID)' with pfx '$SRCPFX'"
			# maybe merge redundant code later:

			if [ -d "$SRCPFX/$DRCU/$STUS/$DOCS/$MYGAMES" ]; then
				while read -r gdir; do
					DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/$MYGAMES/${gdir##*/}"
					prepModGameSym "$DSTL" "$gdir"
				done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$DOCS/$MYGAMES" -mindepth 1 -maxdepth 1 '(' -type d -o -type l -xtype d ')')"
			fi

			if [ -d "$SRCPFX/$DRCU/$STUS/$DOCS" ]; then
				while read -r gdir; do
					if [ "${gdir##*/}" == "$MYGAMES" ]; then
						while read -r gsdir; do
							DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/$MYGAMES/${gsdir##*/}"
							prepModGameSym "$DSTL" "$gsdir"
						done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$DOCS/$MYGAMES" -mindepth 1 -maxdepth 1 '(' -type d -o -type l -xtype d ')')"
					elif [ "${gdir##*/}" == "$EAGA" ]; then
						mkProjDir "$DSTPFX/$DRCU/$STUS/$DOCS/$EAGA"
						while read -r geadir; do
							DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/$EAGA/${geadir##*/}"
							prepModGameSym "$DSTL" "$geadir"
						done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$DOCS/$EAGA" -mindepth 1 -maxdepth 1 '(' -type d -o -type l -xtype d ')')"
					elif [ "${gdir##*/}" == "$LAGA" ]; then
						mkProjDir "$DSTPFX/$DRCU/$STUS/$DOCS/$LAGA"
						while read -r gladir; do
							DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/$LAGA/${gladir##*/}"
							prepModGameSym "$DSTL" "$gladir"
						done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$DOCS/$LAGA" -mindepth 1 -maxdepth 1 '(' -type d -o -type l -xtype d ')')"
					elif [ "${gdir##*/}" == "$BIOW" ]; then
						mkProjDir "$DSTPFX/$DRCU/$STUS/$DOCS/$BIOW"
						while read -r gbiodir; do
							DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/$BIOW/${gbiodir##*/}"
							prepModGameSym "$DSTL" "$gbiodir"
						done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$DOCS/$BIOW" -mindepth 1 -maxdepth 1 '(' -type d -o -type l -xtype d ')')"
					else
						DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/${gdir##*/}"
						prepModGameSym "$DSTL" "$gdir"
					fi
				done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$DOCS" -mindepth 1 -maxdepth 1 -not -empty '(' -type d -o -type l -xtype d ')')"
			fi

			if [ -d "$SRCPFX/$DRCU/$STUS/$MYDOCS" ] && [ ! -L "$SRCPFX/$DRCU/$STUS/$MYDOCS" ]; then
				while read -r gdir; do
					if [ "${gdir##*/}" == "$MYGAMES" ]; then
						while read -r gsdir; do
							DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/$MYGAMES/${gsdir##*/}"
							prepModGameSym "$DSTL" "$gsdir"
						done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$MYDOCS/$MYGAMES" -mindepth 1 -maxdepth 1 '(' -type d -o -type l -xtype d ')')"
					elif [ "${gdir##*/}" == "$EAGA" ]; then
						mkProjDir "$DSTPFX/$DRCU/$STUS/$DOCS/$EAGA"
						while read -r geadir; do
							DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/$EAGA/${geadir##*/}"
							prepModGameSym "$DSTL" "$geadir"
						done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$MYDOCS/$EAGA" -mindepth 1 -maxdepth 1 '(' -type d -o -type l -xtype d ')')"
					elif [ "${gdir##*/}" == "$LAGA" ]; then
						mkProjDir "$DSTPFX/$DRCU/$STUS/$DOCS/$LAGA"
						while read -r gladir; do
							DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/$LAGA/${gladir##*/}"
							prepModGameSym "$DSTL" "$gladir"
						done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$MYDOCS/$LAGA" -mindepth 1 -maxdepth 1 '(' -type d -o -type l -xtype d ')')"
					elif [ "${gdir##*/}" == "$BIOW" ]; then
						mkProjDir "$DSTPFX/$DRCU/$STUS/$DOCS/$BIOW"
						while read -r gbiodir; do
							DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/$BIOW/${gbiodir##*/}"
							prepModGameSym "$DSTL" "$gbiodir"
						done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$DOCS/$BIOW" -mindepth 1 -maxdepth 1 '(' -type d -o -type l -xtype d ')')"
					else
						DSTL="$DSTPFX/$DRCU/$STUS/$DOCS/${gdir##*/}"
						prepModGameSym "$DSTL" "$gdir"
					fi
				done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$MYDOCS" -mindepth 1 -maxdepth 1 -not -empty '(' -type d -o -type l -xtype d ')')"
			fi

			if [ -d "$SRCPFX/$DRCU/$STUS/$APDA" ]; then
				while read -r gdir; do
					if [ "${gdir##*/}" != "Microsoft" ] ; then
						DSTL="$DSTPFX/$DRCU/$STUS/$ADRO/${gdir##*/}"
						prepModGameSym "$DSTL" "$gdir"
					fi
				done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$APDA" -mindepth 1 -maxdepth 1 -not -empty '(' -type d -o -type l -xtype d ')')"
			fi

			if [ -d "$SRCPFX/$DRCU/$STUS/$ADLO" ]; then
				while read -r gdir; do
					if [ "${gdir##*/}" != "openvr" ] && [ "${gdir##*/}" != "Microsoft" ] && [ "${gdir##*/}" != "cache" ] ; then
						if [ "${gdir##*/}" == "$MO" ] && [ ! -L "$gdir" ]; then
							writelog "WARN" "${FUNCNAME[0]} - Renaming old real directory '$gdir' to '${gdir}_OLD', to make place for a symlink into '$DSTPFX'"
							mv "$gdir" "${gdir}_OLD"
						else
							DSTL="$DSTPFX/$DRCU/$STUS/$ADLO/${gdir##*/}"
							prepModGameSym "$DSTL" "$gdir"
						fi
					fi
				done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$ADLO" -mindepth 1 -maxdepth 1 -not -empty '(' -type d -o -type l -xtype d ')')"
			fi

			if [ -d "$SRCPFX/$DRCU/$STUS/$ADLOLO" ]; then
				while read -r gdir; do
					if [ "${gdir##*/}" != "openvr" ] && [ "${gdir##*/}" != "Microsoft" ] ; then
						if [ "${gdir##*/}" == "$MO" ] && [ ! -L "$gdir" ]; then
							writelog "WARN" "${FUNCNAME[0]} - Renaming old real directory '$gdir' to '${gdir}_OLD', to make place for a symlink into '$DSTPFX'"
							mv "$gdir" "${gdir}_OLD"
						else
							DSTL="$DSTPFX/$DRCU/$STUS/$ADLOLO/${gdir##*/}"
							prepModGameSym "$DSTL" "$gdir"
						fi
					fi
				done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$ADLOLO" -mindepth 1 -maxdepth 1 -not -empty '(' -type d -o -type l -xtype d ')')"
			fi

			if [ -d "$SRCPFX/$DRCU/$STUS/$ADLO/LOOT" ]; then
				while read -r gdir; do
					DSTL="$MODLOOT/${gdir##*/}"
					prepModGameSym "$DSTL" "$gdir"
				done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$ADLO/LOOT" -mindepth 1 -maxdepth 1 -not -empty '(' -type d -o -type l -xtype d ')')"
			fi

			if [ -d "$SRCPFX/$DRCU/$STUS/$LSAD" ]; then
				while read -r gdir; do
					if [ "${gdir##*/}" != "openvr" ] && [ "${gdir##*/}" != "Microsoft" ] ; then
						DSTL="$DSTPFX/$DRCU/$STUS/$ADLO/${gdir##*/}"
						prepModGameSym "$DSTL" "$gdir"
					fi
				done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$LSAD" -mindepth 1 -maxdepth 1 -not -empty '(' -type d -o -type l -xtype d ')')"
			fi

			if [ -d "$SRCPFX/$DRCU/$STUS/$SAGE/$CDPR" ]; then
				mkProjDir "$DSTPFX/$DRCU/$STUS/$SAGE/$CDPR"
				while read -r gdir; do
						DSTL="$DSTPFX/$DRCU/$STUS/$SAGE/$CDPR/${gdir##*/}"
						prepModGameSym "$DSTL" "$gdir"
				done <<< "$(find -L "$SRCPFX/$DRCU/$STUS/$SAGE/$CDPR" -mindepth 1 -maxdepth 1 -not -empty '(' -type d -o -type l -xtype d ')')"
			fi

			MSREG="$SRCPFX/$SREG"
			if [ -f "$MSREG" ]; then
				if grep -qi "^\"installed path\"=" "$MSREG"; then
					MODGREG="$STLSHM/modgames.reg"
					if [ ! -f "$MODGREG" ]; then
						echo "Windows Registry Editor Version 5.00" > "$MODGREG"
					fi
					MEFD="$(getGameDirFromAM "$CHKAPMA")"
					if [ -d "$MEFD" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Game Dir is '$MEFD' - adding the windows variant into the registry, because it is required for this game"
						grep -i -B2 "^\"installed path\"=" "$MSREG" | grep -v "^#\|LastKey\|CurrentVersion\|^--" | head -n1 | sed "s:^\[Software:\[HKEY_LOCAL_MACHINE\\\Software:" | sed "s:\\\\Wow6432Node::" >> "$MODGREG"
						# the path could be grepped as well, but at least two games had the Steamworks Shared path in the reg value instead here
						printf "\"installed path\"=\"Z:%s\\\\\"\n" "${MEFD//\//\\\\}" >> "$MODGREG"
					else
						writelog "SKIP" "${FUNCNAME[0]} - Game Dir '$MEFD' not found"
					fi
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - '$MSREG' not found"
			fi
		fi
	fi
}

function listWinSteamLibraries {
	listSteamLibraries

	unset SLARR
	SL1="${SROOT%*/}"
	mapfile -t -O "${#SLARR[@]}" SLARR <<< "$SL1"

	while read -r line; do
		W1="${line//\/steamapps/}"
		mapfile -t -O "${#SLARR[@]}" SLARR <<< "$W1"
	done < "$STELILIST"

	unset SLARRU
	while IFS= read -r SLC; do
		if ! grep -qx "$SLC" <<< "$(printf "%s\n" "${SLARRU[@]-}")"; then
			mapfile -t -O "${#SLARRU[@]}" SLARRU <<< "$SLC"
		fi
	done <<< "$(printf "%s\n" "${SLARR[@]-}")"

	COUNTER=1
	for W1 in "${SLARRU[@]}"; do
		W2="${W1//\//\\\\}"
		echo "\"$COUNTER\" \"Z:$W2\""
		COUNTER=$((COUNTER+1))
	done
}

function installDotNet {
	INSTPFX="$1"
	INSTWINE="$2"
	if [ -n "$3" ]; then
		DNVER="$3"
	else
		DNVER="48"
	fi
	LOGSUFFIX=" ${4}"
	DNFORCE="$5"
	chooseWinetricks
	ILOG="$STLSHM/installDotNet.log"
	DNLOGPRETTYNAME="${ILOG}${LOGSUFFIX}"  # Mainly used for HMM game install logs
	rm "${ILOG}${LOGNAME}" 2>/dev/null

	# Experiment -- Add option to 'force' dotnet install (idea here is to fix dotnet48 failing)
	# Adding --force will force it to always be installed for a given prefix, even if it is already installed  -- May not even fix issues, but could
	writelog "INFO" "${FUNCNAME[0]} - Starting $DOTN$DNVER install - check ${DNLOGPRETTYNAME}"
	if [ -z "$DNFORCE" ]; then
		writelog "INFO" "${FUNCNAME[0]} - WINEDEBUG=\"-all\" WINEPREFIX=\"$INSTPFX\" WINE=\"$INSTWINE\" \"$WINETRICKS\" --unattended \"$DOTN$DNVER\""

		WINEDEBUG="-all" WINEPREFIX="$INSTPFX" WINE="$INSTWINE" "$WINETRICKS" --unattended "$DOTN$DNVER" >> "${DNLOGPRETTYNAME}"
	else
		writelog "INFO" "${FUNCNAME[0]} - WINEDEBUG=\"-all\" WINEPREFIX=\"$INSTPFX\" WINE=\"$INSTWINE\" \"$WINETRICKS\" --force --unattended \"$DOTN$DNVER\""

		WINEDEBUG="-all" WINEPREFIX="$INSTPFX" WINE="$INSTWINE" "$WINETRICKS" --force --unattended "$DOTN$DNVER" >> "${DNLOGPRETTYNAME}"
	fi

	# WINEDEBUG="-all" WINEPREFIX="$INSTPFX" WINE="$INSTWINE" "$WINETRICKS" --unattended "$DOTN$DNVER" >> "${ILOG}${LOGSUFFIX}"
	writelog "INFO" "${FUNCNAME[0]} - Stopped $DOTN$DNVER install - check ${DNLOGPRETTYNAME}"
}

function updateWineRegistryKey {
	REGOP="$1"  # i.e. "add", "delete"
	REGPATH="$2"
	REGVAL="$3"
	WINEPFX="$4"
	WINERUNCMD="$5"

	writelog "INFO" "${FUNCNAME[0]} - Removing key '$REGVAL' from '$REGPATH' using '$WINERUNCMD'"
	WINEPREFIX="$WINEPFX" "$WINERUNCMD" reg "${REGOP}" "${REGPATH}" "/v" "${REGVAL}" "/f"
}

