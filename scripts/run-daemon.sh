#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_env.sh"
cd "$REPO_ROOT"
exec swift run watchcli-daemon "$@"
