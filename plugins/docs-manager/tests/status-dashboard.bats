#!/usr/bin/env bats
load helpers

setup() {
    setup_test_env
    export REAL_HOME="$HOME"
    export HOME="$DOCS_MANAGER_HOME/fakehome"
    mkdir -p "$HOME"
}

teardown() {
    export HOME="$REAL_HOME"
    teardown_test_env
}

@test "without ~/.docs-manager/: config.exists=false" {
    # HOME has no .docs-manager directory
    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.operational.config.exists')" = "false" ]
}

@test "with valid config: config.exists=true, config.valid=true" {
    mkdir -p "$HOME/.docs-manager"
    cat > "$HOME/.docs-manager/config.yaml" << 'EOF'
index_type: json
machine_id: testbox
index_path: /tmp/docs-index.json
EOF

    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.operational.config.exists')" = "true" ]
    [ "$(echo "$output" | jq -r '.operational.config.valid')" = "true" ]
}

@test "--test flag: output contains tests array" {
    mkdir -p "$HOME/.docs-manager"
    cat > "$HOME/.docs-manager/config.yaml" << 'EOF'
index_type: json
machine_id: testbox
EOF

    run bash "$SCRIPTS_DIR/status-dashboard.sh" --test
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    # tests key should be present and be an array
    [ "$(echo "$output" | jq 'has("tests")')" = "true" ]
    [ "$(echo "$output" | jq '.tests | type')" = '"array"' ]
}

@test "output is valid JSON" {
    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
}
