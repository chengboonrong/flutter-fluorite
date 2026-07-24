#!/usr/bin/env bash
#
# Build the Linux toolchain image with Apple's `container`
# (https://github.com/apple/container). Safe to run from anywhere.
#
#   ./build.sh                 # builds fluorite-linux:latest
#   IMAGE=my/tag ./build.sh    # override the tag
#
set -euo pipefail

IMAGE="${IMAGE:-fluorite-linux:latest}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v container >/dev/null 2>&1; then
  echo "error: Apple's 'container' CLI was not found on PATH." >&2
  echo "       Install it from https://github.com/apple/container/releases" >&2
  echo "       (requires an Apple-silicon Mac, macOS 15+; macOS 26 recommended)." >&2
  exit 1
fi

# The container system (helper services) must be running before build/run.
container system start >/dev/null 2>&1 || true

echo ">> Building $IMAGE for linux/amd64 (Flutter 3.32.0) ..."
container build --tag "$IMAGE" --file "$HERE/Dockerfile" "$HERE"

echo
echo ">> Done. Next steps:"
echo "     $HERE/ci.sh     # mirror GitHub Actions: pub get + analyze + test"
echo "     $HERE/run.sh    # interactive shell in the Linux container"
