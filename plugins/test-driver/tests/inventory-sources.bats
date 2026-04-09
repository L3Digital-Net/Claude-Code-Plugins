#!/usr/bin/env bats
# Tests for inventory-sources.sh
# Validates source file discovery, counting, and exclusion logic.

load helpers

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "empty directory returns total_files: 0" {
    mkdir -p "$TEST_TMPDIR/empty-src"
    run "$SCRIPTS_DIR/inventory-sources.sh" python "$TEST_TMPDIR/empty-src"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 0, f'expected 0, got {d[\"total_files\"]}'
assert d['source_files'] == []
"
}

@test "python project with .py files returns correct count" {
    mkdir -p "$TEST_TMPDIR/py-src/lib"
    cat > "$TEST_TMPDIR/py-src/app.py" <<'EOF'
def main():
    pass
EOF
    cat > "$TEST_TMPDIR/py-src/lib/utils.py" <<'EOF'
def helper():
    pass

def another():
    pass
EOF
    run "$SCRIPTS_DIR/inventory-sources.sh" python "$TEST_TMPDIR/py-src"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 2, f'expected 2 files, got {d[\"total_files\"]}'
"
}

@test "test files (test_*.py) are excluded" {
    mkdir -p "$TEST_TMPDIR/py-exclude"
    cat > "$TEST_TMPDIR/py-exclude/app.py" <<'EOF'
def run():
    pass
EOF
    cat > "$TEST_TMPDIR/py-exclude/test_app.py" <<'EOF'
def test_run():
    pass
EOF
    run "$SCRIPTS_DIR/inventory-sources.sh" python "$TEST_TMPDIR/py-exclude"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 1, f'expected 1 (test file excluded), got {d[\"total_files\"]}'
paths = [f['path'] for f in d['source_files']]
assert 'test_app.py' not in paths, 'test_app.py should be excluded'
"
}

@test "excluded directories (__pycache__) are skipped" {
    mkdir -p "$TEST_TMPDIR/py-cache/__pycache__"
    cat > "$TEST_TMPDIR/py-cache/main.py" <<'EOF'
def entry():
    pass
EOF
    cat > "$TEST_TMPDIR/py-cache/__pycache__/main.cpython-312.py" <<'EOF'
def entry():
    pass
EOF
    run "$SCRIPTS_DIR/inventory-sources.sh" python "$TEST_TMPDIR/py-cache"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 1, f'expected 1 (pycache excluded), got {d[\"total_files\"]}'
paths = [f['path'] for f in d['source_files']]
for p in paths:
    assert '__pycache__' not in p, f'__pycache__ file should be excluded: {p}'
"
}

@test "function count is approximate but > 0 for files with functions" {
    mkdir -p "$TEST_TMPDIR/py-funcs"
    cat > "$TEST_TMPDIR/py-funcs/funcs.py" <<'EOF'
def alpha():
    pass

def beta():
    pass

async def gamma():
    pass
EOF
    run "$SCRIPTS_DIR/inventory-sources.sh" python "$TEST_TMPDIR/py-funcs"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_functions_approx'] > 0, f'expected >0 functions, got {d[\"total_functions_approx\"]}'
# Should find at least 3 functions
assert d['total_functions_approx'] >= 3, f'expected >=3 functions, got {d[\"total_functions_approx\"]}'
"
}

@test "output is valid JSON with required fields" {
    mkdir -p "$TEST_TMPDIR/py-fields"
    touch "$TEST_TMPDIR/py-fields/empty.py"
    run "$SCRIPTS_DIR/inventory-sources.sh" python "$TEST_TMPDIR/py-fields"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
required = ['source_files', 'total_files', 'total_lines', 'total_functions_approx', 'counting', 'excluded_patterns', 'truncated']
for key in required:
    assert key in d, f'missing required field: {key}'
assert d['counting'] == 'approximate'
assert isinstance(d['truncated'], bool)
"
}
