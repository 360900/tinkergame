#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function getGlobalSteamCompatToolInternalName {
	STEAMCOMPATTOOLSECTION="$( getVdfSection "CompatToolMapping" "" "" "$CFGVDF" )"  # Get CompatToolMapping section
	if [ -n "$STEAMCOMPATTOOLSECTION" ]; then
		printf "%s" "$STEAMCOMPATTOOLSECTION" > "/tmp/tmp.vdf"
    	GLOBALSTEAMCOMPATTOOLSECTION="$( getVdfSection "0" "" "" "/tmp/tmp.vdf" )"

		if [ -n "$GLOBALSTEAMCOMPATTOOLSECTION" ]; then
			echo "$GLOBALSTEAMCOMPATTOOLSECTION" | grep -i "name" | sed "s-\t- -g;s-\"name\"--g;s-\"--g" | xargs
		else
			writelog "SKIP" "${FUNCNAME[0]} - Could not find Global Compatibility Tool in CompatToolMapping in '$CFGVDF' - Giving up"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - Could not find CompatToolMapping section in '$CFGVDF' - Giving up"
	fi
}

# Takes an signed 32bit integer and converts it to an unsigned 32bit integer
# Steam uses this for Short UserIDs (userdata folder names) and Short Non-Steam Game AppIDs (Steam Shortcut Grid ID names)
function generateSteamShortID {
	echo $(( $1 & 0xFFFFFFFF ))
}

