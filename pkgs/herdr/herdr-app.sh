#!@shell@
# Starts Herdr from the Nix store. The app's own updater would download a
# release it can't install over the read-only store, so point it at a copy of
# the pinned release manifests (it then reports itself up to date), and leave
# telling about newer releases to herdr-update-check.

export HERDR_RELEASES_URL="file://@releases@"
# The app downloads with curl and looks for herdr-core on PATH. Appended, so
# the terminals it opens keep the user's own tools first.
export PATH="${PATH:+$PATH:}@appPath@"

"@out@/bin/herdr-update-check" >/dev/null 2>&1 &
exec "@exe@" "$@"
