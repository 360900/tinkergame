#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function mkProjDir {
	mkdir -p "$1" 2>/dev/null >/dev/null
}

# create project dirs
function createProjectDirs {
	mkProjDir "$STLCFGDIR"
	mkProjDir "$STLLANGDIR"
	mkProjDir "$LOGDIRID"
	mkProjDir "$LOGDIRTI"
	mkProjDir "$STLPROTONIDLOGDIR"
	mkProjDir "$STLPROTONTILOGDIR"
	mkProjDir "$STLDXVKLOGDIR"
	mkProjDir "$STLWINELOGDIR"
	mkProjDir "$STLGLLOGDIRID"
	mkProjDir "$STLGLLOGDIRTI"
	mkProjDir "$STLGAMEDIRID"
	mkProjDir "$STLGAMEDIRTI"
	mkProjDir "$STLCOLLECTIONDIR"
	mkProjDir "$TWEAKDIR"
	mkProjDir "$USERTWEAKDIR"
	mkProjDir "$TWEAKCMDDIR"
	mkProjDir "$SBSTWEAKDIR"
	mkProjDir "$STLDLDIR"
	mkProjDir "$STLSHADDIR"
	mkProjDir "$STLVORTEXDIR"
	mkProjDir "${STLVORTEXDIR}/downloads"
	mkProjDir "$RESHADESRCDIR"
	mkProjDir "$CUSTPROTDLDIR"
	mkProjDir "$CUSTPROTEXTDIR"
	mkProjDir "$WINEDLDIR"
	mkProjDir "$WINEEXTDIR"
	mkProjDir "$STLGAMES"
	mkProjDir "$STLGDESKD"
	mkProjDir "$STLIDFD"
	mkProjDir "$STLGHEADD"
	mkProjDir "$STLGICO"
	mkProjDir "$STLGZIP"
	mkProjDir "$STLGPNG"
	mkProjDir "$STLAPPINFOIDDIR"
	mkProjDir "$HIDEDIR"
	mkProjDir "$VORTEXCOMPDATA"
	mkProjDir "$GEMETA"
	mkProjDir "$MO2COMPDATA"
	mkProjDir "$STLVKD3DLOGDIR"
	mkProjDir "$GEMETA"
	mkProjDir "$CUMETA"
	mkProjDir "$TIGEMETA"
	mkProjDir "$TICUMETA"
	mkProjDir "$STLCUSTVARSDIR"
	mkProjDir "$STLGDECKCOMPAT"
}

