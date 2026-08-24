#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function setGameScopeVars {
	function getGameScopeArg {
		ARGS="$1"  # e.g. "$GAMESCOPE_ARGS"
		UNESCAPED_FLAG="$2"
		FLAG="${2//-/\\-}"  # e.g. "--hdr-enabled" becomes "\-\-hdr\-enabled"
		VAR="$3"  # e.g. "$GSHDR"
		TRUEVAL="$4"  # e.g. "1" (on UI)
		DEFVAL="$5"  # e.g. "0" (on UI)
		ARGTYPE="${6,,}"  # e.g. "chk", "cb", etc (matches Yad widget types mostly)

		# Set values for undefined arguments
		if [ -n "$VAR" ]; then
			return
		fi

		# If the flag is not in the args string, return the default value for display purposes
		if ! grep -qw "$FLAG" <<< "$ARGS"; then
			echo "$DEFVAL"
			return
		fi

		if [[ $ARGTYPE =~ "cb" ]] || [[ $ARGTYPE =~ "num" ]]; then
			# Get the value given to the argument as the enabled/selected value, e.g. get '2' from '-U 2' if we passed '-U'
			# If the value does not contain only numbers (with or without decimals) then this will be blank and we return the default value 'DEFVAL'
			GSPARSEDARGVAL="$( tr ' ' '\n' <<< "$ARGS" | grep -wA1 "$FLAG" | tail -n1 )"

			# Don't validate parsed value for combobox, this is free-text and could be anything
			if ! [[ $ARGTYPE =~ "num" ]]; then
				echo "$GSPARSEDARGVAL"
				return
			fi

			# If we get passed an invalid GameScope commandline argument where a flag that is supposed to be followed by a NUMBER is not,
			# we could end up returning the next argument, e.g. `-s -f` would return `-s` if we didn't include the `grep -P`
			# Using the `grep -P` we filter out potential garbage returned by the rest of the parsing.
			#
			# We are most likely to encounter problems without this `grep -P` when it comes to the `GSINTRES` and `GSSHWRES`,
			# as if these are blank we end up displaying 'x'.
			#
			# For comboboxes that can display text, we will just have to assume we are passed a valid string, as freetext comboboxes could contain
			# anything and we cannot/should not try to assume what is valid for them in this way.
			# This logic only exists to filter out non-numerical values for flags which expect to be given a numerical argument
			#
			# For more background, see: https://github.com/sonic2kk/steamtinkerlaunch/pull/1152#issuecomment-2316286429
			GSPARSEDARGNUMVAL="$( echo "${GSPARSEDARGVAL}" | grep -P "^([\d]+)(?:\.([\d]{1,2}?))?$" )"
			if [ -n "${GSPARSEDARGNUMVAL}" ]; then
				echo "$GSPARSEDARGNUMVAL"
			else
				echo "$DEFVAL"
			fi
		elif [[ $ARGTYPE =~ "path" ]] || [[ $ARGTYPE =~ "txt" ]]; then
			# Get value given to arguments with two dashes, like `--`
			echo "$ARGS" | sed 's:--:\n--:g' | grep -wA1 "$FLAG" | sed "s:${UNESCAPED_FLAG}::g;s:-:\n-:g" | head -n1 | xargs
		else
			echo "$TRUEVAL"
		fi
	}

	function getGameScopeGeneralOpts {
		# GameScope Show Resolution (corresponds to -W, -H options, uppercase) -- Actual GameScope window size (defaults to 1280x720) -- Dropdown
		# Although this is a combobox, we still use "num" as the `getGameScopeArg` type because we want numeric validation
		GSSHOWRESARGWIDTH="$( getGameScopeArg "$GAMESCOPE_ARGS" "-W" "$GSSHOWRESARGWIDTH" "" "1280" "num")"
		GSSHOWRESARGHEIGHT="$( getGameScopeArg "$GAMESCOPE_ARGS" "-H" "$GSSHOWRESARGHEIGHT" "" "720" "num")"

		GSSHWRES="${GSSHOWRESARGWIDTH}x${GSSHOWRESARGHEIGHT}"

		# GameScope Internal Resolution (corresponds to -w, -h options, lowercase) -- Resolution that games see (defaults to 1280x720) -- Dropdown
		# Although this is a combobox, we still use "num" as the `getGameScopeArg` type because we want numeric validation
		GSINTRESARGWIDTH="$( getGameScopeArg "$GAMESCOPE_ARGS" "-w" "$GSINTRESARGWIDTH" "" "1280" "num")"
		GSINTRESARGHEIGHT="$( getGameScopeArg "$GAMESCOPE_ARGS" "-h" "$GSINTRESARGHEIGHT" "" "720" "num")"

		GSINTRES="${GSINTRESARGWIDTH}x${GSINTRESARGHEIGHT}"

		# Default internal resolution to $NON ('none') if blank -- Ensures we don't pass invalid resolution to GameScope
		if [ -z "$GSINTRES" ]; then  GSINTRES="$NON"; fi

		# Default show resolution to $NON ('none') if blank -- Ensures we don't pass invalid resolution to GameScope
		if [ -z "$GSSHWRES" ]; then  GSSHWRES="$NON"; fi

		# Focused Frame Rate Limit -- Dropdown
		GSFLR="$( getGameScopeArg "$GAMESCOPE_ARGS" "-r" "$GSFLR" "" "$UL" "cb")"

		# Unfocused Frame Rate Limit -- Dropdown
		GSFLU="$( getGameScopeArg "$GAMESCOPE_ARGS" "-o" "$GSFLU" "" "$UL" "cb")"

		# Fullscreen (-f) -- Checkbox
		GSFS="$( getGameScopeArg "$GAMESCOPE_ARGS" "-f" "$GSFS" "1" "0" )"

		# Borderless Window (-b) -- Checkbox
		GSBW="$( getGameScopeArg "$GAMESCOPE_ARGS" "-b" "$GSBW" "1" "0" )"

		# Steam Integration (-e) -- Can fix some strange bugs with some peripherals -- Checkbox
		GSSE="$( getGameScopeArg "$GAMESCOPE_ARGS" "-e" "$GSSE" "1" "0" )"

		# Force windows to be fullscreen inside the nested dislay (--force-windows-fullscreen) -- Checkbox
		GSFWF="$( getGameScopeArg "$GAMESCOPE_ARGS" "--force-windows-fullscreen" "$GSFWF" "1" "0" )"

		# Force grab cursor -- Keeps cursor inside GameScope nested display -- Checkbox
		GSFGC="$( getGameScopeArg "$GAMESCOPE_ARGS" "--force-grab-cursor" "$GSFGC" "1" "0" )"

		# Force grab keyboard -- Keeps keyboard input locked to GameScope nested display -- Checkbox
		GSFGK="$( getGameScopeArg "$GAMESCOPE_ARGS" "-g" "$GSFGK" "1" "0" )"

		# Orientation (--force-orientation) -- Can be either 'left', 'right', 'normal', 'upsidedown' (Defaults to 'normal') -- Dropdown
		# NOTE: Passing this normally to GameScope (e.g. `gamescope --force-orientation upsidedown -- supertuxkart`) doesn't seem to do anything?
		GSFOOR="$( getGameScopeArg "$GAMESCOPE_ARGS" "--force-orientation" "$GSFOOR" "" "$GSNORM" "cb")"

		# Custom cursor image (--cursor) -- File picker
		GSENABLECUSTCUR="0"
		GSCURSOR="$( getGameScopeArg "$GAMESCOPE_ARGS" "--cursor" "$GSCURSOR" "" "" "path" )"
		if [ -n "$GSCURSOR" ]; then  GSENABLECUSTCUR="1"; fi

		# Mouse Sensitivity (-s) -- Spinner
		GSMOUSESENSITIVITY="$( getGameScopeArg "$GAMESCOPE_ARGS" "-s" "$GSMOUSESENSITIVITY" "" "1.0" "num" )"

		# There is a `--cursor-scale-height` option, but at time of writing (15/02/23) this doesn't seem to do anything - We can add it in future, but not now
		# There is a `--framerate-limit` option, but I am not totally sure how it differs from -r/-o -- I tested it out and the behaviour seemed identical? Maybe one works in both nested/embedded and the other doesn't, not sure...
	}

	function getGameScopeFilteringOpts {
		# Equivalent to check for --fsr-sharpness or --sharpness, so should work fine
		if grep -q "\-\-filter" <<< "$("$(command -v "$GAMESCOPE")" --help 2>&1)"; then
			GSNEWFILTERMODE=1  # Even though it's called NEWFILTERMODE, it also applies to scaling - Naming is hard
		fi

		# Default scale/filter to none to be safe
		if [ "$GSNEWFILTERMODE" -eq 1 ]; then
			## !!These are the newer flags for checking filter/scale!!
			#
			# Filtering option (-F) -- Combobox (replaces old individual Nearest/FSR/NIS options)
			GSFLTR="$( getGameScopeArg "$GAMESCOPE_ARGS" "-F" "$GSFLTR" "" "$NON" "cb" )"

			# Scaling option (-S) -- Combobox (replaces old individual Integer Scaling option)
			GSSCALE="$( getGameScopeArg "$GAMESCOPE_ARGS" "-S" "$GSSCALE" "" "$NON" "cb" )"
		else
			## !!These are legacy flags with individual switches!!
			## These values are checked for and used to apply the correct filter selection
			## on the UI (i.e. passing -U will select FSR for the filter dropdown)
			##
			## Scale
			# Integer scaling (-i)
			GSIS="$( getGameScopeArg "$GAMESCOPE_ARGS" "-i" "$GSIS" "1" "" )"
			if [ -n "$GSIS" ]; then
				GSSCALE="integer"  # This is hardcoded but /shrug, this is probably not going to matter when parsing a legacy GameScope switch
			fi

			## Filtering (no default values so that if these aren't in the gamescope args, they are -z)
			# Nearest Neighbor (-n)
			GSNN="$( getGameScopeArg "$GAMESCOPE_ARGS" "-n" "$GSNN" "nearest" "" )"

			# FidelityFX 1.0 enabled (-U)
			GSFSR="$( getGameScopeArg "$GAMESCOPE_ARGS" "-U" "$GSFSR" "fsr" "" )"

			# NVIDIA Image Scaling v1.0.3 (-Y) -- Checkbox
			GSNIS="$( getGameScopeArg "$GAMESCOPE_ARGS" "-Y" "$GSNIS" "nis" "" )"


			# This copies the way GameScope prioritises the check (see parse_upscaler_filter in GameScope main.cpp)
			# This maps the old-style filter switches (-U, -Y, -n) to the GameScope dropdowns
			# Eventually this will no longer be needed, once a suitable length of time has passed, but for now it exists to serve as backwards compatibility for users between GameScope versions.
			# Once `-F`/`-S` are standard, we can remove this code
			if [ -n "$GSNN" ]; then
				GSFLTR="nearest"
			elif [ -n "$GSFSR" ]; then
				GSFLTR="fsr"
			elif [ -n "$GSNIS" ]; then
				GSFLTR="nis"
			fi
		fi

		# AMD FidelityFX 1.0 / NVIDIA Image Sharpening upscaler value -- Spinner
		GSFSRS="$( getGameScopeArg "$GAMESCOPE_ARGS" "--fsr-sharpness" "$GSFSRS" "" "2" "num" )"

		# Max Scale Factor -- No idea how this option actually works, the documentation is a bit sparce but Steam Deck seems to default it to 2 (https://github.com/Plagman/gamescope/issues/588#issue-1338038588)
		GSMSF="$( getGameScopeArg "$GAMESCOPE_ARGS" "-m" "$GSMSF" "" "0" "num" )"

		# ReShade Effect File Path (--reshade-effect) -- File picker
		GSRSEP="$( getGameScopeArg "$GAMESCOPE_ARGS" "--reshade-effect" "$GSRSEP" "" "" "path" )"

		# ReShade Technique IDX (index?) (--reshade-technique-idx) -- Spinner
		GSRSTI="$( getGameScopeArg "$GAMESCOPE_ARGS" "--reshade-technique-idx" "$GSRSTI" "" "0" "num" )"
	}

	function getGameScopeHDROpts {
		# HDR (--hdr-enabled) -- Checkbox
		GSHDR="$( getGameScopeArg "$GAMESCOPE_ARGS" "--hdr-enabled" "$GSHDR" "1" "0" )"

		# HDR Wide Gammut for SDR (--hdr-wide-gammut-for-sdr) - Checkbox
		GSHDRWGFS="$( getGameScopeArg "$GAMESCOPE_ARGS" "--hdr-wide-gammut-for-sdr" "$GSHDRWGFS" "1" "0" )"

		# HDR SDR Content Nits (--hdr-sdr-content-nits) -- Defaults to 400 -- Numberbox
		GSHDRSCNITS="$( getGameScopeArg "$GAMESCOPE_ARGS" "--hdr-sdr-content-nits" "$GSHDRSCNITS" "1" "0" )"

		# HDR Inverse Tone Mapping Enabled (--hdr-itm-enable) -- Checkbox
		GSHDRITM="$( getGameScopeArg "$GAMESCOPE_ARGS" "--hdr-itm-enable" "$GSHDRITM" "1" "0" )"

		# HDR Inverse Tone Mapping SDR NITs (--hdr-itm-sdr-nits) -- Spinner
		# Default: 100 nits
		# Max: 1000 nits
		#
		# We default to 0 though in case a user doesn't want to use it, so we won't pass when this is 0
		GSHDRITMSDRNITS="$( getGameScopeArg "$GAMESCOPE_ARGS" "--hdr-itm-sdr-nits" "$GSHDRITMSDRNITS" "" "0" "num" )"

		# HDR Inverse Tone Mapping Target NITs (--hdr-itm-target-nits) -- Spinner
		# Default: 1000 nits
		# Max: 10000 nits
		#
		# Like `GSHDRITMSDRNITS`, we default to 0 because we don't want to always pass a value
		GSHDRITMTGTNITS="$( getGameScopeArg "$GAMESCOPE_ARGS" "--hdr-itm-target-nits" "$GSHDRITMTGTNITS" "" "0" "num" )"

		# There is a --sdr-gamut-wideness option which takes a (float?) value between 0 and 1. Not sure how this is used or what the default is,
		# so it is not added for now, but it could be added in future if requested/once more is known about it
	}

	function getGameScopeVROpts {
		# There are some other GameScope VR options:
		# * --vr-overlay-physical-width
		# * --vr-overlay-physical-curvature
		# * --vr-overlay-physical-pre-curve-pitch
		#
		# These options are probably very bespoke and not important to the average user, especially the physcial width option which takes a value in metres!
		# Usage on these options is also a bit unclear, probably documented in the GameScope source but not sure -We could add these in future if it is requested

		# Enable OpenVR (--openvr) -- Checkbox
		GSVR="$( getGameScopeArg "$GAMESCOPE_ARGS" "--openvr" "$GSVR" "1" "0" )"

		# SteamVR Explicit Name (--vr-overlay-explicit-name) -- Textbox
		GSVREXNA="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-overlay-explicit-name" "$GSVREXNA" "" "" "txt" )"

		# SteamVR Default Name when no window title available (--vr-overlay-default-name) -- Textbox
		GSVRDEFNAM="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-overlay-default-name" "$GSVRDEFNAM" "" "" "txt" )"

		# SteamVR Overlay Key String (--vr-overlay-key) -- Textbox
		GSVROVERLAYKEY="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-overlay-key" "$GSVROVERLAYKEY" "" "" "txt" )"

		# SteamVR Overlay Icon (--vr-overlay-icon) -- Similar to cursor picker -- File picker
		GSVRICONENABLE="0"
		GSVRICON="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-overlay-icon" "$GSVRICON" "" "" "path" )"
		if [ -n "$GSVRICON" ]; then  GSVRICONENABLE="1"; fi

		# Focus VR overlay immediately (--vr-overlay-show-immediately) -- Checkbox
		GSVRSHOIMM="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-overlay-show-immediately" "$GSVRSHOIMM" "1" "0" )"

		# Enable SteamVR Control Bar (--vr-overlay-enable-control-bar) -- Checkbox
		GSVRCONTROLBAR="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-overlay-enable-control-bar" "$GSVRCONTROLBAR" "1" "0" )"

		# Enable SteamVR Keyboard Button on Control Bar (--vr-overlay-enable-control-bar-keyboard) -- Checkbox
		GSVRCONTROLBARKEYBOARD="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-overlay-enable-control-bar-keyboard" "$GSVRCONTROLBARKEYBOARD" "1" "0" )"

		# Enable SteamVR Close Button on Control Bar (--vr-overlay-enable-control-bar-close) -- Checkbox
		GSVRCONTROLBARCLOSE="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-overlay-enable-control-bar-close" "$GSVRCONTROLBARCLOSE" "1" "0" )"

		# VR Trackpad Scroll Speed (--vr-scrolls-speed) -- Spinner
		GSVRSCROLLSSPEED="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-scrolls-speed" "$GSVRSCROLLSSPEED" "" "8.0" "num" )"

		# Show SteamVR Overlay as Modal (--vr-overlay-modal) -- Checkbox
		GSVRMODAL="$( getGameScopeArg "$GAMESCOPE_ARGS" "--vr-overlay-modal" "$GSVRMODAL" "1" "0" )"
	}

	function getGameScopeEmbeddedOpts {
		# Default action on touch (--default-touch-mode) -- Dropdown
		# --------------------
		# 0: hover
		# 1: leftclick
		# 2: rightclick
		# 3: middleclick
		# 4: passthrough
		#
		# More information in the GameScope commit that added it: https://github.com/Plagman/gamescope/commit/39c9e93e0c0539d4c767e1be1c96e0d38778af12
		GSDEFTOUCHMODE="$( getGameScopeArg "$GAMESCOPE_ARGS" "--default-touch-mode" "$GSDEFTOUCHMODE" "" "${GSDEF}" "cb" )"
		case $GSDEFTOUCHMODE in
			0) GSDEFTOUCHMODE="${GSHOVER}" ;;
			1) GSDEFTOUCHMODE="${GSLEFTCLICK}" ;;
			2) GSDEFTOUCHMODE="${GSRIGHTCLICK}" ;;
			3) GSDEFTOUCHMODE="${GSMIDDLECLICK}" ;;
			4) GSDEFTOUCHMODE="${GSPASSTHRU}" ;;
		esac

		# Enable Immediate Flips (--immediate-flips) -- Probably equivalent to the Steam Deck's "allow tearing" option -- Checkbox
		GSIMMEDIATEFLIPS="$( getGameScopeArg "$GAMESCOPE_ARGS" "--immediate-flips" "$GSIMMEDIATEFLIPS" "1" "0" )"

		# Enable Adaptive Sync / VRR (--adaptive-sync) -- Checkbox
		GSADAPTIVESYNC="$( getGameScopeArg "$GAMESCOPE_ARGS" "--adaptive-sync" "$GSADAPTIVESYNC" "1" "0" )"

		# Preferred GameScope Output in order of preference -- Not sure how exactly this should be passed and it can take N number of outputs - For this reason we just give the user a textbox and let them enter their displays manually
		GSPREFOUT="$( getGameScopeArg "$GAMESCOPE_ARGS" "-O" "$GSPREFOUT" "" "" "txt" )"

		# GameScope DRM Mode Generation algorithm to use -- GameScope takes either "cvt" or "fixed", but we will have a "default" option in the dropdown which means we will ignore the flag altogether
		GSDRMMODE="$( getGameScopeArg "$GAMESCOPE_ARGS" "--generate-drm-mode" "$GSDRMMODE" "" "$GSDEF" "cb")"
	}

	function getGameScopeAdvancedOpts {
		# Path to write GameScope statistics to (--stats-path) -- File picker
		# '-T' option is also availsble, but we have to use '--stats-path' because of how 'getGameScopeArg' works
		GSSTATSPATHENABLE="0"
		GSSTATSPATH="$( getGameScopeArg "$GAMESCOPE_ARGS" "--stats-path" "$GSSTATSPATH" "" "" "path" )"
		if [ -n "$GSSTATSPATH" ]; then  GSSTATSPATHENABLE="1"; fi

		# Backend for GameScope to use (--backend) -- Dropdown
		GSBACKEND="$( getGameScopeArg "$GAMESCOPE_ARGS" "--backend" "$GSBACKEND" "" "auto" "cb" )"

		# Amount of time in milliseconds to wait before hiding the cursor (-C) -- Spinner
		GSHIDECURSORDELAY="$( getGameScopeArg "$GAMESCOPE_ARGS" "-C" "$GSHIDECURSORDELAY" "" "0" "num" )"

		# Disables direct scan-out (--force-composition) -- Checkbox
		GSFORCECOMP="$( getGameScopeArg "$GAMESCOPE_ARGS" "--force-composition" "$GSFORCECOMP" "1" "0" )"

		# Draw debug hud (--debug-hud) -- Checkbox
		GSDEBUGHUD="$( getGameScopeArg "$GAMESCOPE_ARGS" "--debug-hud" "$GSDEBUGHUD" "1" "0" )"

		# Force HDR support flag (--hdr-debug-force-support) -- Checkbox
		GSFORCEHDRSUPPORT="$( getGameScopeArg "$GAMESCOPE_ARGS" "--hdr-debug-force-support" "$GSFORCEHDRSUPPORT" "1" "0" )"

		# Force HDR output on display (--hdr-debug-force-output) -- Will look terrible if unsupported -- Checkbox
		GSFORCEHDROUTPUT="$( getGameScopeArg "$GAMESCOPE_ARGS" "--hdr-debug-force-output" "$GSFORCEHDROUTPUT" "1" "0" )"

		# Prefer Vulkan device for compositing (--prefer-vk-device) -- Checkbox
		GSPREFERVKDEVICE="$( getGameScopeArg "$GAMESCOPE_ARGS" "--prefer-vk-device" "$GSPREFERVKDEVICE" "1" "0" )"

		# Expose Wayland (--expose-wayland) -- Checkbox
		GSWAYLAND="$( getGameScopeArg "$GAMESCOPE_ARGS" "--expose-wayland" "$GSWAYLAND" "1" "0" )"

		# Realtime Scheduling (--rt) -- Checkbox
		GSRT="$( getGameScopeArg "$GAMESCOPE_ARGS" "--rt" "$GSRT" "1" "0" )"

		# Headless (--headless) -- Checkbox
		GSHDLS="$( getGameScopeArg "$GAMESCOPE_ARGS" "--headless" "$GSHDLS" "1" "0" )"
	}

	# Set storage vars
	UL="unlimited"
	FSRS_STR="\-\-fsr\-sharpness"
	GSNORM="normal"
	GSFOOROPTS="left!right!${GSNORM}!upsidedown"
	GSFLTROPTS="$NON!linear!nearest!fsr!nis!pixel"
	GSSCALEOPTS="$NON!auto!integer!fit!fill!stretch"
	GSDEF="default"
	GSHOVER="hover:0"
	GSLEFTCLICK="leftclick:1"
	GSRIGHTCLICK="rightclick:2"
	GSMIDDLECLICK="middleclick:3"
	GSPASSTHRU="passthrough:4"
	GSTOUCHMODES="${GSDEF}!${GSHOVER}!${GSLEFTCLICK}!${GSRIGHTCLICK}!${GSMIDDLECLICK}!${GSPASSTHRU}" # Corresponds to 0,1,2,3,4 respectively internally by GameScope -- Default is ingored and the flag is not passed to GameScope
	GSDRMMODES="${GSDEF}!cvt!fixed"
	GSNEWFILTERMODE=0  # Whether gamescope uses -U/-Y/-n/-i (legacy) or -F/-S (new)
	GSBACKENDOPTS="auto!sdl!wayland!drm!headless!openvr"

	# Get values for UI elements based on existing GameScope args
	getGameScopeGeneralOpts
	getGameScopeFilteringOpts
	getGameScopeHDROpts
	getGameScopeVROpts
	getGameScopeEmbeddedOpts
	getGameScopeAdvancedOpts
}

