#!/usr/bin/env bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034,SC2154,SC2153,SC2119,SC2120,SC1090
# (variables, assignments and function calls span the sourced lib/ modules, so
#  cross-module references are invisible to per-file analysis)
# TinkerGame library module -- sourced by the "tinkergame" entry point. Do not execute directly.

function gitUpdate {
	GITDIR="$1"
	GITURL="$2"
	if [ -d "$GITDIR/.git" ]; then
		writelog "INFO" "${FUNCNAME[0]} - Pulling '$GITURL' update in '$GITDIR'"

		if [ "$ONSTEAMDECK" -eq 1 ]; then
			LD_PRELOAD="/usr/lib/libcurl.so.4" "$GIT" --work-tree="$GITDIR" --git-dir="$GITDIR/.git" pull --rebase=false &> "$STLSHM/${FUNCNAME[0]}-SteamDeck-${GITDIR##*/}"
		else
			"$GIT" --work-tree="$GITDIR" --git-dir="$GITDIR/.git" pull --rebase=false &> "$STLSHM/${FUNCNAME[0]}-${GITDIR##*/}"
		fi
	else
		mkProjDir "$GITDIR"
		writelog "INFO" "${FUNCNAME[0]} - Cloning '$GITURL' in '$GITDIR'"

		if [ "$ONSTEAMDECK" -eq 1 ]; then
			LD_PRELOAD="/usr/lib/libcurl.so.4" "$GIT" clone "$GITURL" "$GITDIR" &> "$STLSHM/${FUNCNAME[0]}-SteamDeck-${GITDIR##*/}"
		else
			"$GIT" clone "$GITURL" "$GITDIR" &> "$STLSHM/${FUNCNAME[0]}-${GITDIR##*/}"
		fi
	fi
}

function fetchGitHubTags {
    PROJURL="$1"
    N="$2"

    RELEASESURL="${PROJURL}/releases"
    TAGSURL="${PROJURL}/tags"

    TAGSGREP="${RELEASESURL#"$GHURL"}/tag"

    mapfile -t BASETAGS < <("$WGET" -q "${TAGSURL}" -O - 2> >(grep -v "SSL_INIT") | grep -oE "${TAGSGREP}[^\"]+" | sort -urV | grep -m "$N" "$TAGSGREP")
    for TAG in "${BASETAGS[@]}"; do
        basename "$TAG"
    done
}

# Just for fun ;)
function getSeasonalGreeting {
	CURRDATE="$( date +"%d-%m" )"
	if [ "$CURRDATE" = "25-12" ];then
		echo "Happy Holidays!"
	elif [ "$CURRDATE" = "31-12" ] || [ "$CURRDATE" = "01-01" ]; then
		echo "Happy New Year!"
	elif [ "$CURRDATE" = "31-10" ]; then
		TM="$( date +"%H:%M" )"
		if [ "$TM" = "00:00" ]; then
			echo "Happy Halloween, it's the witching hour!"
		else
			echo "Happy Halloween!"
		fi
	fi
}

