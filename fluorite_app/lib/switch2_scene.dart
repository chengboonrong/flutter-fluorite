import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:vector_math/vector_math_64.dart' show Vector2, Vector3, Quaternion;

// Toyota Connected's engine. "Fluorite" is the project/demo name; the Flutter
// package is `filament_scene`, from github.com/toyota-connected/tcna-packages.
// It wraps Google's Filament (Vulkan/Metal/GL) behind a data-oriented C++ ECS
// and surfaces it to Dart. See pubspec.yaml for the dependency.
import 'package:filament_scene/filament_scene.dart';
import 'package:filament_scene/generated/messages.g.dart';

/// Physical configuration of the console.
enum ConsoleMode {
  handheld('Handheld'),
  tabletop('Tabletop'),
  detached('Detached');

  const ConsoleMode(this.label);
  final String label;
}

/// What the display is showing. Each value maps to a screen material.
enum DisplayApp { home, marioKart, zelda, settings }

/// Builds and drives the Nintendo Switch 2 scene on the Filament/Fluorite
/// engine. All geometry is authored as ECS entities (`Cube`s parented into a
/// hierarchy); the same layout as the WebGL build in /web.
///
/// Construction is done once (the [shapes]/[cameras]/[scene] lists handed to
/// the [SceneView]); after the engine calls [attach] with a live
/// [SceneController], mode/power/app changes are pushed back through the ECS —
/// per-frame eased transforms via [tick], and material swaps via
/// [SceneController.updateFilamentScene].
class Switch2Scene {
  Switch2Scene() {
    _build();
  }

  /// Pigeon-generated bridge to the native Filament view. The [SceneView]
  /// widget requires one; entities use it to queue transform updates.
  final FilamentViewApi filament = FilamentViewApi();

  SceneController? _controller;

  // ---- Materials --------------------------------------------------------
  // Filament materials are compiled `.filmat` blobs. `lit.filmat` and
  // `unlit.filmat` ship with the filament_scene example; drop them under
  // assets/materials/ (see assets/models/README.md). Base color / metallic /
  // roughness are pushed as material parameters.
  Material _lit(Color color, {double metallic = 0.0, double roughness = 0.5}) {
    return Material.asset(
      'assets/materials/lit.filmat',
      parameters: [
        MaterialParameter.baseColor(color: color),
        MaterialParameter.metallic(value: metallic),
        MaterialParameter.roughness(value: roughness),
      ],
    );
  }

  Material _emissive(Color color) {
    // Unlit material for the screen so the display reads as "lit" regardless
    // of scene lighting. A real build would bind an emissive texture here via
    // MaterialParameter.texture(...); we use a flat color per app.
    return Material.asset(
      'assets/materials/unlit.filmat',
      parameters: [MaterialParameter.baseColor(color: color)],
    );
  }

  // Palette matched to the WebGL simulator.
  late final Material _mBody = _lit(const Color(0xFF0E1013), metallic: 0.15, roughness: 0.42);
  late final Material _mJoyLeft = _lit(const Color(0xFF068CC7), metallic: 0.05, roughness: 0.45);
  late final Material _mJoyRight = _lit(const Color(0xFFEB2933), metallic: 0.05, roughness: 0.45);
  late final Material _mRail = _lit(const Color(0xFF4D4F5C), metallic: 0.9, roughness: 0.28);
  late final Material _mStick = _lit(const Color(0xFF0A0A0D), metallic: 0.1, roughness: 0.6);
  late final Material _mBtnLight = _lit(const Color(0xFFB8BCCC), metallic: 0.2, roughness: 0.5);
  late final Material _mBtnDark = _lit(const Color(0xFF1A1C21), metallic: 0.2, roughness: 0.5);
  late final Material _mMetal = _lit(const Color(0xFF8C919E), metallic: 0.95, roughness: 0.25);
  late final Material _mFloor = _lit(const Color(0xFF0D0F12), roughness: 0.9);

