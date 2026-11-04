#!/usr/bin/env bash
# Runs pkgs/*/update.sh and lands each update that builds: committed to main,
# or proposed as a pull request (branch update/<name>) for the packages in
# $REVIEW. Run by update.yml, once per $UPDATE_SYSTEM:
#   x86_64-linux    every package that builds there, and nixpkgs weekly
#   aarch64-darwin  the packages that build only on macOS
# so every update is built before it lands. $PACKAGES limits the run to the
# named packages (nixpkgs for the nixpkgs input). Needs gh, git, jq and nix.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${UPDATE_SYSTEM:?}"
REVIEW="${REVIEW:-}"
PACKAGES="${PACKAGES:-}"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

attrs() { nix eval --json ".#packages.$1" --apply builtins.attrNames | jq -r '.[]'; }
linux="$(attrs x86_64-linux)"
darwin="$(attrs aarch64-darwin)"

# Whether <name> is this system's to update: Linux takes everything that
# builds there, macOS what builds nowhere else.
ours() {
  local name=$1
  case $UPDATE_SYSTEM in
    x86_64-linux) grep -qxF -- "$name" <<<"$linux" ;;
    aarch64-darwin) grep -qxF -- "$name" <<<"$darwin" && ! grep -qxF -- "$name" <<<"$linux" ;;
    *) echo "unknown UPDATE_SYSTEM $UPDATE_SYSTEM" >&2; exit 1 ;;
  esac
}

# The path an update of <name> changes: pkgs/<name>, or flake.lock for the
# nixpkgs input.
paths() { if [ "$1" = nixpkgs ]; then echo flake.lock; else echo "pkgs/$1"; fi; }

# Puts a checked update on update/<name>, on top of main, opens (or retitles)
# its pull request, and starts check.yml there for the other systems, which
# merges it once they all pass: this token's pushes start no workflow
# themselves.
propose() {
  local name=$1 title=$2 branch="update/$1" commit
  git add -A -- "$(paths "$name")"
  git commit -qm "$title"
  commit="$(git rev-parse HEAD)"
  git reset -q --hard HEAD~1
  git switch -q --detach origin/main
  git cherry-pick "$commit" >/dev/null
  git push -qf origin "HEAD:refs/heads/$branch"
  git switch -q main
  if [ "$(gh pr view "$branch" --json state -q .state 2>/dev/null)" = OPEN ]; then
    gh pr edit "$branch" --title "$title" >/dev/null
  else
    gh pr create --head "$branch" --base main --title "$title" \
      --body "Automated update of \`$name\`, built by the Update workflow on $UPDATE_SYSTEM; check.yml runs the other systems and merges this pull request once all of them pass." ||
      { echo "::error::$name: could not open a pull request (Settings → Actions → allow GitHub Actions to create pull requests)"; failed=1; }
  fi
  gh workflow run check.yml --ref "$branch" ||
    { echo "::error::$name: could not start check.yml on $branch"; failed=1; }
}

# Whether update/<name> already holds exactly this update.
proposed() {
  git fetch -q origin "update/$1" 2>/dev/null || return 1
  git diff --quiet FETCH_HEAD -- "$(paths "$1")" &&
    [ -z "$(git ls-files --others --exclude-standard -- "$(paths "$1")")" ]
}

# Drops what a failed update left behind.
discard() { git checkout -q -- "$(paths "$1")"; git clean -fdq -- "$(paths "$1")"; }

# Checks the flake with <name>'s update, then commits it to main, or proposes
# it when it needs review. Sets failed=1 when it fails.
land() {
  local name=$1 title=$2 review=$3
  if $review && proposed "$name"; then
    echo "$name: already proposed on update/$name"
    discard "$name"; return 0
  fi
  # Build every package of this system, so packages built on this one (they
  # take it as an argument) are checked too, and this one itself if checks
  # leave it out (a rolling build). --keep-going reports every failure.
  if ! nix flake check --all-systems --keep-going -L ||
    { [ "$name" != nixpkgs ] &&
      nix eval --quiet ".#packages.$UPDATE_SYSTEM.\"$name\".drvPath" >/dev/null 2>&1 &&
      ! nix build --no-link -L ".#packages.$UPDATE_SYSTEM.\"$name\""; }; then
    echo "::error::$name failed to build after update"
    discard "$name"; failed=1; return 0
  fi
  if $review; then
    propose "$name" "$title"
  else
    git add -A -- "$(paths "$name")"
    git commit -qm "$title"
  fi
}

failed=0
for script in pkgs/*/update.sh; do
  name="$(basename "$(dirname "$script")")"
  if [ -n "$PACKAGES" ] && [[ " $PACKAGES " != *" $name "* ]]; then continue; fi
  ours "$name" || continue
  # A failing script (upstream down, unexpected data) skips only its own
  # package.
  if ! "$script"; then
    echo "::error::$name: update.sh failed"
    discard "$name"; failed=1; continue
  fi
  [ -n "$(git status --porcelain -- "pkgs/$name")" ] || continue
  version="$(jq -r .version "pkgs/$name/hashes.json" 2>/dev/null || echo new)"
  review=false
  [[ " $REVIEW " != *" $name "* ]] || review=true
  land "$name" "Update $name to v$version" "$review"
done

# nixpkgs, which every package's libraries and tools come from: weekly
# (Monday's first run) or when asked for, always through a pull request, since
# it touches every package. Linux only; check.yml builds the rest.
if [ "$UPDATE_SYSTEM" = x86_64-linux ] &&
  { { [ -z "$PACKAGES" ] && [ "$(date -u +%u%H)" = 103 ]; } ||
    [[ " $PACKAGES " == *" nixpkgs "* ]]; }; then
  if nix flake update nixpkgs; then
    if [ -n "$(git status --porcelain -- flake.lock)" ]; then
      rev="$(jq -r .nodes.nixpkgs.locked.rev flake.lock)"
      land nixpkgs "Update nixpkgs to ${rev:0:12}" true
    fi
  else
    echo "::error::nixpkgs: nix flake update failed"
    discard nixpkgs; failed=1
  fi
fi

git pull -q --rebase origin main
git push -q origin HEAD:main
exit "$failed"
