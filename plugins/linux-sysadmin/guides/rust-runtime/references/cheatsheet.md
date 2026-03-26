# Rust Runtime Cheatsheet

## Cargo Command Reference

### Project Lifecycle

| Task | Command |
|------|---------|
| Create binary project | `cargo new myproject` |
| Create library project | `cargo new --lib mylib` |
| Initialize in existing dir | `cargo init` |
| Build (debug) | `cargo build` |
| Build (release) | `cargo build --release` |
| Run | `cargo run` |
| Run with args | `cargo run -- --port 8080` |
| Check (fast, no codegen) | `cargo check` |
| Clean | `cargo clean` |
| Update lockfile | `cargo update` |

### Testing and Quality

| Task | Command |
|------|---------|
| Run all tests | `cargo test` |
| Run specific test | `cargo test test_name` |
| Run tests in module | `cargo test module::` |
| Run doc tests only | `cargo test --doc` |
| Show test output | `cargo test -- --nocapture` |
| Run ignored tests | `cargo test -- --ignored` |
| Run benchmarks | `cargo bench` |
| Lint with clippy | `cargo clippy` |
| Clippy (warnings = errors) | `cargo clippy -- -D warnings` |
| Clippy (all targets) | `cargo clippy --all-targets --all-features` |
| Format code | `cargo fmt` |
| Check formatting (CI) | `cargo fmt --check` |
| Generate docs | `cargo doc` |
| Open docs in browser | `cargo doc --open` |
| Audit for CVEs | `cargo audit` |

### Dependencies

| Task | Command |
|------|---------|
| Add dependency | `cargo add serde` |
| Add with version constraint | `cargo add serde@1.0` |
| Add with features | `cargo add serde --features derive` |
| Add dev dependency | `cargo add --dev tokio-test` |
| Add build dependency | `cargo add --build cc` |
| Remove dependency | `cargo remove serde` |
| Show dependency tree | `cargo tree` |
| Find why crate is included | `cargo tree -i serde` |
| Show outdated deps | `cargo outdated` (install: `cargo install cargo-outdated`) |

### Publishing

| Task | Command |
|------|---------|
| Login to crates.io | `cargo login` |
| Package (dry run) | `cargo package` |
| List packaged files | `cargo package --list` |
| Publish | `cargo publish` |
| Yank a version | `cargo yank --version 1.0.0` |

### Install & Tools

| Task | Command |
|------|---------|
| Install binary crate | `cargo install ripgrep` |
| Install specific version | `cargo install ripgrep@14.0.0` |
| Install from local path | `cargo install --path .` |
| List installed | `cargo install --list` |
| Uninstall | `cargo uninstall ripgrep` |

## Rustup Workflow

```
1. Install rustup         → curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
2. Reload PATH            → source "$HOME/.cargo/env"
3. Verify                 → rustc --version && cargo --version
4. Update toolchains      → rustup update
5. Add nightly            → rustup toolchain install nightly
6. Set project toolchain  → create rust-toolchain.toml
7. Add cross target       → rustup target add aarch64-unknown-linux-gnu
8. Add components         → rustup component add rust-analyzer
```

Priority order (highest wins): `+channel` flag > `RUSTUP_TOOLCHAIN` env var > `rust-toolchain.toml` file > directory override (`rustup override set`) > default (`rustup default`).

## rust-toolchain.toml

Pin toolchain per project. Place in project root.

```toml
[toolchain]
channel = "stable"
# Or pin a specific version:
# channel = "1.82.0"
# Or use nightly with a date:
# channel = "nightly-2026-03-01"

# Components to install automatically
components = ["rustfmt", "clippy", "rust-analyzer"]

# Cross-compilation targets to install
targets = ["x86_64-unknown-linux-musl", "aarch64-unknown-linux-gnu"]

# Override default profile (minimal, default, complete)
profile = "default"
```

## .cargo/config.toml

Per-project or global Cargo configuration.

