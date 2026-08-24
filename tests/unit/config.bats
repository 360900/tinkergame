#!/usr/bin/env bash
# Unit tests for the schema-driven config writers (save.sh) and the
# config upgrade path (updateConfigFile/tgUpgradeConfigFile in manage.sh).

setup() {
	load helpers
	tg_load
	export STLBACKDIR="$BATS_TEST_TMPDIR/backup"
	export STLCFGDIR="$BATS_TEST_TMPDIR/cfg"
	# language descriptions are normally loaded from lang/; provide a few for
	# the comment-writing assertions:
	export DESC_STLLANG="The language to use"
	export RESH="ReShade"
}

@test "saveCfg: creates a fresh global.conf with all 134 schema keys" {
	local f="$BATS_TEST_TMPDIR/global.conf"
	saveCfg "$f" X
	[ -f "$f" ]
	[ "$(grep -cE '^[A-Z0-9_]+=' "$f")" -eq 134 ]
	[ "$(head -1 "$f")" = "## config Version: $PROGVERS" ]
}

@test "saveCfg: global.conf has description comments and previously-unwritten keys" {
	local f="$BATS_TEST_TMPDIR/global.conf"
	saveCfg "$f" X
	grep -q '^## The language to use$' "$f"
	grep -q '^STLLANG="english"$' "$f"
	# keys that the old writer never persisted:
	grep -q '^CUPROTOCOMPAT="0"$' "$f"
	grep -q '^AUTOPULLPROTON="1"$' "$f"
}

@test "saveCfg: global.conf substitutes the STLCFGDIR placeholder" {
	# CUSTPROTDLDIR is derived from STLDLDIR, which paths.sh computes from
	# STLCFGDIR at source time - emulate that derivation for the override:
	export STLDLDIR="$STLCFGDIR/downloads"
	local f="$BATS_TEST_TMPDIR/global.conf"
	saveCfg "$f" X
	grep -q '^CUSTPROTDLDIR="STLCFGDIR/downloads/proton/custom"$' "$f"
	grep -q '^CUSTPROTEXTDIR="STLCFGDIR/proton/custom"$' "$f"
	grep -vq "$STLCFGDIR" "$f"
}

@test "saveCfg: creates url.conf with all 35 keys and the url preamble" {
	local f="$BATS_TEST_TMPDIR/url.conf"
	saveCfg "$f" X
	[ "$(grep -cE '^[A-Z0-9_]+=' "$f")" -eq 35 ]
	[ "$(sed -n 2p "$f")" = "##########################" ]
	[ "$(sed -n 3p "$f")" = "## Url Config:" ]
	[ "$(sed -n 4p "$f")" = "##########################" ]
	[ "$(sed -n 5p "$f")" = 'PROJECTPAGE="https://github.com/360900/tinkergame"' ]
}

@test "saveCfg: url.conf writes the fixed RESHADEPROJURL key (regression: was RESHADEPROJURl)" {
	local f="$BATS_TEST_TMPDIR/url.conf"
	saveCfg "$f" X
	grep -q '^RESHADEPROJURL="https://github.com/crosire/reshade"$' "$f"
	! grep -q '^RESHADEPROJURl=' "$f"
	grep -q '^## ReShade Project URL$' "$f"   # desc expands ${RESH}
}

@test "saveCfg: creates default_template.conf with all 189 keys" {
	local f="$BATS_TEST_TMPDIR/default_template.conf"
	saveCfg "$f" X
	[ "$(grep -cE '^[A-Z0-9_]+=' "$f")" -eq 189 ]
}

@test "saveCfg: default_template.conf writes the fixed MO2SILENTMODEEXEOVERRIDE key" {
	local f="$BATS_TEST_TMPDIR/default_template.conf"
	saveCfg "$f" X
	grep -q '^MO2SILENTMODEEXEOVERRIDE="none"$' "$f"
	! grep -q '^MO2SILENTMODEDESC_MO2SILENTMODEEXEOVERRIDE=' "$f"
}

