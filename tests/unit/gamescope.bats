#!/usr/bin/env bash
# Tests for the GameScopeGui array-driven field parsing (GSFIELDSPEC).
# The yad binary is replaced by a stub which prints a canned pipe-separated
# form result, so the whole parse+save path runs without a GUI.

load helpers

setup() {
	tg_load

	GAMECFG="$BATS_TEST_TMPDIR/game.conf"
	printf 'GAMESCOPE_ARGS="none"\nUSEGAMESCOPE="0"\nUSEGAMESCOPEWSI="0"\n' > "$GAMECFG"
	STLGAMECFG="$GAMECFG"
	FUPDATE="$BATS_TEST_TMPDIR/fupdate.txt"
	STLTEMPDIR="$BATS_TEST_TMPDIR/temp"

	# all GUI_/DESC_/BUT_ labels used by the form come from the real language file
	# shellcheck source=/dev/null
	source "$TG_ROOT/lang/english.txt"

	# xrandr stub (used for the two resolution CBE dropdowns)
	printf '#!/usr/bin/env bash\nexit 0\n' > "$BATS_TEST_TMPDIR/stubbin/xrandr"
	chmod +x "$BATS_TEST_TMPDIR/stubbin/xrandr"
	XRANDR="$BATS_TEST_TMPDIR/stubbin/xrandr"

	# yad stub: one form invocation per GameScopeGui call
	cat > "$BATS_TEST_TMPDIR/stubbin/yad" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"--field"* ]]; then
	echo "form:$*" >> "$STUB_YAD_LOG"
	printf '%s\n' "${STUB_GS_OUT:-}"
	if [ -n "${STUB_YAD_RC_SEQ:-}" ]; then
		n="$(grep -c '^form:' "$STUB_YAD_LOG")"
		# shellcheck disable=SC2206
		seq=($STUB_YAD_RC_SEQ)
		if [ "$n" -le "${#seq[@]}" ]; then
			exit "${seq[$((n - 1))]}"
		fi
		exit "${seq[$(( ${#seq[@]} - 1 ))]}"
	fi
	exit "${STUB_YAD_RC:-0}"
fi
echo "other:$*" >> "$STUB_YAD_LOG"
exit 0
EOF
	chmod +x "$BATS_TEST_TMPDIR/stubbin/yad"
	export YAD="$BATS_TEST_TMPDIR/stubbin/yad"
	export STUB_YAD_LOG="$BATS_TEST_TMPDIR/yad.log"
	export STUB_YAD_RC_SEQ=""
	export STUB_YAD_RC=0
	export STUB_GS_OUT=""
	touch "$STUB_YAD_LOG"

	F1ACTION="echo"
	SHOWPIC="pic"
	STLICON="icon"
	GEOM=""
	SGNAID="TestGame"
	HEADLINEFONT="larger"
	PPW="https://example.org/wiki"
	YADIMGTOP=()
	WINDECO=()

	MARK="$BATS_TEST_TMPDIR/mark"
	mkdir -p "$MARK"
	VARSOUT="$BATS_TEST_TMPDIR/vars.txt"

	# GameScopeGui helpers: keep the run deterministic
	setGameScopeVars() {
		GSNORM="normal"
		GSFOOROPTS="left!right!${GSNORM}!upsidedown"
		GSFLTROPTS="$NON!linear!nearest!fsr!nis!pixel"
		GSSCALEOPTS="$NON!auto!integer!fit!fill!stretch"
		GSDEF="default"
		GSTOUCHMODES="${GSDEF}!hover!left!right!middle!passthru"
		GSDRMMODES="${GSDEF}!cvt!fixed"
		GSBACKENDOPTS="auto!sdl!wayland!drm!headless!openvr"
		GSNEWFILTERMODE=0
	}
	pollWinRes() { return 0; }
	setShowPic() { return 0; }
	fixShowGnAid() { return 0; }
	GameScopeReset() { touch "$MARK/reset"; }
}

# dump the interesting variables after a GameScopeGui run (called in the same
# subshell as the function so the assignments are visible)
gs_dump_vars() {
	{
		echo "GSINTRES=$GSINTRES"
		echo "GSSHWRES=$GSSHWRES"
		echo "GSFLR=$GSFLR"
		echo "USEGAMESCOPE=$USEGAMESCOPE"
		echo "GSFS=$GSFS"
		echo "GSMOUSESENSITIVITY=$GSMOUSESENSITIVITY"
		echo "GSFLTR=$GSFLTR"
		echo "GSHDR=$GSHDR"
		echo "GSVR=$GSVR"
		echo "GSDEFTOUCHMODE=$GSDEFTOUCHMODE"
		echo "GSBACKEND=$GSBACKEND"
		echo "USEGAMESCOPEWSI=$USEGAMESCOPEWSI"
		echo "GAMESCOPE_ARGS=$GAMESCOPE_ARGS"
	} > "$VARSOUT"
}

