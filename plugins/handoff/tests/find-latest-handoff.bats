#!/usr/bin/env bats
load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "empty directory returns found=false" {
    mkdir -p "$TEST_TMPDIR/empty-handoffs"
    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/empty-handoffs"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "false" ]
}

@test "directory with handoff file returns found=true with metadata" {
    mkdir -p "$TEST_TMPDIR/handoffs"
    cat > "$TEST_TMPDIR/handoffs/handoff-2026-04-09-120000.md" << 'EOF'
# Test Handoff Task

**Machine:** testhost
**Working directory:** /tmp/test

## Task Summary
Did some work.

## Next Steps
1. Step one
2. Step two
3. Step three
EOF

    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/handoffs"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "true" ]
    [ "$(echo "$output" | jq -r '.filename')" = "handoff-2026-04-09-120000.md" ]
}

@test "inaccessible directory returns found=false with error" {
    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/does-not-exist"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "false" ]
    [[ "$output" == *"not accessible"* ]]
}

@test "fixture handoff metadata: title, sections, next_steps_count" {
    mkdir -p "$TEST_TMPDIR/handoffs"
    cat > "$TEST_TMPDIR/handoffs/handoff-2026-04-09-120000.md" << 'EOF'
# Test Handoff Task

**Machine:** testhost
**Working directory:** /tmp/test

## Task Summary
Did some work.

## Next Steps
1. Step one
2. Step two
3. Step three
EOF

    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/handoffs"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1

    [ "$(echo "$output" | jq -r '.metadata.title')" = "Test Handoff Task" ]
    [ "$(echo "$output" | jq -r '.metadata.next_steps_count')" = "3" ]

    # Sections should include "Task Summary" and "Next Steps"
    local sections
    sections=$(echo "$output" | jq -r '.metadata.sections[]')
    [[ "$sections" == *"Task Summary"* ]]
    [[ "$sections" == *"Next Steps"* ]]
}
