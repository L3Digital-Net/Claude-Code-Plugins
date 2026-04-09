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

@test "config-resolve: parses portfolio YAML with defaults" {
    cat > "$TEST_TMPDIR/portfolio.yml" << 'EOF'
defaults:
  labels:
    sync: true
  security:
    check_dependabot: true
EOF
    run bash "$SCRIPTS_DIR/config-resolve.sh" "testowner/testrepo" \
        --portfolio-path "$TEST_TMPDIR/portfolio.yml"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
# Portfolio was found and parsed — defaults should propagate
assert d['sources']['portfolio_defaults'] is not None, \
    'portfolio_defaults source should not be None'
assert d['sources']['portfolio_defaults'].get('labels', {}).get('sync') == True, \
    f'defaults.labels.sync not parsed: {d[\"sources\"][\"portfolio_defaults\"]}'
# Resolved config should merge tier defaults with portfolio defaults
assert d['resolved'].get('labels', {}).get('sync') == True, \
    f'labels.sync missing from resolved: {d[\"resolved\"]}'
assert 'portfolio_defaults' in d['precedence_applied'], \
    f'expected portfolio_defaults in precedence: {d[\"precedence_applied\"]}'
print('ok')
"
}

@test "config-resolve: per-repo overrides take precedence over defaults" {
    # Dict-style repos section: repo name as YAML key under repos:
    cat > "$TEST_TMPDIR/portfolio-override.yml" << 'EOF'
defaults:
  community:
    check_all: true
repos:
  myorg/myrepo:
    community:
      check_all: false
EOF
    run bash "$SCRIPTS_DIR/config-resolve.sh" "myorg/myrepo" \
        --portfolio-path "$TEST_TMPDIR/portfolio-override.yml"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
resolved = d['resolved']
# per-repo override should win: community.check_all=false beats defaults' true
assert resolved['community']['check_all'] == False, \
    f'per-repo override did not win: community.check_all={resolved[\"community\"][\"check_all\"]}'
# precedence_applied should include portfolio_repo_override
assert 'portfolio_repo_override' in d['precedence_applied'], \
    f'precedence missing portfolio_repo_override: {d[\"precedence_applied\"]}'
print('ok')
"
}
