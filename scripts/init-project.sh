#!/bin/bash
# Initialize ralph state directory for a project.
# Usage: init-project.sh <project-path>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: init-project.sh <project-path>" >&2
  exit 1
fi

PROJECT_PATH="$(readlink -f "$1")"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Error: Project path does not exist: $PROJECT_PATH" >&2
  exit 1
fi

STATE_DIR="$(get_state_dir "$PROJECT_PATH")"

mkdir -p "$STATE_DIR"

if [[ ! -f "$STATE_DIR/prd.json" ]]; then
  cp "$SKILL_DIR/references/prd-template.json" "$STATE_DIR/prd.json"
  echo "Created: $STATE_DIR/prd.json"
else
  echo "Exists:  $STATE_DIR/prd.json"
fi

if [[ ! -f "$STATE_DIR/progress.txt" ]]; then
  cat > "$STATE_DIR/progress.txt" <<EOF
# Ralph progress log
Started: $(date)
---
EOF
  echo "Created: $STATE_DIR/progress.txt"
else
  echo "Exists:  $STATE_DIR/progress.txt"
fi

echo ""
echo "Ralph state directory: $STATE_DIR"
