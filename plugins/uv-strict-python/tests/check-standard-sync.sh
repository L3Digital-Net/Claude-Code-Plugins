#!/usr/bin/env bash
set -euo pipefail

# Prove the plugin's skill copy mirrors one immutable released payload of the
# Python Tooling standard. A missing CLI or payload is a failed precondition,
# not a skip: silently passing would let stale guidance ship to marketplace
# consumers, which is exactly the environment where the evidence matters.
#
# Requirements: the `project-standards` CLI on PATH (the pinned release below,
# installed as an isolated app — its own shebang interpreter is reused here so
# the introspection never depends on the ambient `python3`), plus GNU grep and
# `cmp`. Deliberately no `rg`: this repository's harness assumes only coreutils.
#
# This is the plugin-side twin of the canonical skill's
# skills/active/uv-strict-python/tests/check-standard-sync.sh in agent-configs.
# The plugin copy carries no evals/, so the prose sweeps below search SKILL.md
# and the two references that carry adoption guidance; the pins, the byte
# resources, and the stale/required prose vocabularies must stay identical to
# canonical — when canonical re-syncs to a new release, both ends move together.

readonly expected_release="5.25.0"
readonly expected_commit="b2f73d9dee080a7579a7900168093dabf4c52b5b"
readonly expected_contract="1.16"
readonly expected_payload_digest="sha256:60d3a68c9973942b7a92f7affcd3fbac553b3c79c31bcd63b723e1186bd3c734"

plugin_root="$(cd "$(dirname "$0")/.." && pwd)"
skill_root="$plugin_root/skills/uv-strict-python"
skill_md="$skill_root/SKILL.md"
templates="$skill_root/templates"
fail=0

report_failure() {
  echo "standard-sync: FAIL — $*" >&2
  fail=1
}

cli="$(command -v project-standards || true)"
if [[ -z "$cli" ]]; then
  echo "standard-sync: FAIL — project-standards $expected_release is required" >&2
  exit 1
fi

actual_release="$("$cli" --version)"
if [[ "$actual_release" != "project-standards $expected_release" ]]; then
  echo "standard-sync: FAIL — expected project-standards $expected_release, got $actual_release" >&2
  exit 1
fi

IFS= read -r cli_shebang < "$cli"
cli_python="${cli_shebang#\#!}"
if [[ "$cli_python" == "$cli_shebang" || ! -x "$cli_python" ]]; then
  echo "standard-sync: FAIL — cannot resolve the isolated CLI interpreter from $cli" >&2
  exit 1
fi

# The installed distribution records the git revision it was built from; that
# is the only local evidence that the CLI is the reviewed release rather than a
# same-numbered rebuild.
verify_provenance() {
  local direct_url="$1"
  "$cli_python" -c '
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected = {
    "commit_id": sys.argv[2],
    "requested_revision": sys.argv[3],
}
try:
    document = json.loads(path.read_text(encoding="utf-8"))
    vcs_info = document["vcs_info"]
except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
    print(f"standard-sync: FAIL — invalid distribution provenance at {path}: {error}", file=sys.stderr)
    raise SystemExit(1) from None
for field, wanted in expected.items():
    actual = vcs_info.get(field)
    if actual != wanted:
        print(
            f"standard-sync: FAIL — direct_url.json {field} expected {wanted!r}, got {actual!r}",
            file=sys.stderr,
        )
        raise SystemExit(1)
' "$direct_url" "$expected_commit" "v$expected_release"
}

direct_url="$(
  "$cli_python" -c '
import importlib.metadata

distribution = importlib.metadata.distribution("project-standards")
matches = [
    entry
    for entry in distribution.files or ()
    if str(entry).endswith(".dist-info/direct_url.json")
]
if len(matches) != 1:
    raise SystemExit("installed project-standards distribution must contain one direct_url.json")
print(distribution.locate_file(matches[0]))
'
)"
verify_provenance "$direct_url"

package_root="$(
  "$cli_python" -c \
    'from pathlib import Path; import project_standards; print(Path(project_standards.__file__).resolve().parent)'
)"
payload="$package_root/payloads/python-tooling/$expected_contract"
family_manifest="$package_root/families/python-tooling/standard.toml"

if [[ ! -f "$payload/payload.toml" || ! -f "$family_manifest" ]]; then
  echo "standard-sync: FAIL — installed Python Tooling $expected_contract payload is incomplete" >&2
  exit 1
fi

if ! grep -Fq "version = \"$expected_contract\"" "$family_manifest" ||
  ! grep -Fq "digest = \"$expected_payload_digest\"" "$family_manifest"; then
  report_failure "installed family metadata does not bind Python Tooling $expected_contract to $expected_payload_digest"
fi

readonly sync_pin="Project Standards v$expected_release (peeled commit \`$expected_commit\`) and Python Tooling $expected_contract (\`$expected_payload_digest\`)"
if ! grep -Fq "$sync_pin" "$skill_md"; then
  report_failure "SKILL.md does not name the immutable release, commit, contract, and payload digest"
fi

declare -A parity=(
  ["$templates/check.py"]="$payload/resources/check.py"
  ["$templates/check.yml"]="$payload/resources/check.yml"
  ["$templates/python-version"]="$payload/resources/python-version"
)

for candidate in "${!parity[@]}"; do
  canonical="${parity[$candidate]}"
  if [[ ! -f "$candidate" ]]; then
    report_failure "required byte resource missing: ${candidate#"$skill_root"/}"
  elif ! cmp -s "$candidate" "$canonical"; then
    report_failure "byte resource diverges: ${candidate#"$skill_root"/} vs Python Tooling $expected_contract/${canonical#"$payload"/}"
  fi
done

# Catalog 5 reconciles these as semantic units; a copy-only template here would
# reintroduce the V3 model the skill no longer describes.
semantic_templates=(
  AGENTS.md
  AGENTS.pointer.md
  CLAUDE.md
  editorconfig
  pyproject.python-tooling.toml
  vscode-extensions.json
  vscode-settings.json
  vscode-tasks.json
)
for stale_template in "${semantic_templates[@]}"; do
  if [[ -e "$templates/$stale_template" ]]; then
    report_failure "V3 copy-only semantic template remains authorized: templates/$stale_template"
  fi
done

prose=(
  "$skill_md"
  "$skill_root/references/pyproject.md"
  "$skill_root/references/migration-checklist.md"
)

stale_patterns=(
  "project-standards@v3"
  "project-standards adopt python-tooling"
  "canonical repo (or the adopt CLI)"
  "canonical-repo-or-adopt-cli"
  "copy [templates/AGENTS.md]"
  "copying those over transcribing"
  "AGENTS.pointer.md"
  "full-agents-template-or-stop"
)
for stale_pattern in "${stale_patterns[@]}"; do
  if grep -Fq -- "$stale_pattern" "${prose[@]}"; then
    report_failure "stale V3 guidance remains: $stale_pattern"
  fi
done

required_guidance=(
  ".standards/config.toml"
  "project-standards init --catalog 5"
  "project-standards reconcile --check"
  "project-standards reconcile --apply"
  "semantic units"
  "exactly three byte-identical"
)
for guidance in "${required_guidance[@]}"; do
  if ! grep -Fq -- "$guidance" "${prose[@]}"; then
    report_failure "Catalog 5 guidance missing: $guidance"
  fi
done

if [[ $fail -ne 0 ]]; then
  exit 1
fi

echo "standard-sync: OK (Project Standards $expected_release at provenance commit $expected_commit; Python Tooling $expected_contract $expected_payload_digest; ${#parity[@]} byte resources)"
