#!/usr/bin/env bats
load helpers

setup() {
    setup_test_env
    # Use a unique state file per test to avoid cross-contamination
    export STATE_FILE="$TEST_TMPDIR/tracker-state.json"
    # The script hardcodes /tmp/up-docs-drift-tracker.json — we clean it
    rm -f /tmp/up-docs-drift-tracker.json
}

teardown() {
    rm -f /tmp/up-docs-drift-tracker.json
    teardown_test_env
}

@test "init returns status=initialized" {
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.status')" = "initialized" ]
}

@test "start-phase creates phase entry" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.status')" = "started" ]
}

@test "record-iteration increments iteration count" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1

    run bash -c 'echo "{\"findings\":[\"a\"],\"fixes_applied\":1}" | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.iteration')" = "1" ]

    run bash -c 'echo "{\"findings\":[\"b\"],\"fixes_applied\":1}" | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1'
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.iteration')" = "2" ]
}

@test "check-convergence with zero findings returns converged=true" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    echo '{"findings":[],"fixes_applied":0}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" check-convergence 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.converged')" = "true" ]
}

@test "check-convergence with findings returns converged=false" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    echo '{"findings":["issue-a"],"fixes_applied":1}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" check-convergence 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.converged')" = "false" ]
}

@test "check-oscillation with <3 iterations returns oscillating=false" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    echo '{"findings":["a"],"fixes_applied":1}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
    echo '{"findings":[],"fixes_applied":0}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" check-oscillation 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.oscillating')" = "false" ]
    [[ "$output" == *"fewer than 3 iterations"* ]]
}

@test "reset clears state" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" reset
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.status')" = "reset" ]

    # After reset, status should return the template (empty phases)
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" status
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq '.phases | length')" = "0" ]
}

@test "invalid subcommand exits 1" {
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" bogus-command
    [ "$status" -eq 1 ]
}
