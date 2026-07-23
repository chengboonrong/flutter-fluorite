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
  `pubspec.yaml` and you get a 3D engine. The scene is a **`FluoriteView`
  widget** — "lightweight, composable, put it anywhere" — so 3D and Flutter UI
  live in the same widget tree and share state.
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
- **Multiple simultaneous views.** Several `FluoriteView`s can render the same
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

[`fluorite_app/`](fluorite_app/) is a real Flutter project structured around
Fluorite's documented API. It maps 1:1 to the web scene:
[`lib/switch2_scene.dart`](fluorite_app/lib/switch2_scene.dart) builds the same
entities the WebGL `buildEntities()` does.

```bash
cd fluorite_app
flutter pub get
flutter run            # or: flutter run -d chrome
```

> **Heads‑up:** Fluorite is an early‑stage package (0.0.x) whose native engine
> compiles per platform. This project was authored in a Node‑only environment
> without the Flutter SDK, so the Fluorite build is provided as a faithful
> **reference** against the published API rather than a CI‑verified binary — pin
> the package to a known‑good ref and provide the screen textures under
> `assets/models/` before running. The **web build is the fully working,
> verified deliverable.**

---

## Project layout

```
web/index.html              Working WebGL2 simulator (self-contained)
fluorite_app/
  pubspec.yaml              Flutter + fluorite dependency
  lib/main.dart             FluoriteView + Flutter UI overlay
  lib/switch2_scene.dart    ECS scene: entities, materials, mode animation
  assets/models/            (screen textures / GLB assets go here)
```

---

## Sources

- Open Source For You — *Toyota Builds Open Source Fluorite Engine To Power Console‑Grade Car Cockpits* — https://www.opensourceforu.com/2026/02/toyota-builds-open-source-fluorite-engine-to-power-console-grade-car-cockpits/
- Phoronix — *Toyota Developing A Console‑Grade, Open‑Source Game Engine – Using Flutter & Dart* — https://www.phoronix.com/news/Fluorite-Toyota-Game-Engine
- Techzine — *Toyota drives development of open source game engine* — https://www.techzine.eu/blogs/applications/138584/toyota-drives-development-of-open-source-game-engine/
- Holdapp — *3D Games Coming Soon to Flutter: Meet Fluorite Engine* — https://www.holdapp.com/blog/flutter-3d-games-fluorite-engine
- Fluorite — official site — https://fluorite.game/
- Fluorite — pub.dev package — https://pub.dev/packages/fluorite

---

*This is a fan/educational project and is not affiliated with Nintendo or Toyota.
"Nintendo Switch" and game titles are trademarks of their respective owners.*
