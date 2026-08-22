#!/usr/bin/env bash

load helpers

setup() {
	tg_load
	# helpers' stub yad exits 0 with no output -> YADHELP empty -> safe
	# defaults for YADIMGTOP/WINDECO; only the theming block is under test here.
	CSSFILE="$BATS_TEST_TMPDIR/custom.css"
	printf 'window { opacity: 0.95; }\n' > "$CSSFILE"
	PGOUT="$BATS_TEST_TMPDIR/pg.out"
	unset GTK_THEME YAD_OPTIONS YADTHEME YADCSS || true
}

# prepareGUI exports its results, so it must run in a subshell that dumps the
# interesting variables to a file the test shell can read afterwards.
pg_dump() {
	( set +e
	  prepareGUI
	  printf 'GTK_THEME=%s\n' "${GTK_THEME-}"
	  printf 'YAD_OPTIONS=%s\n' "${YAD_OPTIONS-}"
	) > "$PGOUT"
}

@test "prepareGUI: YADTHEME exports GTK_THEME" {
	YADTHEME="Adwaita:dark"
	pg_dump
	grep -qx 'GTK_THEME=Adwaita:dark' "$PGOUT"
}

@test "prepareGUI: unset YADTHEME leaves GTK_THEME alone" {
	pg_dump
	grep -qx 'GTK_THEME=' "$PGOUT"
}

@test "prepareGUI: YADTHEME=none leaves GTK_THEME alone" {
	YADTHEME="$NON"
	pg_dump
	grep -qx 'GTK_THEME=' "$PGOUT"
}

@test "prepareGUI: YADCSS file adds --css to YAD_OPTIONS" {
	YADCSS="$CSSFILE"
	pg_dump
	grep -qx "YAD_OPTIONS=--css=$CSSFILE" "$PGOUT"
}

@test "prepareGUI: YADCSS=none leaves YAD_OPTIONS alone" {
	YADCSS="$NON"
	pg_dump
	grep -qx 'YAD_OPTIONS=' "$PGOUT"
}

@test "prepareGUI: missing YADCSS file is skipped with a log entry" {
	YADCSS="$BATS_TEST_TMPDIR/does-not-exist.css"
	LOGLEVEL=2 pg_dump
	grep -qx 'YAD_OPTIONS=' "$PGOUT"
	grep -q "is not a readable file" "$TEMPLOG"
}

@test "prepareGUI: existing YAD_OPTIONS is preserved and extended" {
	YAD_OPTIONS="--keep-me"
	YADCSS="$CSSFILE"
	pg_dump
	grep -qx "YAD_OPTIONS=--keep-me --css=$CSSFILE" "$PGOUT"
}

@test "prepareGUI: theming vars are referenced in lib code so emptyVars clears them" {
	# emptyVars 'S' unsets variables that appeared after saveOrgVars only if
	# their '$NAME' occurs somewhere in lib/. The '$GTK_THEME' and '$YAD_OPTIONS'
	# references live in comments/code of prepare.sh on purpose - they keep the
	# game process free of GUI-only environment overrides.
	grep -q '\$GTK_THEME' "$TG_ROOT/lib/gui/prepare.sh"
	grep -q '\$YAD_OPTIONS' "$TG_ROOT/lib/gui/prepare.sh"
}

@test "schema: YADTHEME and YADCSS are known global options" {
	tgSchemaHasKey "global" "YADTHEME"
	tgSchemaHasKey "global" "YADCSS"
}
