#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function dlLatestDprs {
	writelog "INFO" "${FUNCNAME[0]} - Search for latest $DPRS version online"
	LATDPRS="$("$WGET" -q "${DPRSRELURL}/latest" -O - 2> >(grep -v "SSL_INIT") | grep -m1 "${DPRS}-v*.*.exe" | grep -oE "${DPRS}-v[^\"]+")"

	if [ -n "$LATDPRS" ]; then
		DSPATH="$DPRSDLDIR/$LATDPRS"

		if [ ! -f "$DSPATH" ]; then
			DPRSVR1="${LATDPRS//$DPRS-}"
			DPRSVRS="${DPRSVR1//.exe}"

			DLURL="$DPRSRELURL/download/$DPRSVRS/$LATDPRS"
			writelog "INFO" "${FUNCNAME[0]} - Downloading $LATDPRS to $VORTEXDLDIR from '$DLURL'"
			notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$LATDPRS")"
			dlCheck "$DLURL" "$DSPATH" "X" "Downloading '$LATDPRS'"
			notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$LATDPRS")"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Already have the latest version in '$DSPATH'"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - No valid '$DPRS' version found ('$LATDPRS') - nothing to download - skipping"
	fi
}

function dlLatestDepsProg {
	writelog "INFO" "${FUNCNAME[0]} - Search for latest $DEPS version online"
	DEPS64ZIP="${DEPS}_x64_Release.zip"
	DEPS32ZIP="${DEPS64ZIP//64/86}"

	LATDEPSR1="$("$WGET" -q "${DEPURL}/latest" -O - 2> >(grep -v "SSL_INIT") | grep -m1 "$DEPS64ZIP")"
	LATDEPSR2="${LATDEPSR1%/*}"
	LATDEPSV="${LATDEPSR2##*/}"

	if [ -n "$LATDEPSV" ]; then
		DLDIR="$DEPSDLDIR/$LATDEPSV"

		if [ -s "$DEPSLATDIR" ] && [ "$(readlink -f "$DEPSLATDIR")" == "$(readlink -f "$DLDIR")" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Symlink '$DEPSLATDIR' already points to latest version '$DLDIR'" E
		else
			mkProjDir "$DLDIR/64"
			mkProjDir "$DLDIR/32"
			DEPS64ZPATH="$DLDIR/$DEPS64ZIP"
			DEPS32ZPATH="$DLDIR/$DEPS32ZIP"

			if [ ! -f "$DEPS64ZPATH" ]; then
				DLURL="$DEPURL/download/$LATDEPSV/$DEPS64ZIP"
				writelog "INFO" "${FUNCNAME[0]} - Downloading $DEPS64ZIP to '$DLDIR' from '$DLURL'"
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$DEPS64ZIP")" "S"
				dlCheck "$DLURL" "$DEPS64ZPATH" "X" "Downloading '$DEPS64ZIP'"
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$DEPS64ZIP")" "S"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Already have '$DEPS64ZIP' in '$DLDIR'"
			fi

			if [ ! -f "$DEPS32ZPATH" ]; then
				DLURL="$DEPURL/download/$LATDEPSV/$DEPS32ZIP"
				writelog "INFO" "${FUNCNAME[0]} - Downloading $DEPS32ZIP to '$DLDIR' from '$DLURL'"
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON" "$DEPS64ZIP")" "S"
				dlCheck "$DLURL" "$DEPS32ZPATH" "X" "Downloading '$DEPS32ZIP'"
				notiShow "$(strFix "$NOTY_DLCUSTOMPROTON2" "$DEPS64ZIP")" "S"
			else
				writelog "SKIP" "${FUNCNAME[0]} - Already have '$DEPS32ZIP' in '$DLDIR'"
			fi

			rm "$DEPSLATDIR" 2>/dev/null
			writelog "INFO" "${FUNCNAME[0]} - 'ln -s \"$DLDIR\" \"$DEPSLATDIR\"'" E
			ln -s "$DLDIR" "$DEPSLATDIR"

			if [ ! -f "$DEPSL64" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Extracting $DEPS64ZIP to '$DLDIR/64'"
				"$UNZIP" -q "$DEPS64ZPATH" -d "$DLDIR/64"
				notiShow "$GUI_DONE" "S"
			fi

			if [ ! -f "$DEPSL32" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Extracting $DEPS32ZIP to '$DLDIR/32'"
				"$UNZIP" -q "$DEPS32ZPATH" -d "$DLDIR/32"
				notiShow "$GUI_DONE" "S"
			fi
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - No valid '$DEPS' version found ('$LATDPRS') - nothing to download - skipping"
	fi
}

function checkDepsLaunch {
	if [ "$RUN_DEPS" -eq 1 ] && [ "$ISGAME" -eq 2 ] && [ "$USEWINE" -eq 0 ]; then

		if [ "$DEPSAUTOUP" -eq 1 ] || [ ! -f "$DEPSL64" ]; then
			StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "$DEPS")" "dlLatestDepsProg" "DownloadDepsStatus"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Starting '$DEPS' for '$GE ($AID)'"

		if [ "$(getArch "$GP")" == "32" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using '$DEPSL32' as '$GE' is 32bit"
			DEPSEXE="$DEPSL32"
		elif [ "$(getArch "$GP")" == "64" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using '$DEPSL64' as '$GE' is 64bit"
			DEPSEXE="$DEPSL64"
		else
			writelog "INFO" "${FUNCNAME[0]} - Could not get architecture of '$GP' - using '$DEPSL64'"
			DEPSEXE="$DEPSL64"
		fi

		if [ ! -f "$DEPSEXE" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Installing failed - can't start '$DEPSEXE' - skipping"
			RUN_DEPS=0
		else
			WGP="$(extWine64Run "$RUNWINE" winepath -w "$GP")"
			writelog "INFO" "${FUNCNAME[0]} - Starting '$DEPSEXE' using extWine64Run for the game '$WGP'"
			extWine64Run "$RUNWINE" "$DEPSEXE" "$WGP"
		fi
	fi
}

function startDepressurizer {
	if [ ! -d "$DPRSCOMPDATA" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Creating '$DPRS' $CODA and installing deps"
		mkProjDir "$DPRSCOMPDATA"
		reCreateCompatdata "ccd" "$DPRS" "s"
	fi

	mkProjDir "$DPRSDLDIR"
	if [ "$DPRSPAUTOUP" -eq 1 ]; then
		dlLatestDprs
	fi

	DPRSEXE="$(find "${DPRSDLDIR}" -name "${DPRS}-v*.exe" | sort -V | tail -n1)"

	if [ ! -f "$DPRSEXE" ] || { [ "$(getArch "$DPRSEXE")" -ne "32" ] && [ "$(getArch "$DPRSEXE")" -ne "64" ];}; then
		dlLatestDprs
		DPRSEXE="$(find "${DPRSDLDIR}" -name "${DPRS}-v*.exe" | sort -V | tail -n1)"
	fi

	if [ ! -f "$DPRSEXE" ]; then
		writelog "ERROR" "${FUNCNAME[0]} - Could not find or download a '$DPRS' exe"
	else

	# copy or symlink required vdf files from steam to the DPRSCOMPDATA

	DPRSPFX="${DPRSCOMPDATA//\"/}/pfx"
	VDFDSTDIR="$DPRSPFX/$DRC/$PFX86S"

	if [ -z "$SUSDA" ] || [ -z "$STUIDPATH" ]; then
		setSteamPaths
	fi
	SC="$STUIDPATH/$SRSCV"
	FSCV="$STUIDPATH/config/$SCVDF"

	AIDST="$VDFDSTDIR/$AAVDF"
	PIDST="$VDFDSTDIR/$APVDF"
	SRSDST="$VDFDSTDIR/$USDA/$STEAMUSERID/$SRSCV"
	SRLDST="$VDFDSTDIR/$USDA/${FLCV//$SUSDA\/}"
	SCDST="$VDFDSTDIR/$USDA/${FLCV//$SUSDA\/}"
	SCSHDST="$VDFDSTDIR/$USDA/$STEAMUSERID/$SCRSH"

	AISRC="$FAIVDF"
	PISRC="$PIVDF"
	SRSSRC="$STUIDPATH/$SRSCV"
	SRLSRC="$FLCV"
	SCSRC="$STUIDPATH/config/$SCVDF"
	SCSHSRC="$STUIDPATH/$SCRSH"

	{
		echo "SC $SC"
		echo "FLCV $FLCV"
		echo "FSCV $FSCV"
		echo "AIDST $AIDST"
		echo "PIDST $PIDST"
		echo "SRSDST $SRSDST"
		echo "SRLDST $SRLDST"
		echo "SCDST $SCDST"
		echo "SCSHDST $SCSHDST"
		echo "AISRC $AISRC"
		echo "PISRC $PISRC"
		echo "SRSSRC $SRSSRC"
		echo "SRLSRC $SRLSRC"
		echo "SCSRC $SCSRC"
		echo "SCSHSRC $SCSHSRC"
	} > "$STLSHM/${DPRS}-paths.txt"

	function cleanCpSrcTo {
		if [ -f "$1" ]; then
			mkProjDir "${2%/*}"
			if ! cmp -s "$1" "$2" || [ -L "$2" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Copying '$1' to '$2'"
				rm "$2" 2>/dev/null
				cp "$1" "$2"
			else
				writelog "SKIP" "${FUNCNAME[0]} - '$2' is identical to '$1'"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Source file '$1' not found"
		fi
	}

	function cleanLnSrcTo {
		if [ -f "$1" ]; then
			mkProjDir "${2%/*}"
			if [ "$(readlink -f "$2")" == "$(readlink -f "$1")" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - '$2' is already pointing to '$1'"
			else
				writelog "INFO" "${FUNCNAME[0]} - Symlinking '$1' to '$2'"
				rm "$2" 2>/dev/null
				ln -s "$1" "$2"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Source file '$1' not found"
		fi
	}

	if [ "$DPRSUSEVDFSYMLINKS" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Symlinking required vdf files from the linux steam install into '$DPRSCOMPDATA'"
		cleanLnSrcTo "$AISRC" "$AIDST"
		cleanLnSrcTo "$PISRC" "$PIDST"
		cleanLnSrcTo "$SRSSRC" "$SRSDST"
		cleanLnSrcTo "$SRLSRC" "$SRLDST"
		cleanLnSrcTo "$SCSRC" "$SCDST"
		cleanLnSrcTo "$SCSHSRC" "$SCSHDST"
	elif [ "$DPRSUSEVDFSYMLINKS" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Copying required vdf files from the linux steam install to '$DPRSCOMPDATA'"
		cleanCpSrcTo "$AISRC" "$AIDST"
		cleanCpSrcTo "$PISRC" "$PIDST"
		cleanCpSrcTo "$SRSSRC" "$SRSDST"
		cleanCpSrcTo "$SRLSRC" "$SRLDST"
		cleanCpSrcTo "$SCSRC" "$SCDST"
		cleanCpSrcTo "$SCSHSRC" "$SCSHDST"
	else
		writelog "WARN" "${FUNCNAME[0]} - DPRSUSEVDFSYMLINKS is neither '1' nor '0' - this shouldn't happen!"
	fi

	# start $DPRS via proton starting here

		writelog "INFO" "${FUNCNAME[0]} - Using Proton Version '$USEDPRSPROTON'"

		if test -z "$DPRSPROTON" || [ ! -f "$DPRSPROTON" ]; then
			if [ -z "${ProtonCSV[0]}" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Don't have the Array of available Proton versions yet - creating"
				getAvailableProtonVersions "up" X
			fi
			DPRSPROTON="$(getProtPathFromCSV "$USEDPRSPROTON")"
		fi

		if [ ! -f "$DPRSPROTON" ]; then
			DPRSPROTON="$(fixProtonVersionMismatch "USEDPRSPROTON" "$STLGAMECFG" X)"
		fi

		if [ ! -f "$DPRSPROTON" ]; then
			writelog "WARN" "${FUNCNAME[0]} - proton file '$DPRSPROTON' for proton version '$USEDPRSPROTON' not found - trying 'USEPROTON' instead"
			DPRSPROTON="$(getProtPathFromCSV "$USEPROTON")"
		fi

		CHECKWINED="$(dirname "$DPRSPROTON")/$DBW"
		CHECKWINEF="$(dirname "$DPRSPROTON")/$FBW"
		if [ -f "$CHECKWINED" ]; then
			DPRSWINE="$CHECKWINED"
		elif [ -f "$CHECKWINEF" ]; then
			DPRSWINE="$CHECKWINEF"
		fi

		if [ -f "$DPRSWINE" ];then
			writelog "INFO" "${FUNCNAME[0]} - Starting '$DPRSEXE' using '$DPRSWINE'"
			DPRSWINEDEBUG="-all"
			DPRSSUDIR="$DPRSPFX/$DRCU/$STUS/$APDA/$DPRS"
			mkProjDir "$DPRSSUDIR"
			cd "$DPRSSUDIR" >/dev/null || return
			sleep 1
			# LC_ALL="C" was previously used here, but may not be required anymore
			PATH="$STLPATH" LD_LIBRARY_PATH="" LD_PRELOAD="" WINE="$DPRSWINE" WINEARCH="win64" WINEDEBUG="$DPRSWINEDEBUG" WINEPREFIX="$DPRSPFX" "$DPRSWINE" "$DPRSEXE" >/dev/null 2>/dev/null
			cd - >/dev/null || return
		else
			writelog "ERROR" "${FUNCNAME[0]} - Proton Wine for not found - can't start '$DPRSEXE'"
		fi
	fi
}

function checkDep {
	CATNAM="$1"
	CHECKPROG="$2"

	if [ -n "${!CATNAM##*[!0-9]*}" ]; then
		if [ "${!CATNAM}" -eq 1 ]; then
			if [ ! -x "$(command -v "$CHECKPROG")" ]; then
				writelog "WARN" "${FUNCNAME[0]} - Disabling '$CATNAM' because '$CHECKPROG' is missing"
				notiShow "$(strFix "$NOTY_PROGRAMMISSING" "$CATNAM" "$CHECKPROG")"
				unset "$CATNAM"
			fi
		fi
	fi
}

function checkExtDeps {
	if [ -z "$NOTY" ]; then
		NOTY="notify-send"
	fi

	checkDep "USEGAMEMODERUN" "$GAMEMODERUN"
	checkDep "USEGAMESCOPE" "$GAMESCOPE"
	checkDep "RUN_NYRNA" "$NYRNA"
	checkDep "STRACERUN" "$STRACE"
	checkDep "RUN_WINETRICKS" "$WINETRICKS"
	checkDep "WINETRICKSPAKS" "$WINETRICKS"
	checkDep "RUN_REPLAY" "$REPLAY"
	checkDep "USELUXTORPEDA" "$LUXTORPEDACMD"
	checkDep "USEROBERTA" "$ROBERTACMD"
	checkDep "USEBOXTRON" "$BOXTRONCMD"
	checkDep "RUNSBSVR" "$VRVIDEOPLAYER"
	checkDep "USENETMON" "$NETMON"
	checkDep "USENOTIFIER" "$NOTY"
	checkDep "CHECKHMD" "$LSUSB"
	checkDep "BACKUPSTEAMUSER" "$RSYNC"
	checkDep "USESPECIALK" "$SEVZA"
	checkDep "USEMANGOAPP" "$MANGOAPP"
	checkDep "USEOBSCAP" "$OBSCAP"
}

function getLatestYadAppImage {
	# Probe GitHub for the newest Yad AppImage release name, so we don't hardcode an old version
	# Prints nothing if the probe fails and the caller can fall back to a known-good default
	local YADLATEST
	YADLATEST="$("$WGET" -q --timeout=10 "${AGHURL}/repos/sonic2kk/steamtinkerlaunch-tweaks/releases/latest" -O - 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -n1 | cut -d '"' -f4)"
	if [ -n "$YADLATEST" ] && grep -qi "\.appimage$" <<< "$YADLATEST"; then
		echo "$YADLATEST"
	fi
}

function setYadBin {
	local YADINSTLDLDIR
	local YADINSTLDEPS

	function findYad {
		SEARCHDIR="$1"

		for f in "$SEARCHDIR"/*
		do
			MATCHFILE="$( basename "$f" | grep -ioE "(.*yad).*\.appimage$" )"
			if [ -f "$SEARCHDIR/$MATCHFILE" ]; then
				echo "$MATCHFILE"
				return
			fi
		done
	}

	if [ -f "$1" ]; then
		YADFILE="$1"
	elif [ "$1" == "conty" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using conty as yad binary"
		if [ ! -f "$CONTYDLDIR/$CONTY" ]; then
			StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${CONTY%%.*}")" "dlConty" "DownloadContyStatus"
		else
			writelog "INFO" "${FUNCNAME[0]} - Found Conty binary in '$CONTYDLDIR/$CONTY'"
		fi

		if [ -f "$CONTYDLDIR/$CONTY" ]; then
			if [ "$(readlink "$CONTYDLDIR/$YAD")" == "$CONTYDLDIR/$CONTY" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Symlink '$CONTYDLDIR/$YAD' already points to '$CONTYDLDIR/$CONTY'"
			else
				writelog "INFO" "${FUNCNAME[0]} - Creating symlink '$CONTYDLDIR/${YAD##*/}' pointing to '$CONTYDLDIR/$CONTY'"
				ln -s "$CONTYDLDIR/$CONTY" "$CONTYDLDIR/${YAD##*/}"
			fi

			if [ "$(readlink "$CONTYDLDIR/${YAD##*/}")" == "$CONTYDLDIR/$CONTY" ]; then
				YADFILE="$CONTYDLDIR//${YAD##*/}"
			fi
		fi

	elif [ "$1" == "ai" ] || [ "$1" == "appimage" ]; then
		# YADSTLIMAGE="Yad-8418e37-x86_64.AppImage"
		# Probe for the latest release so we don't silently fall back to an old version, then use a known-good default
		YADSTLIMAGE="$(getLatestYadAppImage)"
		if [ -z "$YADSTLIMAGE" ]; then
			writelog "WARN" "${FUNCNAME[0]} - Could not determine latest Yad AppImage release, falling back to the default"
			YADSTLIMAGE="Yad-13.0-x86_64.AppImage"
		fi
		YAIDL="$YAIURL/$YADSTLIMAGE/$YADSTLIMAGE"
		YADAPPIMAGE="$YADSTLIMAGE"
		DLCHK="sha512sum"
		mkProjDir "$YADAIDLDIR"

		if [ -n "$2" ] && grep -q "^http" <<< "$2"; then
			YAIDL="$2"
			DLCHK="X"
			if grep -q "AppImage$" <<< "$YAIDL"; then
				YADAPPIMAGE="${YAIDL##*/}"
			else
				YADAPPIMAGE="Yad-$(date +%Y%m%d)-x86_64.AppImage"
			fi

			writelog "INFO" "${FUNCNAME[0]} - Trying to download $YAD from provided url '$YAIDL'"
		elif [ -n "$2" ] && [ -f "$2" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Trying to use provided file '$2' for yad"
			YAIDST="$2"
			DLCHK="X"
		elif [ -n "$2" ] && [ ! -f "$2" ]; then
			if [ "$2" == "sd" ]; then
				export ONSTEAMDECK=1
				YADAIDLDIR="$STLSDPATH"
				YAIDST="$YADAIDLDIR/$YADAPPIMAGE"
				YAIURL="$GHURL/sonic2kk/steamtinkerlaunch-tweaks/releases/download"
				YAIDL="$YAIURL/$YADSTLIMAGE/$YADSTLIMAGE"
				YADAPPIMAGE="$YADSTLIMAGE"

				# If offline and Yad isn't installed, try to find Yad somewhere sensible
				if [ "$INTERNETCONNECTION" -eq 0 ] && ! [ -f "$YAIDST" ]; then
					writelog "WARN" "${FUNCNAME[0]} - No internet connection, searching for locally saved Yad AppImage"
					echo "No internet connection, searching for locally saved Yad AppImage..."
					YADINSTLDLDIR="$( findYad "$STLDLDIR/yadappimage" )"
					YADINSTLDEPS="$( findYad "$STLDEPS" )"

					if [ -f "$STLDLDIR/yadappimage/$YADAPPIMAGE" ]; then
						# Yad in $HOME/.config/tinkergame/downloads with full matching name
						writelog "INFO" "${FUNCNAME[0]} - Found local Yad AppImage in '$STLDLDIR/yadappimage/$YADAPPIMAGE'"
						echo "Found local Yad AppImage in '$STLDLDIR/yadappimage/$YADAPPIMAGE'!"
						mv "$STLDLDIR/yadappimage/$YADAPPIMAGE" "$YAIDST" || steamDeckInstallFail
					elif [ -f "$STLDEPS/$YADAPPIMAGE" ]; then
						# Yad in $HOME/tg/deps with full matching name
						writelog "INFO" "${FUNCNAME[0]} - Found local Yad AppImage in '$STLDEPS/$YADAPPIMAGE'"
						echo "Found local Yad AppImage in '$STLDEPS/$YADAPPIMAGE'!"
						mv "$STLDEPS/$YADAPPIMAGE" "$YAIDST" || steamDeckInstallFail
					elif [ -n "$YADINSTLDLDIR" ]; then
						# Partial match for Yad in STLDLDIR but only with filename starting with `yad` and ending with `.appimage` (case insensitive)
						writelog "INFO" "${FUNCNAME[0]} - Found local Yad AppImage in '$STLDLDIR/yadappimage/$YADINSTLDLDIR'"
						echo "Found local Yad AppImage in '$STLDLDIR/yadappimage/$YADINSTLDLDIR'!"
						mv "$STLDLDIR/yadappimage/$YADINSTLDLDIR" "$YAIDST" || steamDeckInstallFail
					elif [ -n "$YADINSTLDEPS" ]; then
						# Partial match for Yad in STLDEPS but only with filename starting with `yad` and ending with `.appimage` (case insensitive)
						writelog "INFO" "${FUNCNAME[0]} - Found local Yad AppImage in '$STLDEPS/$YADINSTLDEPS'"
						echo "Found local Yad AppImage in '$STLDEPS/$YADINSTLDEPS'!"
						mv "$STLDEPS/$YADINSTLDEPS" "$YAIDST" || steamDeckInstallFail
					else
						# No match for Yad anywhere, offline installation will most likely fail
						# Some ISPs will fail the offline check even if a user is online, so we will attempt to download Yad anyway if we can't find it - This may be problematic though!
						# Here be dragons!
						writelog "ERROR" "${FUNCNAME[0]} - Cannot find locally saved Yad AppImage, will attempt to download from GitHub anyway - See #704"
						echo "Cannot find locally saved Yad AppImage, will attempt to download from GitHub anyway - See #704"
						# return 1;
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - Downloading default AppImage for SteamDeck to '$YADAIDLDIR'"
				fi
			else
				writelog "WARN" "${FUNCNAME[0]} - Provided string '$2' is neither a http download url nor a valid absolute path to a file - downloading and using the default instead"
			fi
		fi

		if [ -f "$YAIDST" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Using Yad AppImage under '$YAIDST'"
		else
			YAIDST="$YADAIDLDIR/$YADAPPIMAGE"
			if [ "$DLCHK" == "sha512sum" ]; then
				INCHK="$("$WGET" -q "${YAIDL}.${DLCHK}" -O - 2> >(grep -v "SSL_INIT") | cut -d ' ' -f1)"
			else
				INCHK="$NON"
			fi

			# Only show download notification if we didn't find local AppImage on Steam Deck
			if [ "$ONSTEAMDECK" -eq 1 ]; then
				notiShow "$( strFix "$NOTY_STEAMDECK_DEPSDOWNLOAD" "Yad" )" "X"
				strFix "$NOTY_STEAMDECK_DEPSDOWNLOAD" "Yad"
			fi

			# Yad Download
			dlCheck "$YAIDL" "$YAIDST" "$DLCHK" "Downloading '$YAIDL' to '$YAIDST'" "$INCHK"
		fi
		if [ -f "$YAIDST" ]; then
			YADFILE="$YAIDST"
		fi
	else
		writelog "ERROR" "${FUNCNAME[0]} - '$1' is no valid option"
	fi

	if [ -n "$YADFILE" ]; then
		MINYAD="7.2"
		chmod +x "$YADFILE" 2>/dev/null
		if [ "$ONSTEAMDECK" -eq 1 ]; then
			# skipping version check on SteamDeck, because the program might have been started via ssh, and yad requires a display
			writelog "INFO" "${FUNCNAME[0]} - Using '$YADFILE' on SteamDeck"
			if [ ! -f "$YADAIDLDIR/yad" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Creating symlink from '$YADFILE' to '$YADAIDLDIR/$YAD'"
				ln -s "$YADFILE" "$YADAIDLDIR/yad"
			fi
			touch "$FUPDATE"
			updateConfigEntry "YAD" "$YADAIDLDIR/yad" "$STLDEFGLOBALCFG"  # Update Yad entry on config file on Steam Deck to point to symlink in deps dir
		else
			YADVER="$("$YADFILE" --version | tail -n1 | cut -d ' ' -f1)"
			if [ "$(printf '%s\n' "$MINYAD" "$YADVER" | sort -V | head -n1)" != "$MINYAD" ] || grep -qi "[A-Z]" <<< "$YADVER" ; then
				writelog "ERROR" "${FUNCNAME[0]} - Version for '$YADFILE' is invalid. You need to at least version '$MINYAD'"
			else
				writelog "INFO" "${FUNCNAME[0]} - configuring yad binary to '$YADFILE'"
				touch "$FUPDATE"
				updateConfigEntry "YAD" "$YADFILE" "$STLDEFGLOBALCFG"
			fi
		fi
	fi
}

function isHelpOrVersionArg {
	case "$1" in
		help|--help|-h|version|--version|-v) return 0 ;;
		*) return 1 ;;
	esac
}

