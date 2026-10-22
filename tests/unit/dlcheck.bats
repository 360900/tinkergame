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

# Progress bar: dlCheck swaps StatusWindow's text window for a yad --progress
# window fed from wget's --show-progress output (issue #3).

@test "dlProgressFeed: turns wget progress output into yad progress input" {
	# captured from GNU Wget 1.25 with --show-progress --progress=bar:force:noscroll
	run dlProgressFeed < "$TG_FIXTURES/wget-show-progress.txt"
	[ "$status" -eq 0 ]
	[ "$output" = "0
# 0%  0 --.-KB/s
23
# 23%  559.64K 2.72MB/s
100
# 100%  2.29M 7.82MB/s in 0.3s" ]
}

@test "dlProgressFeed: reads wget2's escape-sequence progress output" {
	# captured from GNU Wget2 2.3.0 (Fedora's wget) with the same options
	run dlProgressFeed < "$TG_FIXTURES/wget2-show-progress.txt"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "50" ]
	[ "${lines[1]}" = "# 50%  1.25M --.-KB/s" ]
	[ "${lines[2]}" = "100" ]
}

@test "dlProgressFeed: a download of unknown size pulses the bar" {
	run dlProgressFeed < "$TG_FIXTURES/wget-show-progress-nosize.txt"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "pulse" ]
	[ "${lines[3]}" = "# 320.00K 1.55MB/s" ]
	! grep -qx "[0-9]*" <<< "$output"

	run dlProgressFeed < "$TG_FIXTURES/wget2-show-progress-nosize.txt"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "pulse" ]
	[ "${lines[1]}" = "# 1.25M --.-KB/s" ]
}

# Fake yad: records every call, drains a --progress window's input to
# $FAKEYAD_PROGRESS, keeps text windows open until killed.
setup_progress_fakes() {
	export FAKEYAD_CALLS="$BATS_TEST_TMPDIR/yad.calls"
	export FAKEYAD_PROGRESS="$BATS_TEST_TMPDIR/yad.progress"
	export FAKEYAD_PIDS="$BATS_TEST_TMPDIR/yad.pids"
	: > "$FAKEYAD_CALLS"
	: > "$FAKEYAD_PIDS"
	YAD="$BATS_TEST_TMPDIR/fakeyad"
	cat > "$YAD" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKEYAD_CALLS"
case " $* " in
	*" --progress "*)
		# FAKEYAD_CLOSE: the user closes the bar right away
		[ -z "${FAKEYAD_CLOSE:-}" ] || exit 252
		cat >>"$FAKEYAD_PROGRESS"; exit 0 ;;
esac
echo $$ >>"$FAKEYAD_PIDS"
while :; do sleep 0.1; done
FAKE
	chmod +x "$YAD"
	unset -f sleep
	pollWinRes() { :; }
	GEOM="--geometry=800x600+0+0"

	WGET=fakeProgressWget
	fakeProgressWget() {
		local DEST=""
		if [ "$1" = --help ]; then
			echo "       --show-progress             display the progress bar in any verbosity mode"
			return 0
		fi
		printf '%s\n' "$@" >> "$DLCHECK_CALLS"
		while [ "$#" -gt 0 ]; do
			case "$1" in -O) DEST="$2"; shift 2 ;; *) shift ;; esac
		done
		cat "${DLCHECK_FIXTURE:-$TG_FIXTURES/wget-show-progress.txt}" >&2
		printf '%s' 'downloaded content' > "$DEST"
		return "${DLCHECK_WGET_RC:-0}"
	}
	progressTask() { dlCheck https://example.invalid/archive "$DLCHECK_DEST" X "Test download"; }
}

no_window_left_open() {
	local PID
	while read -r PID; do
		if kill -0 "$PID" 2>/dev/null; then
			return 1
		fi
	done < "$FAKEYAD_PIDS"
}

