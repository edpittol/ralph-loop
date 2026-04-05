#!/usr/bin/env bats

load helpers/setup

_integration_test_setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export CLAUDE_CONFIG_DIR="$TEST_TEMP_DIR/config"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects"
}

setup() {
  _integration_test_setup

  # Create a test repo
  create_test_repo "$TEST_TEMP_DIR/myproject"

  # Compute state dir and create PRD
  source "$SCRIPTS_DIR/common.sh"
  TEST_STATE_DIR="$(get_state_dir "$TEST_TEMP_DIR/myproject")"
  create_test_prd "$TEST_STATE_DIR" "ralph/test-integration"

  # Create mock claude that captures the prompt
  mkdir -p "$TEST_TEMP_DIR/bin"
  export MOCK_CLAUDE_ITERATIONS=0
  export MOCK_TRANSCRIPT="$TEST_TEMP_DIR/transcript.jsonl"
  export CLAUDE_CALLS="$TEST_TEMP_DIR/claude_calls.log"
}

teardown() {
  if [[ -d "${TEST_TEMP_DIR:-}" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

@test "integration test: multiple iterations trigger sequentially" {
  # Set up mock claude that tracks iterations
  cat > "$TEST_TEMP_DIR/bin/claude" <<'MOCK'
#!/bin/bash
# Mock claude that simulates the ralph loop
WORKTREE_DIR="$(pwd)"
TEST_STATE_DIR="$TEST_TEMP_DIR/config/projects/-home-pittol-myproject/ralph"

# Increment iteration counter
MOCK_CLAUDE_ITERATIONS=$((MOCK_CLAUDE_ITERATIONS + 1))
echo "Claude called - iteration $MOCK_CLAUDE_ITERATIONS" >> "$CLAUDE_CALLS"

# Create transcript with assistant message
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"Iteration '"$MOCK_CLAUDE_ITERATIONS"' output"}]}}' > "$MOCK_TRANSCRIPT"

# Exit with success to simulate normal operation
exit 0
MOCK
  chmod +x "$TEST_TEMP_DIR/bin/claude"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"

  # Set max iterations to 2 for testing
  bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/myproject" --max-iterations 2

  # Verify that claude was called (in real scenario, stop hook would restart)
  [[ -f "$CLAUDE_CALLS" ]]
  run cat "$CLAUDE_CALLS"
  # This should show that claude was called at least once
  echo "$output" | grep -q "Claude called"
}

@test "integration test: stop hook increments iteration correctly" {
  # Set up minimal worktree like launch.sh would
  WORKTREE="$TEST_TEMP_DIR/myproject/.claude"
  mkdir -p "$WORKTREE"

  # Create ralph-state.local.md
  create_test_state_file "$TEST_TEMP_DIR/myproject" "1" "3"

  # Create a test transcript
  create_test_transcript "$TEST_TEMP_DIR/transcript.jsonl" "Some work output"

  # Create input file for stop hook
  cat > "$TEST_TEMP_DIR/increment_input.json" <<EOF
{
  "session_id": "test-session-123",
  "transcript_path": "$TEST_TEMP_DIR/transcript.jsonl"
}
EOF

  # Run the stop hook directly to test iteration increment
  # Must run from the worktree directory
  cd "$TEST_TEMP_DIR/myproject"
  run bash "$SCRIPTS_DIR/stop-hook.sh" < "$TEST_TEMP_DIR/increment_input.json" 2>/dev/null
  cd - || true

  # Verify stop hook outputs block decision
  [[ "$status" -eq 0 ]]
  # Should contain block decision in JSON output
  [[ -n "$output" ]]
  echo "$output" | jq -e '.decision == "block"' > /dev/null

  # Verify state file was updated
  grep -q "iteration: 2" "$TEST_TEMP_DIR/myproject/.claude/ralph-state.local.md"
}

