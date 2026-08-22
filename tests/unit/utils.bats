#!/usr/bin/env bash
# Unit tests for small pure utility functions and updateConfigEntry.

setup() {
	load helpers
	tg_load
}

@test "retBool: maps TRUE to 1 and everything else to 0" {
	[ "$(retBool "TRUE")" = "1" ]
	[ "$(retBool "FALSE")" = "0" ]
	[ "$(retBool "true")" = "0" ]
	[ "$(retBool "")" = "0" ]
}

@test "trimWhitespaces: strips leading and trailing whitespace, keeps inner" {
	[ "$(trimWhitespaces "  hello world  ")" = "hello world" ]
	[ "$(trimWhitespaces "$(printf '\t\ttabs\t\t')")" = "tabs" ]
	[ "$(trimWhitespaces "none")" = "none" ]
	[ "$(trimWhitespaces "  a  b  ")" = "a  b" ]
}

@test "trimWhitespaces: joins multiple arguments with IFS" {
	[ "$(trimWhitespaces " a " " b ")" = "a   b" ]
}

@test "delEmptyFile: removes files with at most one line" {
	printf 'only line\n' >"$BATS_TEST_TMPDIR/empty.conf"
	printf 'a\nb\n' >"$BATS_TEST_TMPDIR/full.conf"

	delEmptyFile "$BATS_TEST_TMPDIR/empty.conf"
	[ ! -f "$BATS_TEST_TMPDIR/empty.conf" ]

	delEmptyFile "$BATS_TEST_TMPDIR/full.conf"
	[ -f "$BATS_TEST_TMPDIR/full.conf" ]
}

@test "delEmptyFile: missing file is silently ignored" {
	run delEmptyFile "$BATS_TEST_TMPDIR/does-not-exist"
	[ "$status" -eq 0 ]
}

@test "rmDupLines: keeps first occurrence of duplicate lines" {
	printf 'a\nb\na\nc\nb\n' >"$BATS_TEST_TMPDIR/dup.txt"
	rmDupLines "$BATS_TEST_TMPDIR/dup.txt"
	[ "$(cat "$BATS_TEST_TMPDIR/dup.txt")" = "$(printf 'a\nb\nc')" ]
}

@test "rmDupLines: file without duplicates is unchanged" {
	printf 'x\ny\nz\n' >"$BATS_TEST_TMPDIR/uniq.txt"
	rmDupLines "$BATS_TEST_TMPDIR/uniq.txt"
	[ "$(cat "$BATS_TEST_TMPDIR/uniq.txt")" = "$(printf 'x\ny\nz')" ]
}

@test "updateConfigEntry: updates an existing key in place" {
	printf 'FOO="old"\nBAR="keep"\n' >"$BATS_TEST_TMPDIR/conf"
	unset FOO
	run updateConfigEntry "FOO" "new" "$BATS_TEST_TMPDIR/conf"
	grep -q '^FOO="new"$' "$BATS_TEST_TMPDIR/conf"
	grep -q '^BAR="keep"$' "$BATS_TEST_TMPDIR/conf"
	[ "$(wc -l <"$BATS_TEST_TMPDIR/conf")" = "2" ]
}

@test "updateConfigEntry: appends a missing key" {
	printf 'BAR="keep"\n' >"$BATS_TEST_TMPDIR/conf"
	run updateConfigEntry "FOO" "new" "$BATS_TEST_TMPDIR/conf"
	grep -q '^FOO="new"$' "$BATS_TEST_TMPDIR/conf"
}

@test "updateConfigEntry: activates a commented-out key" {
	printf '#FOO="old"\n' >"$BATS_TEST_TMPDIR/conf"
	run updateConfigEntry "FOO" "new" "$BATS_TEST_TMPDIR/conf"
	grep -q '^FOO="new"$' "$BATS_TEST_TMPDIR/conf"
	! grep -q '^#FOO' "$BATS_TEST_TMPDIR/conf"
}

