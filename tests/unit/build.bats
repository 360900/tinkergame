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

@test "make install: the desktop file runs the installed script by absolute path" {
	# PREFIX/bin (e.g. ~/.local/bin) is often missing from the desktop session's PATH
	local DIR
	for DIR in collections data eval guicfgs lang misc; do mkdir -p "$BUILD_ROOT/$DIR"; done
	cp "$TG_ROOT/misc/tinkergame.desktop" "$BUILD_ROOT/misc/"
	: > "$BUILD_ROOT/misc/tinkergame.svg"
	: > "$BUILD_ROOT/README.md"
	: > "$BUILD_ROOT/MIGRATION.md"
	run make -C "$BUILD_ROOT" install DESTDIR="$BATS_TEST_TMPDIR/dest" PREFIX="/opt/my games/50%"
	[ "$status" -eq 0 ]
	run grep '^Exec=' "$BATS_TEST_TMPDIR/dest/opt/my games/50%/share/applications/tinkergame.desktop"
	[ "$output" = 'Exec="/opt/my games/50%%/bin/tinkergame" settings' ]
}