@test "saveCfg: default_template.conf persists keys the old writer dropped" {
	local f="$BATS_TEST_TMPDIR/default_template.conf"
	saveCfg "$f" X
	grep -q '^RUNSBS="0"$' "$f"
	grep -q '^USEGAMESCOPEWSI="0"$' "$f"
	grep -q '^WINE_FULLSCREEN_FSR_MODE="none"$' "$f"
	# VORTEXUSESLRPOSTINSTALL is a global-scope key the old writer dropped:
	local g="$BATS_TEST_TMPDIR/global.conf"
	saveCfg "$g" X
	grep -q '^VORTEXUSESLRPOSTINSTALL=' "$g"
}

@test "saveCfg: unknown scope is rejected and writes nothing" {
	local f="$BATS_TEST_TMPDIR/bogus.conf"
	run saveCfg "$f" X
	[ ! -f "$f" ]
}

@test "saveCfg: existing file is upgraded, not rewritten from scratch" {
	local f="$BATS_TEST_TMPDIR/global.conf"
	printf '## config Version: v0.0.1\nSTLLANG="german"\n' >"$f"
	saveCfg "$f" X
	grep -q '^STLLANG="german"$' "$f"       # existing value survives
	[ "$(grep -cE '^[A-Z0-9_]+=' "$f")" -eq 134 ]   # missing keys appended
}

@test "updateConfigFile: fast path leaves a current-version file untouched" {
	local f="$BATS_TEST_TMPDIR/current.conf"
	printf '## config Version: %s\nKEEPSTLOPEN="0"\n' "$PROGVERS" >"$f"
	updateConfigFile "$f" "default_template"
	[ "$(cat "$f")" = "$(printf '## config Version: %s\nKEEPSTLOPEN="0"' "$PROGVERS")" ]
}

@test "updateConfigFile: unknown scope is skipped" {
	local f="$BATS_TEST_TMPDIR/x.conf"
	printf '## config Version: v0.0.1\nFOO="1"\n' >"$f"
	updateConfigFile "$f" "bogus"
	[ "$(head -1 "$f")" = "## config Version: v0.0.1" ]
}

@test "updateConfigFile: missing arg is skipped" {
	run updateConfigFile "" "global"
	[ "$status" -eq 0 ]
}

@test "updateConfigFile: renames legacy typo keys and keeps their value" {
	local f="$BATS_TEST_TMPDIR/url.conf"
	printf '## config Version: v0.0.1\nRESHADEPROJURl="https://example/old"\n' >"$f"
	updateConfigFile "$f" "url"
	grep -q '^RESHADEPROJURL="https://example/old"$' "$f"
	! grep -q 'RESHADEPROJURl' "$f"
}

@test "updateConfigFile: renames the mangled MO2 key" {
	local f="$BATS_TEST_TMPDIR/t.conf"
	printf '## config Version: v0.0.1\nMO2SILENTMODEDESC_MO2SILENTMODEEXEOVERRIDE="myexe"\n' >"$f"
	updateConfigFile "$f" "default_template"
	grep -q '^MO2SILENTMODEEXEOVERRIDE="myexe"$' "$f"
}

@test "updateConfigFile: drops duplicate keys keeping the first occurrence" {
	local f="$BATS_TEST_TMPDIR/t.conf"
	printf '## config Version: v0.0.1\nKEEPSTLOPEN="0"\nKEEPSTLOPEN="1"\n' >"$f"
	updateConfigFile "$f" "default_template"
	[ "$(grep -c '^KEEPSTLOPEN=' "$f")" -eq 1 ]
	grep -q '^KEEPSTLOPEN="0"$' "$f"
}

@test "updateConfigFile: drops unknown keys but keeps allowlisted per-game keys" {
	local f="$BATS_TEST_TMPDIR/game.conf"
	{
		printf '## config Version: v0.0.1\n'
		printf 'STLDXVKCFG="/tmp/dxvk/1.conf"\n'
		printf 'INSTALL_RESHADE="1"\n'
		printf 'CHECKCATEGORIES="0"\n'
		printf 'GHOSTKEY="1"\n'
	} >"$f"
	updateConfigFile "$f" "default_template"
	grep -q '^STLDXVKCFG="/tmp/dxvk/1.conf"$' "$f"
	grep -q '^INSTALL_RESHADE="1"$' "$f"
	grep -q '^CHECKCATEGORIES="0"$' "$f"
	! grep -q '^GHOSTKEY=' "$f"
}

