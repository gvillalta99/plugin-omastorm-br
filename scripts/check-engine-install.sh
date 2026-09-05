#!/usr/bin/env bash
# Installer and pin (DESIGN.md, distribution): hash verify, refuse a
# mismatch, install under a scratch XDG_DATA_HOME, skip a current dest,
# reject an unsupported machine, keep ordinary launch and a checkout
# --ensure off the installer. Uses a scratch pin and the debug engine so
# check.sh does not need a release rebuild. When target/dist matches the
# committed pin, that asset is installed too.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { printf '%s\n' "$@" >&2; exit 1; }
[[ -x target/debug/omastorm-engine ]] || fail 'Need target/debug/omastorm-engine (check.sh builds it).'

scratch=$(mktemp -d /tmp/omastorm-engine-install.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
export XDG_DATA_HOME="$scratch/data" XDG_CACHE_HOME="$scratch/cache" XDG_RUNTIME_DIR="$scratch/runtime"
mkdir -p "$XDG_RUNTIME_DIR"
debug=$PWD/target/debug/omastorm-engine
sum=$(sha256sum -- "$debug" | awk '{print $1}')
pin=$scratch/release.pin
cat > "$pin" <<PIN
tag=engine-test
repo=wesleygrimes/omastorm
asset=omastorm-engine-x86_64-unknown-linux-gnu
sha256=$sum
PIN
export OMASTORM_ENGINE_PIN=$pin
dest=$XDG_DATA_HOME/omastorm/bin/omastorm-engine
install_cmd=(bash scripts/install-engine.sh)

# A substituted file is refused and leaves no dest.
printf 'not-the-engine' > "$scratch/bogus"
if OMASTORM_ENGINE_ASSET="$scratch/bogus" "${install_cmd[@]}" 2>"$scratch/mismatch.err"; then
  fail 'Installer accepted a sha256 mismatch'
fi
rg -q 'sha256 mismatch' "$scratch/mismatch.err" || fail "Mismatch error was unclear: $(cat "$scratch/mismatch.err")"
[[ ! -e $dest ]] || fail 'Mismatch wrote a dest'

# Matching asset installs, is executable, and hashes to the pin.
OMASTORM_ENGINE_ASSET="$debug" "${install_cmd[@]}"
[[ -x $dest ]] || fail 'Installer did not write an executable dest'
[[ $(sha256sum -- "$dest" | awk '{print $1}') == "$sum" ]] || fail 'Installed dest does not match the pin'
path=$(OMASTORM_ENGINE_ASSET="$debug" bash scripts/install-engine.sh --print-path)
[[ $path == "$dest" ]] || fail "--print-path: $path"

# A dest that already matches is left alone; no asset and no download.
unset OMASTORM_ENGINE_ASSET
bash scripts/install-engine.sh

# The curl path (file://, no GitHub) verifies and installs too.
rm -f "$dest"
OMASTORM_ENGINE_URL="file://$debug" bash scripts/install-engine.sh
[[ -x $dest && $(sha256sum -- "$dest" | awk '{print $1}') == "$sum" ]] || fail 'file:// install did not match the pin'

# A stale dest is replaced when a matching asset is supplied.
printf 'stale' > "$dest"
chmod 755 -- "$dest"
OMASTORM_ENGINE_ASSET="$debug" bash scripts/install-engine.sh
[[ $(sha256sum -- "$dest" | awk '{print $1}') == "$sum" ]] || fail 'Stale dest was not replaced'

# aarch64 is named, not fetched.
if OMASTORM_ENGINE_MACHINE=aarch64 bash scripts/install-engine.sh 2>"$scratch/arch.err"; then
  fail 'Installer accepted aarch64'
fi
rg -q 'aarch64 is deferred' "$scratch/arch.err" || fail "Arch error was unclear: $(cat "$scratch/arch.err")"

# Checkout --ensure uses the debug engine and does not write the data home.
rm -rf "$XDG_DATA_HOME"
bash run.sh --ensure
[[ ! -e $dest ]] || fail 'Checkout --ensure wrote the release dest'
timeout 2 socat -t0.2 - "UNIX-CONNECT:$XDG_RUNTIME_DIR/omastorm/engine.sock" < /dev/null | rg -q '"type":"hello"' \
  || fail 'Checkout --ensure did not produce a hello'
target/debug/omastorm-engine stop >/dev/null

# A tree without target/debug installs from the asset and ensures.
clone=$scratch/clone
mkdir -p "$clone"
git archive HEAD | tar -x -C "$clone"
# Working tree: this check runs before the packaging commit is on HEAD.
mkdir -p "$clone/scripts" "$clone/engine"
cp -- run.sh "$clone/run.sh"
cp -- scripts/install-engine.sh "$clone/scripts/install-engine.sh"
install -D -m 644 "$pin" "$clone/engine/release.pin"
rm -rf "$clone/target"
export OMASTORM_ENGINE_ASSET=$debug OMASTORM_ENGINE_PIN=$clone/engine/release.pin
(cd "$clone" && bash run.sh --ensure)
[[ -x $dest ]] || fail 'Clone --ensure did not install the engine'
timeout 2 socat -t0.2 - "UNIX-CONNECT:$XDG_RUNTIME_DIR/omastorm/engine.sock" < /dev/null | rg -q '"type":"hello"' \
  || fail 'Clone --ensure did not produce a hello'
"$dest" stop >/dev/null

# Committed pin, if present, is well formed; the dist asset must match when it exists.
if [[ -f engine/release.pin ]]; then
  committed=$(awk -F= '/^sha256=/{print $2}' engine/release.pin)
  [[ $committed =~ ^[a-f0-9]{64}$ ]] || fail 'Committed pin sha256 is not 64 lowercase hex digits'
  dist=target/dist/omastorm-engine-x86_64-unknown-linux-gnu
  if [[ -f $dist ]]; then
    [[ $(sha256sum -- "$dist" | awk '{print $1}') == "$committed" ]] \
      || fail "$dist does not match engine/release.pin"
    unset OMASTORM_ENGINE_PIN
    export OMASTORM_ENGINE_ASSET=$dist OMASTORM_ENGINE_PIN=$PWD/engine/release.pin
    rm -f "$dest"
    bash scripts/install-engine.sh
    [[ $(sha256sum -- "$dest" | awk '{print $1}') == "$committed" ]] \
      || fail 'Committed-pin install did not match'
  fi
fi

echo 'Engine install: pin verify, mismatch refuse, dest install, skip current, replace stale, arch, checkout --ensure, clone --ensure PASS'
