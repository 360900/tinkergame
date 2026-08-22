#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function startSettings {
	FUSEID "$1"

	writelog "INFO" "${FUNCNAME[0]} - createProtonList:"
	createProtonList X

	writelog "INFO" "${FUNCNAME[0]} - openTrayIcon:"
	openTrayIcon

	writelog "INFO" "${FUNCNAME[0]} - MainMenu:"
	MainMenu "$USEID"

	writelog "INFO" "${FUNCNAME[0]} - cleanYadLeftOvers:"
	cleanYadLeftOvers
}

function retBool {
	if [ "$1" == "TRUE" ]; then
		echo "1"
	else
		echo "0"
	fi
}

function SteamCatSelect {
	writelog "INFO" "${FUNCNAME[0]} - Steam Collection Selection"
	export CURWIKI="$PPW/Steam-Collections"
	TITLE="${PROGNAME}-SteamCollectionSelection"
	pollWinRes "$TITLE"

	setShowPic
	unset VALTAGS
	mapfile -d "\n" -t -O "${#VALTAGS[@]}" VALTAGS <<< "$(getActiveSteamCollections | grep -v "^rt[A-Z]")"
	SCATSELOUT="$(while read -r f; do if [[ ! "${SCATSEL[*]}" =~ $f ]]; then 	echo FALSE ; echo "$f"; else echo TRUE ; echo "$f" ;fi ; done <<< "$(printf "%s\n" "${VALTAGS[@]}")" | \
	"$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --window-icon="$STLICON" --center "${WINDECO[@]}" --list --checklist --column="" --column="Steam Collection" --separator="\n" --print-column="2" \
	--text="$(spanFont "$GUI_STEAMCATSEL" "H")" --title="$TITLE" --button="$BUT_SEL":0 --button="$BUT_CAN":2 "$GEOM")"

	case $? in
		0)  {
		writelog "INFO" "${FUNCNAME[0]} - Selected Select"
				if [ -n "$SCATSELOUT" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Selected following Collections: '$(sort -u <<< "$SCATSELOUT" | sed '/^$/d' | tr '\n' ',')'"
					unset SCATSEL
					mapfile -d "\n" -t -O "${#SCATSEL[@]}" SCATSEL <<< "$(sort -u <<< "$SCATSELOUT" | sed '/^$/d')"
				fi
			}
		;;
		2)  writelog "INFO" "${FUNCNAME[0]} - Selected CANCEL"
		;;
	esac

	goBackToPrevFunction "${FUNCNAME[0]}" "$2"
}