@test "updateConfigFile: comments of dropped keys are discarded, of kept keys preserved" {
	local f="$BATS_TEST_TMPDIR/game.conf"
	{
		printf '## config Version: v0.0.1\n'
		printf '## comment of a ghost key\n'
		printf 'GHOSTKEY="1"\n'
		printf '## comment of a real key\n'
		printf 'KEEPSTLOPEN="0"\n'
	} >"$f"
	updateConfigFile "$f" "default_template"
	! grep -q 'comment of a ghost key' "$f"
	grep -q '^## comment of a real key$' "$f"
}

@test "updateConfigFile: game header comments survive the upgrade" {
	local f="$BATS_TEST_TMPDIR/game.conf"
	{
		printf '## config Version: v0.0.1\n'
		printf '##########################\n'
		printf '#GAMENAME: Test\n'
		printf 'STLDXVKCFG="/tmp/dxvk/1.conf"\n'
	} >"$f"
	updateConfigFile "$f" "default_template"
	grep -q '^#GAMENAME: Test$' "$f"
}

@test "updateConfigFile: bumps the version and prepends it when missing" {
	local f="$BATS_TEST_TMPDIR/novers.conf"
	printf 'KEEPSTLOPEN="0"\n' >"$f"
	updateConfigFile "$f" "default_template"
	[ "$(head -1 "$f")" = "## config Version: $PROGVERS" ]
	[ "$(sed -n 2p "$f")" = "##########################" ]
	grep -q '^KEEPSTLOPEN="0"$' "$f"
}

@test "updateConfigFile: writes a timestamped backup before upgrading" {
	local f="$BATS_TEST_TMPDIR/game.conf"
	printf '## config Version: v0.0.1\nKEEPSTLOPEN="0"\n' >"$f"
	updateConfigFile "$f" "default_template"
	[ "$(ls "$STLBACKDIR" | grep -c '^game\.conf\..*\.bak$')" -eq 1 ]
	grep -q '^## config Version: v0.0.1$' "$STLBACKDIR"/game.conf.*.bak
}

@test "updateConfigFile: appends missing keys with fresh description comments" {
	local f="$BATS_TEST_TMPDIR/t.conf"
	printf '## config Version: v0.0.1\nKEEPSTLOPEN="0"\n' >"$f"
	updateConfigFile "$f" "default_template"
	[ "$(grep -c '^KEEPSTLOPEN=' "$f")" -eq 1 ]
	# all 189 schema keys present afterwards:
	[ "$(grep -cE '^[A-Z0-9_]+=' "$f")" -eq 189 ]
}

@test "updateConfigFile: missing per-game keys inherit values from the default template" {
	local f="$BATS_TEST_TMPDIR/game.conf"
	local t="$BATS_TEST_TMPDIR/template.conf"
	printf '## config Version: v0.0.1\nKEEPSTLOPEN="0"\n' >"$f"
	printf 'KEEPSTLOPEN="0"\nUSEZINK="1"\n' >"$t"
	STLGAMECFG="$f" STLDEFGAMECFG="$t" updateConfigFile "$f" "default_template"
	# USEZINK was missing in the game config and must be taken from the template:
	grep -q '^USEZINK="1"$' "$f"
}

@test "updateConfigFile: substitutes the STLCFGDIR placeholder in appended values" {
	local f="$BATS_TEST_TMPDIR/t.conf"
	printf '## config Version: v0.0.1\nKEEPSTLOPEN="0"\n' >"$f"
	PROTON_LOG_DIR="$STLCFGDIR/protonlogs" updateConfigFile "$f" "default_template"
	grep -q '^PROTON_LOG_DIR="STLCFGDIR/protonlogs"$' "$f"
}
