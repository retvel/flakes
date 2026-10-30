#!@shell@
# Starts Herdr from the Nix store. The app's own updater would download a
# release it can't install over the read-only store, so point it at a copy of
# the pinned release manifests (it then reports itself up to date), and say
# here, once per release, when upstream has a newer one to update to via Nix.

export HERDR_RELEASES_URL="file://@releases@"
# The app downloads with curl and looks for herdr-core on PATH. Appended, so
# the terminals it opens keep the user's own tools first.
export PATH="${PATH:+$PATH:}@appPath@"

notify() {
  if [ "$(uname -s)" = Darwin ]; then
    /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" >/dev/null 2>&1
  else
    notify-send --app-name=Herdr --icon=herdr-app "$1" "$2" >/dev/null 2>&1
  fi
}

newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ]; }

check_updates() {
  PATH="@checkPath@:$PATH"
  state="${XDG_CACHE_HOME:-$HOME/.cache}/herdr-nix"
  mkdir -p "$state" || return
  # At most every 6 hours, and never for HERDR_NIX_NO_UPDATE_CHECK=1.
  [ "${HERDR_NIX_NO_UPDATE_CHECK:-}" = 1 ] && return
  [ -n "$(find "$state/checked" -mmin -360 2>/dev/null)" ] && return
  touch "$state/checked"

  app="$(curl -fsSL --max-time 20 https://releases.herdr.dev/app/latest.json | jq -r '.version // empty')"
  core="$(curl -fsSL --max-time 20 https://releases.herdr.dev/core/latest.json | jq -r '.version // empty')"
  news=""
  [ -n "$app" ] && newer "$app" "@appVersion@" && news="Herdr $app (installed @appVersion@)"
  [ -n "$core" ] && newer "$core" "@coreVersion@" &&
    news="${news:+$news, }herdr-core $core (installed @coreVersion@)"
  [ -n "$news" ] || return
  # Once per set of releases.
  [ "$(cat "$state/notified" 2>/dev/null)" = "$news" ] && return
  printf '%s' "$news" > "$state/notified"
  notify "Herdr update available" "$news. Update it through Nix: nix flake update, then rebuild."
}

(check_updates) &
exec "@exe@" "$@"
