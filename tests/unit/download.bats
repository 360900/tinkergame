#!/usr/bin/env bash
# Custom Proton installation must stop on transport, integrity or archive errors.

setup() {
	load helpers
	tg_load
	source "$TG_ROOT/lang/english.txt"

	CUPROTOCOMPAT=0
	CUSTPROTDLDIR="$BATS_TEST_TMPDIR/downloads with spaces"
	CUSTPROTEXTDIR="$BATS_TEST_TMPDIR/tools with spaces"
	PROTONCSV="$STLSHM/ProtonCSV.txt"
	PROTBUMPTEMP="$STLSHM/protonbump.tmp"
	mkdir -p "$CUSTPROTDLDIR" "$CUSTPROTEXTDIR"
	printf '%s\n' 'existing cache' > "$PROTONCSV"

	export TG_ARCHIVE="$BATS_TEST_TMPDIR/archive.tar.gz"
	export WGET_CALLS="$BATS_TEST_TMPDIR/wget.calls"
	REGISTER_CALLS="$BATS_TEST_TMPDIR/register.calls"
	REFRESH_CALLS="$BATS_TEST_TMPDIR/refresh.calls"
	: > "$WGET_CALLS"
	: > "$REGISTER_CALLS"
	: > "$REFRESH_CALLS"

	writelog() { :; }
	notiShow() { :; }
	sleep() { :; }
	getAvailableProtonVersions() { printf '%s\n' "$*" >> "$REFRESH_CALLS"; }
	addCustomProtonToList() { printf '%s\n' "$1" >> "$REGISTER_CALLS"; }

	WGET="$BATS_TEST_TMPDIR/fakewget"
	cat > "$WGET" <<'EOF'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
	case "$1" in
		-q) shift ;;
		-O) DEST="$2"; shift 2 ;;
		*) SOURCE="$1"; shift ;;
	esac
done
printf '%s\n' "$SOURCE" >> "$WGET_CALLS"
if [ "$DEST" = - ]; then
	printf '%s  archive.tar.gz\n' "${TG_EXPECTED_DIGEST:-}"
	exit "${TG_DIGEST_RC:-0}"
fi
if [ "${TG_DOWNLOAD_RC:-0}" -ne 0 ]; then
	printf '%s' partial > "$DEST"
	exit "$TG_DOWNLOAD_RC"
fi
cp "$TG_ARCHIVE" "$DEST"
EOF
	chmod +x "$WGET"
}

makeProtonTar() {
	local ROOT="$BATS_TEST_TMPDIR/source" LAYOUT="${1:-Test-Proton}"
	mkdir -p "$ROOT/$LAYOUT"
	printf '#!/bin/sh\nexit 0\n' > "$ROOT/$LAYOUT/proton"
	chmod +x "$ROOT/$LAYOUT/proton"
	tar -czf "$TG_ARCHIVE" -C "$ROOT" "$LAYOUT"
	local DIGEST
	DIGEST="$(sha512sum "$TG_ARCHIVE")"
	export TG_EXPECTED_DIGEST="${DIGEST%% *}"
}

assertNoProtonInstall() {
	[ ! -s "$REGISTER_CALLS" ]
	[ ! -s "$REFRESH_CALLS" ]
	[ ! -e "$PROTBUMPTEMP" ]
	[ -f "$PROTONCSV" ]
}

@test "dlCustomProton: network failure does not extract, register or cache a partial archive" {
	makeProtonTar
	export TG_DOWNLOAD_RC=8
	run dlCustomProton https://example.invalid/Test-Proton.tar.gz
	[ "$status" -eq 8 ]
	[ ! -e "$CUSTPROTDLDIR/Test-Proton.tar.gz" ]
	[ -z "$(find "$CUSTPROTEXTDIR" -mindepth 1 -print)" ]
	assertNoProtonInstall
}

@test "dlCustomProton: missing or malformed GE checksums stop before the archive download" {
	makeProtonTar
	export TG_EXPECTED_DIGEST=""
	run dlCustomProton https://example.invalid/GE-Proton-Test.tar.gz
	[ "$status" -ne 0 ]
	[ "$(wc -l < "$WGET_CALLS")" -eq 1 ]
	[ ! -e "$CUSTPROTDLDIR/GE-Proton-Test.tar.gz" ]
	assertNoProtonInstall

	export TG_EXPECTED_DIGEST=deadbeef
	run dlCustomProton https://example.invalid/GE-Proton-Test.tar.gz
	[ "$status" -ne 0 ]
	[ "$(wc -l < "$WGET_CALLS")" -eq 2 ]
	assertNoProtonInstall
}

@test "dlCustomProton: checksum transport errors cannot pass with partial digest output" {
	makeProtonTar
	export TG_DIGEST_RC=8
	run dlCustomProton https://example.invalid/GE-Proton-Test.tar.gz
	[ "$status" -eq 8 ]
	[ "$(wc -l < "$WGET_CALLS")" -eq 1 ]
	assertNoProtonInstall
}

@test "dlCustomProton: a bad GE checksum prevents extraction and cache publication" {
	makeProtonTar
	export TG_EXPECTED_DIGEST="$(printf '%0128d' 0)"
	run dlCustomProton https://example.invalid/GE-Proton-Test.tar.gz
	[ "$status" -ne 0 ]
	[ ! -e "$CUSTPROTDLDIR/GE-Proton-Test.tar.gz" ]
	[ -z "$(find "$CUSTPROTEXTDIR" -mindepth 1 -print)" ]
	assertNoProtonInstall
}

