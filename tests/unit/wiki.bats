#!/usr/bin/env bash
# F1 help opens the wiki page in CURWIKI: every page named there must exist.
# tests/fixtures/wiki-pages.txt lists the pages of the project wiki
# (https://github.com/360900/tinkergame.wiki.git); update it with the wiki.

setup() {
	load helpers
}

@test "CURWIKI: every literal wiki page name exists in the wiki" {
	local PAGE MISSING=""
	while IFS= read -r PAGE; do
		PAGE="${PAGE#CURWIKI=\"\$PPW/}"
		PAGE="${PAGE%\"}"
		# names built from variables are not literal
		if [[ "$PAGE" == *'$'* ]]; then
			continue
		fi
		if ! grep -qxF -- "$PAGE" "$TG_FIXTURES/wiki-pages.txt"; then
			MISSING+="$PAGE"$'\n'
		fi
	done < <(grep -rhoE 'CURWIKI="\$PPW/[^"]+"' "$TG_ROOT/lib")
	echo "missing wiki pages: $MISSING"
	[ -z "$MISSING" ]
}
