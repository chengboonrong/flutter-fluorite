#!/usr/bin/env bash
#
# Run the same checks GitHub Actions runs, but locally inside the Linux
# container: pub get -> analyze -> test, on the same Flutter 3.32.0. Handy on a
# Mac, where the Fluorite (filament_scene) plugin can't be built natively.
#
#   ./ci.sh
#
set -euo pipefail

IMAGE="${IMAGE:-fluorite-linux:latest}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"

command -v container >/dev/null 2>&1 || {
  echo "error: Apple's 'container' CLI not found — see build.sh for install notes." >&2
  exit 1
}

container system start >/dev/null 2>&1 || true
container images inspect "$IMAGE" >/dev/null 2>&1 || "$HERE/build.sh"

container run --rm \
  --volume "$REPO:/work" \
  --workdir /work/fluorite_app \
  "$IMAGE" bash -lc '
    set -e
    flutter --version
    flutter pub get
    flutter analyze --no-fatal-infos
    flutter test
    echo
    echo "== analyze + test passed =="
    echo "For the native render path, inside the container run:"
    echo "  flutter build linux --debug"
    echo "(needs the ivi-homescreen filament_view runtime + a GPU/display — see container/README.md)"
  '
