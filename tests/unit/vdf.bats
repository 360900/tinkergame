#!/usr/bin/env bash
# Unit tests for the text-VDF helper functions.

setup() {
	load helpers
	tg_load
	VDF="$TG_FIXTURES/vdf/localconfig.vdf"
}

@test "safequoteVdfBlockName: quotes unquoted names, keeps quoted ones" {
	[ "$(safequoteVdfBlockName "apps")" = '"apps"' ]
	[ "$(safequoteVdfBlockName '"apps"')" = '"apps"' ]
}

@test "generateVdfIndentString: repeats the indent token N times" {
	[ "$(generateVdfIndentString 3)" = "$(printf '\t\t\t')" ]
	[ "$(generateVdfIndentString 1)" = "$(printf '\t')" ]
	[ "$(generateVdfIndentString 2 '[[:space:]]')" = '[[:space:]][[:space:]]' ]
}

@test "guessVdfIndent: counts tabs of the first matching block line" {
	[ "$(guessVdfIndent '"CompatToolMapping"' "$VDF")" = "4" ]
	[ "$(guessVdfIndent '"UserLocalConfigStore"' "$VDF")" = "0" ]
}

@test "getVdfSection: extracts a block including its braces" {
	run getVdfSection '"CompatToolMapping"' "" 4 "$VDF"
	[ "$status" -eq 0 ]
	local expected
	expected="$(printf '\t\t\t\t"CompatToolMapping"\n\t\t\t\t{\n\t\t\t\t\t"22320"\n\t\t\t\t\t{\n\t\t\t\t\t\t"name"\t\t"proton_8"\n\t\t\t\t\t\t"config"\t\t"payload"\n\t\t\t\t\t}\n\t\t\t\t\t"570"\n\t\t\t\t\t{\n\t\t\t\t\t\t"name"\t\t"Proton-tg"\n\t\t\t\t\t}\n\t\t\t\t}')"
	[ "$output" = "$expected" ]
}

@test "getVdfSection: auto-guesses indent when not given" {
	run getVdfSection '"CompatToolMapping"' "" "" "$VDF"
	[ "$status" -eq 0 ]
	[ "$(grep -c "CompatToolMapping" <<<"$output")" = "1" ]
	grep -q '"Proton-tg"' <<<"$output"
}

@test "getVdfSection: default prints all matching blocks, STOPAFTERFIRSTMATCH stops at one" {
	local all first
	all="$(getVdfSection '"apps"' "" 1 "$VDF")"
	first="$(getVdfSection '"apps"' "" 1 "$VDF" "X")"

	# both duplicate "apps" blocks (7 lines each)
	[ "$(wc -l <<<"$all")" = "14" ]
	# NOTE: the stop pattern is not ^-anchored, so the stop fires on the first
	# line *containing* indent-1 tabs + '}' -- the inner block's closing brace.
	# This pins current behavior; fix belongs to the stability phase.
	[ "$(wc -l <<<"$first")" = "6" ]
	grep -q '"730"' <<<"$first"
	! grep -q '"440"' <<<"$first"
}

@test "getNestedVdfSection: walks a slash-separated path down the tree" {
	run getNestedVdfSection "UserLocalConfigStore/Software/Valve/Steam/CompatToolMapping" "" "$VDF"
	[ "$status" -eq 0 ]
	grep -q '"CompatToolMapping"' <<<"$output"
	# NOTE: due to the unanchored stop pattern in getVdfSection, the walk
	# truncates after the first nested block's closing brace -- the section
	# below pins that (buggy) behavior until the anchor bug is fixed.
	grep -q '"22320"' <<<"$output"
	grep -q '"proton_8"' <<<"$output"
	! grep -q '"UserLocalConfigStore"' <<<"$output"
}

@test "getVdfSectionValue: returns the full property line by default" {
	local section
	section="$(getNestedVdfSection "UserLocalConfigStore/Software/Valve/Steam/CompatToolMapping" "" "$VDF")"
	[ "$(getVdfSectionValue "$section" "config")" = '"config"		"payload"' ]
}

@test "getVdfSectionValue: ONLYVALUE cuts the value field" {
	local section
	section="$(getNestedVdfSection "UserLocalConfigStore/Software/Valve/Steam/CompatToolMapping" "" "$VDF")"
	[ "$(getVdfSectionValue "$section" "config" "X")" = '"payload"' ]
}

@test "getVdfSectionValue: values are case-insensitively matched and trimmed" {
	local section
	section="$(getVdfSection "apps" "" 1 "$VDF" "X")"
	[ "$(getVdfSectionValue "$section" "OverlayAppEnable" "X")" = '"1"' ]
}

@test "checkVdfSectionAlreadyExists: finds and misses nested blocks" {
	checkVdfSectionAlreadyExists '"CompatToolMapping"' "22320" "$VDF" 4
	checkVdfSectionAlreadyExists '"CompatToolMapping"' "570" "$VDF" 4
	run checkVdfSectionAlreadyExists '"CompatToolMapping"' "99999" "$VDF" 4
	[ "$status" -ne 0 ]
}

@test "createVdfPropertyString: quotes key and value, joins with double tab" {
	[ "$(createVdfPropertyString "name" "value")" = "$(printf '"name"\t\t"value"')" ]
}

@test "createVdfPropertyString: quoted string values are valid JSON and go through the JSON path" {
	# '"quoted"' parses as a JSON string, so it is double-escaped (od-verified golden)
	[ "$(createVdfPropertyString "name" '"quoted"')" = '"name"'$'\t\t''\"\\\"quoted\\\"\"' ]
}

@test "createVdfPropertyString: JSON object values get double-escaped without quotes" {
	[ "$(createVdfPropertyString "json" '{"a":1}')" = '"json"'$'\t\t''\"{\\\"a\\\":1}\"' ]
}

@test "prepareJSONVdfProperty: double-escapes JSON and strips outer quotes" {
	[ "$(prepareJSONVdfProperty '{"a":1}')" = '\"{\\\"a\\\":1}\"' ]
}

@test "substituteVdfSection: replaces old block text in the file in place" {
	cp "$VDF" "$BATS_TEST_TMPDIR/edit.vdf"
	local section newsection
	section="$(getVdfSection '"CompatToolMapping"' "" 4 "$BATS_TEST_TMPDIR/edit.vdf")"
	newsection="${section//proton_8/proton_9}"

	substituteVdfSection "$section" "$newsection" "$BATS_TEST_TMPDIR/edit.vdf"

	grep -q '"proton_9"' "$BATS_TEST_TMPDIR/edit.vdf"
	! grep -q '"proton_8"' "$BATS_TEST_TMPDIR/edit.vdf"
	# rest of the file survives
	grep -q '"UserLocalConfigStore"' "$BATS_TEST_TMPDIR/edit.vdf"
}

@test "substituteVdfSection: rewrites file with trailing newline" {
	printf '"root"\n{\n\t"a"\t\t"1"\n}' >"$BATS_TEST_TMPDIR/min.vdf"
	substituteVdfSection '"a"		"1"' '"a"		"2"' "$BATS_TEST_TMPDIR/min.vdf"
	[ "$(cat "$BATS_TEST_TMPDIR/min.vdf")" = "$(printf '"root"\n{\n\t"a"\t\t"2"\n}')" ]
}
