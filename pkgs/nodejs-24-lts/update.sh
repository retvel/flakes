#!/usr/bin/env bash
# Follow official stable Node 24 LTS releases. Needs python3 (standard
# library only) and gpgv.
set -euo pipefail
cd "$(dirname "$0")"
exec python3 update.py "$@"
