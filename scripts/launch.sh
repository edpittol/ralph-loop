#!/bin/bash
# Global Ralph - AFK entrypoint
# Sets up worktree, state files, and launches Claude in a loop.
# Usage: launch.sh <project-path> [--max-iterations N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Parse arguments
PROJECT_PATH=""
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --max-iterations)
      if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations requires a positive integer" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    *)
      if [[ -z "$PROJECT_PATH" ]]; then
        PROJECT_PATH="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$PROJECT_PATH" ]]; then
  echo "Usage: launch.sh <project-path> [--max-iterations N]" >&2
  exit 1
fi

PROJECT_PATH="$(readlink -f "$PROJECT_PATH")"

if [[ ! -d "$PROJECT_PATH/.git" ]] && ! git -C "$PROJECT_PATH" rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: $PROJECT_PATH is not a git repository" >&2
  exit 1
fi

STATE_DIR="$(get_state_dir "$PROJECT_PATH")"
PRD_FILE="$STATE_DIR/prd.json"
PROGRESS_FILE="$STATE_DIR/progress.txt"
LAST_BRANCH_FILE="$STATE_DIR/.last-branch"
ARCHIVE_DIR="$STATE_DIR/archive"

if [[ ! -f "$PRD_FILE" ]]; then
  echo "Error: PRD not found at $PRD_FILE" >&2
  echo "Run init-project.sh first, or use /global-ralph to set up." >&2
  exit 1
fi

# Read branch name from PRD
BRANCH_NAME=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
if [[ -z "$BRANCH_NAME" ]]; then
  echo "Error: no branchName found in $PRD_FILE" >&2
  exit 1
fi

# Archive previous run if branch changed
if [[ -f "$LAST_BRANCH_FILE" ]]; then
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  if [[ -n "$LAST_BRANCH" ]] && [[ "$LAST_BRANCH" != "$BRANCH_NAME" ]]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME="${LAST_BRANCH#ralph/}"
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [[ -f "$PRD_FILE" ]] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [[ -f "$PROGRESS_FILE" ]] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "  Archived to: $ARCHIVE_FOLDER"

    # Reset progress for new branch
    cat > "$PROGRESS_FILE" <<EOF
# Ralph progress log
Started: $(date)
Branch: $BRANCH_NAME
---
EOF
  fi
fi

echo "$BRANCH_NAME" > "$LAST_BRANCH_FILE"

# Create or reuse worktree
BRANCH_SUFFIX="${BRANCH_NAME#ralph/}"
WORKTREE_DIR="$STATE_DIR/worktrees"
WORKTREE_PATH="$WORKTREE_DIR/ralph-$BRANCH_SUFFIX"

mkdir -p "$WORKTREE_DIR"

if [[ -d "$WORKTREE_PATH" ]]; then
  echo "Reusing worktree: $WORKTREE_PATH"
else
  echo "Creating worktree: $WORKTREE_PATH"
  if ! git -C "$PROJECT_PATH" worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" 2>/dev/null; then
    echo "Branch exists, checking out..."
    git -C "$PROJECT_PATH" fetch origin "$BRANCH_NAME" 2>/dev/null || true
    git -C "$PROJECT_PATH" worktree add "$WORKTREE_PATH" "$BRANCH_NAME" 2>/dev/null || \
      git -C "$PROJECT_PATH" worktree add "$WORKTREE_PATH" -B "$BRANCH_NAME" 2>/dev/null
  fi
  echo "Worktree created"
fi

# Set up worktree .claude/ directory
mkdir -p "$WORKTREE_PATH/.claude"

# Create settings with stop-hook registration
STOP_HOOK_PATH="$SCRIPT_DIR/stop-hook.sh"
sed "s|{{STOP_HOOK_PATH}}|$STOP_HOOK_PATH|g" \
  "$SKILL_DIR/references/worktree-settings.json" \
  > "$WORKTREE_PATH/.claude/settings.local.json"

# Generate agent prompt with paths substituted
AGENT_PROMPT=$(sed \
  -e "s|{{PRD_PATH}}|$PRD_FILE|g" \
  -e "s|{{PROGRESS_PATH}}|$PROGRESS_FILE|g" \
  "$SKILL_DIR/references/agent-prompt.md")

# Create ralph state file for the stop-hook
cat > "$WORKTREE_PATH/.claude/ralph-state.local.md" <<EOF
---
active: true
iteration: 1
session_id:
max_iterations: $MAX_ITERATIONS
completion_promise: "COMPLETE"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$AGENT_PROMPT
EOF

# Initialize progress if needed
if [[ ! -f "$PROGRESS_FILE" ]]; then
  cat > "$PROGRESS_FILE" <<EOF
# Ralph progress log
Started: $(date)
Branch: $BRANCH_NAME
---
EOF
fi

echo ""
echo "========================================"
echo "  Global Ralph - AFK Launch"
echo "========================================"
echo "Project:        $PROJECT_PATH"
echo "Branch:         $BRANCH_NAME"
echo "Worktree:       $WORKTREE_PATH"
echo "State dir:      $STATE_DIR"
echo "Max iterations: $MAX_ITERATIONS"
echo "========================================"
echo ""

cd "$WORKTREE_PATH"
exec claude --dangerously-skip-permissions -p "$AGENT_PROMPT"
