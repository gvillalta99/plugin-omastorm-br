#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export OMASTORM_ROOT="$PWD"
# Plugin bootstrap: no build and no second Quickshell process. A checkout
# with a debug engine stays offline. Otherwise the pinned release installer
# fetches once, verifies the committed sha256, and installs under
# $XDG_DATA_HOME/omastorm/bin (DESIGN.md, distribution).
if [[ ${1:-} == --ensure ]]; then
  # The plugin bootstrap runs detached; its stderr goes to the log it names.
  if [[ -n ${OMASTORM_BOOTSTRAP_LOG:-} ]]; then
    mkdir -p "$(dirname "$OMASTORM_BOOTSTRAP_LOG")"
    exec 2> "$OMASTORM_BOOTSTRAP_LOG"
  fi
  if [[ -x target/debug/omastorm-engine ]]; then
    exec target/debug/omastorm-engine ensure
  fi
  engine=$(bash scripts/install-engine.sh --print-path)
  exec "$engine" ensure
fi
if [[ ! -f ui/shaders/radar.frag.qsb || ! -f ui/shaders/tile.frag.qsb ]]; then
  echo 'Missing shader packages. Run bash scripts/build-shader.sh (see data/README.md).' >&2
  exit 1
fi
# Launch is strictly offline. Fetch build dependencies explicitly during setup.
bash scripts/cargo.sh build --offline --locked --quiet
target/debug/omastorm-engine ensure
exec quickshell -p "${OMASTORM_QML:-ui/shell.qml}" "$@"