@test "dlCustomProton: cached GE archives are verified before extraction" {
	makeProtonTar
	cp "$TG_ARCHIVE" "$CUSTPROTDLDIR/GE-Proton-Test.tar.gz"
	export TG_EXPECTED_DIGEST="$(printf '%0128d' 0)"
	run dlCustomProton https://example.invalid/GE-Proton-Test.tar.gz
	[ "$status" -ne 0 ]
	[ "$(wc -l < "$WGET_CALLS")" -eq 1 ]
	[ -z "$(find "$CUSTPROTEXTDIR" -mindepth 1 -print)" ]
	assertNoProtonInstall
}

@test "dlCustomProton: valid GE archives are checked once and installed" {
	makeProtonTar GE-Proton-Test
	run dlCustomProton https://example.invalid/GE-Proton-Test.tar.gz
	[ "$status" -eq 0 ]
	[ "$(wc -l < "$WGET_CALLS")" -eq 2 ]
	[ -f "$CUSTPROTEXTDIR/GE-Proton-Test/proton" ]
	grep -qxF "$CUSTPROTEXTDIR/GE-Proton-Test/proton" "$REGISTER_CALLS"
	[ -f "$PROTBUMPTEMP" ]
	[ ! -e "$PROTONCSV" ]
}

@test "dlCustomProton: failed extraction leaves no installed tool or success markers" {
	makeProtonTar
	TAR=failedExtraction
	failedExtraction() {
		if [ "$1" = -tf ]; then
			tar "$@"
		else
			# Simulate an extractor which writes proton before failing later.
			tar "$@"
			return 2
		fi
	}
	run dlCustomProton https://example.invalid/Test-Proton.tar.gz
	[ "$status" -ne 0 ]
	[ -z "$(find "$CUSTPROTEXTDIR" -mindepth 1 -print)" ]
	assertNoProtonInstall

	TAR=tar
	run dlCustomProton https://example.invalid/Test-Proton.tar.gz
	[ "$status" -eq 0 ]
	[ -f "$CUSTPROTEXTDIR/Test-Proton/proton" ]
}

@test "dlCustomProton: failed archive listing cannot be masked by a proton filename" {
	makeProtonTar
	TAR=failedListing
	failedListing() { printf '%s\n' Test-Proton/proton; return 2; }
	run dlCustomProton https://example.invalid/Test-Proton.tar.gz
	[ "$status" -ne 0 ]
	[ -z "$(find "$CUSTPROTEXTDIR" -mindepth 1 -print)" ]
	assertNoProtonInstall
}

@test "dlCustomProton: archives without proton fail without refreshing or registering" {
	mkdir -p "$BATS_TEST_TMPDIR/source"
	printf '%s\n' 'not a Proton build' > "$BATS_TEST_TMPDIR/source/readme"
	tar -czf "$TG_ARCHIVE" -C "$BATS_TEST_TMPDIR/source" readme
	run dlCustomProton https://example.invalid/Test-Proton.tar.gz
	[ "$status" -ne 0 ]
	assertNoProtonInstall
}

@test "dlCustomProton: tarbombs get their own directory" {
	makeProtonTar .
	run dlCustomProton https://example.invalid/Test-Proton.tar.gz
	[ "$status" -eq 0 ]
	[ -f "$CUSTPROTEXTDIR/Test-Proton/proton" ]
	[ ! -e "$CUSTPROTEXTDIR/proton" ]
	grep -qxF "$CUSTPROTEXTDIR/Test-Proton/proton" "$REGISTER_CALLS"
}

@test "dlCustomProton: incomplete existing directories are preserved rather than registered" {
	makeProtonTar
	mkdir -p "$CUSTPROTEXTDIR/Test-Proton"
	printf '%s\n' 'keep user work' > "$CUSTPROTEXTDIR/Test-Proton/marker"
	run dlCustomProton https://example.invalid/Test-Proton.tar.gz
	[ "$status" -ne 0 ]
	[ "$(cat "$CUSTPROTEXTDIR/Test-Proton/marker")" = 'keep user work' ]
	assertNoProtonInstall
}

@test "dlCustomProton: existing installations never register a stale global path" {
	makeProtonTar
	mkdir -p "$CUSTPROTEXTDIR/Test-Proton"
	printf '#!/bin/sh\n' > "$CUSTPROTEXTDIR/Test-Proton/proton"
	PROTFULLPATH="$BATS_TEST_TMPDIR/unrelated-proton"
	printf '#!/bin/sh\n' > "$PROTFULLPATH"
	run dlCustomProton https://example.invalid/Test-Proton.tar.gz
	[ "$status" -eq 0 ]
	grep -qxF "$CUSTPROTEXTDIR/Test-Proton/proton" "$REGISTER_CALLS"
	! grep -qxF "$PROTFULLPATH" "$REGISTER_CALLS"
}

@test "dlCustomProton: invalid URLs and unsupported archives do not download" {
	run dlCustomProton file:///tmp/Proton.tar.gz
	[ "$status" -ne 0 ]
	run dlCustomProton https://example.invalid/Proton.exe
	[ "$status" -ne 0 ]
	[ ! -s "$WGET_CALLS" ]
	assertNoProtonInstall
}
