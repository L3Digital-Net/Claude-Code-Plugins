#!/usr/bin/env bats
# Tests for the setup-shims.sh SessionStart hook. The behavioral contract
# under test is opt-in: only `shims: always` in the project's
# .claude/uv-strict-python.local.md installs the PATH shims, because direct
# agent commands are enforced by the python-command-guard PreToolUse hook and
# the shims impersonate the interpreter for every child process.

SETUP_SCRIPT="${BATS_TEST_DIRNAME}/../hooks/setup-shims.sh"

setup() {
  export CLAUDE_ENV_FILE
  CLAUDE_ENV_FILE="$(mktemp)"
  # Create a fake uv so the guard passes
  FAKE_BIN="$(mktemp -d)"
  echo '#!/usr/bin/env bash' >"$FAKE_BIN/uv"
  chmod +x "$FAKE_BIN/uv"
  export FAKE_BIN
  # Default project dir carries a Python marker, so every "no install" case
  # below proves the opt-in gate rather than the absence of a Python project.
  PROJECT_DIR="$(mktemp -d)"
  touch "$PROJECT_DIR/pyproject.toml"
  export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
  # Save original PATH
  export ORIG_PATH="$PATH"
}

teardown() {
  rm -f "$CLAUDE_ENV_FILE"
  rm -rf "$FAKE_BIN" "$PROJECT_DIR"
}

opt_in() {
  mkdir -p "${1}/.claude"
  printf -- '---\nshims: %s\n---\n' "$2" >"${1}/.claude/uv-strict-python.local.md"
}

@test "exits silently when CLAUDE_ENV_FILE is not set" {
  opt_in "$PROJECT_DIR" always
  run env -u CLAUDE_ENV_FILE PATH="${FAKE_BIN}:${ORIG_PATH}" \
    bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
}

@test "exits silently when uv is not available" {
  opt_in "$PROJECT_DIR" always
  # Remove fake uv dir from PATH; keep rest so bash/coreutils work
  local path_without_uv=""
  local IFS=:
  for dir in $ORIG_PATH; do
    [[ "$dir" == "$FAKE_BIN" ]] && continue
    # Also skip dirs with real uv
    [[ -x "$dir/uv" ]] && continue
    path_without_uv="${path_without_uv:+${path_without_uv}:}$dir"
  done
  run env PATH="$path_without_uv" CLAUDE_ENV_FILE="$CLAUDE_ENV_FILE" \
    bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  [[ ! -s "$CLAUDE_ENV_FILE" ]]
}

@test "does not install without an opt-in, even in a Python project" {
  run env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  [[ ! -s "$CLAUDE_ENV_FILE" ]]
}

@test "does not install for shims: auto" {
  opt_in "$PROJECT_DIR" auto
  run env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  [[ ! -s "$CLAUDE_ENV_FILE" ]]
}

@test "does not install for shims: never" {
  opt_in "$PROJECT_DIR" never
  run env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  [[ ! -s "$CLAUDE_ENV_FILE" ]]
}

@test "does not install when only Python markers are present" {
  rm "$PROJECT_DIR/pyproject.toml"
  touch "$PROJECT_DIR/uv.lock"
  echo '3.14' >"$PROJECT_DIR/.python-version"
  run env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  [[ ! -s "$CLAUDE_ENV_FILE" ]]
}

@test "shims: always writes the PATH export to CLAUDE_ENV_FILE" {
  opt_in "$PROJECT_DIR" always
  run env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  [[ $status -eq 0 ]]
  grep -q 'export PATH=' "$CLAUDE_ENV_FILE"
}

@test "shims: always installs in a non-Python project" {
  local empty_dir
  empty_dir="$(mktemp -d)"
  opt_in "$empty_dir" always
  env PATH="${FAKE_BIN}:${ORIG_PATH}" CLAUDE_PROJECT_DIR="$empty_dir" \
    bash "$SETUP_SCRIPT"
  grep -q 'export PATH=' "$CLAUDE_ENV_FILE"
  rm -rf "$empty_dir"
}

@test "exported shims dir is this plugin's, by absolute path" {
  opt_in "$PROJECT_DIR" always
  env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  local shims_dir line
  shims_dir="$(cd "${BATS_TEST_DIRNAME}/../hooks/shims" && pwd)"
  grep -q "$shims_dir" "$CLAUDE_ENV_FILE"
  line="$(cat "$CLAUDE_ENV_FILE")"
  [[ "$line" =~ export\ PATH=\"/ ]]
}

@test "appends to existing CLAUDE_ENV_FILE content" {
  opt_in "$PROJECT_DIR" always
  echo 'export FOO=bar' >"$CLAUDE_ENV_FILE"
  env PATH="${FAKE_BIN}:${ORIG_PATH}" bash "$SETUP_SCRIPT"
  grep -q 'export FOO=bar' "$CLAUDE_ENV_FILE"
  grep -q 'export PATH=' "$CLAUDE_ENV_FILE"
}
