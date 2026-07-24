import 'package:flutter_test/flutter_test.dart';
import 'package:switch2_fluorite/switch2_scene.dart';

// Pure-Dart tests: they build the scene graph and exercise its state machine
// without touching the native Filament view (no SceneController is attached, so
// runtime pushes are safely no-ops). This is what CI can verify deterministically
// — the full render path needs the native engine + compiled assets.
void main() {
  test('scene builds a GLB body, two Joy-Cons, a camera, and parts', () {
    final scene = Switch2Scene();

    // Rounded-edge body is loaded as a GLB model.
    expect(scene.models, hasLength(1));
    expect(scene.models.single.assetPath, contains('switch2_body.glb'));

    // One orbit camera.
    expect(scene.cameras, hasLength(1));

    // Floor + screen + edge buttons + kickstand + two Joy-Cons with their parts.
    expect(scene.shapes.length, greaterThan(15));

    // Every child references a real parent id (no dangling parents).
    final ids = {
      for (final s in scene.shapes) s.id,
      for (final m in scene.models) m.id,
    };
    for (final s in scene.shapes) {
      if (s.parentId != null) {
        expect(ids, contains(s.parentId), reason: '${s.name} has an unknown parent');
      }
    }
  });

  test('cycleApp advances through the display apps and wraps', () {
    final scene = Switch2Scene();
    expect(scene.app, DisplayApp.home);

    scene.cycleApp();
    expect(scene.app, DisplayApp.marioKart);

    scene.cycleApp();
    scene.cycleApp();
    scene.cycleApp(); // settings -> wrap back to home
    expect(scene.app, DisplayApp.home);
  });

  test('cycling an app while powered off turns the display back on', () {
    final scene = Switch2Scene()..setPowered(false);
    expect(scene.powered, isFalse);

    scene.cycleApp();
    expect(scene.powered, isTrue);
  });

  test('mode changes are recorded', () {
    final scene = Switch2Scene();
    expect(scene.mode, ConsoleMode.handheld);

    scene.setMode(ConsoleMode.tabletop);
    expect(scene.mode, ConsoleMode.tabletop);

    scene.setMode(ConsoleMode.detached);
    expect(scene.mode, ConsoleMode.detached);
  });

  test('ConsoleMode labels are human-readable', () {
    expect(ConsoleMode.handheld.label, 'Handheld');
    expect(ConsoleMode.tabletop.label, 'Tabletop');
    expect(ConsoleMode.detached.label, 'Detached');
  });
}
