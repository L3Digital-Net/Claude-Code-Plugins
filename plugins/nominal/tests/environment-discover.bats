#!/usr/bin/env bats
# Tests for environment-discover.sh — environment profile discovery.

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "outputs valid JSON" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)"
}

@test "contains _schema_version field" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert '_schema_version' in data, 'missing _schema_version'
assert data['_schema_version'] == '1.0.0'
"
}

@test "environment object has all 10 required categories" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
# Find the environment key (not _schema_version)
env_keys = [k for k in data if k != '_schema_version']
assert len(env_keys) == 1, f'expected 1 environment key, got {len(env_keys)}: {env_keys}'
env = data[env_keys[0]]
required = ['host', 'network', 'ingress', 'ssl', 'monitoring', 'backup', 'secrets', 'security_tooling', 'vcs', 'services']
for cat in required:
    assert cat in env, f'missing required category: {cat}'
"
}

@test "host.hostname is non-null" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
env_key = [k for k in data if k != '_schema_version'][0]
hostname = data[env_key]['host']['hostname']
assert hostname is not None, 'hostname is null'
assert len(hostname) > 0, 'hostname is empty'
"
}

@test "services is an array" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
env_key = [k for k in data if k != '_schema_version'][0]
services = data[env_key]['services']
assert isinstance(services, list), f'services is {type(services).__name__}, expected list'
"
}
