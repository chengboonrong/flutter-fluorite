import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

// The Fluorite package surface used below (FluoriteView, Scene, Entity,
// Transform, MeshBuilder, PbrMaterial, DirectionalLight, PerspectiveCamera,
// OrbitController, System) follows Toyota Connected's documented model:
// a Flutter widget backed by a data-oriented C++ ECS, Filament for rendering,
// and glTF/GLB for assets. Types are imported here so the file reads as a real
// integration; pin the package in pubspec.yaml before building locally.
import 'package:fluorite/fluorite.dart';

/// The four "scenes" the display can show. In a shipped build these would be
/// separate render targets or textures; here each is a material swap on the
/// screen entity, mirroring the WebGL build's canvas-texture approach.
enum DisplayApp { home, marioKart, zelda, settings }

/// Physical configuration of the console, matching the WebGL simulator.
enum ConsoleMode {
  handheld('Handheld'),
  tabletop('Tabletop'),
  detached('Detached');

  const ConsoleMode(this.label);
  final String label;
}

/// The Flutter widget that hosts the 3D scene. This is the *only* place the
/// engine touches the widget tree — everything else is data.
class Switch2SceneView extends StatelessWidget {
  const Switch2SceneView({
    super.key,
    required this.controller,
    required this.onReady,
  });

  final Switch2Controller controller;
  final void Function(Scene scene) onReady;

  @override
  Widget build(BuildContext context) {
    // A FluoriteView is a normal Widget: "lightweight, composable, put it
    // anywhere." Multiple FluoriteViews can even share one Scene to render the
    // same world from different cameras.
    return FluoriteView(
      controller: controller.engine,
      onSceneReady: onReady,
      // Drag to orbit, pinch/scroll to dolly — handled by the engine's input.
      cameraController: controller.orbit,
    );
  }
}

/// Drives the scene: builds entities, animates mode transitions, swaps the
/// display material, and exposes a live FPS value to the Flutter overlay.
class Switch2Controller {
  Switch2Controller();

  /// Backing engine controller for the [FluoriteView].
  final FluoriteController engine = FluoriteController();

  /// Orbit camera the view binds its gestures to.
  final OrbitCameraController orbit = OrbitCameraController(
    target: Vector3(0, 0.2, 0),
    distance: 15.5,
    theta: -0.5,
    phi: 1.15,
    minDistance: 8,
    maxDistance: 30,
    autoOrbit: true,
    autoOrbitSpeed: 0.28,
  );

  /// FPS surfaced to the info panel; the engine ticks this each frame.
  final ValueNotifier<int> frameRate = ValueNotifier<int>(0);

  late Scene _scene;

  // Entities we animate after construction.
  Entity? _leftJoyCon;
  Entity? _rightJoyCon;
  Entity? _kickstand;
  Entity? _screen;

  DisplayApp _app = DisplayApp.home;
  bool _powered = true;

  // ---- Palette (linear-ish PBR base colors), matched to the WebGL build ----
  static final _bodyBlack = PbrMaterial(baseColor: Color(0xFF0E1013), metallic: 0.15, roughness: 0.42, clearCoat: 0.6);
  static final _joyLeft   = PbrMaterial(baseColor: Color(0xFF068CC7), metallic: 0.05, roughness: 0.45, clearCoat: 0.5);
  static final _joyRight  = PbrMaterial(baseColor: Color(0xFFEB2933), metallic: 0.05, roughness: 0.45, clearCoat: 0.5);
  static final _rail      = PbrMaterial(baseColor: Color(0xFF4D4F5C), metallic: 0.9,  roughness: 0.28);
  static final _stick     = PbrMaterial(baseColor: Color(0xFF0A0A0D), metallic: 0.1,  roughness: 0.6);
  static final _btnLight  = PbrMaterial(baseColor: Color(0xFFB8BCCC), metallic: 0.2,  roughness: 0.5);
  static final _btnDark   = PbrMaterial(baseColor: Color(0xFF1A1C21), metallic: 0.2,  roughness: 0.5);
  static final _metal     = PbrMaterial(baseColor: Color(0xFF8C919E), metallic: 0.95, roughness: 0.25);
  static final _glass     = PbrMaterial(baseColor: Color(0xFF050508), metallic: 0.0,  roughness: 0.08, clearCoat: 1.0);