@test "updateConfigEntry: converts TRUE/FALSE to 1/0" {
	printf 'FLAG="0"\n' >"$BATS_TEST_TMPDIR/conf"
	unset FLAG
	run updateConfigEntry "FLAG" "TRUE" "$BATS_TEST_TMPDIR/conf"
	grep -q '^FLAG="1"$' "$BATS_TEST_TMPDIR/conf"

	printf 'FLAG2="1"\n' >"$BATS_TEST_TMPDIR/conf2"
	unset FLAG2
	run updateConfigEntry "FLAG2" "FALSE" "$BATS_TEST_TMPDIR/conf2"
	grep -q '^FLAG2="0"$' "$BATS_TEST_TMPDIR/conf2"
}

@test "updateConfigEntry: empty value is ignored" {
	printf 'FOO="old"\n' >"$BATS_TEST_TMPDIR/conf"
	unset FOO
	run updateConfigEntry "FOO" "" "$BATS_TEST_TMPDIR/conf"
	grep -q '^FOO="old"$' "$BATS_TEST_TMPDIR/conf"
}

@test "updateConfigEntry: missing config file is skipped" {
	run updateConfigEntry "FOO" "new" "$BATS_TEST_TMPDIR/missing.conf"
	[ "$status" -eq 0 ]
	[ ! -f "$BATS_TEST_TMPDIR/missing.conf" ]
}

@test "updateConfigEntry: backslashes survive a round-trip as single backslashes" {
	printf 'FOO="old"\n' >"$BATS_TEST_TMPDIR/conf"
	unset FOO
	run updateConfigEntry "FOO" 'C:\games\bin' "$BATS_TEST_TMPDIR/conf"
	# ESCAPED_CFGVALUE doubles the backslashes and sed's 'c' command text
	# un-escapes them again, so the file faithfully keeps single backslashes.
	grep -q '^FOO="C:\\games\\bin"$' "$BATS_TEST_TMPDIR/conf"
}

@test "updateConfigEntry: backslash escape sequences are not expanded" {
	printf 'FOO="old"\n' >"$BATS_TEST_TMPDIR/conf"
	unset FOO
	run updateConfigEntry "FOO" 'C:\tools\nstuff' "$BATS_TEST_TMPDIR/conf"
	# '\t' and '\n' in Windows paths must stay literal, not become tab/newline:
	grep -q '^FOO="C:\\tools\\nstuff"$' "$BATS_TEST_TMPDIR/conf"
	! grep -qP '\t|\n' "$BATS_TEST_TMPDIR/conf"
}

@test "updateConfigEntry: STLCFGDIR placeholder is substituted on update and append" {
	printf 'FOO="old"\n' >"$BATS_TEST_TMPDIR/conf"
	unset FOO
	run updateConfigEntry "FOO" "$STLCFGDIR/downloads/thing" "$BATS_TEST_TMPDIR/conf"
	grep -q '^FOO="STLCFGDIR/downloads/thing"$' "$BATS_TEST_TMPDIR/conf"

	printf 'OTHER="x"\n' >"$BATS_TEST_TMPDIR/conf2"
	unset BAR
	run updateConfigEntry "BAR" "$STLCFGDIR/downloads/thing" "$BATS_TEST_TMPDIR/conf2"
	grep -q '^BAR="STLCFGDIR/downloads/thing"$' "$BATS_TEST_TMPDIR/conf2"
}

@test "updateConfigEntry: FUPDATE force flag rewrites and is consumed" {
	printf 'FOO="same"\n' >"$BATS_TEST_TMPDIR/conf"
	FOO="same"
	touch "$FUPDATE"

	run updateConfigEntry "FOO" "same" "$BATS_TEST_TMPDIR/conf"

	grep -q '^FOO="same"$' "$BATS_TEST_TMPDIR/conf"
	[ ! -f "$FUPDATE" ]
}