@test "dlCheck: a download inside a StatusWindow shows a progress bar" {
	setup_progress_fakes

	run StatusWindow "Downloading test thing" progressTask "TestStatus"
	[ "$status" -eq 0 ]
	[ "$(cat "$DLCHECK_DEST")" = 'downloaded content' ]
	grep -q -- "--show-progress" "$DLCHECK_CALLS"
	run grep -c -- "--progress --auto-close --text=Downloading test thing..." "$FAKEYAD_CALLS"
	[ "$output" -eq 1 ]
	# sized to its content, not to the saved geometry
	run grep -- "--progress" "$FAKEYAD_CALLS"
	[[ "$output" == *"--fixed"* ]]
	[[ "$output" != *"--geometry"* ]]
	grep -qx "23" "$FAKEYAD_PROGRESS"
	grep -qx "# 23%  559.64K 2.72MB/s" "$FAKEYAD_PROGRESS"
	# text window before and after the bar, and none left open
	run grep -c -- "--borders=16 --text=Downloading test thing..." "$FAKEYAD_CALLS"
	[ "$output" -eq 2 ]
	no_window_left_open
}

@test "dlCheck: a failed download with a progress bar keeps the wget status" {
	setup_progress_fakes
	DLCHECK_WGET_RC=8

	run StatusWindow "Downloading test thing" progressTask "TestStatus"
	[ "$status" -eq 8 ]
	[ ! -e "$DLCHECK_DEST" ]
	[ -z "$(find "$BATS_TEST_TMPDIR" -name '*.part.*' -print)" ]
	no_window_left_open
}

@test "dlCheck: markup in the status text is escaped in the progress window" {
	setup_progress_fakes

	run StatusWindow "Download <Tom & Jerry>" progressTask "TestStatus"
	[ "$status" -eq 0 ]
	grep -qF -- "--text=Download &lt;Tom &amp; Jerry&gt;..." "$FAKEYAD_CALLS"
}

@test "dlCheck: no progress bar outside a StatusWindow" {
	setup_progress_fakes

	run progressTask
	[ "$status" -eq 0 ]
	[ ! -s "$FAKEYAD_CALLS" ]
	! grep -q -- "--show-progress" "$DLCHECK_CALLS"
}

@test "dlCheck: no progress bar from a subshell of the StatusWindow" {
	setup_progress_fakes
	subshellTask() { ( progressTask ); }

	run StatusWindow "Downloading test thing" subshellTask "TestStatus"
	[ "$status" -eq 0 ]
	! grep -q -- "--progress" "$FAKEYAD_CALLS"
	no_window_left_open
}

@test "dlCheck: a download of unknown size shows a pulsating bar" {
	setup_progress_fakes
	DLCHECK_FIXTURE="$TG_FIXTURES/wget-show-progress-nosize.txt"

	run StatusWindow "Downloading test thing" progressTask "TestStatus"
	[ "$status" -eq 0 ]
	[ "$(cat "$DLCHECK_DEST")" = 'downloaded content' ]
	run grep -c -- "--progress --pulsate --auto-close" "$FAKEYAD_CALLS"
	[ "$output" -eq 1 ]
	no_window_left_open
}

@test "dlCheck: closing the progress bar cancels the download" {
	setup_progress_fakes
	export FAKEYAD_CLOSE=1
	# a slow download that keeps reporting progress
	fakeProgressWget() {
		local DEST="" I
		if [ "$1" = --help ]; then
			echo "       --show-progress             display the progress bar in any verbosity mode"
			return 0
		fi
		while [ "$#" -gt 0 ]; do
			case "$1" in -O) DEST="$2"; shift 2 ;; *) shift ;; esac
		done
		for I in $(seq 1 99); do
			printf '/dev/null  %s%%[=>   ]  %sK  1MB/s\r' "$I" "$I" >&2
			command sleep 0.1
		done
		printf '%s' 'downloaded content' > "$DEST"
	}

	SECONDS=0
	run StatusWindow "Downloading test thing" progressTask "TestStatus"
	[ "$status" -ne 0 ]
	[ "$SECONDS" -lt 5 ]
	[ ! -e "$DLCHECK_DEST" ]
	[ -z "$(find "$BATS_TEST_TMPDIR" -name '*.part.*' -print)" ]
	grep -q "cancelling the download" "$DLCHECK_LOG"
	no_window_left_open
}

@test "dlCheck: no progress bar when wget fails before its first update" {
	setup_progress_fakes
	DLCHECK_FIXTURE=/dev/null
	DLCHECK_WGET_RC=4

	run StatusWindow "Downloading test thing" progressTask "TestStatus"
	[ "$status" -eq 4 ]
	! grep -q -- "--progress" "$FAKEYAD_CALLS"
	no_window_left_open
}
