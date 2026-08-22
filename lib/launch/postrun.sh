#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function writeLastRun {
	writelog "INFO" "${FUNCNAME[0]} - Recreating $LASTRUN"
	{
	echo "RUNPROTON=\"$RUNPROTON\""
	echo "RUNWINE=\"$RUNWINE\""
	echo "PROTONVERSION=\"$PROTONVERSION\""
	echo "PREVAID=\"$AID\""
	echo "PREVGAME=\"$GN\""
	echo "PREVABSGAMEEXEPATH=\"$ABSGAMEEXEPATH\""
	} >	"$LASTRUN"
}

function storeMetaData {
	MAID="$1"
	MGNA1="${2//\//_}"
	MGNA="${MGNA1//\"/}"
	MPFX="$3"
	GDIR="$4"

	writelog "INFO" "${FUNCNAME[0]} - Saving metadata for game '$MGNA ($MAID)'"

	if [ ! -f "$GEMETA/$MAID.conf" ]; then
		if [ "$SGDBAUTODL" == "no_meta" ] ; then
			writelog "INFO" "${FUNCNAME[0]} - Automatic Grid Update Check '$SGDBAUTODL'"
			# getGrids "$MAID"
			commandlineGetSteamGridDBArtwork --search-id="$MAID" --steam
		fi
		touch "$GEMETA/$MAID.conf"
	fi

	loadCfg "$GEMETA/$MAID.conf" X
	updateConfigEntry "GAMEID" "$MAID" "$GEMETA/$MAID.conf"

	if [ -z "$KEEPGAMENAME" ] || [ "$KEEPGAMENAME" -eq 0 ] || [ "$GAMENAME" == "$NON" ]; then
		updateConfigEntry "GAMENAME" "$MGNA" "$GEMETA/$MAID.conf"
	fi

	if [ -n "$GE" ] && [ -z "$GAMEEXE" ]; then
		GAMEEXE="$GE"
	fi

	if [ -n "$GAMEEXE" ]; then
		updateConfigEntry "GAMEEXE" "$GAMEEXE" "$GEMETA/$MAID.conf"
	fi

	if [ -n "$GP" ]; then
		updateConfigEntry "GAMEARCH" "$(getArch "$GP")" "$GEMETA/$MAID.conf"
	fi

	if [ ! -f "$CUMETA/$MAID.conf" ]; then
		touch "$CUMETA/$MAID.conf"
	fi
	loadCfg "$CUMETA/$MAID.conf" X

	if [ "$MPFX" != "$NON" ]; then
		updateConfigEntry "WINEPREFIX" "$MPFX" "$CUMETA/$MAID.conf"
	fi

	updateConfigEntry "MEGAMEDIR" "$GDIR" "$CUMETA/$MAID.conf"

	if [ "$STLPLAY" -eq 1 ]; then
		touch "$FUPDATE"
		updateConfigEntry "STL_COMPAT_DATA_PATH" "$STEAM_COMPAT_DATA_PATH" "$CUMETA/$MAID.conf"
	fi
	createSymLink "${FUNCNAME[0]}" "$GEMETA/$MAID.conf" "$TIGEMETA/${MGNA}.conf" X
	createSymLink "${FUNCNAME[0]}" "$CUMETA/$MAID.conf" "$TICUMETA/${MGNA}.conf" X

	if [ "$STLPLAY" -eq 0 ]; then
		createSymLink "${FUNCNAME[0]}" "$EVMETAID/${EVALSC}_${MAID}.vdf" "$EVMETATITLE/${EVALSC}_${MGNA}.vdf"
	fi
}

function delMenuTemps {
	find "$STLSHM" -maxdepth 1 -type f -regextype posix-extended -regex '^.*menu.[A-Z,a-z,0-9]{8}' -exec rm {} \;
}

function delWinetricksTemps {
	# cosmetics - GE leaves empty winetricks directories back, removing them
	find "/tmp" -maxdepth 1 -type d -regextype posix-extended -regex '^.*winetricks.[A-Z,a-z,0-9]{8}' -exec rmdir {} \;	2>/dev/null
}