# upgrade configfile $1 (global var CFGFILE) for scope $2 to the current
# option schema: renames legacy typo keys, drops duplicate and unknown keys,
# keeps allowlisted per-game keys verbatim, preserves comments belonging to
# kept keys and appends missing schema keys. A timestamped backup of the
# original file is written to $STLBACKDIR beforehand.
function tgUpgradeConfigFile {

	# pre-resolve value and description for every schema key of scope $2:
	local key desc val line tkey tval
	local -A tmpl=()

	# per-game configs inherit values for missing keys from the default template:
	UPFROMTMPL=0
	if [ "$CFGFILE" == "$STLGAMECFG" ] && [ -f "$STLDEFGAMECFG" ]; then
		UPFROMTMPL=1
		while IFS= read -r line; do
			case "$line" in
				"#"*|"") continue ;;
				*=*)
					tkey="${line%%=*}"
					tval="${line#*=}"
					tval="${tval%\"}"
					tval="${tval#\"}"
					tmpl["$tkey"]="$tval"
					;;
			esac
		done < "$STLDEFGAMECFG"
	fi

	local keysfile="$STLSHM/tg-upgrade-keys.$$"
	local dropfile="$STLSHM/tg-upgrade-dropped.$$"
	local newfile="${CFGFILE}.tgnew"
	mkProjDir "$STLSHM"
	: > "$dropfile"

	while IFS= read -r key; do
		[ -n "$key" ] || continue
		if [ "$UPFROMTMPL" -eq 1 ] && [ -n "${tmpl[$key]+x}" ]; then
			val="${tmpl[$key]}"
		else
			val="${!key}"
		fi
		val="${val//$STLCFGDIR/STLCFGDIR}"
		desc="$(tgSchemaDesc "$2" "$key")"
		if [ -n "$desc" ]; then
			desc="$(tgExpandDesc "$desc")"
		fi
		printf '%s\037%s\037%s\n' "$key" "$val" "$desc"
	done <<< "$(tgSchemaKeys "$2")" > "$keysfile"

	awk -F'\037' -v dropfile="$dropfile" '
		FNR == NR {
			# schema keysfile: key, resolved value, expanded description
			n++
			korder[n] = $1
			kval[$1] = $2
			kdesc[$1] = $3
			next
		}
		{
			if (match($0, /^[A-Za-z][A-Za-z0-9_]*=/)) {
				k = substr($0, 1, RLENGTH - 1)
				v = substr($0, RLENGTH + 1)
				# legacy typo keys are renamed in place:
				if (k == "RESHADEPROJURl") {
					k = "RESHADEPROJURL"
					$0 = k "=" v
				} else if (k == "MO2SILENTMODEDESC_MO2SILENTMODEEXEOVERRIDE") {
					k = "MO2SILENTMODEEXEOVERRIDE"
					$0 = k "=" v
				}
				# allowlisted per-game keys are always kept verbatim:
				if (k == "STLDXVKCFG" || k == "INSTALL_RESHADE" || k == "CHECKCATEGORIES") {
					printf "%s", pending
					pending = ""
					print $0
					next
				}
				if (k in kval) {
					if (k in seen) {
						pending = ""
						print "duplicate\t" k > (dropfile)
						next
					}
					seen[k] = 1
					printf "%s", pending
					pending = ""
					print $0
					next
				}
				pending = ""
				print "unknown\t" k > (dropfile)
				next
			}
			# comments and any other non-key lines are buffered so they stay
			# attached to (and are dropped with) the key line that follows:
			pending = pending $0 "\n"
		}
		END {
			printf "%s", pending
			for (i = 1; i <= n; i++) {
				k = korder[i]
				if (!(k in seen)) {
					if (kdesc[k] != "") {
						print "## " kdesc[k]
					}
					print k "=\"" kval[k] "\""
				}
			}
		}
	' "$keysfile" "$CFGFILE" > "$newfile" && mv "$newfile" "$CFGFILE"

	while IFS=$'\t' read -r dtype dkey; do
		[ -n "$dkey" ] || continue
		if [ "$dtype" = "duplicate" ]; then
			writelog "UPDATE" "${FUNCNAME[0]} - Removed duplicate key '$dkey' from '$CFGFILE'"
		else
			writelog "UPDATE" "${FUNCNAME[0]} - Removed unknown key '$dkey' from '$CFGFILE'"
		fi
	done < "$dropfile"

	rm -f "$keysfile" "$dropfile" "$newfile"
}

