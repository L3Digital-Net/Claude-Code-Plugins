#!/usr/bin/env bats
# Tests for invariant-check.sh — state invariant validation.

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

# -- review mode --

@test "review: clean state passes all 7 invariants" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    passed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])")
    [ "$passed" -eq 7 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -eq 0 ]
}

@test "review: Track B finding with auto_fix_eligible=true fails invariant" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"B","severity":"high","section":"Principles","description":"Violated","auto_fix_eligible":true}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    # Check the specific violation
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('auto_fix_eligible' in v.get('detail','') or 'auto-fixed' in v.get('invariant','') for v in violations), f'Expected auto_fix invariant violation, got: {violations}'
"
}

@test "review: resolved finding missing resolution fails invariant" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"A","severity":"medium","section":"Overview","description":"Issue"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    # Manually set status to resolved without resolution to trigger invariant violation
    state_file="/tmp/design-assistant-${SESSION_ID}.json"
    python3 -c "
import json
with open('$state_file') as f:
    state = json.load(f)
state['finding_queue'][0]['status'] = 'resolved'
state['finding_queue'][0]['resolution'] = None
with open('$state_file', 'w') as f:
    json.dump(state, f, indent=2)
"

    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('resolution' in v.get('invariant','').lower() or 'resolution' in v.get('detail','').lower() for v in violations), f'Expected resolution invariant violation, got: {violations}'
"
}

# -- draft mode --

@test "draft: valid state passes all invariants" {
    draft_state='{"phase":1,"step":"discover","candidates":[],"tension_log":[],"phase_history":[1],"registry_locked":false,"coverage_sweep_complete":false,"open_questions":[]}'
    run bash -c "echo '$draft_state' | '$SCRIPTS_DIR/invariant-check.sh' draft -"
    [ "$status" -eq 0 ]
    passed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])")
    [ "$passed" -eq 7 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -eq 0 ]
}

# -- error cases --

@test "invalid command type exits 1" {
    run "$SCRIPTS_DIR/invariant-check.sh" bogus "some-id"
    [ "$status" -eq 1 ]
}

@test "missing session in review mode exits 1" {
    run "$SCRIPTS_DIR/invariant-check.sh" review "nonexistent-session-99999"
    [ "$status" -eq 1 ]
}
