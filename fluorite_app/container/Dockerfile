# Linux build environment for the Fluorite-native Switch 2 app.
#
# Why this exists
# ---------------
# The `filament_scene` engine (Toyota "Fluorite") declares a Flutter plugin for
# **linux only** — its pubspec has no android / ios / macos / web plugin entry,
# and its native core lives in toyota-connected/ivi-homescreen-plugins
# (filament_view, v2.0), which targets embedded Linux/Wayland. The engine-native
# app can therefore only be *built* on Linux. On macOS you need a Linux
# container; this image is meant to be driven by Apple's `container` tool
# (https://github.com/apple/container) via the scripts next to this Dockerfile.
#
# It is pinned to the same Flutter the GitHub Actions CI uses (3.32.0 / Dart 3.8).
# The image builds for the host's native architecture — Apple's `container` runs
# a native-arm64 Linux VM on Apple-silicon Macs and does not emulate amd64, so a
# forced linux/amd64 image fails to exec (ENOEXEC). Flutter is therefore
# installed via git (not the x86_64-only release tarball) so the flutter tool can
# fetch the matching-arch Dart SDK + engine on both arm64 and amd64 hosts.
FROM ubuntu:22.04

ARG FLUTTER_VERSION=3.32.0
ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH

# --- Toolchain --------------------------------------------------------------
# curl/git/unzip/xz/zip : fetch + unpack the SDK, and Flutter's own tooling.
# clang/cmake/ninja/pkg-config + libgtk-3-dev/liblzma-dev/libstdc++-12-dev :
#     Flutter Linux desktop build toolchain (per flutter.dev/desktop).
# GL / Vulkan / Wayland dev libs : the Filament (filament_view) native render
#     path — present so the engine core can compile. Actually *rendering* still
#     needs a real GPU / display at run time.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip \
      build-essential clang cmake ninja-build pkg-config \
      libgtk-3-dev liblzma-dev libstdc++-12-dev \
      libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev \
      libvulkan-dev mesa-vulkan-drivers vulkan-tools \
      libwayland-dev wayland-protocols libxkbcommon-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Flutter SDK (pinned to match CI) ---------------------------------------
# Cloned at the release tag rather than downloaded as the x86_64-only tarball,
# so this builds natively on arm64 and amd64 alike; the first `flutter` call
# below fetches the host-arch Dart SDK + engine artifacts.
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" \
      https://github.com/flutter/flutter.git "$FLUTTER_HOME"

# Flutter runs git against its own repo, and the repo is bind-mounted at run
# time under a different uid; git (and therefore Flutter) refuse such checkouts
# unless they are marked safe.
RUN git config --global --add safe.directory '*'

# Enable the Linux desktop target and warm the caches once, at build time, so
# the first `flutter` call in a run is fast. `doctor` will note the missing
# display/Android tooling — expected in a headless build container.
RUN flutter config --enable-linux-desktop --no-analytics \
    && flutter precache --linux --universal \
    && flutter doctor -v || true

WORKDIR /work
CMD ["bash"]