# Store loginusers data in CSV in in $STLSHM
# We parse this info out of loginusers.vdf which stores has blocks grouped by Long UserID
# We can convert down to the Short UserID from this.
#
# There should be a Short UserID folder in the SUSDA folder because each Steam User LongID in loginusers.vdf
# should also have a corresponding Short UserID userdata folder.
#
# Columns for now are as follows (we can extend in future if we need to):
# Long UserID,Short UserID,MostRecent
function fillLoginUsersCSV {
	# Don't overwrite LoginUsersCSV file if it exists and is not blank, only re-create it if SHM dir is cleared
	# The loginusers are not likely to change after the SHM dir is created so this is a bit more efficient
	if [ -f "$LOGINUSERSCSV" ] && [ -s "$LOGINUSERSCSV" ]; then
		writelog "INFO" "${FUNCNAME[0]} - '${LOGINUSERSCSV}' already exists -- Not re-creating"
		return
	fi

	# NOTE: For testing only
	# LOGUVDF="$HOME/.local/share/Steam/config/test_loginusers.vdf"

	# Toplevel block in loginusers.vdf is "users", get all block names ("[0-9]+" with one hardcoded indent, because we know we only have 1 indent)
	#
	# TODO it would be nice to have a generic function to get all toplevel VDF block names like this, but
	# We can't know the pattern and would need to know how to differentiate between a blockname and a property name
	# It just so happens for loginusers that it only contains blocks
	if [ -f "${LOGUVDF}" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Found loginusers file at '${LOGUVDF}' -- Will attempt to parse this file"
		mapfile -t LOGINUSERLONGIDS < <(getVdfSection '"users"' "" "" "${LOGUVDF}" | grep -oP '^\t"[0-9]+"' | tr -d '\t"\ ')
	else
		writelog "WARN" "${FUNCNAME[0]} - loginusers file at '${LOGUVDF}' does not exist! Will fall back to taking first Steam userdata folder as only login user"
	fi

	# If we couldn't parse loginusers.vdf, fall back to taking the first userdata folder we can find from the Steam userdata dir
	if [ "${#LOGINUSERLONGIDS}" -eq 0 ]; then
		writelog "WARN" "${FUNCNAME[0]} - Could not find any loginusers in '${LOGUVDF}', either loginusers file doesn't exist or did not return any parsable data -- Falling back to old method of grabbing first directory in '$SUSDA'"

		# If we don't have loginusers.vdf, we don't have the long UserID because you can't get the Long UserID from the Short UserID
		# The Short UserID uses bitwise AND which loses information
		#
		# In this case we just default to 1 (to avoid conflicting with the '0' userdata folder from Steam)
		# This should be fine as we never need the Long UserID
		LOGINUSERLONGID="1"

		# We used to do this in setSteamPaths before we tried to parse MostRecent login user
		LOGINUSERSHORTID="$( find "$SUSDA" -maxdepth 1 -type d -name "[1-9]*" | head -n1)"
		LOGINUSERSHORTID="${LOGINUSERSHORTID##*/}"

		# LOGINUSERLONGID="$( generateSteamShortID "${LOGINUSERLONGID}" )"
		LOGINUSERMOSTRECENT="1"  # Default to 1 as we would only have one loginuser in this case

		writelog "INFO" "${FUNCNAME[0]} - Writing loginuser '${LOGINUSERLONGID},${LOGINUSERSHORTID},${LOGINUSERMOSTRECENT}' to '${LOGINUSERSCSV}'"
		printf '%s;%s;%s\n' "${LOGINUSERLONGID}" "${LOGINUSERSHORTID}" "${LOGINUSERMOSTRECENT}" > "${LOGINUSERSCSV}"

		# Don't move onto below loop
		return
	fi

	# If we could parse loginusers.vdf, assume valid data and iterate over it, storing it in LoginUsersCSV
	for LOGINUSERLONGID in "${LOGINUSERLONGIDS[@]}"; do
		writelog "INFO" "the id is ${LOGINUSERLONGID}"

		LOGINUSERSHORTID="$( generateSteamShortID "${LOGINUSERLONGID}" )"
		LOGINUSERMOSTRECENT="0"  # Default MostRecent to 0

		# Check if user is most recent by trying to get the corresponding LongID block in loginusers.vdf
		# and then picking out the MostRecent field
		#
		# If we find any value for MostRecent in the Long UserID block, store it in LOGINUSERMOSTRECENT
		# This value should really only ever be 0 or 1
		LOGINUSERBLOCK="$( getVdfSection "${LOGINUSERLONGID}" "" "1" "${LOGUVDF}" )"
		if [ -n "${LOGINUSERBLOCK}" ]; then
			LOGINUSERMOSTRECENTVAL="$( getVdfSectionValue "${LOGINUSERBLOCK}" "MostRecent" "1" | tr -d '"' )"

			if [ -n "$LOGINUSERMOSTRECENTVAL" ]; then
				LOGINUSERMOSTRECENT="$LOGINUSERMOSTRECENTVAL"
			fi
		fi

		writelog "INFO" "${FUNCNAME[0]} - Writing loginuser '${LOGINUSERLONGID},${LOGINUSERSHORTID},${LOGINUSERMOSTRECENT}' to '${LOGINUSERSCSV}'"
		printf '%s;%s;%s\n' "${LOGINUSERLONGID}" "${LOGINUSERSHORTID}" "${LOGINUSERMOSTRECENT}"
	done >"$LOGINUSERSCSV"
}

function updateLocalConfigAppsValue {
	# Add key for specific AppID to localconfig.vdf's Apps section, creating the initial 'Apps' section if it doesn't exist
	# Used to set AllowOverlay and OpenVR when adding Non-Steam Games
	# Note that this may need reworked when we allow the user to select their Steam user

	LCVAID="$1"  # AppID for section name, i.e. '"-1123145"' (must be signed 32bit integer)
	LCVKEYNAME="$2"  # Key to write into section, i.e. '"OverlayAppEnable"'
	LCVKEYVAL="$3"  # Value to assign to key, i.e. '"1"'

	# This part in particular may need reworked if/when we add the option to select a Steam User
	if [ ! -f "$FLCV" ]; then
		writelog "WARN" "${FUNCNAME[0]} - No localconfig.vdf found at '${FLCV}' -- Nothing to do."
		return
	else
		writelog "INFO" "${FUNCNAME[0]} - Using localconfig.vdf (FLCV) file at '$FLCV'"
	fi

	# Get the "Apps" section in localconfig.vdf
	FLCVAPPSSECTION="$( getVdfSection "Apps" "" "1" "${FLCV}" )"
	if [ -z "$FLCVAPPSSECTION" ]; then
		writelog "INFO" "${FUNCNAME[0]} - ${FLCV} is missing 'Apps' section, creating it now"
		createVdfEntry "${FLCV}" "UserLocalConfigStore" "Apps" "" "0" ""
	else
		writelog "INFO" "${FUNCNAME[0]} - localconfig.vdf already has 'Apps' section, nothing to do"
	fi

	# Next we need to check if the given AppID
	FLCVAPPAID="$( getNestedVdfSection "Apps/${LCVAID}" "1" "$FLCV" )"
	if ! grep -q -- "$LCVAID" <<< "$FLCVAPPAID"; then
		# This case adds a new entry under the "Apps" section with the initial content: "LCVKEYNAME"		"LCVKEYVAL"
		writelog "INFO" "${FUNCNAME[0]} - No existing section in 'Apps' section for AppID '${LCVAID}' with key/value pair '${LCVKEYNAME}!${LCVKEYVAL}'"

		FLCVAPPAIDENTRY=( "${LCVKEYNAME}!${LCVKEYVAL}" )
		createVdfEntry "${FLCV}" "Apps" "${LCVAID}" "" "2" "" "${FLCVAPPAIDENTRY[@]}"
	else
		# This case is where the "AppID" section already exists under "Apps", so we want to add the value to the section if it doesn't exist,
		# or update the existing section
		writelog "INFO" "${FUNCNAME[0]} - 'Apps' section already has block for AppID '${LCVAID}', checking if the key '${LCVKEYNAME}' already exists"

		# Check if the "Apps/AppID" section has the given key already
		LCVFSECTIONVAL="$( getVdfSectionValue "${FLCVAPPAID}" "${LCVKEYNAME}" "1" )"
		writelog "INFO" "${FUNCNAME[0]} - LCVFSECTIONVAL is '$LCVFSECTIONVAL'"
		# editVdfSectionValue "${FLCVAPPAID}" "${LCVKEYNAME}" "${LCVKEYVAL}" "${FLCV}" "1"
		if [ -n "$LCVFSECTIONVAL" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Key '${LCVKEYNAME}' already exists in 'Apps/${LCVAID}' section, updating its value from '${LCVFSECTIONVAL}' to '${LCVKEYVAL}'"
			editVdfSectionValue "${FLCVAPPAID}" "${LCVKEYNAME}" "${LCVKEYVAL}" "${FLCV}"
		else
			writelog "INFO" "${FUNCNAME[0]} - Key '${LCVKEYNAME}' does not exist in 'Apps/${LCVAID}' section, adding it now with value '${LCVKEYVAL}'"
			addVdfSectionValue "${FLCVAPPAID}" "${LCVKEYNAME}" "${LCVKEYVAL}" "${FLCV}"
		fi
	fi
}

### END TEXT-BASED VDF INTERACTION FUNCTIONS

