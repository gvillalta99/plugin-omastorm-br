#!/usr/bin/env bash
# Prefer an installed toolchain; also support an isolated checkout-local one.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v cargo >/dev/null && [[ -x .tools/cargo/bin/cargo ]]; then
  export RUSTUP_HOME="$PWD/.tools/rustup" CARGO_HOME="$PWD/.tools/cargo"
  export PATH="$CARGO_HOME/bin:$PATH"
fi
exec cargo "$@"
