#!/usr/bin/env bats
# Tests for coverage-sweep.sh — pre-Phase-5 coverage analysis.

load helpers

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "empty context returns ready_for_phase_5=true" {
    input='{"context":{},"sections":[],"open_questions":[]}'
    run bash -c "echo '$input' | '$SCRIPTS_DIR/coverage-sweep.sh'"
    [ "$status" -eq 0 ]
    ready=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['ready_for_phase_5'])")
    [ "$ready" = "True" ]
}

@test "constraint with exact match in section: status=covered, confidence=exact" {
    input='{"context":{"constraints":["must support offline mode"]},"sections":[{"name":"Architecture","content_summary":"The system must support offline mode via local caching"}],"open_questions":[]}'
    run bash -c "echo '$input' | '$SCRIPTS_DIR/coverage-sweep.sh'"
    [ "$status" -eq 0 ]
    status_val=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['constraints']['items'][0]['status'])")
    [ "$status_val" = "covered" ]
    confidence=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['constraints']['items'][0]['confidence'])")
    [ "$confidence" = "exact" ]
}

@test "constraint not in any section: status=uncovered, in blocking_items" {
    input='{"context":{"constraints":["must support real-time sync"]},"sections":[{"name":"Architecture","content_summary":"Local storage only, no networking"}],"open_questions":[]}'
    run bash -c "echo '$input' | '$SCRIPTS_DIR/coverage-sweep.sh'"
    [ "$status" -eq 0 ]
    status_val=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['constraints']['items'][0]['status'])")
    [ "$status_val" = "uncovered" ]
    blocking=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['blocking_items']))")
    [ "$blocking" -ge 1 ]
    ready=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['ready_for_phase_5'])")
    [ "$ready" = "False" ]
}

@test "constraint with partial keyword match: status=covered, confidence=partial" {
    input='{"context":{"constraints":["database migration strategy needed"]},"sections":[{"name":"Data Layer","content_summary":"The database layer handles migration through versioned schemas and strategy patterns"}],"open_questions":[]}'
    run bash -c "echo '$input' | '$SCRIPTS_DIR/coverage-sweep.sh'"
    [ "$status" -eq 0 ]
    status_val=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['constraints']['items'][0]['status'])")
    [ "$status_val" = "covered" ]
    confidence=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['constraints']['items'][0]['confidence'])")
    [ "$confidence" = "partial" ]
}

@test "risk covered by open question: status=open_question" {
    input='{"context":{"risks":["vendor lock-in risk"]},"sections":[{"name":"Risks","content_summary":"General risk assessment"}],"open_questions":[{"text":"What is our vendor lock-in risk mitigation plan?","associated_section":"Risks"}]}'
    run bash -c "echo '$input' | '$SCRIPTS_DIR/coverage-sweep.sh'"
    [ "$status" -eq 0 ]
    status_val=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['risks']['items'][0]['status'])")
    [ "$status_val" = "open_question" ]
}

@test "invalid JSON input exits 1" {
    run bash -c "echo 'not valid json' | '$SCRIPTS_DIR/coverage-sweep.sh'"
    [ "$status" -eq 1 ]
}
