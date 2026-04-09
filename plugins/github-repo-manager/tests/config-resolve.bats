#!/usr/bin/env bats
# Tests for config-resolve.sh

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "config-resolve: missing repo argument exits 1" {
    run bash "$SCRIPTS_DIR/config-resolve.sh"
    [ "$status" -eq 1 ]
}

@test "config-resolve: nonexistent portfolio returns valid JSON with tier defaults" {
    run bash "$SCRIPTS_DIR/config-resolve.sh" "owner/repo" \
        --portfolio-path "$TEST_TMPDIR/nonexistent-portfolio.yml"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "config-resolve: output has repo, sources, resolved fields" {
    run bash "$SCRIPTS_DIR/config-resolve.sh" "testowner/testrepo" \
        --portfolio-path "$TEST_TMPDIR/nonexistent-portfolio.yml"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'repo' in d, 'missing repo'
assert 'sources' in d, 'missing sources'
assert 'resolved' in d, 'missing resolved'
print('ok')
"
}

@test "config-resolve: repo field matches input argument" {
    run bash "$SCRIPTS_DIR/config-resolve.sh" "myorg/myrepo" \
        --portfolio-path "$TEST_TMPDIR/nonexistent-portfolio.yml"
    [ "$status" -eq 0 ]
    repo_val=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['repo'])")
    [ "$repo_val" = "myorg/myrepo" ]
}
