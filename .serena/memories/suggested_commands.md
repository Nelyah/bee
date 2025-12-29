# Suggested commands

## Build / run
- `cargo build`
- `cargo run -- help`
- `cargo run -- list`
- `cargo install --path crates/bee-cli`

## Formatting / linting / tests
- `cargo fmt`
- `cargo clippy --all-targets --all-features`
- `cargo test`
- `cargo test -p bee-core`
- `cargo test -p bee-actions`
- `cargo test -p bee-cli`
- `cargo test -- --nocapture`

## Migrations
- `cargo run -p migration -- up`
- `cargo run -p migration -- status`

## Coverage (optional)
- `./code_coverage.sh`
- `cargo tarpaulin --out Html`

## Useful macOS shell commands
- `ls`, `pwd`, `cd`
- `rg <pattern> <path>` for fast search
- `git status -sb`, `git diff`, `git log --oneline`
