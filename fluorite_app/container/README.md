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
#       flutter build linux --debug
```

The whole repo is bind‑mounted (`--volume <repo>:/work`), so edits on the Mac
are visible instantly in the container and build output lands back on the host —
no rebuild of the image when you change code. Override the image tag with
`IMAGE=my/tag ./build.sh` (the run/ci scripts honour the same variable).

## Native render path caveat

`flutter build linux` compiles the Dart and the plugin, but a *running* 3D view
additionally needs:

- the **`filament_view`** native runtime from ivi‑homescreen, and its compiled
  `.filmat` material blobs + an IBL `.hdr` (see the notes in the project
  [`README`](../../README.md#run-the-fluorite-native-build)), and
- a real **GPU / display** — a headless container has neither, so treat
  `build linux` here as a compile check, and run the actual window on a Linux
  host with a GPU (or an X/Wayland display forwarded in).

For a fully interactive experience with zero setup, use the WebGL build at
[`web/index.html`](../../web/index.html).
