#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function migrateCfgOption {
	# temporary function to update specific configuration options - will vary depending on the current tinkergame version and mostly won't be used at all
	if [ "$1" == "$STLGAMECFG" ]; then
		# update dxvk config handling:
		if grep -q "^#STLDXVKCFG" "$STLGAMECFG" && ! grep -q "^STLDXVKCFG" "$STLGAMECFG"; then
			writelog "INFO" "${FUNCNAME[0]} - Commenting in STLDXVKCFG in '$STLGAMECFG' automatically"
			sed "s:^#STLDXVKCFG:STLDXVKCFG:g" -i "$STLGAMECFG"
		fi

		if [ -z "$STLDXVKCFG" ]; then
			STLDXVKLINE="$(grep "^STLDXVKCFG" "$STLGAMECFG")"
			STLDXVKLINE="${STLDXVKLINE//\"/}"
			STLDXVKLINE="${STLDXVKLINE//STLCFGDIR/$STLCFGDIR}"
			if [ -n "$STLDXVKLINE" ]; then
				export "${STLDXVKLINE?}"
			fi
		fi

		if [ -z "$STLDXVKCFG" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Variable 'STLDXVKCFG' could not be found - giving up"
		else
			if [ -z "$STLGAMECFG" ]; then
				setAIDCfgs
			fi

			if grep -q "^STLDXVKCFG" "$STLGAMECFG" && ! grep -q "^USE_STLDXVKCFG=\"1\"" "$STLGAMECFG"; then
				if [ -f "$STLDXVKCFG" ]; then
					if [ "$(wc -l < "$STLDXVKCFG")" -eq 1 ] && grep "^NOTE" "$STLDXVKCFG"; then
						writelog "INFO" "${FUNCNAME[0]} - Empty placeholder config '$STLDXVKCFG' found - not enabling USE_STLDXVKCFG automatically"
					elif [ "$(wc -l < "$STLDXVKCFG")" -gt 1 ] || { [ "$(wc -l < "$STLDXVKCFG")" -eq 1 ] && ! grep "^NOTE" "$STLDXVKCFG"; }; then
						mkProjDir "$STLTEMPDIR"
						DXVKMIGLIST="$STLTEMPDIR/dxvkcfg.txt"
						touch "$DXVKMIGLIST"
						if grep -q "^$AID$" "$DXVKMIGLIST"; then
							writelog "SKIP" "${FUNCNAME[0]} - STLDXVKCFG was already updated for '$AID' before"
						else
							writelog "INFO" "${FUNCNAME[0]} - Found STLDXVKCFG in '$STLGAMECFG' being used, so automatically enabling USE_STLDXVKCFG"
							touch "$FUPDATE"
							USE_STLDXVKCFG=1
							updateConfigEntry "USE_STLDXVKCFG" "$USE_STLDXVKCFG" "$STLGAMECFG"
							echo "$AID" > "$DXVKMIGLIST"
						fi
					else
						writelog "INFO" "${FUNCNAME[0]} - Unknown constellation - shouldn't happen"
					fi
				else
					writelog "INFO" "${FUNCNAME[0]} - File '$STLDXVKCFG' does not exist - nothing to do"
				fi
			fi
		fi

		# specialk replace "old" version
		if [ "$SPEKVERS" == "discord" ] || [ "$SPEKVERS" == "old" ] || [ "$SPEKVERS" == "latest" ] || [ "$SPEKVERS" == "default" ] || [ "$SPEKVERS" == "test" ]; then
			SPEKVERS="stable"
			touch "$FUPDATE"
			writelog "INFO" "${FUNCNAME[0]} - Automatically updating variable SPEKVERS from 'old' to '$SPEKVERS' in '$STLGAMECFG'"
			updateConfigEntry "SPEKVERS" "$SPEKVERS" "$STLGAMECFG"
		fi

		# stop MO2MODE from being 'none' in weird scenarios -- Issue was confirmed to be exclusive to SteamOS and may be a (temporary?) SteamOS regression
		if [ "$MO2MODE" == "$NON" ]; then
			MO2MODE="disabled"
			touch "$FUPDATE"
			writelog "INFO" "${FUNCNAME[0]} - ModOrganizer 2 variable MO2MODE is somehow '$NON' -- Defaulting this to 'disabled'"
			updateConfigEntry "MO2MODE" "$MO2MODE" "$STLGAMECFG"
		fi

		# collections update
		if [ -n "$CHECKCATEGORIES" ] && [ "$CHECKCATEGORIES" -eq 1 ]; then
			CHECKCOLLECTIONS="$CHECKCATEGORIES"
			touch "$FUPDATE"
			writelog "INFO" "${FUNCNAME[0]} - Automatically updating variable CHECKCOLLECTIONS from old variable CHECKCATEGORIES"
			updateConfigEntry "CHECKCOLLECTIONS" "$CHECKCOLLECTIONS" "$STLGAMECFG"
		fi

		# ReShade changes -- Combine USERESHADE and RESHADE_INSTALL into one option (ensure USERESHADE matches whatever value INSTALL_RESHADE had now that they are equivalent)
		if [ -n "$INSTALL_RESHADE" ] && [ "$INSTALL_RESHADE" -eq 1 ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found legacy 'INSTALL_RESHADE' with value '$INSTALL_RESHADE' -- disabling as this is no longer used"
			INSTALL_RESHADE=0
			USERESHADE=1

			# If INSTALL_RESHADE was ever on, disable it and force USERESHADE to 1 as these options are equivalent now
			touch "$FUPDATE"
			updateConfigEntry "INSTALL_RESHADE" "$INSTALL_RESHADE" "$STLGAMECFG"
			updateConfigEntry "USERESHADE" "$USERESHADE" "$STLGAMECFG"
		fi
	fi
}

