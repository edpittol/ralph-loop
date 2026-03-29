#!/bin/bash
# Shared utilities for global-ralph skill scripts

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
export SKILL_DIR

# Default completion promise for Ralph loop
DEFAULT_COMPLETION_PROMISE="COMPLETE"

# Converts an absolute path to the ccsw encoded directory name.
# Example: /home/pittol/Sites/hardwork -> -home-pittol-Sites-hardwork
encode_path() {
  local path="$1"
  echo "${path//\//-}"
}

# Returns the active ccsw profile directory from CLAUDE_CONFIG_DIR.
get_config_dir() {
  if [[ -z "${CLAUDE_CONFIG_DIR:-}" ]]; then
    echo "Error: CLAUDE_CONFIG_DIR environment variable is not set" >&2
    return 1
  fi
  echo "$CLAUDE_CONFIG_DIR"
}

# Returns the ralph state directory for a given project path.
# Example: get_state_dir /home/pittol/Sites/hardwork
#   -> {CLAUDE_CONFIG_DIR}/projects/-home-pittol-Sites-hardwork/ralph
get_state_dir() {
  local project_path="$1"
  local config_dir
  config_dir="$(get_config_dir)"
  local encoded
  encoded="$(encode_path "$project_path")"
  echo "${config_dir}/projects/${encoded}/ralph"
}
