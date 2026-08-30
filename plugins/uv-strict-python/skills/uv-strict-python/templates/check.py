"""Run the selected Python verification gate and stop at the first failure."""

import subprocess
import sys
from collections.abc import Sequence

USAGE = """usage: scripts/check.py [-h]

Run the verification gate commands in order and stop at the first failure.

options:
  -h, --help  show this message and exit
"""

COMMANDS: tuple[tuple[str, ...], ...] = (
    (
        "uv",
        "run",
        "ruff",
        "format",
        "--check",
        "src",
        "tests",
    ),
    (
        "uv",
        "run",
        "ruff",
        "check",
        "src",
        "tests",
    ),
    (
        "uv",
        "run",
        "basedpyright",
    ),
    (
        "uv",
        "run",
        "coverage",
        "run",
        "-m",
        "pytest",
    ),
    (
        "uv",
        "run",
        "coverage",
        "report",
    ),
    (
        "uv",
        "run",
        "pip-audit",
    ),
)


def run_command(command: Sequence[str]) -> int:
    """Run one gate command and preserve its exit code."""
    print(f"\n$ {' '.join(command)}", flush=True)
    return subprocess.run(command, check=False).returncode


def main(argv: Sequence[str]) -> int:
    """Resolve arguments before any gate command, then stop at the first failure.

    Only `-h`/`--help` are accepted, and an unrecognized argument outranks them:
    `check.py --typo --help` must fail rather than print usage and exit 0, or a
    mistyped CI invocation silently skips the whole gate. A `--` ends option
    parsing, so it and everything after it are positionals this script never
    accepts. No gate command runs on any of these paths.
    """
    arguments = list(argv)
    separator = arguments.index("--") if "--" in arguments else len(arguments)
    unrecognized = next(
        (
            argument
            for index, argument in enumerate(arguments)
            if index >= separator or argument not in {"-h", "--help"}
        ),
        None,
    )
    if unrecognized is not None:
        # Pre-split with a magic trailing comma: `ruff.line_length` accepts values
        # down to 79, and this call is 97 columns joined. Issue #115's original
        # 1.10 report had no per-root argv at all, so a low line_length was the
        # only way its managed script could fail its own formatter stage.
        print(
            f"scripts/check.py: error: unrecognized argument: {unrecognized}",
            file=sys.stderr,
        )
        print(USAGE, end="", file=sys.stderr)
        return 2
    if arguments:
        print(USAGE, end="")
        return 0
    for command in COMMANDS:
        if return_code := run_command(command):
            return return_code
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
