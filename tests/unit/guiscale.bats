load helpers

setup() {
	tg_load
}

@test "tgGuiScaleFromDpi: 96 dpi is no scaling - empty result" {
	run tgGuiScaleFromDpi "96"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "tgGuiScaleFromDpi: 120 dpi scales to 1.25" {
	[ "$(tgGuiScaleFromDpi "120")" = "1.25" ]
}

@test "tgGuiScaleFromDpi: 192 dpi scales to 2.00" {
	[ "$(tgGuiScaleFromDpi "192")" = "2.00" ]
}

@test "tgGuiScaleFromDpi: 264 dpi scales to 2.75" {
	[ "$(tgGuiScaleFromDpi "264")" = "2.75" ]
}

@test "tgGuiScaleFromDpi: 384 dpi scales to 4.00" {
	[ "$(tgGuiScaleFromDpi "384")" = "4.00" ]
}

@test "tgGuiScaleFromDpi: below the 1.25 minimum is rejected" {
	run tgGuiScaleFromDpi "119"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "tgGuiScaleFromDpi: above the 4.00 maximum is rejected" {
	run tgGuiScaleFromDpi "500"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "tgGuiScaleFromDpi: empty and junk values are rejected" {
	run tgGuiScaleFromDpi ""
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run tgGuiScaleFromDpi "garbage"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "tgGuiScaleFromDpi: fractional dpi is accepted" {
	[ "$(tgGuiScaleFromDpi "168.5")" = "1.76" ]
}

@test "tgGuiScaleFromDpi: TG_GUI_SCALE_MIN/MAX bounds are honoured" {
	[ "$(TG_GUI_SCALE_MIN=1.0 tgGuiScaleFromDpi "96")" = "1.00" ]
	run tgGuiScaleFromDpi "432"
	[ -z "$output" ]
	[ "$(TG_GUI_SCALE_MAX=5.0 tgGuiScaleFromDpi "432")" = "4.50" ]
	run tgGuiScaleFromDpi "200"
	[ -n "$output" ]
	TG_GUI_SCALE_MIN=3.0 run tgGuiScaleFromDpi "200"
	[ -z "$output" ]
}

@test "tgClampScaleToScreen: 4K screen clamps 2.75 down to what fits" {
	[ "$(tgClampScaleToScreen "2.75" "3840" "2400")" = "1.50" ]
}

@test "tgClampScaleToScreen: a factor that already fits is unchanged" {
	[ "$(tgClampScaleToScreen "1.50" "3840" "2400")" = "1.50" ]
	[ "$(tgClampScaleToScreen "1.25" "3200" "1800")" = "1.25" ]
}

@test "tgClampScaleToScreen: screen smaller than the reference size rejects scaling" {
	run tgClampScaleToScreen "2.75" "1920" "1080"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "tgClampScaleToScreen: floor rounding happens before the minimum check" {
	run tgClampScaleToScreen "2.75" "3072" "2400"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	[ "$(TG_GUI_SCALE_MIN=1.0 tgClampScaleToScreen "2.75" "3072" "2400")" = "1.20" ]
}

@test "tgClampScaleToScreen: missing or invalid screen dimensions pass the factor through" {
	[ "$(tgClampScaleToScreen "2.75" "" "")" = "2.75" ]
	[ "$(tgClampScaleToScreen "2.75" "garbage" "2400")" = "2.75" ]
}

@test "tgClampScaleToScreen: invalid factor is rejected" {
	run tgClampScaleToScreen "" "3840" "2400"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run tgClampScaleToScreen "garbage" "3840" "2400"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "tgClampScaleToScreen: TG_GUI_FIT_WIDTH/HEIGHT and 0-disable are honoured" {
	[ "$(TG_GUI_FIT_WIDTH=1920 tgClampScaleToScreen "2.75" "3840" "2400")" = "1.66" ]
	[ "$(TG_GUI_FIT_WIDTH=0 TG_GUI_FIT_HEIGHT=0 tgClampScaleToScreen "2.75" "3840" "2400")" = "2.75" ]
}

@test "tgClampWinXY: clamps a window larger than the screen" {
	[ "$(tgClampWinXY "9999" "9999" "3840" "2400")" = "3840 2400" ]
	[ "$(tgClampWinXY "4000" "600" "3840" "2400")" = "3840 600" ]
	[ "$(tgClampWinXY "800" "3000" "3840" "2400")" = "800 2400" ]
}

@test "tgClampWinXY: a fitting window is unchanged" {
	[ "$(tgClampWinXY "800" "600" "3840" "2400")" = "800 600" ]
	[ "$(tgClampWinXY "3840" "2400" "3840" "2400")" = "3840 2400" ]
}

@test "tgClampWinXY: missing or invalid screen passes the window through" {
	[ "$(tgClampWinXY "9999" "9999" "" "")" = "9999 9999" ]
	[ "$(tgClampWinXY "9999" "9999" "garbage" "2400")" = "9999 9999" ]
	[ "$(tgClampWinXY "9999" "9999" "0" "2400")" = "9999 9999" ]
}

@test "tgClampWinXY: missing or invalid window size is rejected" {
	run tgClampWinXY "" "600" "3840" "2400"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run tgClampWinXY "garbage" "600" "3840" "2400"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "tgClampWinXY: setGeom clamps stale saved geometries to the screen" {
	TGSCRW=3840
	TGSCRH=2400
	WINX=9999
	WINY=9999
	POSX=0
	POSY=0
	( set +e; setGeom; printf '%s' "$GEOM" > "$BATS_TEST_TMPDIR/geom.out" )
	[ "$(cat "$BATS_TEST_TMPDIR/geom.out")" = "--geometry=3840x2400+0+0" ]
}

@test "tgClampWinXY: setGeom keeps a fitting geometry untouched" {
	TGSCRW=3840
	TGSCRH=2400
	WINX=800
	WINY=600
	POSX=0
	POSY=0
	( set +e; setGeom; printf '%s' "$GEOM" > "$BATS_TEST_TMPDIR/geom.out" )
	[ "$(cat "$BATS_TEST_TMPDIR/geom.out")" = "--geometry=800x600+0+0" ]
}
