#!/usr/bin/env bash
# Follow upstream's published npm release and versioned installer lockfile,
# with overrides.json applied. Needs python3 and nix (for npm, from this
# flake's nodejs-24-lts).
set -euo pipefail
cd "$(dirname "$0")"
exec nix shell ../..#nodejs-24-lts --command python3 update.py "$@"