function AutoMarkSCat {
	writelog "INFO" "${FUNCNAME[0]} - Auto-marking specific Steam Collections"

	if ! grep -q "$DESC_NOST" <<< "$(printf "%s" "${SCATSEL[@]}" | tr '\n' ',')" && grep -q "$DESC_NOST" <<< "$(getActiveSteamCollections | tr '\n' ',')"; then
		writelog "INFO" "${FUNCNAME[0]} - Marking '$DESC_NOST' as Collection"
		mapfile -d "\n" -t -O "${#SCATSEL[@]}" SCATSEL <<< "$DESC_NOST"
	fi

	function maybeLater {
		if [ -f "$AUTOADDSCATLIST" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Marking everything found in '$AUTOADDSCATLIST' as Steam Collection"
			while read -r line; do
				mapfile -d "\n" -t -O "${#SCATSEL[@]}" SCATSEL <<< "$line"
			done < "$AUTOADDSCATLIST"
		else
			writelog "INFO" "${FUNCNAME[0]} - No file '$AUTOADDSCATLIST' containing Steam Collections found for adding"
		fi
	}
}

function filterUnwantedSteamCategories {
	FILTEREDTAGS="$(grep -v "^rt[A-Z]" <<< "$1")"
	printf "%s" "${FILTEREDTAGS[@]}" | tr '\n' '!' | sed 's/\!*$//g'
}

# Download icon for Non-Steam Game using SteamGridDB Game ID (can't set icon for Steam Native games)
function getSteamGridDBNonSteamIcon {
	NOSTICONAID="$1"  # Non-Steam AppID
	NOSTSGDBID="$2"  # SteamGridDB Game ID
	NOSTICONNAME="${NOSTICONAID}_icon"
	SGDBSEARCHENDPOINT_ICONS="${BASESTEAMGRIDDBAPI}/icons/game"

	# Download icon and put it in Steam grids folder, which should be a safe and intuitive location
	# We don't have any way to set search settings for icons and it would be confusing to have this in the Global Menu for now, so just leave blank
	# In future if we have Non-Steam Game global settings, we could include icon settings there too
	downloadArtFromSteamGridDB "$NOSTSGDBID" "$SGDBSEARCHENDPOINT_ICONS" "${NOSTICONNAME}" "" "" "" "" "" "" "replace" "1"
}

function addNonSteamGameGui {
	writelog "INFO" "${FUNCNAME[0]} - Starting the Gui for adding a $NSGA to Steam"

	# defaults
	if [ -n "$1" ]; then
		for i in "$@"; do
			case $i in
				-ep=*|--exepath=*)
				NOSTGEXEPATH="${i#*=}";
				shift
				;;
			esac
		done

		NOSTGAPPNAME="${NOSTGEXEPATH##*/}"
		NOSTGSTDIR="${NOSTGEXEPATH%/*}"
	fi

	if grep -q "^NOSTEAMSTLDEF=\"1\"" "$STLDEFGLOBALCFG"; then  # icon default
		NOSTGICONPATH="$STLICON"
	else
		NOSTGICONPATH=""
	fi
	NOSTGHIDE=0
	NOSTGADC=1
	NOSTGAO=1
	NOSTGVR=0
	unset VALTAGS
	mapfile -d "\n" -t -O "${#VALTAGS[@]}" VALTAGS <<< "$(getActiveSteamCollections | sed '/^$/d')"
	VALIDTAGS="$(filterUnwantedSteamCategories "${VALTAGS[@]}")"
	SGASETACTIONS="copy!link!move"

	AutoMarkSCat

	if [[ -v SCATSEL[@] ]]; then
		NOSTTAGS="$(filterUnwantedSteamCategories "${SCATSEL[@]}")"
	fi
	export CURWIKI="$PPW/Add-Non-Steam-Game"
	TITLE="${PROGNAME}-$NSGA"
	pollWinRes "$TITLE"

	# Generate list of Proton versions excluding Proton versions only available to TinkerGame
	# May cause problems with symlinked Proton versions, unsure, unusual case anyway
	NSGPROTLIST=( "$NON" "default" )
	for STLKNOWNPROT in "${ProtonCSV[@]}"; do
		STLKNOWNPROTNAM="$( echo "$STLKNOWNPROT" | cut -d ';' -f1 )"
		STLKNOWNPROTPATH="$( echo "$STLKNOWNPROT" | cut -d ';' -f2 )"

		STLKNOWNPROTDIR="$( dirname "$STLKNOWNPROTPATH" )"
		if [[ $STLKNOWNPROTDIR = $STLCFGDIR* ]]; then
			writelog "SKIP" "${FUNCNAME[0]} - Proton version '$STLKNOWNPROTNAM' is in TinkerGame config directory at '$STLKNOWNPROTPATH' -- This is not known by Steam, so skipping"
		elif [[ $STLKNOWNPROTDIR = $CUSTPROTEXTDIR* ]] && [[ $CUSTPROTEXTDIR != "$STEAMCOMPATOOLS" ]]; then
			writelog "INFO" "${FUNCNAME[0]} - Proton version '$STLKNOWNPROTNAM' is in TinkerGame Custom Proton dir '$CUSTPROTEXTDIR' on path '$STLKNOWNPROTPATH' -- This path is not the Steam Compatibility Tool directory and so is not known by Steam, so skipping"
		else
			writelog "INFO" "${FUNCNAME[0]} - Proton version '$STLKNOWNPROTNAM' looks like it should be known by Steam as it is not in any TinkerGame-specific folders on path '$STLKNOWNPROTPATH'"
			NSGPROTLIST+=("$STLKNOWNPROTNAM")
		fi
	done
	NSGPROTLIST+=( "$PROGINTERNALPROTNAME" "steamlinuxruntime" )

	NSGPROTYADLIST="$(printf "!%s\n" "${NSGPROTLIST[@]//\"/}" | sort -u | cut -d ';' -f1 | tr -d '\n' | sed "s:^!::" | sed "s:!$::")"

	## Language strings for artwork section were re-used from setGameArt
	NSGSET="$("$YAD" --f1-action="$F1ACTION" --window-icon="$STLICON" --form --scroll --center --on-top "${WINDECO[@]}" \
	--title="$TITLE" --separator="|" \
	--text="$(spanFont "$GUI_ADDNSG" "H")\n<i>$(strFix "$GUI_WARNNSG1" "$STERECO")</i>" \
	--field=" ":LBL " " \
	--field="$(spanFont "$GUI_NOSTGPATHS" "H")":LBL " " \
	--field="     $GUI_NOSTGAPPNAME!$DESC_NOSTGAPPNAME ('NOSTGAPPNAME')" "${NOSTGAPPNAME/#-/ -}" \
	--field="     $GUI_NOSTGEXEPATH!$DESC_NOSTGEXEPATH ('NOSTGEXEPATH')":FL "${NOSTGEXEPATH/#-/ -}" \
	--field="     $GUI_NOSTGSTDIR!$DESC_NOSTGSTDIR ('NOSTGSTDIR')":DIR "${NOSTGSTDIR/#-/ -}" \
	--field="$(spanFont "$GUI_NOSTGGAMEART" "H")":LBL " " \
	--field="     $GUI_NOSTGICONPATH!$DESC_NOSTGICONPATH ('NOSTGICONPATH')":FL "${NOSTGICONPATH/#-/ -}" \
	--field="     $GUI_SGAHERO!$DESC_SGAHERO ('NOSTGHERO')":FL "${NOSTGHERO/#-/ -}" \
	--field="     $GUI_SGALOGO!$DESC_SGALOGO ('NOSTGLOGO')":FL "${NOSTGLOGO/#-/ -}" \
	--field="     $GUI_SGABOXART!$DESC_SGABOXART ('NOSTGBOXART')":FL "${NOSTGBOXART/#-/ -}" \
	--field="     $GUI_SGATENFOOT!$DESC_SGATENFOOT ('NOSTGTENFOOT')":FL "${NOSTGTENFOOT/#-/ -}" \
	--field="     $GUI_SGASETACTION!$DESC_SGASETACTION ('NOSTGSETACTION')":CB "$( cleanDropDown "copy" "$SGASETACTIONS" )" \
	--field="     $GUI_NOSTGEXEARTWORKFALLBACK!$DESC_NOSTGEXEARTWORKFALLBACK ('NOSTGEXEARTWORKFALLBACK')":CHK "${NOSTGEXEARTWORKFALLBACK/#-/ -}" \
	--field="$(spanFont "$GUI_NOSTSGDB" "H")":LBL " " \
	--field="     $GUI_NOSTUSESGDB!$DESC_NOSTUSESGDB ('NOSTUSESGDB')":CHK "${NOSTUSESGDB/#-/ -}" \
	--field="     $GUI_NOSTSGDBSAID!$DESC_NOSTSGDBSAID ('NOSTSGDBSAID')" "${NOSTSGDBSAID/#-/ -}" \
	--field="     $GUI_NOSTSGDBAID!$DESC_NOSTSGDBAID ('NOSTSGDBAID')" "${NOSTSGDBAID/#-/ -}" \
	--field="     $GUI_NOSTSGDBSNAME!$DESC_NOSTSGDBSNAME ('NOSTSGDBSNAME')" "${NOSTSGDBSNAME/#-/ -}" \
	--field="$(spanFont "$GUI_NOSTGPROPS" "H")":LBL " " \
	--field="     $GUI_NOSTGCOMPATTOOL!$DESC_NOSTGCOMPATTOOL ('NOSTCOMPATTOOL')":CBE "$( cleanDropDown "$NON" "$NSGPROTYADLIST" )" \
	--field="     $GUI_NOSTGLAOP!$DESC_NOSTGLAOP ('NOSTGLAOP')" "${NOSTGLAOP/#-/ -}" \
	--field="     $GUI_NOSTTAGS!$DESC_NOSTTAGS ('NOSTTAGS')":CBE "$(cleanDropDown "${NOSTTAGS/#-/ -}" "$VALIDTAGS")" \
	--field="     $GUI_NOSTGHIDE!$DESC_NOSTGHIDE ('NOSTGHIDE')":CHK "${NOSTGHIDE/#-/ -}" \
	--field="     $GUI_NOSTGADC!$DESC_NOSTGADC ('NOSTGADC')":CHK "${NOSTGADC/#-/ -}" \
	--field="     $GUI_NOSTGAO!$DESC_NOSTGAO ('NOSTGAO')":CHK "${NOSTGAO/#-/ -}" \
	--field="     $GUI_NOSTGVR!$DESC_NOSTGVR ('NOSTGVR')":CHK "${NOSTGVR/#-/ -}" \
	--button="$BUT_CAN":0 --button="$BUT_TAGS":2 --button="$BUT_CREATE":4 "$GEOM")"

	case $? in
		0)  writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN'"
		;;
		2)  writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_TAGS"
			SteamCatSelect "$NON" "${FUNCNAME[0]}"
		;;
		4)  writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CREATE'"
			if [ -n "$NSGSET" ]; then
				mapfile -d "|" -t -O "${#NSGSETARR[@]}" NSGSETARR < <(printf '%s' "$NSGSET")

				writelog "INFO" "${FUNCNAME[0]} - The Non-Steam Game args are ${NSGSETARR[*]}"
				# NSGSETARR[0] is blank space
				# NSGSETARR[1] is Paths heading
				NOSTGAPPNAME="${NSGSETARR[2]}"
				NOSTGEXEPATH="${NSGSETARR[3]}"
				NOSTGSTDIR="${NSGSETARR[4]}"
				# NSGSETARR[5] is Artwork heading
				NOSTGICONPATH="${NSGSETARR[6]}"
				NOSTGHERO="${NSGSETARR[7]}"
				NOSTGLOGO="${NSGSETARR[8]}"
				NOSTGBOXART="${NSGSETARR[9]}"
				NOSTGTENFOOT="${NSGSETARR[10]}"
				NOSTGSETACTION="${NSGSETARR[11]}"
				NOSTGEXEARTWORKFALLBACK="$( retBool "${NSGSETARR[12]}" )"
				# NSGSETARR[13] is the SteamGridDB heading
				NOSTUSESGDB="$( retBool "${NSGSETARR[14]}" )"
				NOSTSGDBSAID="${NSGSETARR[15]}"
				NOSTSGDBAID="${NSGSETARR[16]}"
				NOSTSGDBSNAME="${NSGSETARR[17]}"
				# NSGSETARR[18] is Properties heading
				NOSTCOMPATTOOL="${NSGSETARR[19]}"
				NOSTGLAOP="${NSGSETARR[20]}"
				NOSTTAGS="${NSGSETARR[21]}"
				NOSTGHIDE="$( retBool "${NSGSETARR[22]}" )"
				NOSTGADC="$( retBool "${NSGSETARR[23]}" )"
				NOSTGAO="$( retBool "${NSGSETARR[24]}" )"
				NOSTGVR="$( retBool "${NSGSETARR[25]}" )"

				## ignore none compatibility tool
				if [[ "$NOSTCOMPATTOOL" = "$NON" ]]; then
					NOSTCOMPATTOOL=""
				fi

				NOSTARTEXECMD=""
				if [ "$NOSTGEXEARTWORKFALLBACK" -eq 1 ]; then
					NOSTARTEXECMD="--auto-artwork"
				fi

				if [ "$NOSTUSESGDB" -eq 0 ]; then
					# Ignore SteamGridDB values if SteamGridDB not enabled - Blank values means that function will ignore SteamGridDB entirely
					# We still need the checkbox so we can tell the addNonSteamGame function whether we want to fall back on Non-Steam Game Name
					NOSTSGDBAID=""
					NOSTSGDBSAID=""
					NOSTSGDBSNAME=""
				elif [[ ( -z "$NOSTSGDBAID" && -z "$NOSTSGDBSAID" && -z "$NOSTSGDBSNAME" ) && "$NOSTUSESGDB" -eq 1 ]]; then
					# If enabled SteamGridDB but did NOT pass any values, enable SteamGridDB which will allow us to search on Game Name
					# UI-specific logic that doesn't apply to commandline usage, since on commandline a user would manually pass this flag
					# only need to pass this flag if other search options are not set, as if one of these is set, we automatically enable SteamGridDB search
					NOSTGUIUSESGDB="--use-steamgriddb"
				fi

				## Arguments here like -hr, -lg, etc are made to match setGameArt
				writelog "INFO" "${FUNCNAME[0]} - addNonSteamGame -an=\"$NOSTGAPPNAME\" -ep=\"$NOSTGEXEPATH\" -sd=\"$NOSTGSTDIR\" -ip=\"$NOSTGICONPATH\" -lo=\"$NOSTGLAOP\" -hd=\"$NOSTGHIDE\" -adc=\"$NOSTGADC\" -ao=\"$NOSTGAO\" -vr=\"$NOSTGVR\" -t=\"$NOSTTAGS\" -ct=\"$NOSTCOMPATTOOL\" -hr=\"$NOSTGHERO\" -lg=\"$NOSTGLOGO\" -ba=\"$NOSTGBOXART\" -tf=\"$NOSTGTENFOOT\" \"--${NOSTGSETACTION}\" \"$NOSTARTEXECMD\" -sgai=\"$NOSTSGDBSAID\" -sgid=\"$NOSTSGDBAID\" -sgnm=\"$NOSTSGDBSNAME\" \"$NOSTGUIUSESGDB\""
				addNonSteamGame -an="$NOSTGAPPNAME" -ep="$NOSTGEXEPATH" -sd="$NOSTGSTDIR" -ip="$NOSTGICONPATH" -lo="$NOSTGLAOP" -hd="$NOSTGHIDE" -adc="$NOSTGADC" -ao="$NOSTGAO" -vr="$NOSTGVR" -t="$NOSTTAGS" -ct="$NOSTCOMPATTOOL" -hr="$NOSTGHERO" -lg="$NOSTGLOGO" -ba="$NOSTGBOXART" -tf="$NOSTGTENFOOT" "--${NOSTGSETACTION}" "$NOSTARTEXECMD" -sgai="$NOSTSGDBSAID" -sgid="$NOSTSGDBAID" -sgnm="$NOSTSGDBSNAME" "$NOSTGUIUSESGDB"
			fi
		;;
	esac
}