function GameScopeGui {
	if [ -n "$1" ]; then
		AID="$1"
		setAIDCfgs
	fi

	if [ -n "$2" ]; then
		GN="$2"
		fixShowGnAid
	fi

	# Setup Yad UI stuff
	loadCfg "$STLGAMECFG"
	export CURWIKI="$PPW/GameScope"
	TITLE="${PROGNAME}-${FUNCNAME[0]}"
	pollWinRes "$TITLE"
	setShowPic
	setGameScopeVars  # Get values for UI elements below

	# Ordered field map for the form below: one entry per --field line, in
	# exactly the same order. Entries starting with "H:" are section headings
	# (LBL) which occupy an output slot but are not assigned to a variable.
	# This single list replaces the former hand-counted heading indexes.
	local -a GSFIELDSPEC=(
		"H:GUI_GSGENERALSET"
		"GSINTRES" "GSSHWRES" "GSFLR" "GSFLU" "USEGAMESCOPE" "GSFS" "GSBW" "GSSE" "GSFWF" "GSFGC" "GSFGK" "GSFOOR" "GSENABLECUSTCUR" "GSCURSOR" "GSMOUSESENSITIVITY"
		"H:GUI_GSFILTERINGSET"
		"GSFLTR" "GSSCALE" "GSFSRS" "GSMSF" "GSRSEP" "GSRSTI"
		"H:GUI_GSHDRSET"
		"GSHDR" "GSHDRWGFS" "GSHDRSCNITS" "GSHDRITM" "GSHDRITMSDRNITS" "GSHDRITMTGTNITS"
		"H:GUI_GSVRSET"
		"GSVR" "GSVREXNA" "GSVRDEFNAM" "GSVROVERLAYKEY" "GSVRICONENABLE" "GSVRICON" "GSVRSHOIMM" "GSVRCONTROLBAR" "GSVRCONTROLBARKEYBOARD" "GSVRCONTROLBARCLOSE" "GSVRSCROLLSSPEED" "GSVRMODAL"
		"H:GUI_GSEMBEDDEDSET"
		"GSDEFTOUCHMODE" "GSIMMEDIATEFLIPS" "GSADAPTIVESYNC" "GSPREFOUT" "GSDRMMODE"
		"H:GUI_GSADVOPTIONS"
		"GSBACKEND" "GSSTATSPATHENABLE" "GSSTATSPATH" "GSHIDECURSORDELAY" "GSFORCECOMP" "GSDEBUGHUD" "GSFORCEHDRSUPPORT" "GSFORCEHDROUTPUT" "GSPREFERVKDEVICE" "GSWAYLAND" "GSRT" "GSHDLS" "USEGAMESCOPEWSI"
	)

	# GameScope Yad options form
	GASCOS="$("$YAD" --f1-action="$F1ACTION" --image "$SHOWPIC" "${YADIMGTOP[@]}" --scroll --window-icon="$STLICON" --form --center --on-top "${WINDECO[@]}" \
			--title="$TITLE" --separator="|" \
			--text="$(spanFont "$(strFix "$GUI_GASCOSET" "$SGNAID")" "H")" \
			--field="$(spanFont "$GUI_GSGENERALSET" "H")":LBL "SKIP" \
			--field="$GUI_GSINTRES!$DESC_GSINTRES ('GSINTRES')":CBE "$(cleanDropDown "${GSINTRES//\"}" "$(printf "%s\n" "$("$XRANDR" --current 2>/dev/null | grep "[0-9]x" | awk '{print $1}' | grep "^[0-9]" | tr '\n' '!')")")" \
			--field="$GUI_GSSHWRES!$DESC_GSSHWRES ('GSSHWRES')":CBE "$(cleanDropDown "${GSSHWRES//\"}" "$(printf "%s\n" "$("$XRANDR" --current 2>/dev/null | grep "[0-9]x" | awk '{print $1}' | grep "^[0-9]" | tr '\n' '!')")")" \
			--field="$GUI_GSFLR!$DESC_GSFLR ('GSFLR')":CBE "$(cleanDropDown "${GSFLR//\"}" "30!60!90!120!$UL")" \
			--field="$GUI_GSFLU!$DESC_GSFLU ('GSFLU')":CBE "$(cleanDropDown "${GSFLU//\"}" "30!60!90!120!$UL")" \
			--field="$GUI_USEGAMESCOPE!$DESC_USEGAMESCOPE ('USEGAMESCOPE')":CHK "${USEGAMESCOPE/#-/ -}" \
			--field="$GUI_GSFS!$DESC_GSFS ('GSFS')":CHK "$GSFS" \
			--field="$GUI_GSBW!$DESC_GSBW ('GSBW')":CHK "$GSBW" \
			--field="$GUI_GSSE!$DESC_GSSE ('GSSE')":CHK "$GSSE" \
			--field="$GUI_GSFWF!$DESC_GSFWF ('GSFWF')":CHK "$GSFWF" \
			--field="$GUI_GSFGC!$DESC_GSFGC ('GSFGC')":CHK "$GSFGC" \
			--field="$GUI_GSFGK!$DESC_GSFGK ('GSFGK')":CHK "$GSFGK" \
			--field="$GUI_GSFOOR!$DESC_GSFOOR ('GSFOOR')":CB "$(cleanDropDown "${GSFOOR}" "${GSFOOROPTS}")" \
			--field="$GUI_GSENABLECUSTCUR!$GUI_GSENABLECUSTCUR ('GSENABLECUSTCUR')":CHK "$GSENABLECUSTCUR" \
			--field="$GUI_GSCURSOR!$DESC_GSCURSOR ('GSCURSOR')":FL "${GSCURSOR/#-/ -}" \
			--field="$GUI_GSMOUSESENSITIVITY!$DESC_GSMOUSESENSITIVITY ('GSMOUSESENSITIVITY')":NUM "${GSMOUSESENSITIVITY/#-/ -}" \
			--field="$(spanFont "$GUI_GSFILTERINGSET" "H")":LBL "SKIP" \
			--field="$GUI_GSFLTR!$DESC_GSFLTR ('GSFLTR')":CBE "$(cleanDropDown "${GSFLTR}" "${GSFLTROPTS}")" \
			--field="$GUI_GSSCALE!$DESC_GSSCALE ('GSSCALE')":CBE "$(cleanDropDown "${GSSCALE}" "${GSSCALEOPTS}")" \
			--field="$GUI_GSFSRS!$DESC_GSFSRS ('GSFSRS')":NUM "${GSFSRS/#-/ -}:!0..20" \
			--field="$GUI_GSMSF!$DESC_GSMSF ('GSMSF')":NUM "$GSMSF" \
			--field="$GUI_GSRSEP!$DESC_GSRSEP ('GSRSEP')":FL "${GSRSEP//\"}" \
			--field="$GUI_GSRSTI!$DESC_GSRSTI ('GSRSTI')":NUM "${GSRSTI/#-/ -}" \
			--field="$(spanFont "$GUI_GSHDRSET" "H")":LBL "SKIP" \
			--field="$GUI_GSHDR!$DESC_GSHDR ('GSHDR')":CHK "$GSHDR" \
			--field="$GUI_GSHDRWGFS!$DESC_GSHDRWGFS ('GSHDRWGFS')":CHK "$GSHDRWGFS" \
			--field="$GUI_GSHDRSCNITS!$DESC_GSHDRSCNITS ('GSHDRSCNITS')":NUM "${GSHDRSCNITS/#-/ -}" \
			--field="$GUI_GSHDRITM!$DESC_GSHDRITM ('GSHDRITM')":CHK "$GSHDRITM" \
			--field="$GUI_GSHDRITMSDRNITS!$DESC_GSHDRITMSDRNITS ('GSHDRITMSDRNITS')":NUM "${GSHDRITMSDRNITS/#-/ -}" \
			--field="$GUI_GSHDRITMTGTNITS!$DESC_GSHDRITMTGTNITS ('GSHDRITMTGTNITS')":NUM "${GSHDRITMTGTNITS/#-/ -}" \
			--field="$(spanFont "$GUI_GSVRSET" "H")":LBL "SKIP" \
			--field="$GUI_GSVR!$DESC_GSVR ('GSVR')":CHK "$GSVR" \
			--field="$GUI_GSVREXNA!$DESC_GSVREXNA ('GSVREXNA')" "$GSVREXNA" \
			--field="$GUI_GSVRDEFNAM!$DESC_GSVRDEFNAM ('GSVRDEFNAM')" "$GSVRDEFNAM" \
			--field="$GUI_GSVROVERLAYKEY!$DESC_GSVROVERLAYKEY ('GSVROVERLAYKEY')" "$GSVROVERLAYKEY" \
			--field="$GUI_GSVRICONENABLE!$DESC_GSVRICONENABLE ('GSVRICONENABLE')":CHK "$GSVRICONENABLE" \
			--field="$GUI_GSVRICON!$DESC_GSVRICON ('GSVRICON')":FL "${GSVRICON//\"}" \
			--field="$GUI_GSVRSHOIMM!$DESC_GSVRSHOIMM ('GSVRSHOIMM')":CHK "$GSVRSHOIMM" \
			--field="$GUI_GSVRCONTROLBAR!$DESC_GSVRCONTROLBAR ('GSVRCONTROLBAR')":CHK "$GSVRCONTROLBAR" \
			--field="$GUI_GSVRCONTROLBARKEYBOARD!$DESC_GSVRCONTROLBARKEYBOARD ('GSVRCONTROLBARKEYBOARD')":CHK "$GSVRCONTROLBARKEYBOARD" \
			--field="$GUI_GSVRCONTROLBARCLOSE!$DESC_GSVRCONTROLBARCLOSE ('GSVRCONTROLBARCLOSE')":CHK "$GSVRCONTROLBARCLOSE" \
			--field="$GUI_GSVRSCROLLSSPEED!$DESC_GSVRSCROLLSSPEED ('GSVRSCROLLSSPEED')":NUM "$GSVRSCROLLSSPEED" \
			--field="$GUI_GSVRMODAL!$DESC_GSVRMODAL ('GSVRMODAL')":CHK "$GSVRMODAL" \
			--field="$(spanFont "$GUI_GSEMBEDDEDSET" "H")":LBL "SKIP" \
			--field="$GUI_GSDEFTOUCHMODE!$DESC_GSDEFTOUCHMODE ('GSDEFTOUCHMODE')":CB "$(cleanDropDown "${GSDEFTOUCHMODE}" "${GSTOUCHMODES}")" \
			--field="$GUI_GSIMMEDIATEFLIPS!$DESC_GSIMMEDIATEFLIPS ('GSIMMEDIATEFLIPS')":CHK "$GSIMMEDIATEFLIPS" \
			--field="$GUI_GSADAPTIVESYNC!$DESC_GSADAPTIVESYNC ('GSADAPTIVESYNC')":CHK "$GSADAPTIVESYNC" \
			--field="$GUI_GSPREFOUT!$DESC_GSPREFOUT ('GSPREFOUT')" "" \
			--field="$GUI_GSDRMMODE!$DESC_GSDRMMODE ('GSDRMMODE')":CB "$(cleanDropDown "${GSDRMMODE}" "${GSDRMMODES}")" \
			--field="$(spanFont "$GUI_GSADVOPTIONS" "H")":LBL "SKIP" \
			--field="$GUI_GSBACKEND!$DESC_GSBACKEND ('GSBACKEND')":CBE "$(cleanDropDown "${GSBACKEND}" "${GSBACKENDOPTS}")" \
			--field="$GUI_GSSTATSPATHENABLE!$DESC_GSSTATSPATHENABLE ('GSSTATSPATHENABLE')":CHK "$GSSTATSPATHENABLE" \
			--field="$GUI_GSSTATSPATH!$DESC_GSSTATSPATH ('GSSTATSPATH')":DIR "${GSSTATSPATH//\"}" \
			--field="$GUI_GSHIDECURSORDELAY!$DESC_GSHIDECURSORDELAY ('GSHIDECURSORDELAY')":NUM "${GSHIDECURSORDELAY/#-/ -}" \
			--field="$GUI_GSFORCECOMP!$DESC_GSFORCECOMP ('GSFORCECOMP')":CHK "$GSFORCECOMP" \
			--field="$GUI_GSDEBUGHUD!$DESC_GSDEBUGHUD ('GSDEBUGHUD')":CHK "$GSDEBUGHUD" \
			--field="$GUI_GSFORCEHDRSUPPORT!$DESC_GSFORCEHDRSUPPORT ('GSFORCEHDRSUPPORT')":CHK "$GSFORCEHDRSUPPORT" \
			--field="$GUI_GSFORCEHDROUTPUT!$DESC_GSFORCEHDROUTPUT ('GSFORCEHDROUTPUT')":CHK "$GSFORCEHDROUTPUT" \
			--field="$GUI_GSPREFERVKDEVICE!$DESC_GSPREFERVKDEVICE ('GSPREFERVKDEVICE')":CHK "$GSPREFERVKDEVICE" \
			--field="$GUI_GSWAYLAND!$DESC_GSWAYLAND ('GSWAYLAND')":CHK "$GSWAYLAND" \
			--field="$GUI_GSRT!$DESC_GSRT ('GSRT')":CHK "$GSRT" \
			--field="$GUI_GSHDLS!$DESC_GSHDLS ('GSHDLS')":CHK "$GSHDLS" \
			--field="$GUI_USEGAMESCOPEWSI!$DESC_USEGAMESCOPEWSI ('USEGAMESCOPEWSI')":CHK "$USEGAMESCOPEWSI" \
			--button="$BUT_CAN:0" --button="$BUT_DGM:2" --button="$BUT_DONE:4" "$GEOM"
			)"
			case $? in
				0)	{
						writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_CAN' - Exiting"
					}
				;;
				2)  {
						writelog "INFO" "${FUNCNAME[0]} - Selected '$BUT_DGM' - Resetting GameScope options to default"
						GameScopeReset
						GameScopeGui
				    }
				;;
				4)	{
						# Get selected GameScope options
						mapfile -d "|" -t -O "${#GSARR[@]}" GSARR < <(printf '%s' "$GASCOS")

						if [ "${#GSARR[@]}" -ne "${#GSFIELDSPEC[@]}" ]; then
							writelog "WARN" "${FUNCNAME[0]} - GameScope form returned ${#GSARR[@]} values, but ${#GSFIELDSPEC[@]} fields were expected - results may be incomplete"
						fi

						# Assign every non-heading form result to its variable,
						# purely driven by the GSFIELDSPEC order above
						GSI=0
						for GSSPEC in "${GSFIELDSPEC[@]}"; do
							if [[ "$GSSPEC" == H:* ]]; then
								GSI=$(( GSI + 1 ))
								continue
							fi
							printf -v "$GSSPEC" '%s' "${GSARR[$GSI]}"
							GSI=$(( GSI + 1 ))
						done

						# Build the GameScope arguments string
						unset GAMESCOPE_ARGS
						GAMESCOPE_ARGS=""

						# Internal width/height (-w, -h) broken out from string like '1280x720'
						# NOTE: In future if `GSINTW` is blank but `GSINTH` is set, we could calculate a corresponding 16:9 width like GameScope does
						GSINTW1="${GSINTRES%x*}"
						GSINTW="${GSINTW1%%-*}"
						GSINTH1="${GSINTRES#*x}"
						GSINTH="${GSINTH1%%-*}"

						# Show width/height (-W, -H) broken out from string like '1280x720'
						# NOTE: In future if `GSINTW` is blank but `GSINTH` is set, we could calculate a corresponding 16:9 width like GameScope does
						GSSHWW1="${GSSHWRES%x*}"
						GSSHWW="${GSSHWW1%%-*}"
						GSSHWH1="${GSSHWRES#*x}"
						GSSHWH="${GSSHWH1%%-*}"

						### GENERAL OPTIONS ###
						if [ -n "$GSINTW" ] && [ -n "$GSINTH" ]                         ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -w ${GSINTW} -h ${GSINTH}"; fi
						if [ -n "$GSSHWW" ] && [ -n "$GSSHWH" ]                         ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -W ${GSSHWW} -H ${GSSHWH}"; fi
						if [ "$GSFLR" -eq "$GSFLR" ] 2>/dev/null                        ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -r ${GSFLR}"; fi
						if [ "$GSFLU" -eq "$GSFLU" ] 2>/dev/null                        ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -o ${GSFLU}"; fi
						if [ "$GSFS" == "TRUE" ]                                        ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -f"; fi
						if [ "$GSBW" == "TRUE" ]                                        ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -b"; fi
						if [ "$GSSE" == "TRUE" ]                                        ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -e"; fi
						if [ "$GSFWF" == "TRUE" ]                                       ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --force-windows-fullscreen"; fi
						if [ "$GSFGC" == "TRUE" ]                                       ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --force-grab-cursor"; fi
						if [ "$GSFGK" == "TRUE" ]                                       ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -g"; fi
						if [ -f "$GSCURSOR" ] && [ "$GSENABLECUSTCUR" == "TRUE" ]       ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --cursor '${GSCURSOR}'"; fi
						if [ "$GSMOUSESENSITIVITY" -gt 1 ]							; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -s ${GSMOUSESENSITIVITY}"; fi
						if [ ! "$GSFOOR" == "$GSNORM" ] && [ -n "$GSFOOR" ]             ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --force-orientation ${GSFOOR}"; fi  # Only force orientation if option other than default 'normal' is selected
						### GENERAL OPTIONS END ###

						### FILTERING OPTIONS ###
						# Used to control whether to apply --sharpness since there are various conditions where
						# this could be true (new -F option but ONLY if we pass fsr/nis, or legacy -U/-S option)
						GSAPPLYSHARPNESS=0
						if [ ! "$GSFLTR" == "$NON" ] && [ -n "$GSFLTR" ]; then
							# Pass -F if available for current GameScope version, otherwise pass legacy switches
							if [ "$GSNEWFILTERMODE" -eq 1 ]; then
								GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -F ${GSFLTR}"
							else
								# Only manages -U/-Y/-n, because those were the only filtering switches available
								# we don't have any other to account for with older GameScope versions -- If a different
								# option is selected for GSFLTR, then we just don't pass any flags
								#
								# Even though with legacy options, all 3 of these could be passed, the -F flag won't support this and neither
								# will the UI, so we only support selecting 1
								if [ "$GSFLTR" == "nearest" ]; then
									GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -n"
								elif [ "$GSFLTR" == "fsr" ]; then
									GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -U"
								elif [ "$GSFLTR" == "nis" ]; then
									GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -Y"
								fi
							fi

							if [ "$GSFLTR" == "fsr" ] || [ "$GSFLTR" == "nis" ]; then  # CASE SENSITIVE
								GSAPPLYSHARPNESS=1
							fi
						fi

						if [ ! "$GSSCALE" == "$NON" ] && [ -n "$GSSCALE" ]; then
							if [ "$GSNEWFILTERMODE" -eq 1 ]; then
								GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -S ${GSSCALE}"
							else
								# This is the only legacy scale switch, -i
								if [ "$GSSCALE" == "integer" ]; then
									GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -i"
								fi
							fi
						fi

						if [ ! "$GSMSF" == "0" ]                                        ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -m ${GSMSF}"; fi # Ignore Max Scale Factor if 0
						if [ "$GSFSRS" -eq "$GSFSRS" ] 2>/dev/null && [ "$GSAPPLYSHARPNESS" -eq 1 ]; then
							# Sharpness Value should only be passed if FSR or NIS is enabled
							writelog "INFO" "${FUNCNAME[0]} - Adding sharpness parameter to the gamescope arguments:"
							if grep -q "$FSRS_STR" <<< "$("$(command -v "$GAMESCOPE")" --help 2>&1)"; then
								writelog "INFO" "${FUNCNAME[0]} - using '--fsr-sharpness ${GSFSRS}'"
								GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --fsr-sharpness ${GSFSRS}"
							else
								writelog "INFO" "${FUNCNAME[0]} - using '--sharpness ${GSFSRS}'"
								GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --sharpness ${GSFSRS}"
							fi
						fi

						if [ -f "$GSRSEP" ]                                        		; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --reshade-effect '${GSRSEP}'"; fi
						if [ ! "$GSRSTI" == "0" ]                              			; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --reshade-technique-idx ${GSRSTI}"; fi
						## FILTERING OPTIONS END ###

						### HDR OPTIONS ###
						# Possible to check if any HDR displays available and warn if not?
						if [ "$GSHDR" == "TRUE" ]; then
							GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --hdr-enabled";

							writelog "INFO" "${FUNCNAME[0]} - GameScope HDR enabled, forcing DXVK_HDR=1"
							export DXVK_HDR=1
						fi
						if [ "$GSHDRWGFS" == "TRUE" ]; then
							# Don't enable GSHDRWGFS if GSHDR is not enabled first
							if [ "$GSHDR" == "TRUE" ]; then
								GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --hdr-wide-gammut-for-sdr"
							else
								writelog "WARN" "${FUNCNAME[0]} - GSHDRWGFS (--hdr-wide-gammut-for-sdr) option for GameScope enabled but HDR was not enabled - Ignoring as this option would have no effect"
							fi
						fi
						if [ ! "$GSHDRSCNITS" == "400" ]; then
							# Only pass value if nits != 400 && HDR enabled (400 is the default)
							if [ "$GSHDR" == "TRUE" ] && [ "$GSHDRWGFS" == "TRUE" ]; then
								GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --hdr-sdr-content-nits ${GSHDRSCNITS}"
							else
								writelog "WARN" "${FUNCNAME[0]} - GSHDRSCNITS (--hdr-sdr-content-nits) option for GameScope was set but HDR and SDR were not enabled - Ignoring as this option would have no effect"
							fi
						else
							writelog "INFO" "${FUNCNAME[0]} - GSHDRSCNITS (--hdr-sdr-content-nits) option for GameScope was left at default 203 - GameScope should use this anyway - Ignoring as this option would have no effect"
						fi
						if [ "$GSHDRITM" == "TRUE" ]                                    ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --hdr-itm-enable"; fi
						if [ ! "$GSHDRITMSDRNITS" == "0" ]                              ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --hdr-itm-sdr-nits ${GSHDRITMSDRNITS}"; fi
						if [ ! "$GSHDRITMTGTNITS" == "0" ]                              ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --hdr-itm-target-nits ${GSHDRITMTGTNITS}"; fi
						### HDR OPTIONS END ###

						### VR OPTIONS ###
						if [ "$GSVR" == "TRUE" ]                                        ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --openvr"; fi
						if [ "${#GSVREXNA}" -gt 0 ]                                     ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-overlay-explicit-name '${GSVREXNA}'"; fi  # Don't set explicit name if it's blank
						if [ "${#GSVRDEFNAM}" -gt 0 ]                                   ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-overlay-default-name '${GSVRDEFNAM}'"; fi  # Don't set default name if it's blank
						if [ "${#GSVROVERLAYKEY}" -gt 0 ] 								; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-overlay-key '${GSVROVERLAYKEY}'"; fi  # Don't set overlay key if it's blank
						if [ -f "$GSVRICON" ] && [ "$GSVRICONENABLE" == "TRUE" ]        ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-overlay-icon '${GSVRICON}'"; fi
						if [ "$GSVRSHOIMM" == "TRUE" ]                                  ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-overlay-show-immediately"; fi
						if [ "$GSVRCONTROLBAR" == "TRUE" ]                              ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-overlay-enable-control-bar"; fi
						if [ "$GSVRCONTROLBARKEYBOARD" == "TRUE" ]                      ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-overlay-enable-control-bar-keyboard"; fi
						if [ "$GSVRCONTROLBARCLOSE" == "TRUE" ]                         ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-overlay-enable-control-bar-close"; fi
						if [ "$GSVRSCROLLSSPEED" -gt 8 ]                                ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-scrolls-speed ${GSVRSCROLLSSPEED}"; fi  # 8.0 is the default value
						if [ "$GSVRMODAL" == "TRUE" ]                                   ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --vr-overlay-modal"; fi
						### VR OPTIONS END

						### EMBEDDED OPTIONS ###
						# Don't pass default touch mode option if we left at default
						if [ ! "${GSDEFTOUCHMODE}" == "${GSDEF}" ] && [ -n "${GSDEFTOUCHMODE}" ]; then
							# Get the corresponding number that should be passed to GameScope from the number in the dropdown string, e.g. gets "0" from "hover:0"
							SELECTEDTOUCHMODE="$( echo "$GSDEFTOUCHMODE" | cut -d ":" -f 2 )"
							GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --default-touch-mode ${SELECTEDTOUCHMODE}"
						fi
						if [ "$GSIMMEDIATEFLIPS" == "TRUE" ]                            ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --immediate-flips"; fi
						if [ "$GSADAPTIVESYNC" == "TRUE" ]                              ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --adaptive-sync"; fi
						if [ "${#GSPREFOUT}" -gt 0 ]                                    ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -O ${GSPREFOUT}"; fi  # Don't pass preferred output(s) if the textbox is blank
						# EMBEDDED OPTIONS END

						## ADVANCED OPTIONS ###
						if [ ! "$GSBACKEND" == "auto" ]                                 ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --backend ${GSBACKEND}"; fi  # Don't pass GameScope Backend if left at "auto"; GameScope defaults to this anyway
						if [ ! "$GSDRMMODE" == "${GSDEF}" ] && [ -n "$GSDRMMODE" ]      ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --generate-drm-mode ${GSDRMMODE}"; fi  # Don't pass DRM mode if "default"
						if [ -d "$GSSTATSPATH" ] && [ "$GSSTATSPATHENABLE" == "TRUE" ]  ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --stats-path '${GSSTATSPATH}'"; fi
						if [ ! "$GSHIDECURSORDELAY" == "0" ]                            ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} -C ${GSHIDECURSORDELAY}"; fi  # Ignore cursor delay if it's 0
						if [ "$GSFORCECOMP" == "TRUE" ]                                 ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --force-composition"; fi
						if [ "$GSDEBUGHUD" == "TRUE" ]                                  ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --debug-hud"; fi
						if [ "$GSFORCEHDRSUPPORT" == "TRUE" ]                           ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --hdr-debug-force-support"; fi
						if [ "$GSFORCEHDROUTPUT" == "TRUE" ]                            ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --hdr-debug-force-output"; fi
						if [ "$GSPREFERVKDEVICE" == "TRUE" ]                            ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --prefer-vk-device"; fi
						if [ "$GSWAYLAND" == "TRUE" ]                                   ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --expose-wayland"; fi
						if [ "$GSRT" == "TRUE" ]                                        ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --rt"; fi
						if [ "$GSHDLS" == "TRUE" ]                                      ; then  GAMESCOPE_ARGS="${GAMESCOPE_ARGS} --headless"; fi
						### ADVANCED OPTIONS END ###

						# Remove trailing whitespace and append '--'
						GAMESCOPE_ARGS="${GAMESCOPE_ARGS# } --"

						writelog "INFO" "${FUNCNAME[0]} - Saving configured GAMESCOPE_ARGS '$GAMESCOPE_ARGS' into '$STLGAMECFG'"
						touch "$FUPDATE"
						updateConfigEntry "GAMESCOPE_ARGS" "$GAMESCOPE_ARGS" "$STLGAMECFG"
						touch "$FUPDATE"
						updateConfigEntry "USEGAMESCOPE" "$USEGAMESCOPE" "$STLGAMECFG"
						touch "$FUPDATE"
						updateConfigEntry "USEGAMESCOPEWSI" "$USEGAMESCOPEWSI" "$STLGAMECFG"  # GAMESCOPE_WSI_ENABLE=1 option, since its an env var and not a gamescope flag we save it to game config
					}
				;;
			esac
}

function GameScopeReset {
	# This resets the options on the GUI to blank, but when the UI is re-loaded the options are set again to their menu defaults
	# once the "Done" button is pressed e.g. the resolutions default to 1280x720
	GAMESCOPE_ARGS="$NON"
	touch "$FUPDATE"
	updateConfigEntry "GAMESCOPE_ARGS" "$GAMESCOPE_ARGS" "$STLGAMECFG"
	setGameScopeVars  # This needs to be called to fix empty dropdown values for some reason (even though it should get called from GameScopeGui /shrug)
}