```toml
# Per-project: .cargo/config.toml
# Global: ~/.cargo/config.toml

# Cross-compilation linker for ARM64
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

[target.x86_64-unknown-linux-musl]
linker = "musl-gcc"

# Default target (compile for this target without --target flag)
[build]
# target = "x86_64-unknown-linux-musl"

# Use sccache for faster rebuilds
[build]
# rustc-wrapper = "sccache"

# Faster linking on Linux (mold linker)
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
```

## Cross-Compilation Setup

### Static Linux binary (musl)
```bash
# Install musl toolchain
sudo apt install musl-tools

# Add target
rustup target add x86_64-unknown-linux-musl

# Build
cargo build --release --target x86_64-unknown-linux-musl

# Binary is at: target/x86_64-unknown-linux-musl/release/myapp
# Verify static: ldd target/x86_64-unknown-linux-musl/release/myapp
# Should say: "not a dynamic executable" (fully static)
```

### ARM64 cross-compilation
```bash
# Install cross linker
sudo apt install gcc-aarch64-linux-gnu

# Add target
rustup target add aarch64-unknown-linux-gnu

# Configure linker in .cargo/config.toml
# [target.aarch64-unknown-linux-gnu]
# linker = "aarch64-linux-gnu-gcc"

# Build
cargo build --release --target aarch64-unknown-linux-gnu
```

### Using cross (Docker-based, easiest)
```bash
# Install cross
cargo install cross

# Build for ARM64 (uses Docker, no manual linker setup)
cross build --release --target aarch64-unknown-linux-gnu
cross build --release --target aarch64-unknown-linux-musl

# Run tests on the target platform (in Docker)
cross test --target aarch64-unknown-linux-gnu
```

## Key Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `RUSTUP_HOME` | rustup data directory | `~/.rustup` |
| `CARGO_HOME` | Cargo data directory | `~/.cargo` |
| `RUST_BACKTRACE` | Show backtraces on panic (1 = short, full = verbose) | unset |
| `RUST_LOG` | Log level for `env_logger` / `tracing` crates | unset |
| `RUSTFLAGS` | Extra flags passed to rustc | unset |
| `CARGO_TARGET_DIR` | Override build output directory | `./target` |
| `CARGO_INCREMENTAL` | Enable/disable incremental compilation (1/0) | `1` |
| `RUSTUP_TOOLCHAIN` | Override active toolchain | unset |
| `CARGO_REGISTRIES_CRATES_IO_PROTOCOL` | Registry protocol (sparse = faster) | `sparse` |
| `CC` / `CXX` | C/C++ compiler for build scripts | system default |

## CI Patterns

### GitHub Actions

```yaml
- uses: dtolnay/rust-toolchain@stable
  with:
    components: clippy, rustfmt

- run: cargo fmt --check
- run: cargo clippy --all-targets -- -D warnings
- run: cargo test
- run: cargo build --release
```

### Caching

```yaml
- uses: Swatinem/rust-cache@v2
  # Caches ~/.cargo/registry, ~/.cargo/git, and target/
  # Key includes Cargo.lock hash for automatic invalidation
```

## Popular cargo-install Tools

| Tool | Install | Purpose |
|------|---------|---------|
| ripgrep | `cargo install ripgrep` | Fast recursive search (rg) |
| fd-find | `cargo install fd-find` | Fast file finder (fd) |
| bat | `cargo install bat` | cat with syntax highlighting |
| tokei | `cargo install tokei` | Count lines of code |
| cargo-audit | `cargo install cargo-audit` | CVE checks on dependencies |
| cargo-outdated | `cargo install cargo-outdated` | Show outdated deps |
| cargo-watch | `cargo install cargo-watch` | Auto-rebuild on file changes |
| cargo-expand | `cargo install cargo-expand` | Show expanded macros |
| cargo-nextest | `cargo install cargo-nextest` | Faster test runner |
| cross | `cargo install cross` | Docker-based cross-compilation |
| sccache | `cargo install sccache` | Shared compilation cache |