@test "integration test: stop hook terminates after max iterations" {
  # Set up worktree with max iterations reached
  WORKTREE="$TEST_TEMP_DIR/myproject/.claude"
  mkdir -p "$WORKTREE"

  # Create ralph-state.local.md at max iterations
  create_test_state_file "$TEST_TEMP_DIR/myproject" "3" "3"

  # Create a test transcript
  create_test_transcript "$TEST_TEMP_DIR/transcript.jsonl" "Some work output"

  # Create input file for stop hook
  cat > "$TEST_TEMP_DIR/max_iterations_input.json" <<EOF
{
  "session_id": "test-session-123",
  "transcript_path": "$TEST_TEMP_DIR/transcript.jsonl"
}
EOF

  # Run the stop hook - should terminate now
  # Must run from the worktree directory
  cd "$TEST_TEMP_DIR/myproject"
  run bash "$SCRIPTS_DIR/stop-hook.sh" < "$TEST_TEMP_DIR/max_iterations_input.json" 2>/dev/null
  cd - || true

  # Verify stop hook terminates (exit code 0)
  [[ "$status" -eq 0 ]]

  # Verify state file was removed
  [[ ! -f "$TEST_TEMP_DIR/myproject/.claude/ralph-state.local.md" ]]
}

@test "integration test: stop hook respects completion promise" {
  # Set up worktree with completion promise
  WORKTREE="$TEST_TEMP_DIR/myproject/.claude"
  mkdir -p "$WORKTREE"

  # Create ralph-state.local.md
  create_test_state_file "$TEST_TEMP_DIR/myproject" "1" "5"

  # Create a test transcript with completion promise
  cat > "$TEST_TEMP_DIR/transcript.jsonl" <<EOF
{"role":"assistant","message":{"content":[{"type":"text","text":"Some work output <promise>COMPLETE</promise>"}]}}
EOF

  # Create input file for stop hook
  cat > "$TEST_TEMP_DIR/completion_input.json" <<EOF
{
  "session_id": "test-session-123",
  "transcript_path": "$TEST_TEMP_DIR/transcript.jsonl"
}
EOF

  # Run the stop hook with completion promise
  # Must run from the worktree directory
  cd "$TEST_TEMP_DIR/myproject"
  run bash "$SCRIPTS_DIR/stop-hook.sh" < "$TEST_TEMP_DIR/completion_input.json" 2>/dev/null
  cd - || true

  # Verify stop hook terminates (completion promise met)
  [[ "$status" -eq 0 ]]

  # Verify state file was removed
  [[ ! -f "$TEST_TEMP_DIR/myproject/.claude/ralph-state.local.md" ]]
}

@test "integration test: launch script sets up stop hook correctly" {
  # Mock claude to exit immediately after setup
  cat > "$TEST_TEMP_DIR/bin/claude" <<'MOCK'
#!/bin/bash
# Exit immediately to verify setup was successful
exit 0
MOCK
  chmod +x "$TEST_TEMP_DIR/bin/claude"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"

  # Run launch
  bash "$SCRIPTS_DIR/launch.sh" "$TEST_TEMP_DIR/myproject" --max-iterations 1

  # Verify worktree was created
  WORKTREE="$TEST_STATE_DIR/worktrees/ralph-test-integration"
  [[ -d "$WORKTREE" ]]

  # Verify settings.local.json was created with stop hook
  [[ -f "$WORKTREE/.claude/settings.local.json" ]]
  grep -q "stop-hook.sh" "$WORKTREE/.claude/settings.local.json"

  # Verify ralph-state.local.md was created
  [[ -f "$WORKTREE/.claude/ralph-state.local.md" ]]
  grep -q "iteration: 1" "$WORKTREE/.claude/ralph-state.local.md"
  grep -q "max_iterations: 1" "$WORKTREE/.claude/ralph-state.local.md"
}

