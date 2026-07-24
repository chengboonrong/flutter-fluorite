# Linux container for the Fluorite‑native build (Apple `container`)

The Fluorite engine (`filament_scene`) is **Linux‑only**, so on a Mac the
engine‑native app in [`fluorite_app/`](../) can't be built directly. This folder
packages the exact Linux toolchain the CI uses into a container you drive with
**[Apple `container`](https://github.com/apple/container)** — Apple's native tool
for running Linux containers on Apple‑silicon Macs.

## Why Linux only?

`filament_scene`'s own `pubspec.yaml` declares a Flutter plugin for a single
platform:

```yaml
flutter:
  plugin:
    platforms:
      linux:
        package: com.toyotaconnected.filament_scene
        pluginClass: FilamentViewPlugin
```

There is **no `android`, `ios`, `macos`, or `web` plugin entry**, and the native
engine core isn't even in the package — it lives in
[`toyota-connected/ivi-homescreen-plugins` → `filament_view` (v2.0)](https://github.com/toyota-connected/ivi-homescreen-plugins/tree/v2.0/plugins/filament_view),
which targets **embedded Linux / Wayland**. So:

| Target | Dart compiles? | Fluorite render path? |
|--------|:---:|:---:|
| **Linux** | ✅ | ✅ (this container) |
| web / android / ios / macos | ✅ (scaffolded) | ❌ no native plugin |

That's why `flutter build web` succeeds (the Dart compiles) even though the 3D
view only actually renders on Linux.

## Prerequisites

- An **Apple‑silicon Mac**, macOS 15+ (macOS 26 recommended).
- Apple's `container` CLI — install from the
  [releases page](https://github.com/apple/container/releases), then verify:

  ```sh
  container --version
  ```

## Usage

From this directory (`fluorite_app/container/`):

```sh
# 1. Build the image (Ubuntu 22.04 + Flutter 3.32.0 + Linux desktop toolchain).
#    Builds for the host architecture — `container` runs a native-arm64 Linux VM
#    on Apple silicon (no amd64 emulation), so the image is arm64 there. Flutter
#    is installed from git so it fetches the matching-arch Dart SDK + engine.
./build.sh

# 2a. Mirror GitHub Actions locally: pub get + analyze + test.
./ci.sh

# 2b. …or drop into an interactive shell with the repo mounted at /work.
./run.sh
#     you land in /work/fluorite_app; then, for example:
#       flutter pub get
#       flutter analyze --no-fatal-infos
#       flutter test
#       # flutter build linux — see the ivi-homescreen caveat below
```

The whole repo is bind‑mounted (`--volume <repo>:/work`), so edits on the Mac
are visible instantly in the container and build output lands back on the host —
no rebuild of the image when you change code. Override the image tag with
`IMAGE=my/tag ./build.sh` (the run/ci scripts honour the same variable).

## `flutter build linux` and the ivi‑homescreen caveat

Linux desktop **is** enabled on this project (there is a `linux/` runner), and
`flutter pub get` / `analyze` / `test` all run cleanly in the container — that's
the path `./ci.sh` exercises and what CI verifies.

`flutter build linux`, however, currently **fails at CMake configuration** with
this version of `filament_scene`:

```
CMake Error at flutter/generated_plugins.cmake:
  add_subdirectory given source
  ".plugin_symlinks/filament_scene/linux" which is not an existing directory.
```

The reason: `filament_scene` declares a `linux` plugin in its `pubspec.yaml` but
**ships no `linux/` CMake directory**. Its native side is delivered through
ivi‑homescreen's [`filament_view`](https://github.com/toyota-connected/ivi-homescreen-plugins/tree/v2.0/plugins/filament_view)
embedder — a Wayland compositor runtime — **not** as a standard `flutter build
linux` (GTK) desktop plugin. So the engine‑native app is meant to run under
**ivi‑homescreen**, not `flutter run -d linux`, and even there it additionally
needs the compiled `.filmat` material blobs + an IBL `.hdr` and a real GPU/display
(a headless container has neither).

This is why CI stops at `analyze` + `test`: they type‑check the Dart against the
real engine API without needing the native build, which the standard Flutter
desktop toolchain can't produce for this package yet.

For a fully interactive experience with zero setup, use the WebGL build at
[`web/index.html`](../../web/index.html).
