#!/usr/bin/env bats
# Tests for check-readme-structure.sh

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "check-readme-structure: outputs valid JSON" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "check-readme-structure: JSON contains check field set to readme-structure" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    result=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['check'])")
    [ "$result" = "readme-structure" ]
}

@test "check-readme-structure: findings is an array" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    is_list=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(type(d['findings']).__name__)")
    [ "$is_list" = "list" ]
}

@test "check-readme-structure: each finding has severity, path, detail, auto_fix" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in d['findings']:
    assert 'severity' in f, f'missing severity in {f}'
    assert 'path' in f, f'missing path in {f}'
    assert 'detail' in f, f'missing detail in {f}'
    assert 'auto_fix' in f, f'missing auto_fix in {f}'
print('ok')
"
}

@test "check-readme-structure: findings have valid severity values" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in d['findings']:
    assert f['severity'] in ('warn', 'info'), f'invalid severity: {f[\"severity\"]}'
print('ok')
"
}

@test "check-readme-structure: check field is readme-structure and findings are well-formed" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['check'] == 'readme-structure', 'wrong check name'
# Every finding must have all four required fields with correct types
for f in d['findings']:
    assert isinstance(f['severity'], str), f'severity not str: {f}'
    assert isinstance(f['path'], str), f'path not str: {f}'
    assert isinstance(f['detail'], str), f'detail not str: {f}'
    assert isinstance(f['auto_fix'], bool), f'auto_fix not bool: {f}'
print('ok')
"
}
