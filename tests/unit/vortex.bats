#!/usr/bin/env bash
# Unit tests for the Vortex integration helper.
#
# These cover the two regressions for which Vortex can silently stop
# working (nxm:// links and game auto-detect):
#  1. startVortex "url" must hand Vortex the full nxm:// URL (query string
#     intact) via `runVortex "-d"`.
#  2. setVortexConfigVdf must write the modern nested "libraryfolders"
#     schema (the old flat one Vortex can no longer parse) and register
#     HKCU\Software\Valve\Steam\SteamPath so Vortex can find its Steam base
#     folder inside the prefix.
#
# The Vortex helpers are called inside `set +e` subshells because bats runs
# tests under errexit while the real script does not; the asserts check the
# produced files rather than the exit path.

setup() {
	load helpers
	tg_load

	for stub in xdg-mime pgrep pkill; do
		# shellcheck disable=SC2292
		if ! test -x "$BATS_TEST_TMPDIR/stubbin/$stub"; then
			printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/stubbin/$stub"
			chmod +x "$BATS_TEST_TMPDIR/stubbin/$stub"
		fi
	done

	# Work off a throw-away home so no real desktop files are touched.
	export HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME/.local/share/applications"

	# Fake Steam root so listVortexSteamLibraries/setVortexConfigVdf work.
	VSTEAM="$BATS_TEST_TMPDIR/steam"
	VSTEAMAPPS="$VSTEAM/steamapps"
	mkdir -p "$VSTEAM/config" "$VSTEAMAPPS"
	cat >"$VSTEAM/config/config.vdf" <<'EOF'
"InstallConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"BaseInstallFolder_1"		"VSTEAMAPPS"
			}
		}
	}
}
EOF
	sed -i "s@VSTEAMAPPS@$VSTEAMAPPS@" "$VSTEAM/config/config.vdf"
	cat >"$VSTEAMAPPS/libraryfolders.vdf" <<'EOF'
"libraryfolders"
{
	"0"
	{
		"path"		"VROOT"
	}
}
EOF
	sed -i "s@VROOT@$VSTEAM@" "$VSTEAMAPPS/libraryfolders.vdf"

	export SROOT="$VSTEAM"
	export SA="steamapps"
	export CFGVDF="$VSTEAM/config/config.vdf"
	export LFVDF="$VSTEAMAPPS/libraryfolders.vdf"
	export STELILIST="$BATS_TEST_TMPDIR/SteamLibraries.txt"

	# Fake Vortex install so setVortexVars/startVortex can proceed.
	export VORTEXCOMPDATA="$BATS_TEST_TMPDIR/vortex/vortex-compatdata"
	export VORTEXPFX="$VORTEXCOMPDATA/pfx"
	export VORTEXWINE="$BATS_TEST_TMPDIR/wine"
	touch "$VORTEXWINE"
	export VORTEXINSTDIR="$BATS_TEST_TMPDIR/vortex/vortex-install"
	mkdir -p "$VORTEXINSTDIR"
	export VORTEXEXE="$VORTEXINSTDIR/Vortex.exe"
	touch "$VORTEXEXE"
	export VORTEXDOWNLOADPATH="$BATS_TEST_TMPDIR/vortex/downloads"
	export VORTEXSTAGELIST="$BATS_TEST_TMPDIR/vortex/stages.txt"
	export GLOBALMISCDIR="$TG_ROOT/misc"
	export VORTEXGAMES="$GLOBALMISCDIR/vortexgames.txt"

	# Switches used by startVortex.
	export USEVORTEX=1
	export USEVORTEXPROTON="proton-x"    # skip Proton CSV/network lookup
	export VORTEXUSESLR=0
	export VORTEXUSESLRPOSTINSTALL=0
	export VORTEXDEVICESCALEFACTOR="1"
	export VORTEXARGS="$NON"
	export VORTEXDISABLEGPU=1
	export DISABLEVORTEXAUTOUPDATE=1     # no auto-update branch on start
	export VORTEXNODECORATION=0
	export RUN_VORTEX_WINETRICKS=0
	export RUN_VORTEX_WINECFG=0

	# Record every (mocked) wine invocation instead of running wine.
	export WINE_LOG="$BATS_TEST_TMPDIR/winecmd.log"
	: >"$WINE_LOG"

	# Vortex-related helpers are stubbed: this suite only checks the URL
	# pass-through and the Steam discovery files.
	cat >"$BATS_TEST_TMPDIR/workarounds.bash" <<'EOF'