  /// Called once when the engine hands us a live [Scene]. Builds the world.
  ///
  /// The structure is 1:1 with `buildEntities()` in /web/index.html — same
  /// meshes, same materials, same layout — so the two renderers stay in sync.
  void buildScene(Scene scene) {
    _scene = scene;

    // ---- Environment: image-based lighting + key/fill/rim directionals ----
    scene.setImageBasedLight(intensity: 30000, source: IblSource.studioSoft());
    scene.add(Entity('key')
      ..set(DirectionalLight(color: const Color(0xFFFFFAF0), intensity: 90000, direction: Vector3(-0.5, -0.9, -0.7))));
    scene.add(Entity('fill')
      ..set(DirectionalLight(color: const Color(0xFF8CADF2), intensity: 22000, direction: Vector3(0.8, -0.35, 0.5))));
    scene.add(Entity('rim')
      ..set(DirectionalLight(color: const Color(0xFFE68C8C), intensity: 14000, direction: Vector3(0.1, 0.4, 0.9))));

    scene.setCamera(PerspectiveCamera(fovDegrees: 50, near: 0.1, far: 100));

    // ---- Reusable meshes (rounded boxes / cylinders / spheres) ------------
    final bodyMesh = MeshBuilder.roundedBox(width: 9.4, height: 4.7, depth: 0.62, radius: 0.42);
    final screenMesh = MeshBuilder.roundedBox(width: 8.05, height: 3.9, depth: 0.02, radius: 0.16);
    final glassMesh = MeshBuilder.roundedBox(width: 8.55, height: 4.35, depth: 0.10, radius: 0.30);
    final joyMesh = MeshBuilder.roundedBox(width: 1.55, height: 4.7, depth: 0.62, radius: 0.42);
    final railMesh = MeshBuilder.roundedBox(width: 0.14, height: 4.2, depth: 0.30, radius: 0.05);
    final kickMesh = MeshBuilder.roundedBox(width: 3.6, height: 3.4, depth: 0.08, radius: 0.18);
    final stickMesh = MeshBuilder.cylinder(radiusTop: 0.34, radiusBottom: 0.40, height: 0.34);
    final btnMesh = MeshBuilder.sphere(radius: 0.20);
    final smallBtnMesh = MeshBuilder.sphere(radius: 0.13);
    final dpadMesh = MeshBuilder.roundedBox(width: 0.24, height: 0.72, depth: 0.14, radius: 0.05);
    final floorMesh = MeshBuilder.plane(width: 60, height: 60);

    // ---- Central tablet ---------------------------------------------------
    scene.add(Entity('floor')
      ..set(Transform(position: Vector3(0, -3.5, 0)))
      ..set(MeshInstance(floorMesh))
      ..set(PbrMaterial(baseColor: const Color(0xFF0D0F12), roughness: 0.9)));

    scene.add(Entity('body')..set(Transform())..set(MeshInstance(bodyMesh))..set(_bodyBlack));
    scene.add(Entity('glass')
      ..set(Transform(position: Vector3(0, 0, 0.30)))
      ..set(MeshInstance(glassMesh))
      ..set(_glass));

    // Emissive display; its material is swapped by [_applyDisplay].
    _screen = Entity('screen')
      ..set(Transform(position: Vector3(0, 0, 0.37)))
      ..set(MeshInstance(screenMesh));
    scene.add(_screen!);
    _applyDisplay();

    // Power + volume buttons on the top edge.
    for (final x in const [-1.0, -1.7, -2.3]) {
      scene.add(Entity('edgeBtn$x')
        ..set(Transform(position: Vector3(x, 2.42, 0.0), rotation: Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2)))
        ..set(MeshInstance(MeshBuilder.cylinder(radiusTop: 0.12, radiusBottom: 0.12, height: 0.10)))
        ..set(_metal));
    }

    // ---- Kickstand (starts folded, hinges out for tabletop/detached) ------
    _kickstand = Entity('kickstand')
      ..set(Transform(position: Vector3(0, -1.2, -0.32)))
      ..set(MeshInstance(kickMesh))
      ..set(_bodyBlack)
      ..enabled = false;
    scene.add(_kickstand!);

