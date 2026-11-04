#!@shell@
# cua-driver's telemetry and background update check are on by default. Turn
# them off unless the environment or cua-driver's own config.json says
# otherwise (`cua-driver telemetry enable` writes telemetry_enabled; the
# telemetry one moves with CUA_DRIVER_TELEMETRY_HOME, the update check reads
# ~/.cua-driver's). DO_NOT_TRACK and the shared Cua switches are read by
# cua-driver itself.
has_key() { [ -r "$1/config.json" ] && grep -q "\"$2\"" "$1/config.json"; }
if [ -z "${DO_NOT_TRACK+x}${CUA_DRIVER_RS_TELEMETRY_ENABLED+x}${CUA_TELEMETRY_ENABLED+x}${CUA_TELEMETRY+x}" ] &&
  ! has_key "${CUA_DRIVER_TELEMETRY_HOME:-${HOME:-}/.cua-driver}" telemetry_enabled; then
  export CUA_DRIVER_RS_TELEMETRY_ENABLED=0
fi
if [ -z "${CUA_DRIVER_RS_UPDATE_CHECK+x}" ] && ! has_key "${HOME:-}/.cua-driver" update_check_enabled; then
  export CUA_DRIVER_RS_UPDATE_CHECK=0
fi

# `update --apply` runs upstream's installer, which installs another copy
# outside the Nix store. Updates come from Nix.
update=
for arg in "$@"; do
  case $arg in
    update) update=1 ;;
    --apply) if [ -n "$update" ]; then
      echo "cua-driver: this copy is installed with Nix; update it through Nix, not \`update --apply\`." >&2
      exit 1
    fi ;;
  esac
done

exec @driver@ "$@"
