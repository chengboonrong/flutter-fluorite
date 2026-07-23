import 'package:flutter/material.dart';

import 'switch2_scene.dart';

/// Entry point for the Fluorite-native Nintendo Switch 2 simulator.
///
/// The whole 3D surface is a single [FluoriteView] widget — Fluorite's core
/// promise is that a console-grade renderer drops into a Flutter tree like any
/// other widget: "add one line to pubspec.yaml and you've got a 3D engine."
/// Flutter widgets (the control dock, the info panel) are laid out *on top of*
/// the same widget tree via a [Stack], and they mutate the shared scene through
/// a [Switch2Controller]. Sharing state between Flutter UI and 3D entities like
/// this — instead of shipping commands into a foreign engine object — is the
/// Fluorite way.
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

class _SimulatorPageState extends State<SimulatorPage> {
  late final Switch2Controller _controller;
  ConsoleMode _mode = ConsoleMode.handheld;
  bool _displayOn = true;

  @override
  void initState() {
    super.initState();
    _controller = Switch2Controller();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ---- The entire 3D scene lives in one widget ----------------------
          Positioned.fill(
            child: Switch2SceneView(
              controller: _controller,
              // Fluorite scenes are Hot-Reload enabled: editing buildScene()
              // and hot-reloading re-runs it against the live engine.
              onReady: (scene) => _controller.buildScene(scene),
            ),
          ),

          // ---- Flutter UI overlay, sharing state with the ECS ---------------
          const _Brand(),
          _InfoPanel(mode: _mode, displayOn: _displayOn, controller: _controller),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ControlDock(
              mode: _mode,
              displayOn: _displayOn,
              onMode: (m) {
                setState(() => _mode = m);
                _controller.setMode(m); // animates Joy-Con / kickstand entities
              },
              onTogglePower: () {
                setState(() => _displayOn = !_displayOn);
                _controller.setDisplayPowered(_displayOn);
              },
              onCycleApp: _controller.cycleApp,
              onToggleSpin: _controller.toggleAutoOrbit,
              onResetView: _controller.resetCamera,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay widgets — plain Flutter, composited over the FluoriteView.
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
  const _InfoPanel({required this.mode, required this.displayOn, required this.controller});
  final ConsoleMode mode;
  final bool displayOn;
  final Switch2Controller controller;

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
          ValueListenableBuilder<int>(
            valueListenable: controller.frameRate,
            builder: (_, fps, __) => row('FPS', '$fps'),
          ),
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
