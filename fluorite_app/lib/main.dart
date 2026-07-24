import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:filament_scene/filament_scene.dart';

import 'switch2_scene.dart';

/// Nintendo Switch 2 simulator, rendered with Toyota's Fluorite engine
/// (the `filament_scene` Flutter package).
///
/// The whole 3D world is a single [SceneView] widget — Fluorite's core promise
/// is that a console-grade renderer drops into a Flutter tree like any other
/// widget. The control dock and info panel are ordinary Flutter widgets stacked
/// *on top of* it, mutating the shared ECS scene through [Switch2Scene].
void main() => runApp(const Switch2App());

class Switch2App extends StatelessWidget {
  const Switch2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nintendo Switch 2 · Fluorite Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0C12),
      ),
      home: const SimulatorPage(),
    );
  }
}

class SimulatorPage extends StatefulWidget {
  const SimulatorPage({super.key});

  @override
  State<SimulatorPage> createState() => _SimulatorPageState();
}

class _SimulatorPageState extends State<SimulatorPage> with SingleTickerProviderStateMixin {
  final Switch2Scene _sim = Switch2Scene();

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  // UI-facing state (kept in sync with the scene).
  ConsoleMode _mode = ConsoleMode.handheld;
  bool _displayOn = true;
  int _fps = 0;
  double _fpsAccum = 0;
  int _fpsFrames = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;

    _sim.tick(dt.clamp(0.0, 0.05));

    // FPS readout for the info panel.
    _fpsAccum += dt;
    _fpsFrames++;
    if (_fpsAccum >= 0.25) {
      final fps = (_fpsFrames / _fpsAccum).round();
      _fpsAccum = 0;
      _fpsFrames = 0;
      if (fps != _fps) setState(() => _fps = fps);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ---- The entire 3D scene, in one widget --------------------------
          SceneView(
            filament: _sim.filament,
            models: const [],
            shapes: _sim.shapes,
            cameras: _sim.cameras,
            scene: _sim.scene,
            onCreated: (SceneController controller) {
              _sim.attach(controller);
              _last = Duration.zero;
              _ticker.start(); // begin pushing eased transforms into the ECS
            },
          ),

          // ---- Flutter UI overlay ------------------------------------------
          const _Brand(),
          _InfoPanel(mode: _mode, displayOn: _displayOn, fps: _fps),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ControlDock(
              mode: _mode,
              displayOn: _displayOn,
              onMode: (m) {
                setState(() => _mode = m);
                _sim.setMode(m);
              },
              onTogglePower: () {
                setState(() => _displayOn = !_displayOn);
                _sim.setPowered(_displayOn);
              },
              onCycleApp: _sim.cycleApp,
              onToggleSpin: _sim.toggleAutoOrbit,
              onResetView: _sim.resetView,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay widgets — plain Flutter composited over the SceneView.
// ---------------------------------------------------------------------------

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 18,
      left: 20,
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFE8ECF4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(children: [
              _Dot(),
              SizedBox(width: 9),
              Text('Nintendo Switch 2 · Simulator',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            SizedBox(height: 5),
            SizedBox(
              width: 260,
              child: Text(
                'Real-time 3D rendered with Toyota Fluorite (Filament / Vulkan). '
                'Drag to orbit · pinch to zoom.',
                style: TextStyle(fontSize: 12, color: Color(0xFF93A0B8), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: const Color(0xFF37C3FF),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFF37C3FF).withOpacity(.7), blurRadius: 12)],
        ),
      );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.mode, required this.displayOn, required this.fps});
  final ConsoleMode mode;
  final bool displayOn;
  final int fps;

  @override
  Widget build(BuildContext context) {
    final detached = mode == ConsoleMode.detached;
    Widget row(String k, String v, [Color? c]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: const TextStyle(fontSize: 13, color: Color(0xFF93A0B8))),
            Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c ?? Colors.white)),
          ]),
        );
    return Positioned(
      top: 18,
      right: 18,
      child: Container(
        width: 232,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF12151F).withOpacity(.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SCENE',
              style: TextStyle(fontSize: 12, letterSpacing: 1, color: Color(0xFF93A0B8))),
          const SizedBox(height: 8),
          row('Mode', mode.label),
          row('Left Joy-Con 2', detached ? 'Detached' : 'Attached', const Color(0xFF16B7E6)),
          row('Right Joy-Con 2', detached ? 'Detached' : 'Attached', const Color(0xFFFF5A5F)),
          row('Display', displayOn ? 'On' : 'Off'),
          row('FPS', '$fps'),
        ]),
      ),
    );
  }
}

class _ControlDock extends StatelessWidget {
  const _ControlDock({
    required this.mode,
    required this.displayOn,
    required this.onMode,
    required this.onTogglePower,
    required this.onCycleApp,
    required this.onToggleSpin,
    required this.onResetView,
  });

  final ConsoleMode mode;
  final bool displayOn;
  final ValueChanged<ConsoleMode> onMode;
  final VoidCallback onTogglePower;
  final VoidCallback onCycleApp;
  final VoidCallback onToggleSpin;
  final VoidCallback onResetView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF12151F).withOpacity(.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<ConsoleMode>(
              segments: const [
                ButtonSegment(value: ConsoleMode.handheld, label: Text('Handheld')),
                ButtonSegment(value: ConsoleMode.tabletop, label: Text('Tabletop')),
                ButtonSegment(value: ConsoleMode.detached, label: Text('Detached')),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onMode(s.first),
            ),
            FilledButton.tonalIcon(
              onPressed: onTogglePower,
              icon: const Icon(Icons.power_settings_new, size: 18),
              label: Text(displayOn ? 'Display On' : 'Display Off'),
            ),
            OutlinedButton.icon(
              onPressed: onCycleApp,
              icon: const Icon(Icons.grid_view, size: 18),
              label: const Text('Cycle app'),
            ),
            OutlinedButton.icon(
              onPressed: onToggleSpin,
              icon: const Icon(Icons.threesixty, size: 18),
              label: const Text('Auto-orbit'),
            ),
            OutlinedButton.icon(
              onPressed: onResetView,
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Reset view'),
            ),
          ],
        ),
      ),
    );
  }
}
