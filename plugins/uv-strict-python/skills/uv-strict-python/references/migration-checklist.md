# Migration Checklist

Migrate through the Catalog 5 control plane. Stage legacy cleanup, preserve
repository intent, and never weaken the final standard to make migration pass.

## Before migration

- [ ] Inventory Python versions, package manager, lockfiles, build backend,
  source/test roots, tooling, CI, editor settings, and agent instructions.
- [ ] Decide `src` or flat layout and any additional first-party roots.
- [ ] Decide whether the workflow and check script are managed or
  consumer-owned.
- [ ] Decide the application/internal versus reusable-library `uv.lock` policy.
- [ ] Preview from a branch or other recoverable Git state.

## V4 to Catalog 5

Do not hand-create unified control-plane state. Express supported migration
choices under `python_tooling:` in `.project-standards.yml`, then run:

```bash
project-standards init --catalog 5 --migrate
project-standards init --catalog 5 --migrate --apply
project-standards reconcile --check --json
```

The preview must be applicable before apply. Modified shared configuration and
instruction files are preserved with bounded-takeover warnings. A modified
workflow or check script requires the matching `consumer-owned` decision;
other modified recognized whole files block until their known bytes are
restored.

## Fresh Catalog 5 adoption

```bash
project-standards init --catalog 5
# Add the Python Tooling selection and options to .standards/config.toml.
project-standards reconcile --check
project-standards reconcile --apply
uv lock
uv run python scripts/check.py
project-standards reconcile --check --json
```

The final JSON check must report `ok: true`, `drift: false`, and no findings.

## Legacy dependency migration

Review dependency identities, then change them only through uv:

```bash
uv add requests rich
uv remove mypy pyright ty black isort flake8
```

Python Tooling’s selected development tools are reconciled from package
options; do not hand-edit that dependency group. Remove legacy dependency
files, package-manager state, and environments only after the replacement is
materialized and verified.

## Cleanup after reconciliation

Remove superseded files only when their replacement is active:

- [ ] `requirements*.txt`, `setup.py`, `setup.cfg`, and `MANIFEST.in`;
- [ ] `.flake8`, `mypy.ini`, `pyrightconfig.json`, and `ty` configuration;
- [ ] obsolete Poetry, Pipenv, PDM, tox, nox, or virtual-environment artifacts;
- [ ] overlapping Python gate hooks;
- [ ] obsolete Black, isort, Flake8, Pylint, mypy, Pyright, ty, or pytest-cov
  configuration.

Do not delete consumer-owned settings, tasks, extension recommendations, or
instruction content. Catalog 5 owns bounded semantic units on those shared
surfaces.

## Verification and publication set

```bash
uv run python scripts/check.py
project-standards reconcile --check --json
```

- [ ] The local verification gate passes.
- [ ] Reconciliation reports `ok: true`, `drift: false`, and no findings.
- [ ] `.standards/config.toml`, `.standards/catalog.toml`, and
  `.standards/lock.toml` are included together.
- [ ] `uv.lock` reflects the reconciled development dependency set.
- [ ] Managed outputs and deliberate consumer-owned exceptions are reviewed.