    // ---- Joy-Cons ---------------------------------------------------------
    _leftJoyCon = _buildJoyCon(scene, side: -1, joyMesh: joyMesh, railMesh: railMesh, stickMesh: stickMesh, btnMesh: btnMesh, smallBtnMesh: smallBtnMesh, dpadMesh: dpadMesh);
    _rightJoyCon = _buildJoyCon(scene, side: 1, joyMesh: joyMesh, railMesh: railMesh, stickMesh: stickMesh, btnMesh: btnMesh, smallBtnMesh: smallBtnMesh, dpadMesh: dpadMesh);

    // ---- Systems: drive per-frame animation + FPS readout -----------------
    scene.addSystem(_ModeAnimationSystem(this));
    scene.addSystem(FrameStatsSystem(onFps: (fps) => frameRate.value = fps));
  }

  Entity _buildJoyCon(
    Scene scene, {
    required int side,
    required Mesh joyMesh,
    required Mesh railMesh,
    required Mesh stickMesh,
    required Mesh btnMesh,
    required Mesh smallBtnMesh,
    required Mesh dpadMesh,
  }) {
    final isLeft = side < 0;
    final mat = isLeft ? _joyLeft : _joyRight;
    final baseX = isLeft ? -4.6 : 4.6;

    // Parent entity — children inherit its transform, so animating this one
    // node moves the whole controller (the ECS handles the hierarchy).
    final root = Entity(isLeft ? 'joyLeft' : 'joyRight')
      ..set(Transform(position: Vector3(baseX, 0, 0)))
      ..set(MeshInstance(joyMesh))
      ..set(mat);
    scene.add(root);

    void child(String name, Mesh mesh, PbrMaterial m, Vector3 pos, {Quaternion? rot}) {
      scene.add(Entity(name)
        ..parent = root
        ..set(Transform(position: pos, rotation: rot ?? Quaternion.identity()))
        ..set(MeshInstance(mesh))
        ..set(m));
    }

    // Magnetic rail down the inner edge (Switch 2's magnetic Joy-Con attach).
    child('${root.name}.rail', railMesh, _rail, Vector3(isLeft ? 0.80 : -0.80, 0, 0));

    // Analog stick.
    final stickY = isLeft ? 1.15 : 0.55;
    child('${root.name}.stick', stickMesh, _stick, Vector3(0, stickY, 0.42),
        rot: Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2));

    if (isLeft) {
      // D-pad (Switch 2 left Joy-Con has a proper d-pad) rendered as a plus.
      child('dpadV', dpadMesh, _btnDark, Vector3(0, -0.95, 0.34));
      child('dpadH', dpadMesh, _btnDark, Vector3(0, -0.95, 0.34),
          rot: Quaternion.axisAngle(Vector3(0, 0, 1), math.pi / 2));
      child('minus', smallBtnMesh, _btnDark, Vector3(0.35, 1.85, 0.34));
    } else {
      // ABXY face buttons.
      child('btnX', btnMesh, _btnLight, Vector3(0, -0.53, 0.34));
      child('btnB', btnMesh, _btnLight, Vector3(0, -1.37, 0.34));
      child('btnY', btnMesh, _btnLight, Vector3(-0.42, -0.95, 0.34));
      child('btnA', btnMesh, _btnLight, Vector3(0.42, -0.95, 0.34));
      child('plus', smallBtnMesh, _btnDark, Vector3(-0.35, 1.85, 0.34));
      child('home', smallBtnMesh, _metal, Vector3(-0.35, -1.85, 0.34));
      child('capture', smallBtnMesh, _btnDark, Vector3(0.35, -1.85, 0.34));
    }
    return root;
  }

  // ---- Public controls (called from the Flutter overlay) ------------------

  ConsoleMode mode = ConsoleMode.handheld;

  void setMode(ConsoleMode m) {
    mode = m;
    _kickstand?.enabled = m != ConsoleMode.handheld;
    // The actual eased transforms are applied each frame by
    // [_ModeAnimationSystem], which reads [mode] as its target.
  }

  void setDisplayPowered(bool on) {
    _powered = on;
    _applyDisplay();
  }

  void cycleApp() {
    _app = DisplayApp.values[(_app.index + 1) % DisplayApp.values.length];
    if (!_powered) setDisplayPowered(true);
    _applyDisplay();
  }

  void toggleAutoOrbit() => orbit.autoOrbit = !orbit.autoOrbit;
  void resetCamera() => orbit.reset(theta: -0.5, phi: 1.15, distance: 15.5);

  /// Swaps the emissive material on the screen entity for the current app.
  /// In the WebGL build this is a live <canvas> texture; here it is a
  /// pre-rendered GLB/texture per app (loaded once, cached by the engine).
  void _applyDisplay() {
    final screen = _screen;
    if (screen == null) return;
    if (!_powered) {
      screen.set(PbrMaterial(baseColor: const Color(0xFF000000), emissive: 0.0));
      return;
    }
    final texture = switch (_app) {
      DisplayApp.home => 'assets/models/screen_home.ktx2',
      DisplayApp.marioKart => 'assets/models/screen_mariokart.ktx2',
      DisplayApp.zelda => 'assets/models/screen_zelda.ktx2',
      DisplayApp.settings => 'assets/models/screen_settings.ktx2',
    };
    screen.set(PbrMaterial.emissiveTexture(texture, intensity: 1.15));
  }

  void dispose() {
    engine.dispose();
    frameRate.dispose();
  }
}

