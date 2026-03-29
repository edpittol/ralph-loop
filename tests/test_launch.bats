#!/usr/bin/env bats

load helpers/setup

# launch.sh calls `exec claude` at the end, so we mock it for testing.
# These tests validate everything up to the launch point.

_shared_setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export CLAUDE_CONFIG_DIR="$TEST_TEMP_DIR/config"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects"
}

setup() {
  _shared_setup

  # Create a test repo
  create_test_repo "$TEST_TEMP_DIR/myproject"

  # Compute state dir and create PRD
  source "$SCRIPTS_DIR/common.sh"
  TEST_STATE_DIR="$(get_state_dir "$TEST_TEMP_DIR/myproject")"
  create_test_prd "$TEST_STATE_DIR" "ralph/test-feature"
}

teardown() {
  if [[ -d "${TEST_TEMP_DIR:-}" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

@test "launch fails when no project path given" {
  run bash "$SCRIPTS_DIR/launch.sh"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "launch fails when project is not a git repo" {
  mkdir -p "$TEST_TEMP_DIR/not-a-repo"
  run bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/not-a-repo"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"not a git repository"* ]]
}

@test "launch fails when prd.json is missing" {
  rm "$TEST_STATE_DIR/prd.json"
  run bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/myproject"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"PRD not found"* ]]
}

@test "launch fails when branchName is empty" {
  echo '{"branchName": "", "userStories": []}' > "$TEST_STATE_DIR/prd.json"
  run bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/myproject"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"branchName"* ]]
}

@test "launch creates worktree directory" {
  # Mock claude so we don't actually launch it
  mkdir -p "$TEST_TEMP_DIR/bin"
  cat > "$TEST_TEMP_DIR/bin/claude" <<'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "$TEST_TEMP_DIR/bin/claude"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"

  bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/myproject" --max-iterations 1

  [[ -d "$TEST_STATE_DIR/worktrees/ralph-test-feature" ]]
}

@test "launch creates settings.local.json with stop-hook" {
  mkdir -p "$TEST_TEMP_DIR/bin"
  cat > "$TEST_TEMP_DIR/bin/claude" <<'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "$TEST_TEMP_DIR/bin/claude"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"

  bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/myproject" --max-iterations 1

  WORKTREE="$TEST_STATE_DIR/worktrees/ralph-test-feature"
  [[ -f "$WORKTREE/.claude/settings.local.json" ]]
  jq -e '.hooks.Stop' "$WORKTREE/.claude/settings.local.json" > /dev/null
  grep -q "stop-hook.sh" "$WORKTREE/.claude/settings.local.json"
}

@test "launch creates ralph-state.local.md with correct frontmatter" {
  mkdir -p "$TEST_TEMP_DIR/bin"
  cat > "$TEST_TEMP_DIR/bin/claude" <<'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "$TEST_TEMP_DIR/bin/claude"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"

  bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/myproject" --max-iterations 5

  WORKTREE="$TEST_STATE_DIR/worktrees/ralph-test-feature"
  [[ -f "$WORKTREE/.claude/ralph-state.local.md" ]]
  grep -q "iteration: 1" "$WORKTREE/.claude/ralph-state.local.md"
  grep -q "max_iterations: 5" "$WORKTREE/.claude/ralph-state.local.md"
  grep -q "completion_promise" "$WORKTREE/.claude/ralph-state.local.md"
}

@test "launch substitutes placeholders in agent prompt" {
  mkdir -p "$TEST_TEMP_DIR/bin"
  cat > "$TEST_TEMP_DIR/bin/claude" <<'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "$TEST_TEMP_DIR/bin/claude"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"

  bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/myproject" --max-iterations 1

  WORKTREE="$TEST_STATE_DIR/worktrees/ralph-test-feature"
  STATE_FILE="$WORKTREE/.claude/ralph-state.local.md"

  # Placeholders should be replaced with actual paths
  ! grep -q '{{PRD_PATH}}' "$STATE_FILE"
  ! grep -q '{{PROGRESS_PATH}}' "$STATE_FILE"
  grep -q "prd.json" "$STATE_FILE"
  grep -q "progress.txt" "$STATE_FILE"
}

@test "launch archives previous run on branch change" {
  mkdir -p "$TEST_TEMP_DIR/bin"
  cat > "$TEST_TEMP_DIR/bin/claude" <<'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "$TEST_TEMP_DIR/bin/claude"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"

  # Create a .last-branch with a different branch
  echo "ralph/old-feature" > "$TEST_STATE_DIR/.last-branch"
  echo "old progress" > "$TEST_STATE_DIR/progress.txt"

  bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/myproject" --max-iterations 1

  # Archive should exist
  [[ -d "$TEST_STATE_DIR/archive" ]]
  archive_dir=$(find "$TEST_STATE_DIR/archive" -maxdepth 1 -type d -name "*old-feature" | head -1)
  [[ -n "$archive_dir" ]]
  [[ -f "$archive_dir/prd.json" ]]
  [[ -f "$archive_dir/progress.txt" ]]
}