gs_mkvalues() {
	local out="v0" i
	for i in $(seq 1 62); do
		out="$out|v$i"
	done
	printf '%s' "$out"
}

@test "gamescope: form has 63 --field slots (6 of them LBL headings)" {
	STUB_GS_OUT="$(gs_mkvalues)"
	STUB_YAD_RC=0
	( set +e; GameScopeGui )
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 1 ]
	[ "$(grep -o -- '--field=' "$STUB_YAD_LOG" | wc -l)" -eq 63 ]
	[ "$(grep -o -- ':LBL' "$STUB_YAD_LOG" | wc -l)" -eq 6 ]
}

@test "gamescope: GSFIELDSPEC maps form slots to variables by position" {
	STUB_GS_OUT="$(gs_mkvalues)"
	STUB_YAD_RC=4
	( set +e; GameScopeGui; gs_dump_vars )

	# heading slots are skipped, every variable gets its own slot value
	grep -q '^GSINTRES=v1$' "$VARSOUT"
	grep -q '^GSMOUSESENSITIVITY=v15$' "$VARSOUT"
	grep -q '^GSFLTR=v17$' "$VARSOUT"
	grep -q '^GSHDR=v24$' "$VARSOUT"
	grep -q '^GSVR=v31$' "$VARSOUT"
	grep -q '^GSDEFTOUCHMODE=v44$' "$VARSOUT"
	grep -q '^GSBACKEND=v50$' "$VARSOUT"
	grep -q '^USEGAMESCOPEWSI=v62$' "$VARSOUT"
	grep -q '^USEGAMESCOPE=v5$' "$VARSOUT"

	# config writes: args string + the two use flags
	grep -q -- '--backend v50' "$GAMECFG"
	grep -q -- '-m v20' "$GAMECFG"
	grep -q -- "--vr-overlay-key 'v34'" "$GAMECFG"
	grep -q '^USEGAMESCOPEWSI="v62"$' "$GAMECFG"
	grep -q '^USEGAMESCOPE="v5"$' "$GAMECFG"
}

@test "gamescope: realistic values produce correct GAMESCOPE_ARGS" {
	STUB_GS_OUT="SKIP|1280x720|1920x1080|60||TRUE|TRUE|FALSE|FALSE|FALSE|FALSE|FALSE|normal|FALSE||2|\
SKIP|none|none|0|0||0|\
SKIP|FALSE|FALSE|400|FALSE|0|0|\
SKIP|FALSE||||FALSE|FALSE|FALSE|FALSE|FALSE|FALSE|8|FALSE|\
SKIP|default|FALSE|FALSE||default|\
SKIP|auto|FALSE||0|FALSE|FALSE|FALSE|FALSE|FALSE|FALSE|FALSE|FALSE|FALSE"
	STUB_YAD_RC=4
	( set +e; GameScopeGui; gs_dump_vars )

	grep -q '^GAMESCOPE_ARGS="-w 1280 -h 720 -W 1920 -H 1080 -r 60 -f -s 2 --"$' "$GAMECFG"
	# TRUE/FALSE checkboxes are stored as 1/0
	grep -q '^USEGAMESCOPE="1"$' "$GAMECFG"
	grep -q '^USEGAMESCOPEWSI="0"$' "$GAMECFG"
	grep -q '^GSFS=TRUE$' "$VARSOUT"
}

@test "gamescope: short form output only warns, earlier variables still mapped" {
	LOGLEVEL=2
	local short
	short="$(gs_mkvalues)"
	short="${short%|v62}"
	STUB_GS_OUT="$short"
	STUB_YAD_RC=4
	( set +e; GameScopeGui; gs_dump_vars )

	grep -q "fields were expected" "$TEMPLOG"
	grep -q '^GSINTRES=v1$' "$VARSOUT"
	grep -q '^GSHDR=v24$' "$VARSOUT"
	grep -q '^USEGAMESCOPEWSI=$' "$VARSOUT"
}

@test "gamescope: cancel (rc=0) writes nothing" {
	STUB_GS_OUT="$(gs_mkvalues)"
	STUB_YAD_RC=0
	( set +e; GameScopeGui )

	grep -q '^GAMESCOPE_ARGS="none"$' "$GAMECFG"
	grep -q '^USEGAMESCOPE="0"$' "$GAMECFG"
	[ ! -e "$MARK/reset" ]
}

@test "gamescope: rc=2 resets and reopens the dialog" {
	STUB_GS_OUT="$(gs_mkvalues)"
	STUB_YAD_RC_SEQ="2 0"
	( set +e; GameScopeGui )

	[ -e "$MARK/reset" ]
	[ "$(grep -c '^form:' "$STUB_YAD_LOG")" -eq 2 ]
}