  // ---- Entities we keep handles to (for animation / material swaps) ------
  // The body is a rounded-edge GLB (dimensions baked in → scale 1), so it's the
  // unscaled root every child parents to and keeps its authored local offset.
  late final GlbModel _body;
  late final Cube _leftJoyCon;
  late final Cube _rightJoyCon;
  late final Cube _kickstand;
  late Cube _screen; // rebuilt on app/power change
  int? _screenIndex; // its slot in [_shapes]

  final List<Model> _models = <Model>[];
  final List<Shape> _shapes = <Shape>[];
  final List<Camera> _cameras = <Camera>[];
  late final Scene _scene;
  late final EntityGUID _cameraId;

  List<Model> get models => List.unmodifiable(_models);
  List<Shape> get shapes => List.unmodifiable(_shapes);
  List<Camera> get cameras => _cameras;
  Scene get scene => _scene;

  // ---- Public state -----------------------------------------------------
  ConsoleMode mode = ConsoleMode.handheld;
  bool powered = true;
  DisplayApp app = DisplayApp.home;

  Color _screenColor() {
    if (!powered) return const Color(0xFF000000);
    return switch (app) {
      DisplayApp.home => const Color(0xFF20252E),
      DisplayApp.marioKart => const Color(0xFFE8412E),
      DisplayApp.zelda => const Color(0xFF2E9E6B),
      DisplayApp.settings => const Color(0xFF12151B),
    };
  }

  // -----------------------------------------------------------------------
  // Construction
  // -----------------------------------------------------------------------
  void _build() {
    final noRot = Quaternion.identity();

    // Floor (a thin flat cube).
    _shapes.add(Cube(
      id: generateGuid(),
      name: 'floor',
      position: Vector3(0, -3.5, 0),
      scale: Vector3(60, 0.1, 60),
      rotation: noRot,
      material: _mFloor,
      castShadows: false,
    ));

    // Central tablet body — the ROOT of the console hierarchy. Everything else
    // is parented to it, so moving/rotating the body moves the whole console
    // (used for the turntable auto-orbit) while children keep their local
    // offsets (used for the Joy-Con detach animation).
    //
    // It's a rounded-edge GLB (assets/models/switch2_body.glb, generated by
    // tools/gen_body_glb.mjs) with the 9.4 × 4.7 × 0.62 dimensions and a dark
    // PBR material baked in — hence scale (1,1,1). Loading geometry from glTF is
    // Fluorite's intended asset path (Blender → GLB → GlbModel).
    _body = GlbModel.asset(
      id: generateGuid(),
      name: 'body',
      assetPath: 'assets/models/switch2_body.glb',
      position: Vector3(0, 0, 0),
      scale: Vector3(1, 1, 1),
      rotation: noRot,
      castShadows: true,
      receiveShadows: true,
    );
    _models.add(_body);

    // Emissive screen, parented to the body.
    _screen = Cube(
      id: generateGuid(),
      name: 'screen',
      parentId: _body.id,
      position: Vector3(0, 0, 0.34),
      scale: Vector3(8.05, 3.9, 0.02),
      rotation: noRot,
      material: _emissive(_screenColor()),
    );
    _screenIndex = _shapes.length;
    _shapes.add(_screen);

    // Power + volume buttons on the top edge.
    for (final (i, x) in const [-1.0, -1.7, -2.3].indexed) {
      _shapes.add(Cube(
        id: generateGuid(),
        name: 'edgeBtn$i',
        parentId: _body.id,
        position: Vector3(x, 2.42, 0.0),
        scale: Vector3(0.22, 0.06, 0.24),
        rotation: noRot,
        material: _mMetal,
      ));
    }

    // Kickstand — folded flat against the back until tabletop/detached.
    _kickstand = Cube(
      id: generateGuid(),
      name: 'kickstand',
      parentId: _body.id,
      position: Vector3(0, -1.2, -0.32),
      scale: Vector3(3.6, 3.4, 0.08),
      rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -0.5),
      material: _mBody,
    );
    _shapes.add(_kickstand);

    // Joy-Cons (each parents its own buttons).
    _leftJoyCon = _buildJoyCon(side: -1);
    _rightJoyCon = _buildJoyCon(side: 1);