function cleanSUTemp {
	if [ "$ISGAME" -eq 2 ] && [ "$CLEANPROTONTEMP" -eq 1 ]; then
		PFXSUTEMP="$GPFX/$DRCU/$STUS/Temp"
		if [ -d "$PFXSUTEMP" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Cleaning up Temp directory '$PFXSUTEMP'"
			rm -rf "${PFXSUTEMP:?}"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Temp directory '$PFXSUTEMP' exists, but is empty"
		fi
	fi
}

function restoreSteamUser {

	function startRestore {
		writelog "INFO" "${FUNCNAME[0]} - Restoring backup from '$BACKUPSRC' to '$SteamUserDir'"
		notiShow "$(strFix "$NOTY_STARTRESTORE" "$BACKUPSRC" "$AID")"
		mkProjDir "$SteamUserDir"
		"$RSYNC" -am "$BACKUPSRC" "$SteamUserDir"
		notiShow "$(strFix "$NOTY_STOPRESTORE" "$SteamUserDir")"
	}

	function startRestoreBecause {
		writelog "INFO" "${FUNCNAME[0]} - Restoring, because '$RSTUS' is set"
		startRestore
	}

	function askRestore {
		writelog "INFO" "${FUNCNAME[0]} - Asking if $STUS data from '$BACKUPSRC' shall be restored to '$SteamUserDir'"

		export CURWIKI="$PPW/Backup Support"
		TITLE="${PROGNAME}-Ask_Restore_SteamUser_data"
		pollWinRes "$TITLE"

		"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center --on-top "${WINDECO[@]}" \
		--title="$TITLE" \
		--text="$(spanFont "$(strFix "$GUI_AR" "$BACKUPSRC" "$SteamUserDir")" "H")\n<i>$1</i>" "$GEOM"
		case $? in
			0) 	{
					writelog "INFO" "${FUNCNAME[0]} - Restoring '$SteamUserDir' from '$BACKUPSRC' confirmed"
					startRestore
				}
			;;
			1)	{
					writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL - Not restoring '$BACKUPSRC' to '$SteamUserDir'"
				}
			;;
		esac
	}

	if [ -n "$1" ] && [ "$1" != "$NON" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using value '$1' from argument for RESTORESTEAMUSER"
		RSTUS="$1"
	else
		writelog "INFO" "${FUNCNAME[0]} - Using configured value '$RESTORESTEAMUSER' for RESTORESTEAMUSER"
		RSTUS="$RESTORESTEAMUSER"
	fi

	SteamUserDir="$GPFX/$DRCU/$STUS"
	BACKUPSRC="$SUBADIRID/$AID/$STUS/"

	if [ "$RSTUS" == "$NON" ] ; then
		writelog "INFO" "${FUNCNAME[0]} - Restoration of $STUS data is disabled with RESTORESTEAMUSER being '$RSTUS"
	else
		if [ -n "$AID" ] && [ -d "$BACKUPSRC" ] && [ -d "$GPFX" ]; then
			if [ "$RSTUS" == "ask-always" ] ; then
				askRestore "$GUI_AR_ALWAYSASK"
			elif [ "$RSTUS" == "restore-always" ] ; then
				startRestoreBecause
			elif [ ! -f "$SteamUserDir/$BTS" ] ; then
				if [ "$RSTUS" == "ask-if-dst-has-no-backup-timestamp" ] ; then
					askRestore "$GUI_AR_ASKNODSTTS"
				elif [ "$RSTUS" == "restore-if-dst-has-no-backup-timestamp" ] ; then
					startRestoreBecause
				elif [ "$RSTUS" == "restore-if-dst-is-empty" ]; then
					if [ ! -d "$SteamUserDir" ] || [ "$(find "$SteamUserDir" -type f | wc -l)" -eq 0 ]; then
						startRestoreBecause
					elif [ "$RSTUS" == "ask-if-unsure" ] ; then
						askRestore "$GUI_AR_ALWAYSASK"
					fi
				elif [ "$RSTUS" == "ask-if-unsure" ] ; then
					askRestore "$GUI_AR_ASKUNSURE"
				fi
			elif [ -f "$BACKUPSRC/$BTS" ] && [ -f "$SteamUserDir/$BTS" ]; then
				if [ "$(cat "$BACKUPSRC/$BTS")" -gt "$(cat "$SteamUserDir/$BTS")" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Data in '$BACKUPSRC' is newer than in '$SteamUserDir'"
					if [ "$RSTUS" == "restore-if-backup-timestamp-is-newer" ] ; then
						startRestoreBecause
					elif [ "$RSTUS" == "ask-if-unsure" ] ; then
						askRestore "$GUI_AR_ALWAYSASK"
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - Data in '$BACKUPSRC' is older than in '$SteamUserDir'"
					if [ "$RSTUS" == "ask-if-unsure" ]; then
						askRestore "$GUI_AR_ASKUNSURE"
					elif [ "$RSTUS" == "restore-always" ]; then
						startRestoreBecause
					fi
				fi
			elif [ "$RSTUS" == "ask-if-unsure" ] ; then
				askRestore "$GUI_AR_ASKUNSURE"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Have to skip - this should never happen. RESTORESTEAMUSER is '$RSTUS'"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - At least one of AID '$AID', BACKUPSRC '$BACKUPSRC', SteamUserDir '$SteamUserDir' is missing - can't start restoration of $STUS data"
		fi
	fi
}

function backupSteamUser {
	if [ "$BACKUPSTEAMUSER" -eq 1 ]; then
		BAID="$1"

		if [ -n "$GN" ]; then
			BACKTI="$GN"
		else
			getGameName "$BAID"
			if [ -n "$GAMENAME" ] && [ "$GAMENAME" != "$NON" ]; then
				BACKTI="$GAMENAME"
			fi
		fi

		if [ -n "$2" ]; then
			if [ -d "$2" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Using argument 2 '$2' as WINEPREFIX'"
				GPFX="$2"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Directory in argument 2 '$2' does not exist"
				GPFX=""
			fi
		fi

		setGPfxFromAppMa "$BAID"

		if [ -z "$GPFX" ]; then
			if [ -f "$CUMETA/$BAID.conf" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Loading metadata config '$CUMETA/$BAID.conf'"
				loadCfg "$CUMETA/$BAID.conf" X
				if [ -d "$WINEPREFIX" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Searching in stored metadata WINEPREFIX '$WINEPREFIX' for files to backup"
					GPFX="$WINEPREFIX"
				else
					writelog "SKIP" "${FUNCNAME[0]} - Stored metadata WINEPREFIX '$WINEPREFIX' does not exist"
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - No metadata config '$CUMETA/$BAID.conf' found to search for the WINEPREFIX"
				GPFX=""
			fi
		fi

		if [ -z "$GPFX" ]; then
			if [ -z "$BACKTI" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - Game pfx unknown for '$BAID'"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Game pfx unknown for '$BACKTI ($BAID)'"
			fi
		else
			if [ -z "$2" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Backup enabled for Game '$BACKTI ($BAID)'"
			fi
			mkProjDir "$SUBADIRID/$BAID"
			mkProjDir "$SUBADIRTI"
			SteamUserDir="$GPFX/$DRCU/$STUS"

			if [ -d "$SteamUserDir" ]; then
				writelog "INFO" "${FUNCNAME[0]} - backing up directory '$SteamUserDir' to '$SUBADIRID/$BAID'"
				if [ -z "$2" ]; then
					notiShow "$(strFix "$NOTY_STARTBACKUP" "$BACKTI" "$BAID")"
				fi
				mkProjDir "$BACKEX"

				EXID="$BACKEX/exclude-${BAID}.txt"
				touch "$EXGLOB" "$EXID"
				"$RSYNC" -am --exclude-from="$EXGLOB" --exclude-from="$EXID" "$SteamUserDir" "$SUBADIRID/$BAID"
				date +%s > "$SUBADIRID/$BAID/$STUS/$BTS"

				if [ -z "$2" ]; then
					notiShow "$(strFix "$NOTY_STOPBACKUP" "$BACKTI" "$BAID")"
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - directory '$SteamUserDir' does not exist - nothing to backup"
			fi

			if [ -z "$BACKTI" ]; then
				if [ -z "$2" ]; then
					writelog "SKIP" "${FUNCNAME[0]} - Skipping symlinking backup - no valid game name found"
				fi
			else
				createSymLink "${FUNCNAME[0]}" "$SUBADIRID/$BAID" "$SUBADIRTI/$BACKTI"
			fi
		fi
	fi
}

function backupSteamUserGate {
	BACKUPSTEAMUSER=1
	if [ "$1" != "all" ]; then
		backupSteamUser "$1"
	else
		LOGFILE="$TEMPLOG"
		writelog "INFO" "${FUNCNAME[0]} - Selected to backup all '$STUS' files from all found pfxes"

		while read -r APPMA; do
			AMF="${APPMA##*/}"
			BAID="$(cut -d'_' -f2 <<< "$AMF" | cut -d'.' -f1)"
			BPFX="$(dirname "$APPMA")/$CODA/$BAID/pfx"
			if [ -d "$BPFX" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Backup all '$STUS' files for pfx '$BPFX'"
				backupSteamUser "$BAID" "$BPFX"
			fi
		done <<< "$(listAppManifests)"
	fi
}

function createMetaData {
	LASTMETAUP="$METADIR/lastmeta.txt"
	MAXMETAAGE=1440

	if [ -n "$1" ] && [ "$1" == "yes" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Updating metadata requested via command line"
		rm "$LASTMETAUP"
	fi

	if [ ! -f "$LASTMETAUP" ] || test "$(find "$LASTMETAUP" -mmin +"$MAXMETAAGE")"; then
		writelog "INFO" "${FUNCNAME[0]} - Creating/Updating metadata for all installed games found"

		while read -r APPMA; do
			AMF="${APPMA##*/}"
			MAID="$(cut -d'_' -f2 <<< "$AMF" | cut -d'.' -f1)"

			GNRAW="$(grep "\"name\"" "$APPMA" | awk -F '"name"' '{print $NF}')"
			GNAM="$(awk '{$1=$1};1' <<< "$GNRAW")"
			GDIR="$(getGameDirFromAM "$APPMA")"
			MPFX="$(dirname "$APPMA")/$CODA/$MAID/pfx"

			storeMetaData "$MAID" "$GNAM" "$MPFX" "$GDIR"
		done <<< "$(listAppManifests)"
		writelog "INFO" "${FUNCNAME[0]} - Done with Creating/Updating metadata"
		date +%y-%m-%d > "$LASTMETAUP"
	fi
}

