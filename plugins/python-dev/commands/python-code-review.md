---
allowed-tools: Read, Glob, Grep, Bash
description: Comprehensive Python code review across 11 quality domains — anti-patterns, type safety, design, style, resources, resilience, configuration, observability, testing, async, and background jobs
argument-hint: "[path]  (file, directory, or glob — defaults to current directory)"
---

# Python Code Review

Run a comprehensive quality audit across all 11 Python development domains. Findings are prioritized with 🔴 Critical / 🟡 Needs Attention / 🟢 Good.

## Step 1 — Identify Target Files

If the user provided an argument, use it as the target path. Otherwise, use the current working directory.

Find all Python files at the target:

```bash
# For a directory:
find <path> -name "*.py" -not -path "*/\.*" -not -path "*/__pycache__/*" | sort

# For a glob or specific file, adjust accordingly
```

If no `.py` files are found, stop and report that clearly.

Read all target files before beginning the review.

## Step 2 — Domain Audits

Work through each domain in order. For each domain, emit a section header and findings. If a domain doesn't apply (e.g., no async code for Domain 10), note it briefly and move on.

---

### Domain 1: Anti-Patterns

Check for the most common Python bugs and structural mistakes:

- **Bare exception handling**: `except:` or `except Exception: pass` that swallows errors silently
- **Mutable default arguments**: `def f(items=[])` — shared state across calls
- **Hardcoded config/secrets**: API keys, connection strings, URLs baked into code
- **Scattered retry/timeout logic**: duplicated across call sites instead of centralized
- **Double retry**: retry at application layer while infrastructure (client library) also retries
- **Exposed internal types**: ORM models returned directly from API endpoints
- **Mixed I/O and business logic**: database queries embedded in business logic functions
- **Ignored partial failures in batch processing**: loop that stops on first error
- **Unclosed resources**: files, connections opened without context managers
- **Missing input validation**: data from external sources used without validation

---

### Domain 2: Type Safety

Check for type annotation coverage and correctness:

- Public functions missing parameter or return type annotations
- Collections missing type parameters (`list` instead of `list[str]`)
- `Any` used where a specific type is possible
- `Optional[T]` used instead of the modern `T | None` syntax (Python 3.10+)
- Missing mypy or pyright configuration in pyproject.toml
- Untyped class attributes
- Missing type narrowing before accessing members of a union type

---

### Domain 3: Design Patterns

Check for structural quality:

- **God classes/functions**: classes or functions with more than one clear responsibility
- **Deep nesting**: 3+ levels of conditionals or loops — extract to functions
- **Premature abstraction**: complex factory/registry for 1-2 use cases (Rule of Three)
- **Inheritance where composition fits better**: subclassing concrete classes for behavior reuse
- **Dependency injection absent**: dependencies hard-coded inside constructors or functions (not injected)
- **Missing layer separation**: API, service, and data access logic mixed in one function

---

### Domain 4: Code Style

Check for style and documentation quality:

- Naming: non-PEP 8 identifiers (camelCase functions, lowercase classes, etc.)
- Import organization: missing stdlib/third-party/local grouping; relative imports used
- Long functions (>50 lines) that do multiple distinct things
- Public functions/classes/methods missing docstrings
- Inconsistent quote style, trailing whitespace, or other issues fixable by ruff
- No ruff or mypy configuration present in the project

---

### Domain 5: Resource Management

Check for resource lifecycle correctness:

- Files, sockets, or DB connections opened without `with` blocks
- Custom context managers that don't use `@contextmanager` or `__enter__`/`__exit__`
- String accumulation via `+` in a loop instead of `list` + `join`
- `ExitStack` not used where a dynamic number of resources are managed
- Missing cleanup in exception paths

---

### Domain 6: Resilience

Check for fault tolerance:

- HTTP or RPC calls without retry logic on transient errors
- Retrying all exceptions including permanent ones (`ValueError`, `AuthError`, HTTP 4xx)
- No timeout set on external calls (network, subprocess, DB queries)
- No jitter in retry backoff (thundering herd risk)
- Critical paths with no graceful degradation or fail-safe default
- Non-transient errors being retried (anything that won't fix itself)

---

### Domain 7: Configuration

Check for configuration management:

- Environment-specific values hardcoded (URLs, hostnames, feature flags)
- `os.getenv()` called directly throughout the code instead of a central settings class
- No fail-fast validation of required config at startup
- Secrets or passwords in source files or committed `.env` files
- Missing `.env.example` or documentation of required environment variables

---

### Domain 8: Observability

Check for logging and instrumentation:

- Missing structured logging (using `print()` or unstructured `logging.info(str)`)
- Log levels misused: expected errors logged as ERROR, or real errors suppressed
- No correlation/request IDs threaded through the request lifecycle
- Functions that perform significant work with no timing or logging
- Unbounded metric labels (e.g., using user IDs as Prometheus label values)
- No health check or readiness endpoint (for services)

---

### Domain 9: Testing

Check for test quality and coverage:

- Test files present? If no `tests/` directory exists, flag this.
- Only happy-path tests — no tests for error conditions or edge cases
- Over-mocking: mocking internal implementation details instead of boundaries
- Tests with shared mutable state between test cases
- No parametrized tests where the same logic is tested with multiple inputs
- Async code not tested with `pytest-asyncio`
- No fixture cleanup (teardown missing from setup/teardown fixtures)

---

### Domain 10: Async Patterns

(Skip if no `async def` or `await` in the code.)

- Blocking calls inside `async def` functions: `time.sleep()`, `requests.get()`, synchronous file I/O
- `asyncio.gather()` called on unbounded lists — should use semaphore to limit concurrency
- Catching `asyncio.CancelledError` and not re-raising it
- Mixing sync and async code paths: calling `asyncio.run()` inside an async function
- Not using `asyncio.to_thread()` for CPU-bound or blocking sync code
- Missing `async with` for async context managers

---

### Domain 11: Background Jobs

(Skip if no Celery, RQ, Dramatiq, or similar task queue usage.)

- Tasks not idempotent — no check-before-write or idempotency key
- No state tracking for long-running jobs (users can't poll for status)
- Retrying all exception types, including permanent failures
- No dead letter queue for tasks that exhaust retries
- Missing hard timeout on long-running tasks
- No exponential backoff on retry

---

## Step 3 — Summary Report

After completing all domain audits, output:

```
## Summary

### 🔴 Critical (fix before merge)
<bulleted list — 3 items max>

### 🟡 Needs Attention (fix soon)
<bulleted list — 5 items max>

### 🟢 Highlights
<1-2 things the code does well>

### Top 3 Action Items
1. <most impactful fix>
2. <second most impactful fix>
3. <third most impactful fix>
```

Keep each finding to one line: what it is and where it is (file:line if possible). Do not list the same issue multiple times across domains.
