#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function setLinGameVals {
	if [ "$ISGAME" -eq 3 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Looks like this is a native linux game - disabling some values which are only useful for win games"
		USEVORTEX="0"
		WINETRICKSPAKS="$NON"
		RUN_WINETRICKS="0"
		RUN_WINECFG="0"
		REGEDIT="0"
		VIRTUALDESKTOP="0"
		USERESHADE="0"
		UUUSEIGCS="0"
		IGCSDST="0"
		USESPECIALK="0"
		USEFWS="0"
		USEGEOELF="0"
	fi
}

function prepareProton {
	if [ "$ISGAME" -eq 2 ]; then
		if [ "$USEWINE" -eq 0 ]; then
			if [ "$EARLYUSEWINE" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - Wine has just been disabled, so preparing Proton now"
				getAvailableProtonVersions "up"
				checkStartMode
			fi

			if [ "$HAVEINPROTON" -eq 0 ]; then
				if [ -n "$USEPROTON" ] && [ ! -f "$(getProtPathFromCSV "$USEPROTON")" ]; then
					fixProtonVersionMismatch "USEPROTON" "$STLGAMECFG"
				fi

				# (re)initialize Proton dependant variables, when USEPROTON changed in a menu above
				if [ -n "$USEPROTON" ] && [ "$USEPROTON" != "$FIRSTGAMEUSEPROTON" ] && [ "$ISGAME" -eq 2 ]; then
					writelog "INFO" "${FUNCNAME[0]} - setNewProtVars, because '$USEPROTON' != '$FIRSTGAMEUSEPROTON'"
					setNewProtVars "$(getProtPathFromCSV "$USEPROTON")"
				fi
			else
				USEPROTON="$INPROTV"
				setNewProtVars "$(getProtPathFromCSV "$USEPROTON")"
				writelog "INFO" "${FUNCNAME[0]} - Checking the Proton version is not required, because $SLO is used. Proton version set in Steam is '$USEPROTON'"
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

		# export DXVK_CONFIG_FILE if STLDXVKCFG was found or if USEDLSS is enabled:
		DXDLSSCFG="$GLOBALMISCDIR/dxvk-no-nvapiHack.conf"

		if [ "$USE_STLDXVKCFG" -eq 1 ]; then
			if [ ! -f "$STLDXVKCFG" ]; then
				writelog "INFO" "${FUNCNAME[0]} - USE_STLDXVKCFG is enabled, but the config '$STLDXVKCFG' does not exist yet - creating a blank one"
				echo "## $(strFix "$STLDXVKCFG_WARNING" "$DXVKURL")" > "$STLDXVKCFG"
			fi
			export DXVK_CONFIG_FILE="$STLDXVKCFG"
			if [ -n "$DXVK_HUD" ] && [ "$DXVK_HUD" -eq 0 ]; then
				writelog "INFO" "${FUNCNAME[0]} - disabling variable DXVK_HUD which is set to 0 to make the variable DXVK_CONFIG_FILE functional"
				unset DXVK_HUD
			fi
			writelog "INFO" "${FUNCNAME[0]} - exporting variable 'DXVK_CONFIG_FILE' pointing to '$DXVK_CONFIG_FILE'"
		elif [ "$USEDLSS" -eq 1 ] && [ -f "$DXDLSSCFG" ]; then
			writelog "INFO" "${FUNCNAME[0]} - DLSS is enabled and '$DXDLSSCFG' was found - enabling all options required for DLSS"
			export DXVK_CONFIG_FILE="$DXDLSSCFG"
			if [ -n "$DXVK_HUD" ] && [ "$DXVK_HUD" -eq 0 ]; then
				writelog "INFO" "${FUNCNAME[0]} - disabling variable DXVK_HUD which is set to 0 to make the variable DXVK_CONFIG_FILE functional"
				unset DXVK_HUD
			fi
			export PROTON_ENABLE_NVAPI=1
			export PROTON_HIDE_NVIDIA_GPU=0
		fi

		# set VKD3D variables, if it's STL_ variant is != "$NON"

		if [ "$STL_VKD3D_CONFIG" != "$NON" ]; then
			export VKD3D_CONFIG="$STL_VKD3D_CONFIG"
		fi

		if [ "$STL_VKD3D_DEBUG" != "$NON" ]; then
			export VKD3D_DEBUG="$STL_VKD3D_DEBUG"
		fi

		if [ "$STL_VKD3D_SHADER_DEBUG" != "$NON" ]; then
			export VKD3D_SHADER_DEBUG="$STL_VKD3D_SHADER_DEBUG"
		fi

		if [ "$STL_VKD3D_LOG_FILE" != "$NON" ]; then
			export VKD3D_LOG_FILE="$STL_VKD3D_LOG_FILE"
		fi

		if [ "$STL_VKD3D_VULKAN_DEVICE" != "$NON" ]; then
			export VKD3D_VULKAN_DEVICE="$STL_VKD3D_VULKAN_DEVICE"
		fi

		if [ "$STL_VKD3D_FILTER_DEVICE_NAME" != "$NON" ]; then
			export VKD3D_FILTER_DEVICE_NAME="$STL_VKD3D_FILTER_DEVICE_NAME"
		fi

		if [ "$STL_VKD3D_DISABLE_EXTENSIONS" != "$NON" ]; then
			export VKD3D_DISABLE_EXTENSIONS="$STL_VKD3D_DISABLE_EXTENSIONS"
		fi

		if [ "$STL_VKD3D_TEST_DEBUG" != "$NON" ]; then
			export VKD3D_TEST_DEBUG="$STL_VKD3D_TEST_DEBUG"
		fi

		if [ "$STL_VKD3D_TEST_FILTER" != "$NON" ]; then
			export VKD3D_TEST_FILTER="$STL_VKD3D_TEST_FILTER"
		fi

		if [ "$STL_VKD3D_TEST_EXCLUDE" != "$NON" ]; then
			export VKD3D_TEST_EXCLUDE="$STL_VKD3D_TEST_EXCLUDE"
		fi

		if [ "$STL_VKD3D_TEST_PLATFORM" != "$NON" ]; then
			export VKD3D_TEST_PLATFORM="$STL_VKD3D_TEST_PLATFORM"
		fi

		if [ "$STL_VKD3D_TEST_BUG" != "$NON" ]; then
			export VKD3D_TEST_BUG="$STL_VKD3D_TEST_BUG"
		fi

		if [ "$STL_VKD3D_PROFILE_PATH" != "$NON" ]; then
			export VKD3D_PROFILE_PATH="$STL_VKD3D_PROFILE_PATH"
		fi

		# shortcut to enable all required flags for SBSVR with $GEOELF
		if [ "$SBSVRGEOELF" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - $PROGNAME - $SBSVRGEOELF enabled - starting game in SBS-VR using $GEOELF"
			export RUNSBSVR=1
			export USEGEOELF=1
		# shortcut to enable all required flags for SBSVR with ${RESH}
		elif [ "$SBSVRRS" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - $PROGNAME - SBSVRRS enabled - starting game in SBS-VR using ${RESH}"
			export RUNSBSVR=1
			export RESHADE_DEPTH3D=1
			export USERESHADE=1

			setVulkanPostProcessor
		fi

		if [ "$SBSRS" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - $PROGNAME - SBSRS enabled - starting game in SBS using ${RESH}"
			export RESHADE_DEPTH3D=1
			export USERESHADE=1

			setVulkanPostProcessor
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - No Proton game"
	fi
}

function sortGameArgs {
	if [ -z "$SLOARGS" ] || [ "$SLOARGS" == "$NON" ]; then
		SLOARGS="$NON"

		if [ "$SORTGARGS" -eq 1 ]; then
			if [ "${#ORGCMDARGS[@]}" -ge 1 ]; then
				CFSTG="coming from Steam/the game"
				if [ -n "$ARGUMENTS" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Game arguments '$ARGUMENTS' $CFSTG directly"
					writelog "INFO" "${FUNCNAME[0]} - Separating them from the found arguments '${ORGCMDARGS[*]}'"

					while read -r arg; do
						if [ -n "$arg" ] && [ "$arg" != "" ] && grep -q -- "$arg" <<< "$ARGUMENTS" ; then
							writelog "INFO" "${FUNCNAME[0]} - '$arg' is an argument $CFSTG, because it is within ARGUMENTS: '$ARGUMENTS'"
							mapfile -d " " -t -O "${#HARGSARR[@]}" HARGSARR <<< "$arg"
						elif [[ ! "${HARGSARR[*]}" =~ $arg ]] && [ -n "$arg" ] && [ "$arg" != "" ]; then
							writelog "INFO" "${FUNCNAME[0]} - '$arg' is probably an argument coming from $SLO"
							mapfile -d " " -t -O "${#SLOARRGS[@]}" SLOARRGS <<< "$arg"
						else
							writelog "SKIP" "${FUNCNAME[0]} - skipping '$arg'"
						fi
					done <<< "$(printf "%s\n" "${ORGCMDARGS[@]}")"

					if [ "${#HARGSARR[@]}" -ge 1 ] && [ "$HARDARGS" == "$NOPE" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Filling empty game config variable 'HARDARGS' with arguments $CFSTG"
						HARDARGSR="$(printf "%s" "${HARGSARR[@]}" | tr '\n' ' ')"
						HARDARGS="${HARDARGSR%*[[:blank:]]}"
						touch "$FUPDATE"
						updateConfigEntry "HARDARGS" "$HARDARGS" "$STLGAMECFG"
					fi

				else
					writelog "INFO" "${FUNCNAME[0]} - No game arguments $CFSTG found"
					writelog "INFO" "${FUNCNAME[0]} - So assuming '${ORGCMDARGS[*]}' comes completely from $SLO."
					while read -r arg; do
						mapfile -d " " -t -O "${#SLOARRGS[@]}" SLOARRGS <<< "$arg"
					done <<< "$(printf "%s\n" "${ORGCMDARGS[@]}")"
				fi

				if [ "${#SLOARRGS[@]}" -ge 1 ]; then
					SLOARGSR="$(printf "%s" "${SLOARRGS[@]}" | tr '\n' ' ')"
					SLOARGS="${SLOARGSR%*[[:blank:]]}"
					writelog "INFO" "${FUNCNAME[0]} - Set SLOARGS to '$SLOARGS'"
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - No game arguments $CFSTG or via $SLO"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Sorting the game arguments is disabled"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Nothing to do on the 2nd run"
	fi
}

function initOldProtonArr {
	delEmptyFile "$PROTONCSV"
	if [ -f "$PROTONCSV" ]; then
		unset ProtonCSV
		writelog "INFO" "${FUNCNAME[0]} - Creating an initial array with available Proton versions using the file '$PROTONCSV' which was created during a previous run"
		mapfile -t -O "${#ProtonCSV[@]}" ProtonCSV < "$PROTONCSV"
	fi
}

function initFirstProton {
	initOldProtonArr
	if [ "$HAVEINPROTON" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - skipping function, because Proton version is provided by commandline ($PROGCMD used via '$SLO')"
	else
		writelog "INFO" "${FUNCNAME[0]} - Initializing Proton"

		FUP1="$(grep "^USEPROTON=" "$STLDEFGAMECFG" | cut -d '=' -f2)"
		FIRSTUSEPROTON="${FUP1//\"}"

		if [ -z "$FIRSTUSEPROTON" ]; then
			writelog "INFO" "${FUNCNAME[0]} - No Proton version available in template yet - searching for one"
			FIRSTUSEPROTON="$(getDefaultProton)"
			touch "$FUPDATE"
			updateConfigEntry "USEPROTON" "$USEPROTON" "$STLDEFGAMECFG"
			writelog "INFO" "${FUNCNAME[0]} - Updated 'USEPROTON' in '$STLDEFGAMECFG' to '$USEPROTON'"
		fi
		if [ ! -f "$(getProtPathFromCSV "$FIRSTUSEPROTON")" ]; then
			USEPROTON="$FIRSTUSEPROTON"
			fixProtonVersionMismatch "USEPROTON" "$STLDEFGAMECFG"
			FUP1="$(grep "^USEPROTON=" "$STLDEFGAMECFG" | cut -d '=' -f2)"
			FIRSTUSEPROTON="${FUP1//\"}"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Initial Proton version 'FIRSTUSEPROTON' from '$STLDEFGAMECFG' is '$FIRSTUSEPROTON'"
	fi
}

function setMangoHudCfg {
	if [ "$USEMANGOHUDSTLCFG" -eq 1 ]; then
		mkProjDir "$MAHUCID"
		mkProjDir "$MAHUCTI"
		MHIC="$MAHUCID/${AID}.conf"
		writelog "INFO" "${FUNCNAME[0]} - Using internal $MAHU config '$MHIC' as requested"
		getGameName "$AID"
		MHTC="$MAHUCTI/${GAMENAME}.conf"

		if [ ! -f "$MHIC" ]; then
			writelog "WARN" "${FUNCNAME[0]} - '$MHIC' does not exist (yet) - trying to create it from the template '$MAHUTMPL'"
			if [ ! -f "$MAHUTMPL" ]; then
				writelog "WARN" "${FUNCNAME[0]} - The template '$MAHUTMPL' does not exist (yet) - trying to get the upstream example config"
				MAHUEX="/usr/share/doc/mangohud/MangoHud.conf.example"
				if [ -f "$MAHUEX" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Copying '$MAHUEX' to '$MAHUTMPL'"
					cp "$MAHUEX" "$MAHUTMPL"
				else
					writelog "SKIP" "${FUNCNAME[0]} - Could not find '$MAHUEX'"
				fi
			fi

			if ! grep -q "$MAHULID/XXX" "$MAHUTMPL" && ! grep -q "^output_folder" "$MAHUTMPL" ; then
				writelog "INFO" "${FUNCNAME[0]} - Appending default $MAHU output_folder to '$MAHUTMPL', because none is configured"
				echo "output_folder = $MAHULID/XXX" >> "$MAHUTMPL"
			fi

			if [ -f "$MAHUTMPL" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Copying '$MAHUTMPL' to '$MHIC'"
				cp "$MAHUTMPL" "$MHIC"
				if grep -q "$MAHULID/XXX" "$MHIC"; then
					writelog "INFO" "${FUNCNAME[0]} - Setting $MAHU output_folder to '$MAHULID/$AID' in $MHIC"
					sed "s:$MAHULID/XXX:$MAHULID/$AID:" -i "$MHIC"
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - Could not find or create '$MAHUTMPL'"
			fi
		fi
		if [ -f "$MHIC" ]; then
			if grep -q "$MAHULID/$AID" "$MHIC"; then
				mkProjDir "$MAHULID/$AID"
				mkProjDir "$MAHULTI"
				createSymLink "${FUNCNAME[0]}" "$MAHULID/$AID" "$MAHULTI/${GAMENAME}"
			fi

			writelog "INFO" "${FUNCNAME[0]} - Pointing variable MANGOHUD_CONFIGFILE to '$MHIC'"
			export MANGOHUD_CONFIGFILE="$MHIC"
			createSymLink "${FUNCNAME[0]}" "$MHIC" "$MHTC"
		else
			writelog "SKIP" "${FUNCNAME[0]} - Could not find or create '$MHIC'"
		fi
	fi
}

function autoBumpGE {
	if { [ "$AUTOBUMPGE" -eq 1 ] && grep -q "^GE" <<< "$USEPROTON" && [ "$ISGAME" -eq 2 ];} || [ -n "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Current Proton version is $USEPROTON"
		dlLatestGE "lge" "X"
		getAvailableProtonVersions "up" X

		if [ ! -f "$PROTONCSV" ]; then
			writelog "ERROR" "${FUNCNAME[0]} - Could not find '$PROTONCSV'"
		else
			NEWESTGE="$(grep "^GE" "$PROTONCSV" | sort -V | tail -n1)"
			NEWESTGE="${NEWESTGE%%;*}"
			if [ "$NEWESTGE" == "$USEPROTON" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - $USEPROTON is already the newest GE Proton version"
			else
				writelog "INFO" "${FUNCNAME[0]} - $(strFix "$NOTY_BUMP" "$USEPROTON" "$USEPROTON" "$NEWESTGE")"
				notiShow "$(strFix "$NOTY_BUMP" "$USEPROTON" "$USEPROTON" "$NEWESTGE")"
				USEPROTON="$NEWESTGE"
				touch "$FUPDATE"
				updateConfigEntry "USEPROTON" "$USEPROTON" "$STLGAMECFG"
			fi
		fi
	fi
}

function autoBumpProton {
	if [ "$AUTOBUMPPROTON" -eq 1 ] && grep -v -q "^GE" <<< "$USEPROTON" && [ "$ISGAME" -eq 2 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Current Proton version is $USEPROTON"
		NEWESTPROTON="$(grep -v "^GE" "$PROTONCSV" | sort -V | tail -n1)"
		NEWESTPROTON="${NEWESTPROTON%%;*}"
		if [ "$NEWESTPROTON" == "$USEPROTON" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - $USEPROTON is already the newest official Proton version"
		else
			writelog "INFO" "${FUNCNAME[0]} - $(strFix "$NOTY_BUMP" "$USEPROTON" "$USEPROTON" "$NEWESTPROTON")"
			notiShow "$(strFix "$NOTY_BUMP" "$USEPROTON" "$USEPROTON" "$NEWESTPROTON")"
			USEPROTON="$NEWESTPROTON"
			touch "$FUPDATE"
			updateConfigEntry "USEPROTON" "$USEPROTON" "$STLGAMECFG"
		fi
	fi
}

function checkPev {
	if [ "$ISGAME" -eq 2 ] && [ -f "$GP" ]; then
		unset USEPEVA
		mapfile -d " " -t -O "${#USEPEVA[@]}" USEPEVA < <(printf '%s' "USEPEV_PELDD USEPEV_PEPACK USEPEV_PERES USEPEV_PESCAN USEPEV_PESEC USEPEV_PESTR USEPEV_READPE")

		if [ -n "$USEALLPEV" ] && [ "$USEALLPEV" -eq 1 ]; then
			while read -r SUSEPEV; do
				if [ -n "$SUSEPEV" ]; then
					export "$SUSEPEV=1"
				fi
			done <<< "$(printf "%s\n" "${USEPEVA[@]}")"
		fi

		while read -r USEPEV; do
			if [ "${!USEPEV}" -eq 1 ]; then
				PEVCMD="${USEPEV##*_}"
				PEVCMD="${PEVCMD,,}"
				if [ -x "$(command -v "$PEVCMD")" ]; then
					PEVDSTI="$STLGPEVKD/$PEVCMD/id/$AID"
					PEVDSTT="$STLGPEVKD/$PEVCMD/title/$GN"

					if [ "$PEVCMD" == "$PERES" ]; then
						if [ ! -d "$PEVDSTI" ] || [ "$(find "$PEVDSTI" -type f | wc -l)" -eq 0 ]; then
							mkProjDir "$PEVDSTI"
							writelog "INFO" "${FUNCNAME[0]} - $USEPEV is enabled, extracting data from '$GP' using '$PEVCMD' to '$PEVDSTI'"
							cd "$PEVDSTI" >/dev/null || return
							notiShow "$(strFix "$NOTY_ANALYZE" "$GE" "$PEVCMD")"
							"$PEVCMD" -x "$GP" &
							cd - >/dev/null || return
						else
							writelog "SKIP" "${FUNCNAME[0]} - $USEPEV is enabled, but already have files in '$PEVDSTI'"
						fi
					else
						PEVDSTF="$PEVDSTI/$PEVCMD-$AID.txt"
						if [ ! -f "$PEVDSTF" ]; then
							mkProjDir "$PEVDSTI"
							writelog "INFO" "${FUNCNAME[0]} - $USEPEV is enabled, using command '$PEVCMD' to write data from '$GP' into '$PEVDSTF'"
							notiShow "$(strFix "$NOTY_ANALYZE" "$GE" "$PEVCMD")"
							"$PEVCMD" "$GP" > "$PEVDSTF" &
						else
							writelog "SKIP" "${FUNCNAME[0]} - $USEPEV is enabled, but already have the datafile '$PEVDSTF'"
						fi
					fi
					mkProjDir "${PEVDSTT%/*}"
					if [ ! -L "$PEVDSTT" ]; then
						ln -rs "$PEVDSTI" "$PEVDSTT"
					fi
				else
					writelog "SKIP" "${FUNCNAME[0]} - $USEPEV is enabled, but command '$PEVCMD' could not be found"
				fi
			fi
		done <<< "$(printf "%s\n" "${USEPEVA[@]}")"
	fi
}

function checkAllPev {
	if  [ -n "$USEALLPEV" ] && [ "$USEALLPEV" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - 'USEALLPEV' is enabled, extracting data from '$GP' with all supported pev tools"
		checkPev
	fi
}

function setDxvkVars {
	if [ "$PROTON_USE_WINED3D" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Exporting variable 'DXVK_FRAME_RATE=$DXVK_FPSLIMIT' to limit game framerate"
		export DXVK_FRAME_RATE=$DXVK_FPSLIMIT
	fi
}

function prepareLaunch {
	rm "$CLOSETMP" 2>/dev/null
	rm "$KILLSWITCH" 2>/dev/null

	linkLog

	createProjectDirs
	fixShowGnAid
	saveCfg "$STLDEFGLOBALCFG" X
	loadCfg "$STLDEFGLOBALCFG" X
	writelog "START" "######### Game Launch: $SGNAID #########"

	getGameData "$AID"

	writelog "INFO" "${FUNCNAME[0]} - Game launch args '${ORGGCMD[*]}'"
	writelog "INFO" "${FUNCNAME[0]} - Gamedir '$GFD'"
	if [ -n "$GPFX" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Proton wineprefix '$GPFX'"
	fi

	if [ -z "${INGCMD[*]}" ] && [ -n "${ORGGCMD[*]}" ]; then
		writelog "INFO" "${FUNCNAME[0]} - No INGCMD but valid ORGGCMD - May be Non-Steam game"
	fi
	writelog "INFO" "${FUNCNAME[0]} -------------------"
	writelog "INFO" "${FUNCNAME[0]} - CreateGameCfg:"
	createGameCfg

	writelog "INFO" "${FUNCNAME[0]} - First LoadCfg: $STLGAMECFG"
	loadCfg "$STLGAMECFG"

	checkPev

	autoBumpGE
	autoBumpProton
	autoBumpReShade

	if [ "$ISGAME" -eq 2 ] && [ "$HAVEINPROTON" -eq 0 ]; then
		FIRSTGAMEUSEPROTON="$USEPROTON"
		writelog "INFO" "${FUNCNAME[0]} - Initial Proton version from the game config: '$FIRSTGAMEUSEPROTON'"
		if [ -n "$USEPROTON" ] && [ ! -f "$(getProtPathFromCSV "$USEPROTON")" ]; then
			fixProtonVersionMismatch "USEPROTON" "$STLGAMECFG"
		fi

		writelog "INFO" "${FUNCNAME[0]} - Initializing internal Proton Vars for '$FIRSTGAMEUSEPROTON' using setNewProtVars"
		setNewProtVars "$(getProtPathFromCSV "$USEPROTON")"
	fi

	writelog "INFO" "${FUNCNAME[0]} - OpenTrayIcon:"
	openTrayIcon X

	fixCustomMeta "$CUMETA/$AID.conf" # will be removed again later
	loadCfg "$CUMETA/$AID.conf" X
	loadCfg "$GEMETA/$AID.conf" X

	writelog "INFO" "${FUNCNAME[0]} - sortGameArgs:"
	sortGameArgs

	if [ "$ONSTEAMDECK" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - steamdeckControl:"
		steamdeckControl
	fi

	checkWaitRequester

	if [ -z "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - AskSettings:"
		askSettings
	else
		MainMenu "$AID"
	fi

	writelog "INFO" "${FUNCNAME[0]} - Second LoadCfg after menus: $STLGAMECFG"
	loadCfg "$STLGAMECFG"

	# Setup DXVK
	if [ -n "$DXVK_SCALE" ] && [ "$DXVK_HUD" != "0" ]; then
		writelog "INFO" "${FUNCNAME[0]} - appending 'scale=$DXVK_SCALE' to the DXVK_HUD variable '$DXVK_HUD'"
		DXVK_HUD="${DXVK_HUD},scale=$DXVK_SCALE"
	fi
	setDxvkVars

	# in case a path changed in between, call createProjectDirs again:
	createProjectDirs



	# autoapply configuration settings based on the steam collections the game is in:
	autoCollectionSettings

	checkAllPev

	writelog "INFO" "${FUNCNAME[0]} - sortGameArgs again, in case something changed above:"
	sortGameArgs

	if [ "$ISGAME" -eq 2 ]; then
		writelog "INFO" "${FUNCNAME[0]} - symlinkSteamUser:"
		symlinkSteamUser "$USESUSYM"

		writelog "INFO" "${FUNCNAME[0]} - restoreSteamUser:"
		restoreSteamUser

		writelog "INFO" "${FUNCNAME[0]} - prepareProton:"
		prepareProton
	fi
####

	writelog "INFO" "${FUNCNAME[0]} - setLinGameVals :"
	setLinGameVals

#################

	# override tweak settings
	writelog "INFO" "${FUNCNAME[0]} - CheckTweakLaunch:"
	checkTweakLaunch

	if [ "$ISGAME" -eq 2 ]; then
		writelog "INFO" "${FUNCNAME[0]} - checkXliveless:"
		checkXliveless

		# choose either system winetricks or downloaded one
		writelog "INFO" "${FUNCNAME[0]} - chooseWinetricks:"
		chooseWinetricks
	fi

	# check dependencies - disable functions if dependency programs are missing and/or warn
	writelog "INFO" "${FUNCNAME[0]} - checkExtDeps:"
	checkExtDeps
	writelog "INFO" "${FUNCNAME[0]} - checkExtDeps done"

	if [ "$ISGAME" -eq 2 ]; then
		writelog "INFO" "${FUNCNAME[0]} - setWineVars:"
		setWineVars

		# start winetricks gui if RUN_WINETRICKS is 1 or silently if WINETRICKSPAKS is not empty
		writelog "INFO" "${FUNCNAME[0]} - CheckWinetricksLaunch:"
		checkWinetricksLaunch

		# start $WINECFG if RUN_WINECFG is 1
		writelog "INFO" "${FUNCNAME[0]} - CheckWineCfgLaunch:"
		checkWineCfgLaunch

		# apply some regs if requested
		writelog "INFO" "${FUNCNAME[0]} - CustomRegs:"
		customRegs
	fi

	# minimize all open windows if TOGGLEWINDOWS is 1
	writelog "INFO" "${FUNCNAME[0]} - TogWindows:"
	togWindows windowminimize

	# Pause steamwebhelper if requested
	writelog "INFO" "${FUNCNAME[0]} - StateSteamWebHelper:"
	StateSteamWebHelper pause

	if [ "$ISGAME" -eq 2 ]; then
		# install ${RESH} if USERESHADE is 1
		writelog "INFO" "${FUNCNAME[0]} - InstallReshade:"
		installReshade

		# install Depth3D Shader if RESHADE_DEPTH3D is 1
		writelog "INFO" "${FUNCNAME[0]} - installDepth3DReshade:"
		installDepth3DReshade

		# start game with ${RESH} if USERESHADE is 1
		writelog "INFO" "${FUNCNAME[0]} - checkReshade:"
		checkReshade

		# start game with ${SPEK} if USESPECIALK is 1
		writelog "INFO" "${FUNCNAME[0]} - useSpecialK:"
		useSpecialK

		# start game with $GEOELF if USEGEOELF is 1
		writelog "INFO" "${FUNCNAME[0]} - configureGeoElf:"
		configureGeoElf

		# open Shader Menu if CHOOSESHADERS is 1
		writelog "INFO" "${FUNCNAME[0]} - ChooseShaders:"
		chooseShaders
	fi

	# configure $MAHU
	if [ "$USEMANGOHUD" -eq 1 ]; then
		if [ -f "$MAHUBIN" ] || [ "$MAHUVAR" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - setMangoHudCfg:"
			setMangoHudCfg
		else
			writelog "SKIP" "${FUNCNAME[0]} - USEMANGOHUD is enabled, but $MAHU binary '$MAHUBIN' not found - disabling USEMANGOHUD"
			USEMANGOHUD=0
		fi
	fi

	# start $NYRNA if RUN_NYRNA is 1
	writelog "INFO" "${FUNCNAME[0]} - UseNyrnaz:"
	useNyrna

	# start $REPLAY if RUN_REPLAY is 1
	writelog "INFO" "${FUNCNAME[0]} - UseReplay:"
	useReplay

	# start game with side-by-side VR if RUNSBSVR is not 0
	writelog "INFO" "${FUNCNAME[0]} - CheckSBSVRLaunch:"
	checkSBSVRLaunch "$NON"

	if [ "$RUNSBS" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - CheckSBSLaunch:"
		checkSBSLaunch
	fi

	# start Vortex if USEVORTEX is 1
	if [ "$USEVORTEX" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - ${VTX^} is enabled - startVortex:"
		startVortex "ask" "$AID"
		# (for Vortex) if SELAUNCH is 0 start a preconfigured exe directly
		writelog "INFO" "${FUNCNAME[0]} - CheckVortexSELaunch with argument '$SELAUNCH':"
		checkVortexSELaunch "$SELAUNCH"
	fi

	writelog "INFO" "${FUNCNAME[0]} - checkMO2:"
	checkMO2

	# set other screen resolution
	writelog "INFO" "${FUNCNAME[0]} - setNewRes:"
	setNewRes

	# start custom user script
	writelog "INFO" "${FUNCNAME[0]} - customUserScriptStart:"
	customUserScriptStart

	# redirect STEAM_COMPAT_DATA_PATH on request
	writelog "INFO" "${FUNCNAME[0]} - redirectSCDP:"
	redirectSCDP

	if [ "$ISGAME" -eq 2 ]; then
		# start igcsinjector if USEIGCS is enabled
		writelog "INFO" "${FUNCNAME[0]} - checkIGCSInjector:"
		checkIGCSInjector

		# check if openvr-fsr is enabled
		writelog "INFO" "${FUNCNAME[0]} - checkOpenVRFSR:"
		checkOpenVRFSR
	fi

	# start '$FWS' if USEFWS is enabled
	writelog "INFO" "${FUNCNAME[0]} - CheckFWS:"
	checkFWS

	# load custom variables if available
	loadCustomVars

	# set pulse latency if CHANGE_PULSE_LATENCY is 1
	writelog "INFO" "${FUNCNAME[0]} - checkPulse:"
	checkPulse

	# start strace process in the background if STRACERUN is 1
	writelog "INFO" "${FUNCNAME[0]} - CheckStraceLaunch:"
	checkStraceLaunch

	# start network monitor process in the background if USENETMON is enabled and NETMON found
	writelog "INFO" "${FUNCNAME[0]} - CheckNetMonLaunch:"
	checkNetMonLaunch

	# start wine-discord-ipc-bridge when game starts if USE_WDIB is -eq 1
	writelog "INFO" "${FUNCNAME[0]} - checkWDIB:"
	checkWDIB

	# create/remove steam_appid.txt
	writelog "INFO" "${FUNCNAME[0]} - checkSteamAppIDFile:"
	checkSteamAppIDFile

	# start a custom program if USECUSTOMCMD is enabled
	writelog "INFO" "${FUNCNAME[0]} - CheckCustomLaunch:"
	checkCustomLaunch

	if [ "$ISGAME" -eq 2 ]; then
		# start a custom program if UUUSEPATCH or UUUSEVR is enabled
		writelog "INFO" "${FUNCNAME[0]} - checkUUUPatchLaunch:"
		checkUUUPatchLaunch
	fi

	# Automatic Grid Update Check before_game
	if [ "$SGDBAUTODL" == "before_game" ] && [ "$STLPLAY" -eq 0 ]; then
		writelog "INFO" "${FUNCNAME[0]} - Automatic Grid Update Check '$SGDBAUTODL'"
		# getGrids "$AID" &
		commandlineGetSteamGridDBArtwork --search-id="$AID" --steam
	fi

	if [ "$ISGAME" -eq 2 ]; then
		# Create GameTitle Symlink in STLCOMPDAT if enabled
		writelog "INFO" "${FUNCNAME[0]} - setCompatDataTitle:"
		setCompatDataTitle
	fi

	# delay game launch if requested via WAITFORCUSTOMCOMMAND
	delayGameForCustomLaunch

	# GAME START
	writelog "INFO" "${FUNCNAME[0]} - launchSteamGame:"
	launchSteamGame

	if [ "$KEEPSTLOPEN" -eq 1 ]; then
		writelog "INFO" "${FUNCNAME[0]} - KEEPSTLOPEN is enabled - re-opening the $PROGNAME menu"
		prepareLaunch X
	else
		# GAME ENDED - Closing:
		writelog "STOP" "######### CLEANUP #########"
		closeSTL "######### DONE - $PROGNAME $PROGVERS #########"
	fi
}

function switchProton {
	writelog "INFO" "${FUNCNAME[0]} - Switching used Proton and its Variables to version '$1'"

	if [ ! -f "$(getProtPathFromCSV "$1")" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Tried to switch to Proton '$1', but it is not available"
		if [ "$AUTOPULLPROTON" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - AUTOPULLPROTON is enabled, so trying to download and enable '$1'"
			createDLProtList
			DLURL="$(printf "%s\n" "${ProtonDLList[@]}" | grep -m1 "$1")"
			if [ -n "$DLURL" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Download for requested '$1' found: '$DLURL'"
				StatusWindow "$GUI_DLCUSTPROT" "dlCustomProton ${DLURL//|/\"}" "DownloadCustomProtonStatus"
			else
				writelog "SKIP" "${FUNCNAME[0]} - No download URL found for requested '$1' - skipping"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - AUTOPULLPROTON is disabled, so giving up switching to proton version '$1'"
		fi
	else
		writelog "INFO" "${FUNCNAME[0]} - Requested Proton version '$1' found under '$(getProtPathFromCSV "$1")'"
	fi

	if [ -f "$(getProtPathFromCSV "$1")" ]; then
		USEPROTON="$1"
		setNewProtVars "$(getProtPathFromCSV "$USEPROTON")"
	fi
}

function prepareProtonDBRating {
	if [ "$USEPDBRATING" ] && [ "$STLPLAY" -eq 0 ]; then
		PDBRAINFO="$STLSHM/PTB-${AID}.txt"
		PDBRASINF="${PDBRAINFO//-/short-}"

		if [ ! -f "$PDBRAINFO" ];then
			mapfile -d ";" -t -O "${#PDBARR[@]}" PDBARR <<< "$(getProtonDBRating "$AID")"
			PDBCONFI="${PDBARR[0]}"
			PDBSCORE="${PDBARR[1]}"
			PDBTOTAL="${PDBARR[2]}"
			PDBTREND="${PDBARR[3]}"
			PDBBESTT="${PDBARR[4]}"
			printf '<b>ProtonDB Rating Trend:</b> %s' "${PDBTREND^}" > "$PDBRASINF"
			printf '<u>%s</u>\n<b>Confidence:</b> %s\n<b>Score:</b> %s\n<b>Total Votes:</b> %s\n<b>Rating Trend:</b> %s\n<b>Best Rating:</b> %s\n' "$GUI_USEPDBRATING" "${PDBCONFI}" "${PDBSCORE}" "${PDBTOTAL}" "${PDBTREND}" "${PDBBESTT}" > "$PDBRAINFO"
		fi
	fi
}

function getProtonDBRating {
	if [ -n "$1" ]; then
		AID="$1"
	fi

	PDBAPI="https://www.protondb.com/api/v1/reports/summaries/XXX.json"

	if [ ! -x "$(command -v "$JQ")" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Can't get data from '${PDBAPI//XXX/$AID}' because '$JQ' is not installed"
	else
		DMIN=1440

		if [ -n "$PDBRATINGCACHE" ] && [ "$PDBRATINGCACHE" -ge 1 ]; then
			PDBDLDIR="$STLDLDIR/proton/rating"
			mkProjDir "$PDBDLDIR"
			PDBAJ="$PDBDLDIR/${AID}.json"
			if [ ! -f "$PDBAJ" ] || test "$(find "$PDBAJ" -mmin +"$(( DMIN * PDBRATINGCACHE ))")"; then
				rm "$PDBAJ" 2>/dev/null
				dlCheck "${PDBAPI//XXX/$AID}" "$PDBAJ" "X" "$NON"
			fi

			if [ -f "$PDBAJ" ]; then
				"$JQ" -r '. | "\(.confidence);\(.score);\(.total);\(.trendingTier);\(.bestReportedTier)"' "$PDBAJ"
			fi
		else
			"$WGET" -q "${PDBAPI//XXX/$AID}" -O - 2> >(grep -v "SSL_INIT") | "$JQ" -r '. | "\(.confidence);\(.score);\(.total);\(.trendingTier);\(.bestReportedTier)"'
		fi
	fi
}

function fixProtonVersionMismatch {
	FORCEPROTONMISMATCHRESOLVE="${3:-0}"  # I.e. passed by One-Time Run where "ISGAME -eq 3"
	if [ "$ISGAME" -eq 2 ] || [ "$FORCEPROTONMISMATCHRESOLVE" -eq 1 ]; then
		ORGPROTCAT="$1"
		MIMAPROT="${!1}"

		if [[ "$MIMAPROT" =~ "experimental" ]]; then
			# Look for replacement Proton Experimental - There should only ever be one Proton Experimental version installed at a time
			writelog "INFO" "${FUNCNAME[0]} - Mismatch for 'experimental' Proton version - Looking for updated Proton Experimental"

			# Even though there should only be one Experimental version, only take the first one just in case (should not cause issues, hopefully)
			REPLACEMENTEXPERIMENTAL="$( grep 'experimental' "$PROTONCSV" | head -1 | cut -d ';' -f1 )"
			if [ -n "$REPLACEMENTEXPERIMENTAL" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Found potential replacement for Proton Experimental with '$REPLACEMENTEXPERIMENTAL'"
				switchProton "$REPLACEMENTEXPERIMENTAL"
			else
				# If no Proton replacement, fall back to first Proton version in ProtonCSV
				# Not ideal but a user might've uninstalled Proton Experimental, and we can't assume what versions of Proton they will have except that they'll have *some* version
				FALLBACKPROTON="$( head -1 "$PROTONCSV" )"
				writelog "INFO" "${FUNCNAME[0]} - No potential replacement for Proton Experimental found, falling back to first Proton version in ProtonCSV ('$FALLBACKPROTON')"
				switchProton "$FALLBACKPROTON"
			fi

			touch "$FUPDATE"
			updateConfigEntry "USEPROTON" "$USEPROTON" "$2"
		elif [[ "$MIMAPROT" =~ "proton-unknown" ]]; then
			# Should we fall back to first item in ProtonCSV here?
			writelog "INFO" "${FUNCNAME[0]} - Skipping function for 'proton-unknown' Proton version"
		else
			writelog "INFO" "${FUNCNAME[0]} - Incoming category is '$ORGPROTCAT' with value '$MIMAPROT'"
			writelog "INFO" "${FUNCNAME[0]} - Looking for an alternative similar version for '$MIMAPROT'"

			notiShow "$(strFix "$NOTY_WANTPROTON3" "$MIMAPROT")"

			if [ ! -f "$PROTONCSV" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Looking for available Proton versions"
				getAvailableProtonVersions "up"
			fi

			MIMAPROTSHORT="^${MIMAPROT%-*}"
			NEWMINORPROT="$(grep "$MIMAPROTSHORT" "$PROTONCSV" | cut -d ';' -f1 | sort -nr | head -n1)"

			if [ -f "$(getProtPathFromCSV "${NEWMINORPROT//\"/}")" ] && [ -n "${NEWMINORPROT//\"/}" ]; then
				NEWMINORRUN="$(getProtPathFromCSV "${NEWMINORPROT//\"/}")"
				writelog "INFO" "${FUNCNAME[0]} - Found Proton '$NEWMINORPROT' in path '$NEWMINORRUN' as an alternative for the requested '$MIMAPROT'"
			elif grep -q "GE" <<< "$MIMAPROT"; then
				writelog "INFO" "${FUNCNAME[0]} - No alternative for '$MIMAPROT' found directly"
				NEWMINORPROT="$(grep "GE" "$PROTONCSV" | cut -d ';' -f1 | sort -nr | head -n1)"
				if [ -f "$(getProtPathFromCSV "${NEWMINORPROT//\"/}")" ]; then
					NEWMINORRUN="$(getProtPathFromCSV "${NEWMINORPROT//\"/}")"
					writelog "INFO" "${FUNCNAME[0]} - Using found '$NEWMINORPROT' instead, as it is at least also a GE Proton like the requested '$MIMAPROT'"
				fi
			fi

			if [ -n "$3" ]; then
				if [ -f "$NEWMINORRUN" ]; then
					writelog "INFO" "${FUNCNAME[0]} - found '$NEWMINORRUN'"
					echo "$NEWMINORRUN"
				fi
			else
				if [ -f "$NEWMINORRUN" ]; then
					switchProton "$NEWMINORPROT"
					notiShow "$(strFix "$NOTY_WANTPROTON2" "$NEWMINORPROT" "$MIMAPROT")"
				elif [ "$AUTOLASTPROTON" -eq 1 ]; then
					writelog "INFO" "${FUNCNAME[0]} - Automatically selecting newest official one"
					setNOP
				else
					writelog "INFO" "${FUNCNAME[0]} - Asking for one"
					needNewProton
				fi
			fi

			if [ ! -f "$(getProtPathFromCSV "$MIMAPROT")" ] && [ "$ORGPROTCAT" == "USEPROTON" ] && [ "$MIMAPROT" != "$NEWMINORPROT" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Automatically updating USEPROTON to '$USEPROTON' in '$2'"
				touch "$FUPDATE"
				updateConfigEntry "USEPROTON" "$USEPROTON" "$2"
				setInternalProtonVars
			fi
		fi
	fi
}

function dlConty {
	function upChkConty {
		DLCHK="sha256sum"

		notiShow "$(strFix "$NOTY_DLCONTY" "$CONTYRELURL/$CONTYDLVERS")" "S"
		dlCheck "$CONTYRELURL/$CONTYDLVERS" "$CONTYDLDIR/$CONTY" "$DLCHK" "Downloading '$CONTYRELURL/$CONTYDLVERS' to '$CONTYDLDIR'" "$INCHK"
		notiShow "$GUI_DONE" "S"
	}

	mkProjDir "$CONTYDLDIR"
	CONTYDLVERS="$("$WGET" -q "$CONTYRELURL" -O - 2> >(grep -v "SSL_INIT") | grep -m1 "download.*.$CONTY" | grep -oP 'releases\K[^"]+')"
	CONTYVERS="${CONTYDLVERS%/*}"
	CONTYVERS="${CONTYVERS##*/}"

	INCHK="$("$WGET" -q "${CONTYRELURL}/tag/${CONTYVERS}" -O - 2> >(grep -v "SSL_INIT")| grep "SHA256" -A10 | grep -m1 "${CONTY}" | cut -d ' ' -f1)"

	if [ -f "$CONTYDLDIR/$CONTY" ]; then
		if [ "$UPDATECONTY" -eq 1 ]; then
			if [ -f "$CONTYDLDIR/version.txt" ]; then
				DLVERS="$(cat "$CONTYDLDIR/version.txt")"
			else
				DLVERS="0.0"
			fi

			if [ "$DLVERS" == "$CONTYVERS" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - Skipping downloading Conty - existing version is identical to the latest upstream version '$CONTYVERS'"
			else
				writelog "INFO" "${FUNCNAME[0]} - Updating the available Conty version '$DLVERS' with the newer version '$CONTYVERS'"
				upChkConty
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Skipping downloading Conty - already have one, and update is disabled"
		fi
	else
		upChkConty
	fi

	if [ -f "$CONTYDLDIR/$CONTY" ]; then
		DLSHA="$(sha256sum "$CONTYDLDIR/$CONTY" | cut -d ' ' -f1)"
		writelog "INFO" "${FUNCNAME[0]} - : Downloaded $CONTY has sha256sum '$DLSHA' and should have '$INCHK'"

		if [ "$INCHK" == "$DLSHA" ]; then
			writelog "INFO" "${FUNCNAME[0]} - : $(strFix "$NOTY_CHECKSUM_OK" "$DLSHA")"
			notiShow "$(strFix "$NOTY_CHECKSUM_OK" "$DLSHA")" "S"
			chmod +x "$CONTYDLDIR/$CONTY"
			export RUNCONTY="$CONTYDLDIR/$CONTY"
			if grep -q "[0-9]" <<< "$CONTYVERS"; then
				writelog "INFO" "${FUNCNAME[0]} - Updating Conty version to '$CONTYVERS' in '$CONTYDLDIR/version.txt'"
				echo "$CONTYVERS" > "$CONTYDLDIR/version.txt"
			else
				writelog "SKIP" "${FUNCNAME[0]} - No version found in Url - not writing '$CONTYDLDIR/version.txt'"
			fi
		else
			writelog "ERROR" "${FUNCNAME[0]} - $(strFix "$NOTY_CHECKSUM_NOK" "$DLSHA") - removing the download"
			notiShow "$(strFix "$NOTY_CHECKSUM_NOK" "$DLSHA")" "S"
			rm "$CONTYDLDIR/$CONTY"
		fi
	fi
}

function updateConty {
	if [ "$UPDATECONTY" -eq 1 ]; then
		if [ ! -f "$CONTYDLDIR/version.txt" ]; then
			writelog "INFO" "${FUNCNAME[0]} - No Conty version file found in - so simply downloading latest release"
			StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${CONTY%%.*}")" "dlConty" "DownloadContyStatus"
		else
			CONTYDLVERS="$("$WGET" -q "$CONTYRELURL" -O - 2> >(grep -v "SSL_INIT") | grep -m1 "download.*.$CONTY" | grep -oP 'releases\K[^"]+')"
			CONTYVERS="${CONTYDLVERS%/*}"
			CONTYVERS="${CONTYVERS##*/}"
			if [ -f "$CONTYDLDIR/version.txt" ]; then
				DLVERS="$(cat "$CONTYDLDIR/version.txt")"
			else
				DLVERS="0.0"
			fi
			writelog "INFO" "${FUNCNAME[0]} - $(strFix "$NOTY_UPDATECONTY" "$CONTYVERS" "$DLVERS")"
			notiShow "$(strFix "$NOTY_UPDATECONTY" "$CONTYVERS" "$DLVERS")"
			StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${CONTY%%.*}")" "dlConty" "DownloadContyStatus"
		fi
	fi
}

function askConty {
		writelog "INFO" "${FUNCNAME[0]} - Opening Ask Conty Requester"
		fixShowGnAid
		export CURWIKI="$PPW/Conty"
		TITLE="${PROGNAME}-SelectConty"
		pollWinRes "$TITLE"

		setShowPic

		"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
		--title="$TITLE" \
		--text="$(spanFont "$SGNAID - $GUI_ASKCONTY" "H")" \
		--button="$BUT_DLCONTY":0 \
		--button="$BUT_SELCONTY":2 \
		--button="$SKIPCONTY":4 \
		"$GEOM"

		case $? in
			0)  {
					writelog "INFO" "${FUNCNAME[0]} - Selected to download Conty"
					StatusWindow "$(strFix "$NOTY_DLCUSTOMPROTON" "${CONTY%%.*}")" "dlConty" "DownloadContyStatus"
				}
			;;
			2)  {
					writelog "INFO" "${FUNCNAME[0]} - Selected to pick local Conty executable"
					PICKCONT="$("$YAD" --file)"

					if [ -f "$PICKCONT" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Picked '$PICKCONT' as Conty executable"
						export RUNCONTY="$PICKCONT"
						touch "$FUPDATE"
						updateConfigEntry "CUSTCONTY" "$PICKCONT" "$STLDEFGLOBALCFG"
						CUSTCONTY="$PICKCONT"
					else
						writelog "SKIP" "${FUNCNAME[0]} - No Conty executable selected - skipping"
						export RUNCONTY="$NON"
					fi
				}
			;;
			4)  {
					writelog "SKIP" "${FUNCNAME[0]} - Selected CANCEL - Not using Conty"
					export RUNCONTY="$NON"
				}
			;;
		esac
}

function findConty {
	if [ -n "$CUSTCONTY" ] && [ "$CUSTCONTY" != "$NON" ] && [ -x "$CUSTCONTY" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using custom Conty '$CUSTCONTY'"
		export RUNCONTY="$CUSTCONTY"
	elif [ -x "$CONTYDLDIR/$CONTY" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using downloaded Conty '$CONTYDLDIR/$CONTY'"
		updateConty
		export RUNCONTY="$CONTYDLDIR/$CONTY"
	elif [ -x "$(command -v "$CONTY")" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using Conty in 'PATH' '$("$WHICH" "$CONTY")'"
		RUNCONTY="$(command -v "$CONTY")"
		export RUNCONTY
	else
		writelog "INFO" "${FUNCNAME[0]} - No Conty found - Opening requester"
		askConty
		if [ "$RUNCONTY" != "$NON" ]; then
			"${FUNCNAME[0]}"
		fi
	fi
}

function checkConty {
	if [ "$AUTOCONTY" -eq 1 ]; then
		if [ "$(getArch "$GP")" == "32" ]; then
			CONTYMODE=1
		else
			CONTYMODE=0
		fi
	elif [ "$USECONTY" -eq 1 ]; then
		CONTYMODE=2
	else
		CONTYMODE=0
	fi

	if [ "$CONTYMODE" -ge 1 ]; then
		findConty

		if [ -x "$RUNCONTY" ] && [ "$RUNCONTY" != "$NON" ]; then
			if [ "$CONTYMODE" -eq 1 ]; then
				writelog "INFO" "${FUNCNAME[0]} - '$GP' is 32bit - Starting it using Conty executable '$RUNCONTY'"
			else
				writelog "INFO" "${FUNCNAME[0]} - Starting '$GP' using Conty executable '$RUNCONTY', because 'USECONTY' is enabled"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - No Conty executable found 'RUNCONTY' is '$RUNCONTY' - continuing regularly"
			CONTYMODE=0
		fi
	fi
}

function logPlayTime {
	# Takes seconds and converts it into HH:MM:SS
	function getLengthPlayed {
		((h=${1}/3600))
		((m=(${1}%3600)/60))
		((s=${1}%60))

		if [ "$h" -gt 0 ]; then
			printf "%02d hrs, %02d mins, %02d secs" "$h" "$m" "$s"
		elif [ "$m" -gt 0 ]; then
			printf "%02d mins, %02d secs" "$m" "$s"
		else
			printf "%02d secs" "$s"
		fi
	}

	if [ "$LOGPLAYTIME" -eq 1 ] && [ -n "$GN" ] ; then
		mkProjDir "$PLAYTIMELOGDIR"
		TIMEPLAYEDSTR="$(date +%d.%m.%Y) for $(getLengthPlayed "$1")" # different date formats?
		echo "$TIMEPLAYEDSTR" >> "$PLAYTIMELOGDIR/${GN}.log"
	fi
}

function setHuyList {
	HUTXT="helpurls.txt"

	HELPURLLIST="$GLOBALMISCDIR/$HUTXT"

	if [ -f "$STLCFGDIR/$HUTXT" ]; then
		HELPURLLIST="$STLCFGDIR/$HUTXT"
	fi

	DHU="defhelpurl"

	if [ -z "$HELPURL" ] || [ "$HELPURL" == "$NON" ]; then
		HELPURL="$(grep "$DHU" "$HELPURLLIST" | cut -d ';' -f2)"
	fi
	HUYLIST="$(while read -r line; do cut -d ';' -f1 <<<"$line"; done <<< "$(grep -v "$DHU" "$HELPURLLIST")" | tr '\n' '!')"

	loadCfg "$GEMETA/$AID.conf" X

	if [ -n "$METACRITIC_FULLURL" ]; then
		HUYLIST="${HUYLIST}metacritic!"
	fi

	if [ -n "$GAMEMANUALURL" ]; then
		HUYLIST="${HUYLIST}gamemanual!"
	fi

	export HUYLIST
}

function checkHelpUrl {
	WANTHELPURL="$1"
	if [ -n "$WANTHELPURL" ] && [ "$WANTHELPURL" != "$NON" ] && [ ! -f "$STLSHM/KillBrowser-$AID.txt" ]; then

		if [ "$WANTHELPURL" == "metacritic" ]; then
			HELPURL="$METACRITIC_FULLURL"
		elif [ "$WANTHELPURL" == "gamemanual" ]; then
			HELPURL="$GAMEMANUALURL"
		else
			HELPURL="$(grep "$WANTHELPURL" "$HELPURLLIST" | grep -v "$DHU" | cut -d ';' -f2)"
			writelog "INFO" "${FUNCNAME[0]} - Searching Help Url for '$WANTHELPURL' with command: 'grep \"$WANTHELPURL\" \"$HELPURLLIST\" | grep -v \"$DHU\" | cut -d ';' -f2'"
		fi

		if [ -n "$HELPURL" ]; then
			HELPURLNQ="${HELPURL//\"}"

			if [ -z "$BROWSER" ] || [ "$BROWSER" = "$NON" ]; then
				writelog "INFO" "${FUNCNAME[0]} - No web browser selected falling back to '$XDGO'"
				writelog "WARN" "${FUNCNAME[0]} - If issues occur opening web pages try setting a browser manually"
				BROWSER="$XDGO"
			fi

			writelog "INFO" "${FUNCNAME[0]} - Selected to open '${HELPURLNQ//AID/$AID}' with '$BROWSER'"
			# If $BROWSER is $XDGO we don't want to kill it as it will likely kill something like Steam instead
			if [ "$BROWSER" != "$XDGO" ]; then
				if ! "$PGREP" -f "$BROWSER" >/dev/null; then
					touch "$STLSHM/KillBrowser-$AID.txt"
				fi
			fi

			"$BROWSER" "${HELPURLNQ//AID/$AID}" 2>/dev/null &
		fi
	fi
}

function HelpUrlMenu {
	if [ -n "$1" ]; then
		AID="$1"
		setAIDCfgs
	fi
	fixShowGnAid
	export CURWIKI="$PPW/Help-Url"
	TITLE="${PROGNAME}-${FUNCNAME[0]}"
	pollWinRes "$TITLE"
	setShowPic
	setHuyList

	WANTHELPURL="$("$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
	--title="$TITLE" --separator="\n" \
	--text="$(spanFont "$SGNAID $(strFix "$GUI_ASKOPURL" "$1")" "H")" \
	--field="$GUI_HELPURL!$DESC_HELPURL ":CB "$(cleanDropDown "${HELPURL}" "${HUYLIST}${NON}")" \
	--button="$BUT_CAN":0 \
	--button="$BUT_OPURL":2 \
	"$GEOM"	)"

	case $? in
		0)  {
				checkHelpUrl "$WANTHELPURL"
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN' - Leaving"
			}
		;;
		2)  {
				writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_OPURL' - Opening '$WANTHELPURL' in browser"
				checkHelpUrl "$WANTHELPURL"
			}
		;;
	esac
}

function checkPlayTime {
	WASSTESTA="$STLSHM/SteamStart_${AID}.txt"
	if [ ! -f "$WASSTESTA" ]; then
		writelog "INFO" "${FUNCNAME[0]} - The game was not started via '$PROGCMD' but directly from Steam - skipping Crash Requester"
	elif [ -z "$1" ]; then
		writelog "INFO" "${FUNCNAME[0]} - The game was not even started"
	else
		if [  -n "$CRASHGUESS" ] && [ "$1" -le "$CRASHGUESS" ]; then
			writelog "INFO" "${FUNCNAME[0]} - The game stopped after '$1' seconds - opening CrashGuess Requester"
			steamdeckControl
			fixShowGnAid
			export CURWIKI="$PPW/Crash-Guess"
			TITLE="${PROGNAME}-CrashGuess"
			pollWinRes "$TITLE"

			setShowPic

			setHuyList

			WANTHELPURL="$("$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
			--title="$TITLE" --separator="\n" \
			--text="$(spanFont "$SGNAID $(strFix "$GUI_ASKCRASHGUESS" "$1")" "H")" \
			--field="$GUI_HELPURL!$DESC_HELPURL ":CB "$(cleanDropDown "${HELPURL}" "${HUYLIST}${NON}")" \
			--button="$BUT_RETRYCG":0 \
			--button="$BUT_SKIPCG":2 \
			--button="$BUT_NO":4 \
			"$GEOM"	)"

			case $? in
				0)  {
						checkHelpUrl "$WANTHELPURL"
						writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_RETRYCG' so opening settings"
						duration=0
						SECONDS=0
						prepareLaunch X
					}
				;;
				2)  {
						writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_SKIPCG' - Setting CRASHGUESS to 0 for $SGNAID"
						updateConfigEntry "CRASHGUESS" "0" "$STLGAMECFG"
					}
				;;
				4)  {
						writelog "SKIP" "${FUNCNAME[0]} - Selected '$BUT_NO' - Exiting regularly"
					}
				;;
			esac
		else
			writelog "INFO" "${FUNCNAME[0]} - Playtime '$1' was longer than CRASHGUESS '$CRASHGUESS', not opening the requester"
		fi
	fi
	rm "$WASSTESTA" 2>/dev/null
}

function fixSymlinks {
	if [ "$FIXSYMLINKS" -eq 1 ]; then
		if [ ! -f "$RUNPROTON" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Fixing Symlinks is enabled, but RUNPROTON '$RUNPROTON' does not exist"
		else
			LRUNPROTDIR="${RUNPROTON%/*}"
			ORUNPROTDIR="$(readlink -f "$LRUNPROTDIR")"
			writelog "INFO" "${FUNCNAME[0]} - Starting Symlink Fix as requested"

			# the loop needs >1 second even without updating any symlinks and might need much longer with many syminks to be recreated
			# maybe worth to create a parsable checkfile to skip it on the next run?
			while read -r fixme; do
				SYML="$(awk -F ';' '{print $1}' <<< "$fixme")"
				OFIL="$(awk -F ';' '{print $2}' <<< "$fixme")"

				# make sure the found result is correct
				if [ "$(readlink -f "${SYML//\"}")" == "$(readlink -f "${OFIL//\"}")" ]; then
					OFIA="${OFIL//\"}"
					OFIB="${OFIA##*/files/}"
					OFIC="${OFIB//\/x86_64-windows}"
					OFID="${OFIC//\/i386-windows}"
					OOUT="${OFID##*/dist/}"

					if [ -n "$OOUT" ] && [ "$OOUT" != "" ]; then
						if [ -d "$LRUNPROTDIR/files" ]; then
							NFIL="$LRUNPROTDIR/files/$OOUT"
						elif [ -d "$LRUNPROTDIR/dist" ]; then
							NFIL="$LRUNPROTDIR/dist/$OOUT"
						else
							writelog "SKIP" "${FUNCNAME[0]} - No 'files' or 'dist' dir found in '$LRUNPROTDIR'"
						fi

						unset NEWFILE
						if [ -f "$NFIL" ]; then
							NEWFILE="$NFIL"
						elif [ -f "${NFIL//lib64\/wine/lib64\/wine\/x86_64-windows}" ]; then
							NEWFILE="${NFIL//lib64\/wine/lib64\/wine\/x86_64-windows}"
						elif [ -f "${NFIL//lib\/wine/lib\/wine\/i386-windows}" ]; then
							NEWFILE="${NFIL//lib\/wine/lib\/wine\/i386-windows}"
						else
							writelog "SKIP" "${FUNCNAME[0]} - No equivalent file found for '$OOUT' in '$LRUNPROTDIR'" # collect in generic nofile/${PROTONVERSION}.txt file to skip early?
						fi

						if [ -f "$NEWFILE" ]; then
							writelog "INFO" "${FUNCNAME[0]} - Symlink '${SYML//\"}' points to '${OFIL//\"}', but '$NEWFILE' would be correct - fixing:"
							rm "${SYML//\"}"
							writelog "INFO" "${FUNCNAME[0]} - 'ln -s \"$NEWFILE\" \"${SYML//\"}\"'"
							ln -s "$NEWFILE" "${SYML//\"}"
						fi
					fi
				else
					writelog "SKIP" "${FUNCNAME[0]} - '${SYML//\"}' does not point to '${OFIL//\"}' but to '$(readlink -f "${SYML//\"}")' - Skipping"
				fi
			done <<< "$(find "${GPFX}/${DRC}" -type l -exec echo \"{}\" \; -exec readlink -v {} \; | grep -v "$LRUNPROTDIR\|$ORUNPROTDIR\|$STUS" | grep -iB1 "Proton" | grep -v "^\-\-" | sed 'N;s/\n/;\"/' | sed 's/$/\"/')"
			writelog "INFO" "${FUNCNAME[0]} - Stop Symlink Fix"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Fixing Symlinks is not enabled"
	fi
}

function unSymlink {
	if [ "$UNSYMLINK" -eq 1 ]; then
			LRUNPROTDIR="${RUNPROTON%/*}"
			ORUNPROTDIR="$(readlink -f "$LRUNPROTDIR")"
			writelog "INFO" "${FUNCNAME[0]} - Starting unsymlinking as requested - might needs some time, depending on the symlink count"

			while read -r unsym; do
				SYML="$(awk -F ';' '{print $1}' <<< "$unsym")"
				OFIL="$(awk -F ';' '{print $2}' <<< "$unsym")"
				mv "${SYML//\"}" "${SYML//\"}_OLD"
				cp "${OFIL//\"}" "${SYML//\"}"
				if [ -f "${SYML//\"}" ]; then
					rm "${SYML//\"}_OLD"
				else
					writelog "SKIP" "${FUNCNAME[0]} - Copying to '${SYML//\"}' failed - reverting symlink"
					mv "${SYML//\"}_OLD" "${SYML//\"}"
				fi
			done <<< "$(find "${GPFX}/${DRC}" -type l -exec echo \"{}\" \; -exec readlink -v {} \; | grep -iB1 "Proton" | grep -v "^\-\-" | sed 'N;s/\n/;\"/' | sed 's/$/\"/')"
			writelog "INFO" "${FUNCNAME[0]} - Stop Unsymlinking"
	else
		writelog "SKIP" "${FUNCNAME[0]} - Unsymlinking is not enabled"
	fi
}

function delPrefix {
	if [ "$DELPFX" -eq 1 ]; then
		if [ -d "$STEAM_COMPAT_DATA_PATH" ] ; then
			writelog "INFO" "${FUNCNAME[0]} - Removing the prefix was enabled - Creating a backup of steamuser before"
			BACKUPSTEAMUSER=1
			backupSteamUser "$AID"

			writelog "INFO" "${FUNCNAME[0]} - Removing the prefix '$GPFX' as requested"
			notiShow "$(strFix "$NOTY_DELPFX" "$GPFX")"
			rm -rf "$STEAM_COMPAT_DATA_PATH" 2>/dev/null
			mkProjDir "$STEAM_COMPAT_DATA_PATH"
		fi
	fi
}

function createOrUpdateSymDir {
	SYML="$1"
	ODIR="$2"
	if [ -d "$SYML" ] && [ ! -L "$SYML" ] ; then
		writelog "WARN" "${FUNCNAME[0]} - Renaming existing '$SYML' to '${SYML}_old'"
		mv "$SYML" "${SYML}_old"
	fi

	if [ -L "$SYML" ] && [ "$(readlink "$SYML")" != "$ODIR" ]; then
		writelog "WARN" "${FUNCNAME[0]} - Renaming existing symlink '$SYML' to '${SYML}_old'"
		writelog "WARN" "${FUNCNAME[0]} - because it points to '$(readlink "$SYML")'"
		mv "$SYML" "${SYML}_old"
	fi

	if [ ! -L "$SYML" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Created symlink from '$ODIR' to '$SYML'"
		ln -s "$ODIR" "$SYML"
	fi
}

function gameFix {
	if [ "$AID" -eq 223220 ] || [ "$AID" -eq 246960 ]; then
		writelog "INFO" "${FUNCNAME[0]} - got '$AID' as STEAM_COMPAT_APP_ID - need to change pwd from '$PWD' to '${STEAM_COMPAT_INSTALL_PATH}/launcher'"
		cd "${STEAM_COMPAT_INSTALL_PATH}/launcher" || return
	fi
}

function updateMO2GlobConf {
	mkProjDir "$STLMO2DLDATDIR"
	MYGLOBDLDAT="${STLMO2DLDATDIR}/global.conf"
	writelog "INFO" "${FUNCNAME[0]} - Updating '$MYGLOBDLDAT' with up to date data"
	{
		echo "GMO2EXE=\"$MO2EXE\""
		echo "RUNPROTON=\"$MO2RUNPROT\""
		echo "MO2PFX=\"$MO2PFX\""
		echo "MO2WINE=\"$MO2WINE\""
		echo "MO2INST=\"$MO2INST\""
		echo "STEAM_COMPAT_CLIENT_INSTALL_PATH=\"$STEAM_COMPAT_CLIENT_INSTALL_PATH\""
		echo "STEAM_COMPAT_DATA_PATH=\"$MO2CODA\""
	} > "$MYGLOBDLDAT"
	echo "global" > "$LAMOINST"
}

function updateMO2PortConf {
	MONGURL="$(grep -i "\"$MO2GAM\"" "$MO2GAMES" | head -n1 | cut -d ';' -f4)"
	MONGURL="${MONGURL//\"}"

	if [ -z "${MONGURL}" ]; then
		# Fall back to AID if MO2GAM couldn't be found
		if [ -n "$AID" ]; then
			MONGURL="$(grep -i "\"$AID\"" "$MO2GAMES" | head -n1 | cut -d ';' -f4)"
			MONGURL="${MONGURL//\"}"
			if [ -z "${MONGURL}" ]; then
				writelog "WARN" "${FUNCNAME[0]} - extracting the gamename MONGURL from '$MO2GAMES' by looking for '$MO2GAM' or '$AID' failed - the file '$MYPORTDLDAT' won't be found"
				return
			fi
		else
			writelog "WARN" "${FUNCNAME[0]} - extracting the gamename MONGURL from '$MO2GAMES' by looking for '$MO2GAM' failed - the file '$MYPORTDLDAT' won't be found (and no AID to fall back to)"
			return
		fi
	fi

	mkProjDir "$STLMO2DLDATDIR"
	MYPORTDLDAT="${STLMO2DLDATDIR}/${MONGURL}.conf"

	writelog "INFO" "${FUNCNAME[0]} - Updating '$MYPORTDLDAT' with up to date data"

	{
		echo "GMO2EXE=\"$MO2EXE\""
		echo "RUNPROTON=\"$RUNPROTON\""
		echo "MO2PFX=\"$MO2PFX\""
		echo "MO2WINE=\"$MO2WINE\""
		echo "MO2INST=\"$MO2INST\""
		echo "STEAM_COMPAT_CLIENT_INSTALL_PATH=\"$STEAM_COMPAT_CLIENT_INSTALL_PATH\""
		echo "STEAM_COMPAT_DATA_PATH=\"$STEAM_COMPAT_DATA_PATH\""
	} > "$MYPORTDLDAT"
	echo "portable" > "$LAMOINST"
}

function prepMO2 {
	function setBaseMO2RunCmd {
		unset RUNCMD
		while read -r arg; do
			mapfile -t -O "${#RUNCMD[@]}" RUNCMD <<< "$arg"
			if [ "$arg" == "$WFEAR" ]; then
				break
			fi
		done <<< "$(printf "%s\n" "$@")"
	}

	if [ "$ISGAME" -eq 2 ] && [ "$USEWINE" -ne 1 ]; then
		if [ "$MO2MODE" != "disabled" ]; then
			if [ "$MOINST" == "global" ]; then
				writelog "INFO" "${FUNCNAME[0]} - MO2MODE is '$MO2MODE' - preparing MO2 symlinks in '$GPFX' for '$MOINST' instance"

				GAMMO2DAT="$GPFX/$DRCU/$STUS/$ADLO/$MO"
				ORGMO2DAT="$MO2PFX/$DRCU/$STUS/$ADLO/$MO"
				createOrUpdateSymDir "$GAMMO2DAT" "$ORGMO2DAT"

				OMODDIR="$MO2PFX/$MORDIR"
				GMODDIR="$GPFX/$MORDIR"
				createOrUpdateSymDir "$GMODDIR" "$OMODDIR"
			else
				writelog "INFO" "${FUNCNAME[0]} - MO2MODE is '$MO2MODE' - preparing MO2 symlinks in '$GPFX' for '$MOINST' instance"
			fi

			setBaseMO2RunCmd "$@"
			GMO2EXE="$GPFX/$MOERPATH"
		fi

		if [ "$MO2MODE" == "silent" ]; then
			setMO2Vars
			MO2GAMIN1="$(grep -m1 "\"$AID\"" "$MO2GAMES" | cut -d ';' -f3)"
			MO2GAMINI="${MO2GAMIN1//\"}"

			if [ -n "$MO2GAMINI" ] && [ -f "$MO2EXE" ]; then
				if [ "$(grep -c "^+" "$MODLIST")" -eq 0 ]; then
					writelog "SKIP" "${FUNCNAME[0]} - Not starting $MO silent as requested, because no mod is enabled in '$MODLIST'"
					notiShow "$(strFix "$NOTY_NOMO" "$GN" "$AID")"
					MO2MODE="gui"
				else
					MO2SILENTMODERUN="$MO2GAMINI"  # Executable profile to use in silent mode, defaults to INI but can be overridden

					# Check if MO2 Silent Mode executable has been overwritten
					if [ -n "$MO2SILENTMODEEXEOVERRIDE" ] && [ "$MO2SILENTMODEEXEOVERRIDE" != "$NON" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Overridding ModOrganizer 2 Silent Mode shortcut with '$MO2SILENTMODEEXEOVERRIDE' because it is defined and is not '$NON'"
						MO2SILENTMODERUN="$MO2SILENTMODEEXEOVERRIDE"
					fi

					# Run MO2 EXE with 'moshortcut://:' in for Silent Mode, as this will run a given Executable Profile
					# This defaults to the Executable profile that matches the INI filename. We infer this from mo2games.txt
					#
					# For example, 'Oblivion' will always have 'Oblivion.ini' because we make sure we name the entries in mo2games.txt correctly,
					# and MO2 will always create an Executable profile for *just* the game without its launcher (in this case, 'Oblivion'), so we can assume
					# the INI name will always have a corresponding Executable profile (unless manually removed by the user, and in such a case, the override option allows them to fix that)
					#
					# Some games (like Skyrim Special Edition) may need to use another executable profile, like SKSE64, so a user can override this value and the command
					# would become 'moshortcut://:SKSE64'
					#
					# If a given executable name is invalid, ModOrganizer 2 will show an error dialog stating so and will exit
					RUNCMD=("${RUNCMD[@]}" "$MO2EXE" "moshortcut://:$MO2SILENTMODERUN")

					writelog "INFO" "${FUNCNAME[0]} - Starting '$SGNAID' with $MO enabled mods with command '${RUNCMD[*]}'"
					notiShow "$(strFix "$NOTY_STARTSIMO" "$GN" "$AID")"
				fi
			else
				writelog "SKIP" "${FUNCNAME[0]} - Not starting $MO silent as requested, because MO2GAMINI ('$MO2GAMINI') or MO2EXE ('$MO2EXE') is empty"
				MO2MODE="gui"
			fi
		fi

		if [ "$MO2MODE" == "gui" ]; then
			if [ -n "$MO2GAM" ]; then
				if [ -n "$MOINST" ] && [ "$MOINST" == "portable" ]; then
				#XXXXXXXXXXXXXXXX
				# testing and not working because wabbajack wants to open a nexus url for authentication, which doesn't seem to work
					USEWABBAJACK=0

					WAB="wabbajack"
					if [ "$USEWABBAJACK" -eq 1 ]; then
						writelog "INFO" "${FUNCNAME[0]} - ${WAB^} is enabled - starting"
						WABINST="$MO2DLDIR/${WAB^}.exe"
						export DOTNET_ROOT="$VTX_DOTNET_ROOT"
						export DOTNET_BUNDLE_EXTRACT_BASE_DIR="$VTX_DOTNET_ROOT"
						installDotNet "$MO2PFX" "$MO2WINE" "48"
						RUNCMD=("$MO2WINE" "$WABINST")
					else
						writelog "INFO" "${FUNCNAME[0]} - ${WAB^} MOINST $MOINST"

						writelog "INFO" "${FUNCNAME[0]} - Running $MOINST instance"
						RUNCMD=("${RUNCMD[@]}" "$MO2EXE")
					fi
				else
					RUNCMD=("${RUNCMD[@]}" "$MO2EXE" "-i" "${MO2GAM//\"}")
				fi

				writelog "INFO" "${FUNCNAME[0]} - Starting '$SGNAID' with $MO gui via '${RUNCMD[*]}'"
				notiShow "$(strFix "$NOTY_STARTVEMO" "$GN" "$AID")"
			else
				RUNCMD=("${RUNCMD[@]}" "$MO2EXE")
				writelog "INFO" "${FUNCNAME[0]} - Starting '$SGNAID' with $MO gui via '${RUNCMD[*]}'"
				notiShow "$(strFix "$NOTY_STARTVEMO" "$GN" "$AID")"
			fi

			if [ -n "$MOINST" ] && [ "$MOINST" == "portable" ]; then
				updateMO2PortConf
			else
				updateMO2GlobConf
			fi
		fi
	fi
}

