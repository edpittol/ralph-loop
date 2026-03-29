#!/usr/bin/env bats

load helpers/setup

@test "stop-hook allows exit when no state file exists" {
  cd "$TEST_TEMP_DIR"
  echo '{"session_id":"s1","transcript_path":"/dev/null"}' | \
    run bash "$SCRIPTS_DIR/stop-hook.sh"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "stop-hook blocks exit and increments iteration" {
  cd "$TEST_TEMP_DIR"
  create_test_state_file "$TEST_TEMP_DIR" 1 10

  TRANSCRIPT="$TEST_TEMP_DIR/transcript.jsonl"
  create_test_transcript "$TRANSCRIPT" "Working on story US-001"

  result=$(echo "{\"session_id\":\"test-session-123\",\"transcript_path\":\"$TRANSCRIPT\"}" | \
    bash "$SCRIPTS_DIR/stop-hook.sh")

  # Should output JSON with decision: block
  echo "$result" | jq -e '.decision == "block"'

  # Should have incremented iteration to 2
  grep -q "iteration: 2" "$TEST_TEMP_DIR/.claude/ralph-state.local.md"
}

@test "stop-hook allows exit when completion promise detected" {
  cd "$TEST_TEMP_DIR"
  create_test_state_file "$TEST_TEMP_DIR" 1 10

  TRANSCRIPT="$TEST_TEMP_DIR/transcript.jsonl"
  create_test_transcript "$TRANSCRIPT" "All done! <promise>COMPLETE</promise>"

  echo "{\"session_id\":\"test-session-123\",\"transcript_path\":\"$TRANSCRIPT\"}" | \
    run bash "$SCRIPTS_DIR/stop-hook.sh"

  [[ "$status" -eq 0 ]]
  # State file should be cleaned up
  [[ ! -f "$TEST_TEMP_DIR/.claude/ralph-state.local.md" ]]
}

@test "stop-hook allows exit when max iterations reached" {
  cd "$TEST_TEMP_DIR"
  create_test_state_file "$TEST_TEMP_DIR" 5 5

  TRANSCRIPT="$TEST_TEMP_DIR/transcript.jsonl"
  create_test_transcript "$TRANSCRIPT" "Still working"

  echo "{\"session_id\":\"test-session-123\",\"transcript_path\":\"$TRANSCRIPT\"}" | \
    run bash "$SCRIPTS_DIR/stop-hook.sh"

  [[ "$status" -eq 0 ]]
  [[ ! -f "$TEST_TEMP_DIR/.claude/ralph-state.local.md" ]]
}

@test "stop-hook respects session isolation" {
  cd "$TEST_TEMP_DIR"
  create_test_state_file "$TEST_TEMP_DIR" 1 10

  TRANSCRIPT="$TEST_TEMP_DIR/transcript.jsonl"
  create_test_transcript "$TRANSCRIPT" "Working"

  # Different session_id should allow exit
  echo "{\"session_id\":\"different-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | \
    run bash "$SCRIPTS_DIR/stop-hook.sh"

  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
  # State file should NOT be cleaned up
  [[ -f "$TEST_TEMP_DIR/.claude/ralph-state.local.md" ]]
}

@test "stop-hook handles corrupted iteration field" {
  cd "$TEST_TEMP_DIR"
  mkdir -p "$TEST_TEMP_DIR/.claude"
  cat > "$TEST_TEMP_DIR/.claude/ralph-state.local.md" <<EOF
---
active: true
iteration: abc
session_id: test-session-123
max_iterations: 10
completion_promise: "COMPLETE"
---

Test prompt
EOF

  TRANSCRIPT="$TEST_TEMP_DIR/transcript.jsonl"
  create_test_transcript "$TRANSCRIPT" "Working"

  echo "{\"session_id\":\"test-session-123\",\"transcript_path\":\"$TRANSCRIPT\"}" | \
    run bash "$SCRIPTS_DIR/stop-hook.sh"

  [[ "$status" -eq 0 ]]
  # State file should be cleaned up on corruption
  [[ ! -f "$TEST_TEMP_DIR/.claude/ralph-state.local.md" ]]
}

@test "stop-hook handles missing transcript" {
  cd "$TEST_TEMP_DIR"
  create_test_state_file "$TEST_TEMP_DIR" 1 10

  echo "{\"session_id\":\"test-session-123\",\"transcript_path\":\"/nonexistent/path\"}" | \
    run bash "$SCRIPTS_DIR/stop-hook.sh"

  [[ "$status" -eq 0 ]]
  [[ ! -f "$TEST_TEMP_DIR/.claude/ralph-state.local.md" ]]
}
