#!/usr/bin/env bash
# Follow official stable Node 24 LTS releases; Python standard library only.
set -euo pipefail
cd "$(dirname "$0")"
exec python3 update.py "$@"
