#!/usr/bin/env bash
#
# Open an interactive shell in the Linux build container, with the whole repo
# bind-mounted at /work. The Flutter project is /work/fluorite_app (that's the
# working directory you land in).
#
#   ./run.sh
#   # then, inside the container:
#   flutter pub get && flutter analyze && flutter test
#   flutter build linux --debug      # native path — see container/README.md
#
set -euo pipefail

IMAGE="${IMAGE:-fluorite-linux:latest}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"   # container/ -> fluorite_app/ -> repo root

command -v container >/dev/null 2>&1 || {
  echo "error: Apple's 'container' CLI not found — see build.sh for install notes." >&2
  exit 1
}

container system start >/dev/null 2>&1 || true
container images inspect "$IMAGE" >/dev/null 2>&1 || "$HERE/build.sh"

exec container run --rm -it \
  --volume "$REPO:/work" \
  --workdir /work/fluorite_app \
  "$IMAGE" bash