    // Orbit camera rig — the engine handles drag-to-orbit / pinch-to-zoom
    // natively; we seed the starting framing.
    _cameraId = generateGuid();
    _cameras.add(Camera(
      id: _cameraId,
      orbitOriginPoint: Vector3(0, 0.2, 0),
      orbitDistance: 15.5,
      orbitAngles: Vector2(-0.5, 1.15),
      targetPoint: Vector3(0, 0.2, 0),
    ));

    // Scene: soft studio IBL + key/fill/rim directionals, matching the
    // three-light setup in the WebGL shader.
    _scene = Scene(
      skybox: ColorSkybox(color: const Color(0xFF0A0C12)),
      indirectLight: HdrIndirectLight.asset('assets/envs/studio_soft.hdr'),
      lights: [
        Light(
          id: generateGuid(),
          type: LightType.sun,
          color: const Color(0xFFFFFAF0),
          intensity: 90000,
          direction: Vector3(-0.5, -0.9, -0.7),
          castShadows: true,
        ),
        Light(
          id: generateGuid(),
          type: LightType.directional,
          color: const Color(0xFF8CADF2),
          intensity: 22000,
          direction: Vector3(0.8, -0.35, 0.5),
        ),
        Light(
          id: generateGuid(),
          type: LightType.directional,
          color: const Color(0xFFE68C8C),
          intensity: 14000,
          direction: Vector3(0.1, 0.4, 0.9),
        ),
      ],
    );
  }

  Cube _buildJoyCon({required int side}) {
    final isLeft = side < 0;
    final material = isLeft ? _mJoyLeft : _mJoyRight;
    final baseX = isLeft ? -4.6 : 4.6;
    final noRot = Quaternion.identity();

    final root = Cube(
      id: generateGuid(),
      name: isLeft ? 'joyLeft' : 'joyRight',
      parentId: _body.id,
      position: Vector3(baseX, 0, 0),
      scale: Vector3(1.55, 4.7, 0.62),
      rotation: noRot,
      material: material,
    );
    _shapes.add(root);

    void child(String name, Vector3 pos, Vector3 scale, Material m, {Quaternion? rot}) {
      _shapes.add(Cube(
        id: generateGuid(),
        name: name,
        parentId: root.id,
        position: pos,
        scale: scale,
        rotation: rot ?? noRot,
        material: m,
      ));
    }

    // Magnetic attach rail down the inner edge.
    child('${root.name}.rail', Vector3(isLeft ? 0.80 : -0.80, 0, 0), Vector3(0.14, 4.2, 0.30), _mRail);

    // Analog stick (stubby cube; the example ships GLB sticks you can swap in).
    final stickY = isLeft ? 1.15 : 0.55;
    child('${root.name}.stick', Vector3(0, stickY, 0.42), Vector3(0.7, 0.7, 0.34), _mStick);

    if (isLeft) {
      child('dpadV', Vector3(0, -0.95, 0.34), Vector3(0.24, 0.72, 0.14), _mBtnDark);
      child('dpadH', Vector3(0, -0.95, 0.34), Vector3(0.72, 0.24, 0.14), _mBtnDark);
      child('minus', Vector3(0.35, 1.85, 0.34), Vector3(0.26, 0.26, 0.1), _mBtnDark);
    } else {
      // ABXY.
      child('btnX', Vector3(0, -0.53, 0.34), Vector3(0.4, 0.4, 0.16), _mBtnLight);
      child('btnB', Vector3(0, -1.37, 0.34), Vector3(0.4, 0.4, 0.16), _mBtnLight);
      child('btnY', Vector3(-0.42, -0.95, 0.34), Vector3(0.4, 0.4, 0.16), _mBtnLight);
      child('btnA', Vector3(0.42, -0.95, 0.34), Vector3(0.4, 0.4, 0.16), _mBtnLight);
      child('plus', Vector3(-0.35, 1.85, 0.34), Vector3(0.26, 0.26, 0.1), _mBtnDark);
      child('home', Vector3(-0.35, -1.85, 0.34), Vector3(0.26, 0.26, 0.1), _mMetal);
      child('capture', Vector3(0.35, -1.85, 0.34), Vector3(0.26, 0.26, 0.1), _mBtnDark);
    }
    return root;
  }

  // -----------------------------------------------------------------------
  // Live control (called after [attach])
  // -----------------------------------------------------------------------
  void attach(SceneController controller) => _controller = controller;

  void setMode(ConsoleMode m) => mode = m; // eased toward by [tick]

  void setPowered(bool on) {
    powered = on;
    _refreshScreenMaterial();
  }

  void cycleApp() {
    app = DisplayApp.values[(app.index + 1) % DisplayApp.values.length];
    if (!powered) powered = true;
    _refreshScreenMaterial();
  }

  /// Rebuilds the screen cube with a new material and pushes the updated shape
  /// list to the engine. Material is immutable on a [Shape], so we swap the
  /// entity (keeping its GUID) and re-send via the controller — the confirmed
  /// runtime-update path in [SceneController.updateFilamentScene].
  void _refreshScreenMaterial() {
    final idx = _screenIndex;
    if (idx == null) return;
    _screen = Cube(
      id: _screen.id,
      name: 'screen',
      parentId: _body.id,
      position: Vector3(0, 0, 0.34),
      scale: Vector3(8.05, 3.9, 0.02),
      rotation: Quaternion.identity(),
      material: _emissive(_screenColor()),
    );
    _shapes[idx] = _screen;
    _controller?.updateFilamentScene(shapes: _shapes);
  }

  // ---- Per-frame animation ----------------------------------------------
  // Eased state, matching the WebGL build's targets.
  double _leftX = 0, _rightX = 0, _drop = 0, _lift = 0, _tilt = 0, _kick = 0, _spin = 0;
  bool autoOrbit = true;

  void toggleAutoOrbit() => autoOrbit = !autoOrbit;

  void resetView() {
    // Re-seed the orbit rig. (The native camera-gesture controller also
    // exposes a recenter; here we just reset our turntable.)
    _spin = 0;
    _body.setLocalRotation(_composeBodyRotation());
    _body.updateTransform();
  }

  Quaternion _composeBodyRotation() {
    final turntable = Quaternion.axisAngle(Vector3(0, 1, 0), _spin);
    final tilt = Quaternion.axisAngle(Vector3(1, 0, 0), _tilt);
    return turntable * tilt;
  }

  /// Advance the animation by [dt] seconds and push transforms into the ECS.
  void tick(double dt) {
    if (_controller == null) return;

    final detached = mode == ConsoleMode.detached;
    final tabletop = mode != ConsoleMode.handheld;
    final tgtLeftX = detached ? -3.2 : 0.0;
    final tgtRightX = detached ? 3.2 : 0.0;
    final tgtDrop = detached ? -1.2 : 0.0;
    final tgtLift = tabletop ? 1.4 : 0.0;
    final tgtTilt = tabletop ? -0.28 : 0.0;
    final tgtKick = tabletop ? 1.0 : 0.0;

    final k = 1 - math.pow(0.001, dt).toDouble(); // frame-rate-independent smoothing
    _leftX += (tgtLeftX - _leftX) * k;
    _rightX += (tgtRightX - _rightX) * k;
    _drop += (tgtDrop - _drop) * k;
    _lift += (tgtLift - _lift) * k;
    _tilt += (tgtTilt - _tilt) * k;
    _kick += (tgtKick - _kick) * k;
    if (autoOrbit) _spin += dt * 0.28;

    // Root body: lift + tilt + turntable spin. Children inherit this.
    _body.setLocalPosition(Vector3(0, _lift, 0));
    _body.setLocalRotation(_composeBodyRotation());
    _body.updateTransform();

    // Joy-Cons slide out and drop for "detached".
    _leftJoyCon.setLocalPosition(Vector3(-4.6 + _leftX, _drop, 0));
    _leftJoyCon.updateTransform();
    _rightJoyCon.setLocalPosition(Vector3(4.6 + _rightX, _drop, 0));
    _rightJoyCon.updateTransform();

    // Kickstand hinges out from the back-bottom edge.
    _kickstand.setLocalRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -(0.5 + _kick * 0.55)));
    _kickstand.updateTransform();
  }
}
