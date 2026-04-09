#!/usr/bin/env bats
# Tests for detect-project.sh
# Validates project type detection from marker files.

load helpers

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "empty directory: project_type is null, confidence is none" {
    mkdir -p "$TEST_TMPDIR/empty-proj"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/empty-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] is None, f'expected null, got {d[\"project_type\"]}'
assert d['confidence'] == 'none', f'expected none, got {d[\"confidence\"]}'
"
}

@test "directory with pyproject.toml: detects python type" {
    mkdir -p "$TEST_TMPDIR/py-proj"
    # Include a known framework so confidence stays high
    cat > "$TEST_TMPDIR/py-proj/pyproject.toml" <<'EOF'
[project]
dependencies = ["fastapi"]
EOF
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/py-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'python-fastapi', f'expected python-fastapi, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
assert 'pyproject.toml' in d['markers_found']
"
}

@test "directory with Package.swift: detects swift-swiftui" {
    mkdir -p "$TEST_TMPDIR/swift-proj"
    touch "$TEST_TMPDIR/swift-proj/Package.swift"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/swift-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'swift-swiftui', f'expected swift-swiftui, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
"
}

@test "directory with package.json: detects javascript" {
    mkdir -p "$TEST_TMPDIR/js-proj"
    echo '{}' > "$TEST_TMPDIR/js-proj/package.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/js-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'javascript', f'expected javascript, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
"
}

@test "directory with package.json + tsconfig.json: detects typescript" {
    mkdir -p "$TEST_TMPDIR/ts-proj"
    echo '{}' > "$TEST_TMPDIR/ts-proj/package.json"
    echo '{}' > "$TEST_TMPDIR/ts-proj/tsconfig.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/ts-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'typescript', f'expected typescript, got {d[\"project_type\"]}'
"
}

@test "directory with .claude-plugin/plugin.json: detects claude-plugin" {
    mkdir -p "$TEST_TMPDIR/plugin-proj/.claude-plugin"
    echo '{"name":"test"}' > "$TEST_TMPDIR/plugin-proj/.claude-plugin/plugin.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/plugin-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'claude-plugin', f'expected claude-plugin, got {d[\"project_type\"]}'
assert d['confidence'] == 'high'
"
}

@test "first marker wins: pyproject.toml AND package.json detects python" {
    mkdir -p "$TEST_TMPDIR/multi-proj"
    # Use django so sub-classification keeps a python-* type
    cat > "$TEST_TMPDIR/multi-proj/pyproject.toml" <<'EOF'
[project]
dependencies = ["django"]
EOF
    echo '{}' > "$TEST_TMPDIR/multi-proj/package.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/multi-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# python is first in marker list, so it wins
assert d['project_type'].startswith('python'), f'expected python*, got {d[\"project_type\"]}'
assert 'pyproject.toml' in d['markers_found']
assert 'package.json' in d['markers_found']
"
}

@test "secondary markers collected when multiple markers exist" {
    mkdir -p "$TEST_TMPDIR/multi-proj2"
    cat > "$TEST_TMPDIR/multi-proj2/pyproject.toml" <<'EOF'
[project]
dependencies = ["fastapi"]
EOF
    echo '{}' > "$TEST_TMPDIR/multi-proj2/package.json"
    run "$SCRIPTS_DIR/detect-project.sh" "$TEST_TMPDIR/multi-proj2"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['secondary_markers']) > 0, 'expected secondary markers'
assert 'package.json' in d['secondary_markers']
"
}
