#!/usr/bin/env bats
# Tests for git-function-changes.sh
# Validates git diff parsing and function change detection.

load helpers

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "non-git directory returns error field" {
    mkdir -p "$TEST_TMPDIR/no-git"
    cd "$TEST_TMPDIR/no-git"
    run "$SCRIPTS_DIR/git-function-changes.sh" "2024-01-01" "$TEST_TMPDIR/no-git"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'error' in d, 'expected error field for non-git directory'
"
}

@test "output is valid JSON with required fields" {
    mkdir -p "$TEST_TMPDIR/git-proj"
    cd "$TEST_TMPDIR/git-proj"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    # Need at least one commit for HEAD to exist
    echo "x = 1" > init.py
    git add init.py
    git commit -q -m "init"
    run "$SCRIPTS_DIR/git-function-changes.sh" "2024-01-01" "$TEST_TMPDIR/git-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
required = ['since', 'changed_functions', 'changed_files', 'total_functions_changed', 'total_files_changed']
for key in required:
    assert key in d, f'missing required field: {key}'
assert isinstance(d['changed_functions'], list)
assert isinstance(d['changed_files'], list)
"
}
