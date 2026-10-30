#!@shell@
# Says, by desktop notification and once per release, when upstream has a newer
# Herdr app or herdr-core than this package pins, to update through Nix. Run by
# the herdr-app wrapper and by the module's timer; checks at most every 5
# hours. HERDR_NIX_NO_UPDATE_CHECK=1 turns it off.
PATH="@path@:$PATH"

[ "${HERDR_NIX_NO_UPDATE_CHECK:-}" = 1 ] && exit 0
state="${XDG_CACHE_HOME:-$HOME/.cache}/herdr-nix"
mkdir -p "$state" || exit 0
[ -n "$(find "$state/checked" -mmin -300 2>/dev/null)" ] && exit 0
touch "$state/checked"

newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ]; }

app="$(curl -fsSL --max-time 20 https://releases.herdr.dev/app/latest.json | jq -r '.version // empty')"
core="$(curl -fsSL --max-time 20 https://releases.herdr.dev/core/latest.json | jq -r '.version // empty')"
news=""
[ -n "$app" ] && newer "$app" "@appVersion@" && news="Herdr $app (installed @appVersion@)"
[ -n "$core" ] && newer "$core" "@coreVersion@" &&
  news="${news:+$news, }herdr-core $core (installed @coreVersion@)"
[ -n "$news" ] || exit 0
# Once per set of releases.
[ "$(cat "$state/notified" 2>/dev/null)" = "$news" ] && exit 0
printf '%s' "$news" > "$state/notified"

title="Herdr update available"
body="$news. Update it through Nix: nix flake update, then rebuild."
if [ "$(uname -s)" = Darwin ]; then
  /usr/bin/osascript -e "display notification \"$body\" with title \"$title\""
else
  notify-send --app-name=Herdr --icon=herdr-app "$title" "$body"
fi
