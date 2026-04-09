#!/usr/bin/env bats
# Tests for domain-checker.sh — parameterized verification domain checker.

load helpers

FIXTURE_DIR=""

setup() {
    setup_test_env
    FIXTURE_DIR="$TEST_TMPDIR/.claude/nominal"
    mkdir -p "$FIXTURE_DIR"
    cat > "$FIXTURE_DIR/environment.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "description": "test env",
    "first_discovered": "2026-04-09T00:00:00Z",
    "last_validated": "2026-04-09T00:00:00Z",
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": null, "_discovery_note": null},
    "ingress": {"reverse_proxy_tool": null, "config_path": null, "access_model": null, "_discovery_note": null},
    "ssl": {"cert_tool": null, "config_path": null, "renewal_mechanism": null, "_discovery_note": null},
    "monitoring": {"metrics_tool": null, "metrics_status_check": null, "uptime_tool": null, "uptime_status_check": null, "log_aggregation_tool": null, "log_status_check": null, "_discovery_note": null},
    "backup": {"backup_tool": null, "targets": null, "pre_dump_scripts": null, "last_run_check": null, "_discovery_note": null},
    "secrets": {"approach": null, "canonical_location": null, "_discovery_note": null},
    "security_tooling": {"fim_tool": null, "fim_baseline_update_method": null, "ips_tool": null, "ips_status_check": null, "_discovery_note": null},
    "vcs": {"tool": null, "remote": null, "config_tracked_paths": null, "_discovery_note": null},
    "services": []
  }
}
FIXTURE
}

teardown() { teardown_test_env; }

@test "missing arguments exits 1" {
    run bash -c "'$SCRIPTS_DIR/domain-checker.sh' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}

@test "invalid domain number 0 outputs error" {
    run bash -c "'$SCRIPTS_DIR/domain-checker.sh' 0 '$FIXTURE_DIR/environment.json' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid domain"* ]]
}

@test "invalid domain number 12 outputs error" {
    run bash -c "'$SCRIPTS_DIR/domain-checker.sh' 12 '$FIXTURE_DIR/environment.json' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid domain"* ]]
}

@test "invalid domain number 99 outputs error" {
    run bash -c "'$SCRIPTS_DIR/domain-checker.sh' 99 '$FIXTURE_DIR/environment.json' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid domain"* ]]
}

@test "domain 6 (performance) returns valid JSON with summary" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 6 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert 'summary' in data, 'missing summary'
assert 'total' in data['summary']
assert 'pass' in data['summary']
assert 'fail' in data['summary']
assert 'skip' in data['summary']
"
}

@test "domain 1 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 1 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==1"
}

@test "domain 2 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 2 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==2"
}

@test "domain 3 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 3 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==3"
}

@test "domain 4 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 4 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==4"
}

@test "domain 5 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 5 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==5"
}

@test "domain 6 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 6 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==6"
}

@test "domain 7 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 7 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==7"
}

@test "domain 8 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 8 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==8"
}

@test "domain 9 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 9 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==9"
}

@test "domain 10 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 10 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==10"
}

@test "domain 11 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 11 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==11"
}