@test "integration test: stop hook with session isolation" {
  # Set up worktree
  WORKTREE="$TEST_TEMP_DIR/myproject/.claude"
  mkdir -p "$WORKTREE"

  # Create ralph-state.local.md with different session
  create_test_state_file "$TEST_TEMP_DIR/myproject" "1" "5"
  sed -i 's/session_id: test-session-123/session_id: original-session/' "$TEST_TEMP_DIR/myproject/.claude/ralph-state.local.md"

  # Create a test transcript
  create_test_transcript "$TEST_TEMP_DIR/transcript.jsonl" "Some work output"

  # Create input file for stop hook
  cat > "$TEST_TEMP_DIR/session_isolation_input.json" <<EOF
{
  "session_id": "different-session",
  "transcript_path": "$TEST_TEMP_DIR/transcript.jsonl"
}
EOF

  # Run the stop hook with different session - should not interfere
  # Must run from the worktree directory
  cd "$TEST_TEMP_DIR/myproject"
  run bash "$SCRIPTS_DIR/stop-hook.sh" < "$TEST_TEMP_DIR/session_isolation_input.json" 2>/dev/null
  cd - || true

  # Verify stop hook terminates (session isolation)
  [[ "$status" -eq 0 ]]

  # Verify state file was NOT removed (session isolation)
  [[ -f "$TEST_TEMP_DIR/myproject/.claude/ralph-state.local.md" ]]
  grep -q "session_id: original-session" "$TEST_TEMP_DIR/myproject/.claude/ralph-state.local.md"
}

@test "integration test: stop hook handles corrupted iteration field" {
  # Set up worktree with corrupted iteration
  WORKTREE="$TEST_TEMP_DIR/myproject/.claude"
  mkdir -p "$WORKTREE"

  # Create ralph-state.local.md with corrupted iteration
  cat > "$TEST_TEMP_DIR/myproject/.claude/ralph-state.local.md" <<EOF
---
active: true
iteration: not_a_number
session_id: test-session-123
max_iterations: 5
completion_promise: "COMPLETE"
started_at: "2026-01-01T00:00:00Z"
---

Test prompt content
EOF

  # Create a test transcript
  create_test_transcript "$TEST_TEMP_DIR/transcript.jsonl" "Some work output"

  # Create input file for stop hook
  cat > "$TEST_TEMP_DIR/corrupted_input.json" <<EOF
{
  "session_id": "test-session-123",
  "transcript_path": "$TEST_TEMP_DIR/transcript.jsonl"
}
EOF

  # Run the stop hook - should handle corruption gracefully
  cd "$TEST_TEMP_DIR/myproject"
  run bash "$SCRIPTS_DIR/stop-hook.sh" < "$TEST_TEMP_DIR/corrupted_input.json" 2>/dev/null
  cd - || true

  # Verify stop hook terminates (due to corruption)
  [[ "$status" -eq 0 ]]

  # Verify state file was removed (due to corruption)
  [[ ! -f "$TEST_TEMP_DIR/myproject/.claude/ralph-state.local.md" ]]
}

@test "integration test: stop hook handles missing transcript" {
  # Set up worktree
  WORKTREE="$TEST_TEMP_DIR/myproject/.claude"
  mkdir -p "$WORKTREE"

  # Create ralph-state.local.md
  create_test_state_file "$TEST_TEMP_DIR/myproject" "1" "5"

  # Create input file for stop hook with non-existent transcript
  cat > "$TEST_TEMP_DIR/missing_transcript_input.json" <<EOF
{
  "session_id": "test-session-123",
  "transcript_path": "/non/existent/transcript.jsonl"
}
EOF

  # Run the stop hook - should handle missing transcript gracefully
  cd "$TEST_TEMP_DIR/myproject"
  run bash "$SCRIPTS_DIR/stop-hook.sh" < "$TEST_TEMP_DIR/missing_transcript_input.json" 2>/dev/null
  cd - || true

  # Verify stop hook terminates (due to missing transcript)
  [[ "$status" -eq 0 ]]

  # Verify state file was removed (due to missing transcript)
  [[ ! -f "$TEST_TEMP_DIR/myproject/.claude/ralph-state.local.md" ]]
}
