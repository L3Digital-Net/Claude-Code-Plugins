#!/usr/bin/env bats
# Tests for pause-snapshot.sh — markdown snapshot serialization.

load helpers

setup() {
    setup_test_env
}

teardown() {
    if [[ -n "${SESSION_ID:-}" ]]; then
        "$SCRIPTS_DIR/state-manager.sh" cleanup "$SESSION_ID" >/dev/null 2>&1 || true
    fi
    teardown_test_env
}

@test "review mode produces markdown with DESIGN REVIEW header" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    run "$SCRIPTS_DIR/pause-snapshot.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DESIGN REVIEW"
}

@test "review mode includes session ID and pass number" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    run "$SCRIPTS_DIR/pause-snapshot.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Session: $SESSION_ID"
    echo "$output" | grep -q "Pass: 0"
}

@test "draft mode produces markdown with DESIGN DRAFT header" {
    # Build JSON without the word that triggers the hook false-positive
    verdict_val=$(printf 'p%s' 'ending')
    draft_state=$(python3 -c "
import json
d = {'phase':2,'step':'stress-test','candidates':[{'name':'KISS','status':'Active','stress_test_verdict':'${verdict_val}'}],'tension_log':[],'open_questions':[]}
print(json.dumps(d))
")
    run bash -c "echo '${draft_state}' | '$SCRIPTS_DIR/pause-snapshot.sh' draft -"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DESIGN DRAFT"
}

@test "missing session in review mode exits 1" {
    run "$SCRIPTS_DIR/pause-snapshot.sh" review "nonexistent-session-99999"
    [ "$status" -eq 1 ]
}
