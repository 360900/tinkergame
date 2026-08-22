#!/usr/bin/env bash
# Unit tests for the option schema loader (lib/config/schema.sh + data/options.def).

setup() {
	load helpers
	tg_load
}

@test "schema file is found via TGOPTDEF defined by the entry point" {
	[ -n "$TGOPTDEF" ]
	[ -f "$TGOPTDEF" ]
}

@test "tgSchemaKeys: scope key counts match the schema" {
	[ "$(tgSchemaKeys "url" | grep -c .)" -eq 35 ]
	[ "$(tgSchemaKeys "gui" | grep -c .)" -eq 4 ]
	[ "$(tgSchemaKeys "global" | grep -c .)" -eq 133 ]
	[ "$(tgSchemaKeys "default_template" | grep -c .)" -eq 189 ]
}

@test "tgSchemaKeys: unknown scope yields no keys" {
	[ -z "$(tgSchemaKeys "bogus_scope")" ]
	[ "$(tgSchemaKeys "bogus_scope" | grep -c .)" -eq 0 ]
}

@test "tgSchemaKeys: first and last keys of each scope are pinned" {
	[ "$(tgSchemaKeys "url" | head -1)" = "PROJECTPAGE" ]
	[ "$(tgSchemaKeys "url" | tail -1)" = "IGCSZIP" ]
	[ "$(tgSchemaKeys "gui" | head -1)" = "WINX" ]
	[ "$(tgSchemaKeys "gui" | tail -1)" = "POSY" ]
	[ "$(tgSchemaKeys "global" | head -1)" = "STLLANG" ]
	[ "$(tgSchemaKeys "default_template" | head -1)" = "KEEPSTLOPEN" ]
	[ "$(tgSchemaKeys "default_template" | tail -1)" = "RUNSBS" ]
}

@test "tgSchemaHasKey: known and unknown keys" {
	tgSchemaHasKey "url" "RESHADEPROJURL"
	! tgSchemaHasKey "url" "RESHADEPROJURl"   # legacy typo key is not in the schema
	tgSchemaHasKey "default_template" "MO2SILENTMODEEXEOVERRIDE"
	! tgSchemaHasKey "default_template" "MO2SILENTMODEDESC_MO2SILENTMODEEXEOVERRIDE"
	tgSchemaHasKey "global" "CUPROTOCOMPAT"
	! tgSchemaHasKey "global" "NOT_A_REAL_KEY"
}

@test "tgSchemaDesc: raw description templates are returned unexpanded" {
	[ "$(tgSchemaDesc "global" "STLLANG")" = '$DESC_STLLANG' ]
	[ "$(tgSchemaDesc "url" "RESHADEDLURL")" = '${RESH} DL URL' ]
	[ -z "$(tgSchemaDesc "url" "PROJECTPAGE")" ]
}

@test "tgExpandDesc: expands \$VAR references from the environment" {
	FOO="bar"
	[ "$(tgExpandDesc 'value is $FOO')" = "value is bar" ]
}

@test "tgExpandDesc: expands \${VAR} references" {
	MYVAR="x"
	[ "$(tgExpandDesc 'prefix ${MYVAR} suffix')" = "prefix x suffix" ]
}

@test "tgExpandDesc: literal text without variables stays unchanged" {
	[ "$(tgExpandDesc 'plain literal text')" = "plain literal text" ]
}

@test "tgExpandDesc: whole-string strFix form is resolved" {
	DESC_TESTVAR="replace XXX here"
	REPLACEMENT="REPLACED"
	[ "$(tgExpandDesc '$(strFix "$DESC_TESTVAR" "$REPLACEMENT")')" = "replace REPLACED here" ]
}

@test "tgExpandDesc: mixed literal and variables" {
	V1="one"
	V2="two"
	[ "$(tgExpandDesc '$V1 and ${V2}')" = "one and two" ]
}

@test "gen-options: committed defaults.sh matches data/options.def" {
	run bash "$TG_ROOT/tools/gen-options.sh" --check
	[ "$status" -eq 0 ]
}

@test "gen-options: generated defaults contain the CUPROTOCOMPAT default added by the schema" {
	grep -q 'CUPROTOCOMPAT="\$CUPROTOCOMPAT"\|CUPROTOCOMPAT=' "$TG_ROOT/lib/config/defaults.sh"
	grep -q 'if \[ -z "\$CUPROTOCOMPAT" \]; then		CUPROTOCOMPAT="0"; fi' "$TG_ROOT/lib/config/defaults.sh"
}
