#!/usr/bin/env bash
# Follow upstream's published npm release and versioned installer lockfile.
set -euo pipefail
cd "$(dirname "$0")"
exec python3 update.py "$@"