/// Per-frame system that eases the console between [ConsoleMode]s — sliding the
/// Joy-Cons out and dropping them for "detached", tilting the tablet back and
/// swinging the kickstand for "tabletop". Same targets as the WebGL build.
class _ModeAnimationSystem extends System {
  _ModeAnimationSystem(this.c);
  final Switch2Controller c;

  // Current eased values.
  double _leftX = 0, _rightX = 0, _drop = 0, _lift = 0, _tilt = 0, _kick = 0;

  @override
  void update(double dt, Scene scene) {
    final m = c.mode;
    final tgtLeftX = m == ConsoleMode.detached ? -3.2 : 0.0;
    final tgtRightX = m == ConsoleMode.detached ? 3.2 : 0.0;
    final tgtDrop = m == ConsoleMode.detached ? -1.2 : 0.0;
    final tabletop = m != ConsoleMode.handheld;
    final tgtLift = tabletop ? 1.4 : 0.0;
    final tgtTilt = tabletop ? -0.28 : 0.0;
    final tgtKick = tabletop ? 1.0 : 0.0;

    final k = 1 - math.pow(0.001, dt).toDouble(); // frame-rate independent ease
    _leftX += (tgtLeftX - _leftX) * k;
    _rightX += (tgtRightX - _rightX) * k;
    _drop += (tgtDrop - _drop) * k;
    _lift += (tgtLift - _lift) * k;
    _tilt += (tgtTilt - _tilt) * k;
    _kick += (tgtKick - _kick) * k;

    // Whole console leans back + lifts for tabletop.
    final root = Quaternion.axisAngle(Vector3(1, 0, 0), _tilt);
    for (final name in const ['body', 'glass', 'screen']) {
      scene.byName(name)?.get<Transform>()
        ?..rotation = root
        ..position.y = _lift;
    }

    c.leftJoyConTransform?..position.setValues(-4.6 + _leftX, _drop + _lift, 0);
    c.rightJoyConTransform?..position.setValues(4.6 + _rightX, _drop + _lift, 0);

    // Kickstand hinges out from the back-bottom edge.
    c.kickstandTransform
      ?..position.setValues(0, -1.2 + _lift, -0.32)
      ..rotation = Quaternion.axisAngle(Vector3(1, 0, 0), _tilt - (0.5 + _kick * 0.55));
  }
}

// Small accessors so the animation system stays readable.
extension on Switch2Controller {
  Transform? get leftJoyConTransform => _leftJoyCon?.get<Transform>();
  Transform? get rightJoyConTransform => _rightJoyCon?.get<Transform>();
  Transform? get kickstandTransform => _kickstand?.get<Transform>();
}
