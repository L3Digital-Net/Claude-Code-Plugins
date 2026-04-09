#!/usr/bin/env bats
load bats-helpers

setup() {
    setup_test_env
    export REAL_HOME="$HOME"
    export HOME="$TEST_TMPDIR/fakehome"
    mkdir -p "$HOME/.claude"
}

teardown() {
    export HOME="$REAL_HOME"
    teardown_test_env
}

@test "nonexistent snapshot dir: returns empty actions" {
    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$TEST_TMPDIR/no-such-snapshot" settings
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.actions | length')" = "0" ]
}

@test "--dry-run mode: reports actions but doesn't write" {
    # Set up a snapshot with a settings file
    local snap="$TEST_TMPDIR/snapshot"
    mkdir -p "$snap/claude"
    echo '{"test": true}' > "$snap/claude/settings.json"
    # Make snapshot file newer than local
    touch -t 203001010000 "$snap/claude/settings.json"

    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$snap" settings --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.dry_run')" = "true" ]

    # The action should be reported (created or updated)
    local action_count
    action_count=$(echo "$output" | jq '.actions | length')
    [ "$action_count" -ge 1 ]

    # But the file should NOT exist at destination (since no pre-existing file)
    [ ! -f "$HOME/.claude/settings.json" ]
}

@test "settings category: copies files from snapshot to target" {
    # Set up local file (older)
    echo '{"old": true}' > "$HOME/.claude/settings.json"
    touch -t 202001010000 "$HOME/.claude/settings.json"

    # Set up snapshot with newer file
    local snap="$TEST_TMPDIR/snapshot"
    mkdir -p "$snap/claude"
    echo '{"new": true}' > "$snap/claude/settings.json"
    touch -t 203001010000 "$snap/claude/settings.json"

    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$snap" settings
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.category')" = "settings" ]

    # File should have been updated
    local content
    content=$(cat "$HOME/.claude/settings.json")
    [[ "$content" == *'"new"'* ]]

    # Summary should show updated count
    [ "$(echo "$output" | jq '.summary.updated')" -ge 1 ]
}
