#!/usr/bin/env bats

load helpers/setup

@test "init-project creates state directory" {
  create_test_repo "$TEST_TEMP_DIR/myproject"

  run bash "$SCRIPTS_DIR/init-project.sh" "$TEST_TEMP_DIR/myproject"
  [[ "$status" -eq 0 ]]

  state_dir="$CLAUDE_CONFIG_DIR/projects/$(source "$SCRIPTS_DIR/common.sh" && encode_path "$TEST_TEMP_DIR/myproject")/ralph"
  [[ -d "$state_dir" ]]
}

@test "init-project creates prd.json from template" {
  create_test_repo "$TEST_TEMP_DIR/myproject"

  bash "$SCRIPTS_DIR/init-project.sh" "$TEST_TEMP_DIR/myproject"

  state_dir="$CLAUDE_CONFIG_DIR/projects/$(source "$SCRIPTS_DIR/common.sh" && encode_path "$TEST_TEMP_DIR/myproject")/ralph"
  [[ -f "$state_dir/prd.json" ]]

  # Validate it's valid JSON with expected fields
  jq -e '.branchName' "$state_dir/prd.json" > /dev/null
  jq -e '.userStories' "$state_dir/prd.json" > /dev/null
}

@test "init-project creates progress.txt with header" {
  create_test_repo "$TEST_TEMP_DIR/myproject"

  bash "$SCRIPTS_DIR/init-project.sh" "$TEST_TEMP_DIR/myproject"

  state_dir="$CLAUDE_CONFIG_DIR/projects/$(source "$SCRIPTS_DIR/common.sh" && encode_path "$TEST_TEMP_DIR/myproject")/ralph"
  [[ -f "$state_dir/progress.txt" ]]
  grep -q "Ralph progress log" "$state_dir/progress.txt"
}

@test "init-project does not overwrite existing prd.json" {
  create_test_repo "$TEST_TEMP_DIR/myproject"

  state_dir="$CLAUDE_CONFIG_DIR/projects/$(source "$SCRIPTS_DIR/common.sh" && encode_path "$TEST_TEMP_DIR/myproject")/ralph"
  mkdir -p "$state_dir"
  echo '{"custom": true}' > "$state_dir/prd.json"

  bash "$SCRIPTS_DIR/init-project.sh" "$TEST_TEMP_DIR/myproject"

  # Should still have the custom content
  jq -e '.custom' "$state_dir/prd.json" > /dev/null
}

@test "init-project does not overwrite existing progress.txt" {
  create_test_repo "$TEST_TEMP_DIR/myproject"

  state_dir="$CLAUDE_CONFIG_DIR/projects/$(source "$SCRIPTS_DIR/common.sh" && encode_path "$TEST_TEMP_DIR/myproject")/ralph"
  mkdir -p "$state_dir"
  echo "existing progress" > "$state_dir/progress.txt"

  bash "$SCRIPTS_DIR/init-project.sh" "$TEST_TEMP_DIR/myproject"

  grep -q "existing progress" "$state_dir/progress.txt"
}

@test "init-project fails for non-existent path" {
  run bash "$SCRIPTS_DIR/init-project.sh" "$TEST_TEMP_DIR/nonexistent"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"does not exist"* ]]
}

@test "init-project fails with no arguments" {
  run bash "$SCRIPTS_DIR/init-project.sh"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Usage"* ]]
}
