# Project Configuration Reference

Python Tooling 1.16 is a Catalog 5 package. Configure its options in
`.standards/config.toml`, then let `project-standards reconcile` compose the
tool-owned semantic units. Do not merge a printed `pyproject.toml` fragment or
copy whole shared configuration files.

## Adoption sequence

For a new repository:

```bash
project-standards init --catalog 5
# Add [standards.python-tooling] and its config tables.
project-standards reconcile --check
project-standards reconcile --apply
uv lock
uv run python scripts/check.py
project-standards reconcile --check --json
```

The final JSON check must report `ok: true`, `drift: false`, and no findings.
Commit the central config, catalog, lock, dependency lock, and reconciled
outputs together.

For a V4 consumer:

```bash
project-standards init --catalog 5 --migrate
project-standards init --catalog 5 --migrate --apply
project-standards reconcile --check --json
```

Do not create `.standards/config.toml` manually during V4 migration. Express
supported migration choices in `.project-standards.yml`, preview, and let the
migration publish unified authority atomically.

## Semantic ownership

Python Tooling manages only declared units:

- selected build-system, development-dependency, Ruff, checker, pytest, and
  coverage keys in `pyproject.toml`;
- independent EditorConfig properties and VS Code recommendations, settings,
  and tasks;
- delimiter-bounded Python Tooling blocks in `AGENTS.md` and `CLAUDE.md`;
- `.python-version` as an exclusive whole file;
- `scripts/check.py` and `.github/workflows/check.yml` as whole files only when
  their ownership options are `managed`.

Unrelated tables, settings, tasks, extensions, and instruction content remain
consumer-owned. A conflicting claimed TOML value blocks before writes; resolve
the repository’s deliberate intent through the corresponding package option
instead of overwriting it.

## Scope options

- `source_layout` selects `src` or flat first-party layout.
- `pytest.test_paths` controls collection roots and contributes to Ruff and
  checker scope, but not coverage source by itself.
- `additional_source_roots` adds first-party roots to Ruff, checker, and
  coverage scope. Use `{ path = "scripts", coverage = false }` when a strictly
  typed tooling root should not affect product coverage.
- Ruff extension lists add repository intent without replacing the curated
  baseline.
- Coverage `omit` adds exclusions. `coverage.patch = ["subprocess"]` requires
  `coverage.parallel = true`.
- `build_backend = "none"` is only for a deliberately non-installable
  repository.
- `workflow_ownership` and `script_ownership` select managed or
  consumer-owned whole-file behavior.

## Managed whole-file resources

The skill retains exactly three byte-identical Python Tooling 1.16 resources
for inspection:

| Skill resource | Reconciled destination |
| --- | --- |
| `templates/check.py` | `scripts/check.py` |
| `templates/check.yml` | `.github/workflows/check.yml` |
| `templates/python-version` | `.python-version` |

They are not an alternate adoption path. Reconciliation renders and records
their ownership from the immutable payload and effective options.

## Supplemental material

`templates/dependabot.yml` and
`templates/adr-python-tooling-exception.md` are supplemental skill examples,
not Python Tooling payload resources. Dependabot is the standard update-policy
companion; the ADR skeleton records an explicitly approved exception.

## Dependency and lock discipline

Use `uv add`, `uv add --dev`, and `uv remove` for application dependencies.
Python Tooling owns its selected development-tool dependency set through
reconciliation, so do not add or remove those packages independently. Run
`uv lock` after apply because the reconciled dependency group changes lock
inputs.

Applications and internal services commit `uv.lock`. A reusable library may
ignore it only when that is the repository’s deliberate policy.

## Verification gate

The rendered local gate and managed workflow run the selected commands in the
package-defined order. Run:

```bash
uv run python scripts/check.py
```

`uv run python scripts/check.py --help` prints usage without starting the gate. Any
other argument is a usage error and exits 2.
