#!/usr/bin/env bash
# The build gate must parse every module and propagate syntax failures.

setup() {
	load helpers
	BUILD_ROOT="$BATS_TEST_TMPDIR/project"
	mkdir -p "$BUILD_ROOT/lib/core"
	cp "$TG_ROOT/Makefile" "$BUILD_ROOT/Makefile"
	local SCRIPT
	for SCRIPT in tinkergame install.sh uninstall.sh lib/core/common.sh; do
		printf '#!/usr/bin/env bash\n:\n' > "$BUILD_ROOT/$SCRIPT"
	done
}

@test "make build: valid modules pass, including paths with spaces" {
	mkdir -p "$BUILD_ROOT/lib/extra modules"
	printf '#!/usr/bin/env bash\n:\n' > "$BUILD_ROOT/lib/extra modules/valid module.sh"
	run make -C "$BUILD_ROOT" build
	[ "$status" -eq 0 ]
}

@test "make build: a broken module after the first module fails the build" {
	mkdir -p "$BUILD_ROOT/lib/extra modules"
	printf '#!/usr/bin/env bash\nif true; then\n' > "$BUILD_ROOT/lib/extra modules/broken module.sh"
	run make -C "$BUILD_ROOT" build
	[ "$status" -ne 0 ]
	[[ "$output" == *'syntax error'* ]]
}

@test "make install: any PREFIX is written verbatim into the installed scripts" {
	local DIR
	for DIR in collections data eval guicfgs lang misc; do mkdir -p "$BUILD_ROOT/$DIR"; done
	: > "$BUILD_ROOT/README.md"
	: > "$BUILD_ROOT/MIGRATION.md"
	printf '#!/usr/bin/env bash\nPREFIX="/usr"\necho "$PREFIX"\n' > "$BUILD_ROOT/tinkergame"
	cp "$BUILD_ROOT/tinkergame" "$BUILD_ROOT/lib/core/common.sh"
	local PFX='/opt/my games/a"b:c&d\e$f'"'"'g`h%i'
	run make -C "$BUILD_ROOT" install DESTDIR="$BATS_TEST_TMPDIR/dest" PREFIX="$PFX"
	[ "$status" -eq 0 ]
	run bash "$BATS_TEST_TMPDIR/dest$PFX/bin/tinkergame"
	[ "$output" = "$PFX" ]
	run bash "$BATS_TEST_TMPDIR/dest$PFX/share/tinkergame/lib/core/common.sh"
	[ "$output" = "$PFX" ]
	[ ! -e "$BATS_TEST_TMPDIR/dest$PFX/share/applications" ]
}
