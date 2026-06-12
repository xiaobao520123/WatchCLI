#!/usr/bin/env bash
# Common env setup sourced by other scripts.
# Strips inherited GIT_CONFIG_* env vars that block SwiftPM dependency fetches
# in some shell environments.
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 \
      GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1 \
      GIT_CONFIG_KEY_2 GIT_CONFIG_VALUE_2

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
