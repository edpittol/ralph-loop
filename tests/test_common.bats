#!/usr/bin/env bats

load helpers/setup

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  export CLAUDE_CONFIG_DIR="$TEST_TEMP_DIR/config"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects"
  source "$SCRIPTS_DIR/common.sh"
}

teardown() {
  if [[ -d "${TEST_TEMP_DIR:-}" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

@test "encode_path converts absolute path to dashed format" {
  result="$(encode_path "/home/pittol/Sites/hardwork")"
  [[ "$result" == "-home-pittol-Sites-hardwork" ]]
}

@test "encode_path handles single component" {
  result="$(encode_path "/tmp")"
  [[ "$result" == "-tmp" ]]
}

@test "encode_path handles deep paths" {
  result="$(encode_path "/home/user/a/b/c/d")"
  [[ "$result" == "-home-user-a-b-c-d" ]]
}

@test "get_config_dir returns CLAUDE_CONFIG_DIR" {
  export CLAUDE_CONFIG_DIR="/tmp/test-config"
  result="$(get_config_dir)"
  [[ "$result" == "/tmp/test-config" ]]
}

@test "get_config_dir fails when CLAUDE_CONFIG_DIR is not set" {
  unset CLAUDE_CONFIG_DIR
  run get_config_dir
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"CLAUDE_CONFIG_DIR"* ]]
}

@test "get_state_dir returns correct path" {
  result="$(get_state_dir "/home/pittol/Sites/hardwork")"
  [[ "$result" == "$CLAUDE_CONFIG_DIR/projects/-home-pittol-Sites-hardwork/ralph" ]]
}

@test "SKILL_DIR is set and points to the skill root" {
  [[ -n "$SKILL_DIR" ]]
  [[ -f "$SKILL_DIR/SKILL.md" ]]
}
