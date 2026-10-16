#!/usr/bin/env bash
# Download and integrity failures must never look like successful downloads.

setup() {
	load helpers
	tg_load
	source "$TG_ROOT/lang/english.txt"

	DLCHECK_LOG="$BATS_TEST_TMPDIR/download.log"
	DLCHECK_NOTICES="$BATS_TEST_TMPDIR/notices.log"
	DLCHECK_CALLS="$BATS_TEST_TMPDIR/wget.calls"
	DLCHECK_DEST="$BATS_TEST_TMPDIR/download with spaces.bin"
	: > "$DLCHECK_LOG"
	: > "$DLCHECK_NOTICES"
	: > "$DLCHECK_CALLS"

	writelog() { printf '%s\n' "$*" >> "$DLCHECK_LOG"; }
	notiShow() { printf '%s\n' "$1" >> "$DLCHECK_NOTICES"; }
	sleep() { :; }
	WGET=fakeDownload

	fakeDownload() {
		local DEST=""
		printf '%s\n' "$@" >> "$DLCHECK_CALLS"
		while [ "$#" -gt 0 ]; do
			case "$1" in
				-O) DEST="$2"; shift 2 ;;
				*) shift ;;
			esac
		done
		printf '%s' "${DLCHECK_PAYLOAD:-downloaded content}" > "$DEST"
		return "${DLCHECK_WGET_RC:-0}"
	}
}

@test "dlCheck: propagates wget failures and removes only its partial file" {
	DLCHECK_WGET_RC=8
	run dlCheck https://example.invalid/archive "$DLCHECK_DEST" X "Test download" "$NON"
	[ "$status" -eq 8 ]
	[ ! -e "$DLCHECK_DEST" ]
	[ -z "$(find "$BATS_TEST_TMPDIR" -name '*.part.*' -print)" ]
	! grep -q "Download finished" "$DLCHECK_NOTICES"
}

@test "dlCheck: quiet downloads preserve the wget failure status" {
	DLCHECK_WGET_RC=4
	run dlCheck https://example.invalid/archive "$DLCHECK_DEST" X "$NON"
	[ "$status" -eq 4 ]
	[ ! -e "$DLCHECK_DEST" ]
}

@test "dlCheck: a failed replacement preserves the existing download" {
	printf '%s' 'known good cache' > "$DLCHECK_DEST"
	DLCHECK_WGET_RC=8
	run dlCheck https://example.invalid/archive "$DLCHECK_DEST" X "Test download"
	[ "$status" -eq 8 ]
	[ "$(cat "$DLCHECK_DEST")" = 'known good cache' ]
}

@test "dlCheck: successful downloads work with spaces in the destination" {
	run dlCheck https://example.invalid/archive "$DLCHECK_DEST" X "Test download"
	[ "$status" -eq 0 ]
	[ "$(cat "$DLCHECK_DEST")" = 'downloaded content' ]
	[ -z "$(find "$BATS_TEST_TMPDIR" -name '*.part.*' -print)" ]
}

@test "dlCheck: empty successful responses are not cached" {
	fakeDownload() {
		local DEST
		while [ "$#" -gt 0 ]; do
			case "$1" in -O) DEST="$2"; shift 2 ;; *) shift ;; esac
		done
		: > "$DEST"
	}
	run dlCheck https://example.invalid/archive "$DLCHECK_DEST" X "Test download"
	[ "$status" -ne 0 ]
	[ ! -e "$DLCHECK_DEST" ]
}

@test "dlCheck: checksum-only mismatches return failure and are checked once" {
	printf '%s' 'cached content' > "$DLCHECK_DEST"
	run dlCheck sha256sum "$DLCHECK_DEST" C deadbeef
	[ "$status" -ne 0 ]
	[ "$(grep -c 'NOT correct' "$DLCHECK_NOTICES")" -eq 1 ]
	[ ! -s "$DLCHECK_CALLS" ]
	[ "$(cat "$DLCHECK_DEST")" = 'cached content' ]
}

@test "dlCheck: matching checksum-only checks succeed without downloading" {
	printf '%s' 'cached content' > "$DLCHECK_DEST"
	local DIGEST
	DIGEST="$(sha256sum "$DLCHECK_DEST")"
	run dlCheck sha256sum "$DLCHECK_DEST" C "${DIGEST%% *}"
	[ "$status" -eq 0 ]
	[ "$(grep -c 'is correct' "$DLCHECK_NOTICES")" -eq 1 ]
	[ ! -s "$DLCHECK_CALLS" ]
}

@test "dlCheck: missing expected checksums fail before downloading" {
	run dlCheck https://example.invalid/archive "$DLCHECK_DEST" sha256sum "Test download" ""
	[ "$status" -ne 0 ]
	[ ! -s "$DLCHECK_CALLS" ]
	[ ! -e "$DLCHECK_DEST" ]
}

@test "dlCheck: missing files and failed checksum commands cannot pass verification" {
	run dlCheck sha256sum "$DLCHECK_DEST" C deadbeef
	[ "$status" -ne 0 ]

	printf '%s' 'cached content' > "$DLCHECK_DEST"
	brokenChecksum() { printf '%s\n' deadbeef; return 9; }
	run dlCheck brokenChecksum "$DLCHECK_DEST" C deadbeef
	[ "$status" -ne 0 ]
	! grep -q 'is correct' "$DLCHECK_NOTICES"
}

@test "dlCheck: downloaded checksum mismatches never replace an existing cache" {
	printf '%s' 'known good cache' > "$DLCHECK_DEST"
	# A zero-byte destination is retried; a non-empty checked cache is verified.
	local NEWDEST="$BATS_TEST_TMPDIR/new download.bin"
	run dlCheck https://example.invalid/archive "$NEWDEST" sha256sum "Test download" deadbeef
	[ "$status" -ne 0 ]
	[ ! -e "$NEWDEST" ]
	[ "$(cat "$DLCHECK_DEST")" = 'known good cache' ]
	[ -z "$(find "$BATS_TEST_TMPDIR" -name '*.part.*' -print)" ]
}

@test "dlCheck: size checks validate new downloads before publishing them" {
	run dlCheck https://example.invalid/archive "$DLCHECK_DEST" stat "Test download" 18
	[ "$status" -eq 0 ]
	[ "$(cat "$DLCHECK_DEST")" = 'downloaded content' ]
}