# add missing config entries to configfile $1 for scope $2 (url|gui|global|default_template):
function updateConfigFile {

	if [ -z "$1" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Expected configfile as argument 1"
	else
		CFGFILE="$1"
		SEP="$2"

		if ! tgSchemaKeys "$SEP" | grep -q .; then
			writelog "SKIP" "${FUNCNAME[0]} - Unknown config scope '$SEP' - skipping '$CFGFILE'"
		else

			# disable logging temporarily when the program just started (cosmetics)
			if [ -n "$3" ]; then
				ORGLOGLEVEL="$LOGLEVEL"
				LOGLEVEL=0
			fi

			if grep "$STLCFGDIR" "$CFGFILE" >/dev/null ; then
				writelog "UPDATE" "${FUNCNAME[0]} - Replacing '$STLCFGDIR' with 'STLCFGDIR' in '$CFGFILE'"
				sed "s:$STLCFGDIR:STLCFGDIR:g" -i "$CFGFILE"
			fi

			if grep -q "config Version: $PROGVERS" "$CFGFILE"; then
				writelog "SKIP" "${FUNCNAME[0]} - Config file '$CFGFILE' already at version '$PROGVERS'"
			else
				OLDVERS="$(grep "config Version" "$CFGFILE" | awk -F ': ' '{print $2}')"

				# snapshot the original file before touching anything:
				if mkProjDir "$STLBACKDIR"; then
					cp "$CFGFILE" "$STLBACKDIR/${CFGFILE##*/}.$(date +%Y%m%d-%H%M%S).bak" 2>/dev/null
				fi

				if [ -n "$OLDVERS" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Updating '$CFGFILE' from '$OLDVERS' to '$PROGVERS'"
					sed "s/config Version: $OLDVERS/config Version: $PROGVERS/" -i "$CFGFILE"
				else
					writelog "INFO" "${FUNCNAME[0]} - Updating '$CFGFILE' to '$PROGVERS'"
					sed "1s/^/##########################\n/" -i "$CFGFILE"
					sed "1s/^/## config Version: $PROGVERS\n/" -i "$CFGFILE"
				fi

				tgUpgradeConfigFile "$CFGFILE" "$SEP"
			fi

			# re-enable logging
			if [ -n "$3" ]; then
				LOGLEVEL="$ORGLOGLEVEL"
			fi
		fi
	fi
}

function linkGameCfg {
	if [ -z "$GN" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Skipping symlinking config - no valid game name found"
	else
		createSymLink "${FUNCNAME[0]}" "$STLGAMECFG" "${STLGAMEDIRTI}/${GN}.conf"
	fi
}

# create game configs:
function createGameCfg {

	if [ -f "$STLGAMECFG" ]; then
		# add missing config entries in the default global config:
		updateConfigFile "$STLGAMECFG" "default_template"
	else
		updateConfigEntry "CUSTOMCMD" "$DUMMYBIN" "$STLDEFGAMECFG"
		getGameName "$AID"
		if [ -n "$GAMENAME" ] && [ "$GAMENAME" != "$NON" ]; then
		{
		echo "## config Version: $PROGVERS"
		echo "##########################"
		echo "#########"
		echo "#$PROGNAME $PROGVERS"
		echo "#########"
		getCfgHeader
		echo "## set the default config file for DXVK_CONFIG_FILE which is used when found - defaults to config found in $STLDXVKDIR"
		echo "STLDXVKCFG=\"$STLDXVKDIR/$AID.conf\""
		grep -v "config Version" "$STLDEFGAMECFG"
		} >> "$STLGAMECFG"
		else
			writelog "SKIP" "${FUNCNAME[0]} - No game name found for '$AID' - does the game exist?"
		fi
	fi
	linkGameCfg
}

# override game configs with a tweak config if available:
function checkTweakLaunch {
	if [ -z "$TWEAKCMD" ]; then
		TWEAKCMD=""
	fi

	if [ -f "$GLOBALTWEAKCFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using overrides found in '$GLOBALTWEAKCFG'"
		notiShow "$(strFix "$NOTY_GLOBALTWEAK" "$GLOBALTWEAKCFG")"
		loadCfg "$GLOBALTWEAKCFG"
	fi

	# then user config - (overriding the global one)
	if [ -f "$TWEAKCFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Using overrides found in '$TWEAKCFG'"
		loadCfg "$TWEAKCFG"
	fi

	if [ -n "$TWEAKCMD" ]; then
		# tweak command defined
		if [ -f "$TWEAKCMD" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found TWEAKCMD '$TWEAKCMD'"
			RUNTWEAK="$TWEAKCMD"
		elif [ -f "$TWEAKCMDDIR/$TWEAKCMD" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found TWEAKCMD '$TWEAKCMD' in '$TWEAKCMDDIR'"
			RUNTWEAK="$TWEAKCMDDIR/$TWEAKCMD"
		elif [ -f "$GFD/$TWEAKCMD" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Found TWEAKCMD '$TWEAKCMD' in '$GFD'"
			RUNTWEAK="$GFD/$TWEAKCMD"
		fi
		# tweak command found

		if [ -n "$RUNTWEAK" ]; then

			if grep -q "^TWEAKFILE" "$RUNTWEAK"; then
				# dependency for tweak command defined
				writelog "INFO" "${FUNCNAME[0]} - TWEAKFILE configured in $RUNTWEAK as dependency - checking if the file exists in gamedir - relative to the gameexe"
				TWEAKFILE="$(grep "^TWEAKFILE" "$RUNTWEAK" | awk -F 'TWEAKFILE=' '{print $2}')"
				if [ -f "$EFD/$TWEAKFILE" ]; then
					# dependency for tweak command found
					writelog "INFO" "${FUNCNAME[0]} - Found tweakcmd dependency in $EFD/$TWEAKFILE - starting the tweakcmd now"
					# start tweak command
					"$RUNTWEAK"
					writelog "INFO" "${FUNCNAME[0]} - $RUNTWEAK finished"
				else
					# dependency for tweak command not found
					writelog "SKIP" "${FUNCNAME[0]} - Configured TWEAKFILE $TWEAKFILE not found - skipping launch of the tweakcmd $TWEAKCMD"
				fi
			else
				# start tweak command
				writelog "INFO" "${FUNCNAME[0]} - No TWEAKFILE configured in $RUNTWEAK as dependency - starting the tweakcmd regularly now"
				"$RUNTWEAK"
				writelog "INFO" "${FUNCNAME[0]} - $RUNTWEAK finished"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - Configured TWEAKCMD $TWEAKCMD not found - can't start it"
		fi
	fi
}

function genDefIcon {
	if [ ! -f "$STLICON" ]; then
		base64 -d <<< "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAZlBMVEUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcHByAgIAAAAD///8AAACfn5+AgIC/v78QEBDv7+9gYGBQUFCvr6/Pz88wMDAgICDf399wcHBAQECPj4/mYUh/AAAAEXRSTlMAYICf778gj3DfUEAwz48gEPfJjAsAAAKXSURBVFjDnZfpetsgFEQtW17jtGVAgNBi9/1fsiDz5dbBTKLMH286xwgBFzaSa7Pdbi+Hzc9y+NXikffmJ/wp4pM3xvQWOF9X8zugH1yIgqD0BDSreRucsUixxvloWMsP8wiMsQXpZdDrDMfIqwljp1K6CdaVhsv2VZaL3oBBqVvv1CPOT059NjR4nbf42xlGlckG4dO/qKF7yoh9asCkVM0gvLFWq0/xAK6xB26KGDKv1WCR7lLieowex80enWKGzC+A/SsKbeFdF+8BUIoaMh8TJlivuxjtLWyIXwFJQA3Cx+gROaN2SgTMsPCSOZiYMMe3WdDCEYNPfD0ObezEQFrAeRViJ57gOc/icdocgJnw80z4GTikudjXed6GHru0mLUwhCcGg/awzFRAV3li0MBFxnqVFwOfbZrwgGa8GEpeDJQXQ8mPoxgIL4ay/+RdjRdDwUPFQAwVXgzClwJowovhmYd3zkMMVV4MwuNmeizpzS0bCC+rvw5IWcb3HTH3ZdQuCZlnRVZHakm3cNnUAYsr8bsqnnuBtUAjpqF8TKUPpIcayseUT0H4L55iTjkOhOfjSAyFIPN8JEuKuSA8nUsSmY0Fz2ZzaSh4sp5UDMLzFa1mEL5muJB1V/j6qix1oYwWvlYXpDLR6kQq0wGg5W9OPKmNUp1JG2h13iOs4cv9QQvHec93KCv2SEXW7tK4gO8TieC7O9XX6bD/9l75ZW44frVb54YJ8Xz2DkN4ajDY5xPLc7t64alhAN4+zkwq3B+dOd9hhWeGweIopzZlgN4E0yN+4Kuu8Lv/z43KfNQSX1v3vZKED15OrtoYo52e6pVn0hkfemC3+ux8PQO2jxf5CWhPzz/+3p6/cXpv3vHIefsnf/UP3QHUzgWHsSYAAAAASUVORK5CYII=" > "$STLICON"
	fi

	if [ ! -f "$NOICON" ]; then
		base64 -d <<< "R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==" > "$NOICON"
	fi
}

function createDefaultCfgs {
	writelog "INFO" "${FUNCNAME[0]} - START"

	createProjectDirs

	loadLanguage "$@"

	writelog "INFO" "${FUNCNAME[0]} - setSteamPaths:"
	setSteamPaths

	saveCfg "$STLDEFGLOBALCFG" X
	loadCfg "$STLDEFGLOBALCFG" X
	saveCfg "$STLURLCFG" X
	loadCfg "$STLURLCFG" X
	prepareGUI
	genDefIcon

	createProjectDirs
	getGameOS "$@"
	delEmptyFile "$PROTONCSV"

	if [ "$HAVEINPROTON" -eq 0 ]; then
		if [ "$ISGAME" -eq 2 ] || [ ! -f "$PROTONCSV" ]; then
			writelog "INFO" "${FUNCNAME[0]} - createProtonList:"
			createProtonList X
			writelog "INFO" "${FUNCNAME[0]} - createProtonList end"
		elif [ "$ISGAME" -ne 2 ] && [ -f "$PROTONCSV" ]; then
			mapfile -t -O "${#ProtonCSV[@]}" ProtonCSV < "$PROTONCSV"
		fi
	fi

	checkStartMode
	saveCfg "$STLDEFGAMECFG" X
	createProjectDirs
	setGlobalAIDCfgs
	listAllSettingsEntries
	checkEntryBlocklist
	updateMenuSortFile
	writelog "INFO" "${FUNCNAME[0]} - STOP"
}

# updates or creates option $1 with value $2 in configfile $3:
function updateConfigEntry {
	CFGCAT="$1"
	CFGVALUE="$2"
	CFGFILE="$3"

	if [ "$CFGCAT" == "CUSTOMCMD" ] && [ "$CFGFILE" == "$STLDEFGAMECFG" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Emptying '$CFGCAT' for '$STLDEFGAMECFG'"
		CFGVALUE="$DUMMYBIN"
	fi

	if [ -z "$3" ]; then
		writelog "SKIP" "${FUNCNAME[0]} - Expected 3 arguments - only got $*"
	else
		if [ ! -f "$CFGFILE" ]; then
			writelog "SKIP" "${FUNCNAME[0]} - Configfile '$CFGFILE' does not exist - skipping config update"
		else
			if [ -n "$CFGVALUE" ]; then
				if [ "$CFGVALUE" == "TRUE" ]; then
					CFGVALUE="1"
				elif [ "$CFGVALUE" == "FALSE" ]; then
					CFGVALUE="0"
				fi

				if [ "$CFGVALUE" == "DUMMY" ]; then
					CFGVALUE=""
				fi

				# only save value if it changed
				# sed needs escaped string because otherwise it'll expand escape sequences in strings with backslashes
				# i.e. config values with Windows paths, '\home\test' will have '\t' expanded as a tab character
				# We have to use the regular one for echo though.
				if { [ "${!CFGCAT}" != "$CFGVALUE" ] && [ "${!CFGCAT}" != "${CFGVALUE//$STLCFGDIR/STLCFGDIR}" ];} || [ -f "$FUPDATE" ]; then
					CFGVALUE="${CFGVALUE//$STLCFGDIR/STLCFGDIR}"
					# escape AFTER the STLCFGDIR substitution so the sed branches below
					# persist the placeholder exactly like the append branch does
					ESCAPED_CFGVALUE="$( printf "%s\n" "$CFGVALUE" | sed 's/\\/\\\\/g' )"
					if [ "$(grep -c "#${CFGCAT}=" "$CFGFILE")" -eq 1 ]; then
						writelog "INFO" "${FUNCNAME[0]} - Option '$CFGCAT' commented out in config '${CFGFILE##*/}' - activating it with the new value '$CFGVALUE'"
						sed -i "/^#${CFGCAT}=/c$CFGCAT=\"$ESCAPED_CFGVALUE\"" "$CFGFILE"
					elif [ "$(grep -c "^${CFGCAT}=" "$CFGFILE")" -eq 0 ]; then
						writelog "INFO" "${FUNCNAME[0]} - '$CFGCAT' option missing in config '${CFGFILE##*/}' - adding a new line"
						echo "$CFGCAT=\"$CFGVALUE\"" >> "$CFGFILE"
					else
						writelog "INFO" "${FUNCNAME[0]} - Option '$CFGCAT' is updated with the new value '$CFGVALUE' in config '${CFGFILE##*/}'"
						sed -i "/^${CFGCAT}=/c$CFGCAT=\"$ESCAPED_CFGVALUE\"" "$CFGFILE"
					fi
					rm "$FUPDATE" 2>/dev/null
				fi
			fi
		fi
	fi

	CFGCAT=""
	CFGVALUE=""
	CFGFILE=""
}

# autoapply configuration settings based on the steam collections the game is in:
function autoCollectionSettings {
	if [ "$CHECKCOLLECTIONS" -eq 1 ] && [ "$STLPLAY" -eq 0 ]; then
		if [ -z "$SUSDA" ] || [ -z "$STUIDPATH" ]; then
			setSteamPaths
		fi
		if [ -d "$SUSDA" ]; then
			SC="$STUIDPATH/$SRSCV"

			if [ ! -f "$SC" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - File '${SC##*/}' not found in steam userid dir - skipping"
			else
				writelog "INFO" "${FUNCNAME[0]} - Searching collections for game '$AID' in '$SC'"
				while read -r SCAT; do
					GLOBALSCATCONF="$(find "$GLOBALCOLLECTIONDIR" -type f -iname "$SCAT.conf")"

					# Should we break after a file to load is found? Is there benefit to loading another file?
					if [ -f "$GLOBALSCATCONF" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Global Config '$GLOBALSCATCONF' found - loading its settings"
						loadCfg "$GLOBALSCATCONF"
					else
						writelog "SKIP" "${FUNCNAME[0]} - Global Config '$GLOBALSCATCONF' not found - skipping"
					fi

					SCATCONF="$(find "$STLCOLLECTIONDIR" -type f -iname "$SCAT.conf")"

					if [ -f "$SCATCONF" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Collections Directory Config '$SCATCONF' found - loading its settings"
						loadCfg "$SCATCONF"
					else
						writelog "SKIP" "${FUNCNAME[0]} - Collections Directory Config '$SCATCONF' not found - skipping"
					fi

					SCATCMD="$TWEAKCMDDIR/$SCAT.sh"
					if [ -f "$SCATCMD" ]; then
						writelog "INFO" "${FUNCNAME[0]} - Steam-Collection user command '$SCATCMD' found - executing"
						if [ "$USEWINE" -eq 0 ]; then
							"$SCATCMD" "$AID" "$EFD" "$GPFX"
						else
							"$SCATCMD" "$AID" "$EFD" "$GWFX"
						fi
					fi
				done <<< "$(sed -n "/\"$AID\"/,/}/p;" "$SC" | sed -n "/\"tags\"/,/}/p" | sed -n "/{/,/}/p" | grep -v '{\|}' | cut -d '"' -f4)"
			fi
		else
			writelog "SKIP" "${FUNCNAME[0]} - '$SUSDA' not found - this should not happen! - skipping"
		fi
	fi
}

function stracerun {
	writelog "INFO" "${FUNCNAME[0]} - Starting stracerun"
	waitForGamePid
	writelog "INFO" "${FUNCNAME[0]} - $STRACE -p $(GAMEPID) $STRACEOPTS -o $STRACEDIR/$AID.log"
	mapfile -d " " -t -O "${#RUNSTRACEOPTS[@]}" RUNSTRACEOPTS < <(printf '%s' "$STRACEOPTS")
	"$STRACE" -p "$(GAMEPID)" "${RUNSTRACEOPTS[@]}" -o "$STRACEDIR/$AID.log"
}

function checkStraceLaunch {
	if [ -n "$STRACERUN" ]; then
		if [ "$STRACERUN" -eq 1 ]; then
			stracerun &
		fi
	fi
}

function netrun {
	writelog "INFO" "${FUNCNAME[0]} - Starting network traffic monitor"

	waitForGamePid

	if [ -n "$NETMONDIR" ]; then
		if [ ! -d "$NETMONDIR" ]; then
			writelog "INFO" "${FUNCNAME[0]} - $NETMON dest directory $NETMONDIR does not exist - trying to create it"
			mkProjDir "$NETMONDIR"
		fi

		if [ -d "$NETMONDIR" ]; then
			writelog "INFO" "${FUNCNAME[0]} - Writing network traffic for $AID int dest directory $NETMONDIR"
			if [ -f "$NETMONDIR/$AID-$NETMON.log" ]; then
				writelog "INFO" "${FUNCNAME[0]} - Removing old $NETMONDIR/$AID-$NETMON.log"
				rm "$NETMONDIR/$AID-$NETMON.log"
			fi
			mapfile -d " " -t -O "${#RUNNETOPTS[@]}" RUNNETOPTS < <(printf '%s' "$NETOPTS")
			"$NETMON" "${RUNNETOPTS[@]}" | grep "wineserver" | grep -v "localhost\|0.0.0.0" >> "$NETMONDIR/$AID-$NETMON.log"
		else
			writelog "SKIP" "${FUNCNAME[0]} - $NETMON dest directory $NETMONDIR still does not exist - skipping"
		fi
	else
		writelog "SKIP" "${FUNCNAME[0]} - $NETMON dest directory variable NETMONDIR is empty"
	fi
}

function checkNetMonLaunch {
	if [ "$USENETMON" -eq 1 ]; then
		if [ -n "$NETMON" ]; then
			netrun &
		fi
	fi
}

function checkXliveless {
	if [ -n "$NOGFWL" ]; then
		if [ "$NOGFWL" -eq 1 ]; then
			rm -rf "$GPFX/$DRC/$PFX86/Microsoft Games for Windows - LIVE"
			rm -rf "$GPFX/$DRC/Program Files/Common Files/Microsoft Shared/Windows Live"
			# option for USEWINE probably not really required
			WLID="WLIDSvcM.exe"
			if "$PGREP" "$WLID" >/dev/null; then
				writelog "INFO" "${FUNCNAME[0]} - GFWL starts '$WLID' directly after installation and it never exists - killing it now"
				"$PKILL" -9 "$WLID"
			fi

			XLIVEDLL="xlive.dll"
			XLDL="$STLDLDIR/xlive/"
			XLDST="$XLDL/$XLIVEDLL"
			mkProjDir "$XLDL"

			writelog "INFO" "${FUNCNAME[0]} - Game '$SGNAID' needs '$XLIVEDLL' - checking"
			if [ -f "$EFD/$XLIVEDLL" ]; then
				writelog "SKIP" "${FUNCNAME[0]} - Found '$XLIVEDLL' in dir $EFD - nothing to do"
			else
				writelog "INFO" "${FUNCNAME[0]} - '$XLIVEDLL' not found in gamedir '$EFD'"
				if [ ! -f "$XLDST" ]; then
					dlCheck "$XLIVEURL" "$XLDST" "X" "'$XLDST' not found - downloading automatically from '$XLIVEURL'"
					"$UNZIP" "$XLDL/${DLURL##*/}" -d "$XLDL"
					if [ -f "$XLDL/dinput8.dll" ]; then
						mv "$XLDL/dinput8.dll" "$XLDST"
					fi
				fi
				if [ -f "$XLDST" ]; then
					writelog "INFO" "${FUNCNAME[0]} - Found '$XLIVEDLL' in '$XLDL' - copying into gamedir '$EFD'"
					cp "$XLDST" "$EFD"
				fi
			fi
		fi
	fi
}

