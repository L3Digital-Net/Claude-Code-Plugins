#!/usr/bin/env bats
# Tests for inventory-tests.sh
# Validates test file discovery, categorization, and counting.

load helpers

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "empty directory returns total_tests: 0" {
    mkdir -p "$TEST_TMPDIR/empty-tests"
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/empty-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_tests'] == 0, f'expected 0, got {d[\"total_tests\"]}'
assert d['total_files'] == 0
"
}

@test "python project with test files returns correct count" {
    mkdir -p "$TEST_TMPDIR/py-tests"
    cat > "$TEST_TMPDIR/py-tests/test_app.py" <<'EOF'
def test_one():
    assert True

def test_two():
    assert True
EOF
    cat > "$TEST_TMPDIR/py-tests/test_utils.py" <<'EOF'
def test_helper():
    assert True
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/py-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 2, f'expected 2 test files, got {d[\"total_files\"]}'
assert d['total_tests'] == 3, f'expected 3 tests, got {d[\"total_tests\"]}'
"
}

@test "files in tests/unit/ classified as unit" {
    mkdir -p "$TEST_TMPDIR/cat-tests/tests/unit"
    cat > "$TEST_TMPDIR/cat-tests/tests/unit/test_core.py" <<'EOF'
def test_core_logic():
    assert True
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/cat-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
unit_files = [f for f in d['test_files'] if f['category'] == 'unit']
assert len(unit_files) == 1, f'expected 1 unit file, got {len(unit_files)}'
assert d['by_category']['unit']['files'] == 1
"
}

@test "by_category always includes unit, integration, e2e keys" {
    mkdir -p "$TEST_TMPDIR/cat-keys"
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/cat-keys"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for cat in ('unit', 'integration', 'e2e'):
    assert cat in d['by_category'], f'missing category key: {cat}'
    assert 'files' in d['by_category'][cat]
    assert 'tests' in d['by_category'][cat]
"
}

@test "output is valid JSON with required fields" {
    mkdir -p "$TEST_TMPDIR/json-check"
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/json-check"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
required = ['test_files', 'by_category', 'total_files', 'total_tests']
for key in required:
    assert key in d, f'missing required field: {key}'
assert isinstance(d['test_files'], list)
assert isinstance(d['by_category'], dict)
"
}
