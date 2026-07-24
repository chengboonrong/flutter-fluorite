# Nintendo Switch 2 — Simulator, built with a Fluorite‑style 3D engine

An interactive, real‑time 3D simulation of the **Nintendo Switch 2**, created as
a study of **Fluorite**, Toyota's open‑source Flutter 3D engine.

There are two builds of the same scene:

| Build | Path | Renderer | Runs where |
|------|------|----------|------------|
| **Web (works today)** | [`web/index.html`](web/index.html) | Self‑contained **WebGL2** PBR pipeline, zero dependencies | Any modern browser |
| **Fluorite‑native (reference)** | [`fluorite_app/`](fluorite_app/) | **Toyota Fluorite** (Filament / Vulkan) via Flutter | Flutter SDK + Fluorite package |

Both describe the console the same way — an ECS‑style list of entities, each with
a transform, a mesh, and a PBR material — so the WebGL build is a faithful,
runnable stand‑in for the engine‑native one.

---

## What is Fluorite?

**Fluorite** is a console‑grade, open‑source **3D game engine built for Flutter**,
developed by **Toyota Connected North America** (Plano, Texas) and unveiled at
**FOSDEM 2026**. It exists because Toyota wanted rich 3D vehicle cockpits without
the proprietary blobs, weight, and licensing of Unity/Unreal, and found Godot too
heavy with slow start‑up for embedded automotive use.

Key facts that shaped this project:

- **It's a Flutter package, not a separate runtime.** Add one line to
  `pubspec.yaml` and you get a 3D engine. "Fluorite" is the project/demo name;
  the published Dart package is **`filament_scene`**
  ([toyota-connected/tcna-packages](https://github.com/toyota-connected/tcna-packages)).
  The scene is a **`SceneView` widget** — "lightweight, composable, put it
  anywhere" — so 3D and Flutter UI live in the same widget tree and share state.
- **Filament under the hood.** Rendering is Google's **Filament** engine, using
  modern GPU APIs (**Vulkan**) for physically based rendering, accurate lighting,
  post‑processing, and custom shaders — hardware‑accelerated, console‑grade
  visuals.
- **A data‑oriented C++ ECS core.** Game logic is written in **Dart**; the
  performance‑critical Entity‑Component‑System is C++, portable across mobile,
  desktop, embedded, and console targets.
- **glTF / GLB assets + Hot Reload.** Artists work in Blender and hand off
  `.gltf`/`.glb`; developers write interaction logic in Dart. Fluorite scenes
  support Flutter **Hot Reload**.
- **Multiple simultaneous views.** Several `SceneView`s can render the same
  scene from different cameras.

Built entirely on open foundations (Flutter, Dart, Filament) and proven on
Toyota's embedded stack (Flutter runtime, Yocto Linux, Wayland), with target
platforms spanning Android, iOS/macOS, Windows, Linux, and WebGL.

> Links in [Sources](#sources) below.

---

## The simulation

The scene models a Switch 2 from primitive meshes (rounded boxes, cylinders,
spheres) and shades them with a Cook‑Torrance‑lite PBR shader (GGX specular,
Fresnel, and a cheap image‑free hemisphere IBL) — the same shading model family
Filament/Fluorite use.

**Interact:**

- **Drag** to orbit · **scroll / pinch** to zoom
- **Handheld / Tabletop / Detached** — the Joy‑Con 2 controllers slide off and
  the kickstand hinges out, all eased per‑frame
- **Display** — power the OLED‑style screen on/off
- **Cycle app** — the display is a live texture: Switch 2 home menu (with a real
  clock + battery), Mario Kart World and Zelda splash screens, and System
  Settings
- **Auto‑orbit / Reset view**

The on‑screen **Scene** panel reports the live mode, Joy‑Con attach state, draw
calls, and FPS.

### Run the web build

It's a single self‑contained file — no build step, no dependencies:

```bash
# either just open it…
open web/index.html
# …or serve it (recommended so nothing is cached oddly)
python3 -m http.server -d web 8000   # then visit http://localhost:8000
```

### Run the Fluorite‑native build

[`fluorite_app/`](fluorite_app/) is a real Flutter project coded against the
**actual `filament_scene` API** (read from
[toyota-connected/tcna-packages](https://github.com/toyota-connected/tcna-packages)).
It maps 1:1 to the web scene:
[`lib/switch2_scene.dart`](fluorite_app/lib/switch2_scene.dart) builds the same
entities the WebGL `buildEntities()` does, using the engine's real types —
`SceneView`, `Scene`, `Cube`, `Camera` (orbit rig), `Light`, `Material` /
`MaterialParameter`, and `SceneController`.

How it uses the engine:

- The whole 3D world is one **`SceneView`** widget; the console is a hierarchy
  of **`Cube`** entities parented through `parentId` (the body is the root, so a
  single rotation turntables the whole thing while Joy-Cons keep local offsets).
- **`Camera`** is Fluorite's orbit rig (`orbitDistance` / `orbitAngles`); the
  engine handles drag-to-orbit and pinch-to-zoom natively.
- Mode/detach/kickstand are eased each frame by a Flutter **`Ticker`** that
  writes `setLocalPosition` / `setLocalRotation` + `updateTransform()` into the
  ECS; display power/app swaps rebuild the screen material and push it via
  `SceneController.updateFilamentScene(...)`.

```bash
cd fluorite_app
# 1) pin filament_scene to a known-good ref in pubspec.yaml
# 2) copy lit.filmat / unlit.filmat into assets/materials/ and an .hdr into
#    assets/envs/ (both ship with the filament_scene example)
flutter pub get
flutter run            # Android / desktop / embedded (native Filament view)
```

> **Heads‑up:** `filament_scene` is early-stage and its native Filament view
> compiles per platform (and depends on compiled `.filmat` material blobs +
> an IBL `.hdr`). This project was authored in a Node-only environment without
> the Flutter SDK, so the Flutter build is **written against the real, read
> API** but has not been compiled here — provide the assets and pin the package
> ref before running. The **web build is the fully working, verified
> deliverable.**

---

## Project layout

```
web/index.html              Working WebGL2 simulator (self-contained)
fluorite_app/
  pubspec.yaml              Flutter + filament_scene (git) dependency
  lib/main.dart             SceneView + Ticker loop + Flutter UI overlay
  lib/switch2_scene.dart    ECS scene: Cube entities, materials, mode animation
  assets/materials/         (lit.filmat / unlit.filmat go here)
  assets/envs/              (IBL .hdr goes here)
  assets/models/            (optional GLB upgrades)
```

---

## Sources

- Open Source For You — *Toyota Builds Open Source Fluorite Engine To Power Console‑Grade Car Cockpits* — https://www.opensourceforu.com/2026/02/toyota-builds-open-source-fluorite-engine-to-power-console-grade-car-cockpits/
- Phoronix — *Toyota Developing A Console‑Grade, Open‑Source Game Engine – Using Flutter & Dart* — https://www.phoronix.com/news/Fluorite-Toyota-Game-Engine
- Techzine — *Toyota drives development of open source game engine* — https://www.techzine.eu/blogs/applications/138584/toyota-drives-development-of-open-source-game-engine/
- Holdapp — *3D Games Coming Soon to Flutter: Meet Fluorite Engine* — https://www.holdapp.com/blog/flutter-3d-games-fluorite-engine
- Fluorite — official site — https://fluorite.game/
- Fluorite / `filament_scene` — source (GitHub) — https://github.com/toyota-connected/tcna-packages

---

*This is a fan/educational project and is not affiliated with Nintendo or Toyota.
"Nintendo Switch" and game titles are trademarks of their respective owners.*
