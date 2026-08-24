#!/usr/bin/env bash
# Tests for Steam user detection from loginusers.vdf (fillLoginUsersCSV).
# Modern Steam clients no longer write a "MostRecent" field, so the parser
# must fall back to the newest "Timestamp" (or the only listed user).

load helpers

setup() {
	tg_load

	export STLSHM="$BATS_TEST_TMPDIR/shm"
	mkdir -p "$STLSHM"
	export LOGUVDF="$BATS_TEST_TMPDIR/loginusers.vdf"
	export LOGINUSERSCSV="$STLSHM/LoginUsersCSV.txt"
}

# two users, no MostRecent field, different Timestamps
make_vdf_no_mostrecent() {
	cat > "$LOGUVDF" <<'EOF'
"users"
{
	"76561198000000001"
	{
		"AccountName"	"usera"
		"PersonaName"	"User A"
		"RememberPassword"		"1"
		"Timestamp"		"1000"
	}
	"76561198000000002"
	{
		"AccountName"	"userb"
		"PersonaName"	"User B"
		"RememberPassword"		"1"
		"Timestamp"		"2000"
	}
}
EOF
}

@test "fillLoginUsersCSV: no MostRecent field - newest Timestamp wins" {
	make_vdf_no_mostrecent
	fillLoginUsersCSV

	[ -s "$LOGINUSERSCSV" ]
	[ "$(grep -c ';1$' "$LOGINUSERSCSV")" -eq 1 ]
	grep -q '^76561198000000002;.*;1$' "$LOGINUSERSCSV"
	grep -q '^76561198000000001;.*;0$' "$LOGINUSERSCSV"
}

@test "fillLoginUsersCSV: explicit MostRecent still wins over Timestamp" {
	make_vdf_no_mostrecent
	# user A (older timestamp) is explicitly most recent
	sed -i '/"AccountName"	"usera"/a\		"MostRecent"		"1"' "$LOGUVDF"

	fillLoginUsersCSV

	[ "$(grep -c ';1$' "$LOGINUSERSCSV")" -eq 1 ]
	grep -q '^76561198000000001;.*;1$' "$LOGINUSERSCSV"
}

@test "fillLoginUsersCSV: single user without MostRecent or Timestamp is selected" {
	cat > "$LOGUVDF" <<'EOF'
"users"
{
	"76561198000000042"
	{
		"AccountName"	"solo"
		"PersonaName"	"Solo User"
	}
}
EOF

	fillLoginUsersCSV

	[ "$(grep -c ';1$' "$LOGINUSERSCSV")" -eq 1 ]
	grep -q '^76561198000000042;.*;1$' "$LOGINUSERSCSV"
}