wineVortexRun() {
	printf '%s\n' "$*" >>"$WINE_LOG"
	return 0
}
setVortexSLR() { return 0; }
askVortex() { return 0; }
setVortexInstallDirs() { return 0; }
EOF
}

run_vortex_helpers() {
	# shellcheck source=/dev/null
	source "$BATS_TEST_TMPDIR/workarounds.bash"
	( set +e; "$@" )
}

@test "vortex url: nxm URI reaches the wine binary with the query intact" {
	local url="nxm:stardewvalley:4152/files/123456?fileid=123456&exp=9999999999&key=deadbeef"
	run_vortex_helpers startVortex "noask" "url" "$url"

	grep -q "Vortex.exe" "$WINE_LOG"
	grep -q -- "-d" "$WINE_LOG"
	grep -qF -- "nxm:stardewvalley:4152/files/123456?fileid=123456&exp=9999999999&key=deadbeef" "$WINE_LOG"
}

@test "vortex url: missing URL is not passed to Vortex" {
	run_vortex_helpers startVortex "noask" "url" ""
	if grep -q "Vortex.exe.*-d" "$WINE_LOG"; then
		return 1
	fi
}

@test "setVortexConfigVdf: modern nested libraryfolders schema" {
	run_vortex_helpers setVortexConfigVdf
	out="$VORTEXPFX/drive_c/Program Files (x86)/Steam/config/libraryfolders.vdf"

	grep -q '"libraryfolders"' "$out"
	grep -q '"path"' "$out"
	# Wine style Z:\ prefix.
	grep -qF 'Z:\\' "$out"
	# The legacy flat form must be gone.
	if grep -q '"1" "Z:' "$out"; then
		return 1
	fi
}

@test "setVortexConfigVdf: registers the SteamPath registry value" {
	run_vortex_helpers setVortexConfigVdf
	grep -Fq 'reg ADD HKCU\Software\Valve\Steam /v SteamPath' "$WINE_LOG"
}

@test "purge-cache: kills running Vortex and re-runs the settings reset" {
	# Simulate a running Vortex: the pgrep stub 'finds' the process and the
	# pkill stub records the kill instead of actually killing anything.
	cat >"$BATS_TEST_TMPDIR/stubbin/pgrep" <<'EOF'
#!/bin/sh
echo "found-vortex" >&2
exit 0
EOF
	chmod +x "$BATS_TEST_TMPDIR/stubbin/pgrep"
	KILL_LOG="$BATS_TEST_TMPDIR/killed.log"
	cat >"$BATS_TEST_TMPDIR/stubbin/pkill" <<EOF
#!/bin/sh
echo "\$*" >> "$KILL_LOG"
exit 0
EOF
	chmod +x "$BATS_TEST_TMPDIR/stubbin/pkill"

	export KILL_LOG
	RESET_MARKER="$BATS_TEST_TMPDIR/reset.ran"
	export RESET_MARKER
	# The reset itself writes files through wineVortexRun; stub it to record
	# that it was reached so the test focuses on the purge behaviour.
	# shellcheck source=/dev/null
	source "$BATS_TEST_TMPDIR/workarounds.bash"
	( set +e
	  resetVortexSettings() { : >"$RESET_MARKER"; }
	  purgeVortexCache
	)

[ -f "$RESET_MARKER" ]
	grep -q "Vortex.exe" "$KILL_LOG"
}

@test "purge-cache: no Vortex running still rebuilds the reset" {
	# pgrep stub 'finds nothing' - the kill branch is skipped
	cat >"$BATS_TEST_TMPDIR/stubbin/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
	chmod +x "$BATS_TEST_TMPDIR/stubbin/pgrep"

	RESET_MARKER2="$BATS_TEST_TMPDIR/reset2.ran"
	export RESET_MARKER2
	# shellcheck source=/dev/null
	source "$BATS_TEST_TMPDIR/workarounds.bash"
	( set +e
	  resetVortexSettings() { : >"$RESET_MARKER2"; }
	  purgeVortexCache
	)

	[ -f "$RESET_MARKER2" ]
}