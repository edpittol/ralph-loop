#!/bin/bash
# Shared test fixtures and helpers for global-ralph bats tests

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="$SKILL_DIR/scripts"

# Create isolated temp directory for each test
setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export CLAUDE_CONFIG_DIR="$TEST_TEMP_DIR/config"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects"
}

# Clean up temp directory after each test
teardown() {
  if [[ -d "${TEST_TEMP_DIR:-}" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Create a minimal git repository at the given path
create_test_repo() {
  local repo_path="$1"
  mkdir -p "$repo_path"
  git -C "$repo_path" init -q
  git -C "$repo_path" commit --allow-empty -m "initial" -q
}

# Create a PRD with a single user story
create_test_prd() {
  local state_dir="$1"
  local branch_name="${2:-ralph/test-feature}"
  mkdir -p "$state_dir"
  cat > "$state_dir/prd.json" <<EOF
{
  "project": "test-project",
  "branchName": "$branch_name",
  "description": "Test PRD",
  "userStories": [
    {
      "id": "US-001",
      "title": "Test story",
      "description": "A test user story",
      "acceptanceCriteria": ["It works"],
      "priority": 1,
      "passes": false
    }
  ]
}
EOF
}

# Create a minimal ralph state file
create_test_state_file() {
  local worktree_path="$1"
  local iteration="${2:-1}"
  local max_iterations="${3:-10}"
  mkdir -p "$worktree_path/.claude"
  cat > "$worktree_path/.claude/ralph-state.local.md" <<EOF
---
active: true
iteration: $iteration
session_id: test-session-123
max_iterations: $max_iterations
completion_promise: "COMPLETE"
started_at: "2026-01-01T00:00:00Z"
---

Test prompt content
EOF
}

# Create a fake transcript with assistant messages
create_test_transcript() {
  local path="$1"
  local text="${2:-Some assistant output}"
  cat > "$path" <<EOF
{"role":"assistant","message":{"content":[{"type":"text","text":"$text"}]}}
EOF
}
