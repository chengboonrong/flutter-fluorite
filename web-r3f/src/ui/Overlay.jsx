// The whole HUD is ordinary React composited over the <Canvas> — the same
// arrangement the Fluorite build uses, where Flutter widgets sit on top of a
// SceneView and mutate the shared scene state.

const MODES = [
  ['handheld', 'Handheld'],
  ['tabletop', 'Tabletop'],
  ['detached', 'Detached'],
];

function Row({ label, value, accent }) {
  return (
    <div className="row">
      <span className="k">{label}</span>
      <span className="v" style={accent ? { color: accent } : undefined}>{value}</span>
    </div>
  );
}

export default function Overlay({
  mode, setMode,
  powered, togglePower,
  appLabel, cycleApp,
  autoOrbit, toggleOrbit,
  backend, fps,
}) {
  const detached = mode === 'detached';

  return (
    <>
      <div className="brand">
        <div className="title">
          <span className="dot" />
          Nintendo Switch 2 · Simulator
        </div>
        <p>
          React Three Fiber + WebGPU. A declarative mirror of Toyota's{' '}
          <strong>Fluorite</strong> scene graph. Drag to orbit · scroll to zoom.
        </p>
      </div>

      <div className="panel">
        <div className="cap">Scene</div>
        <Row label="Renderer" value={backend} accent="#37c3ff" />
        <Row label="Mode" value={MODES.find(([m]) => m === mode)?.[1]} />
        <Row label="Left Joy-Con 2" value={detached ? 'Detached' : 'Attached'} accent="#16b7e6" />
        <Row label="Right Joy-Con 2" value={detached ? 'Detached' : 'Attached'} accent="#ff5a5f" />
        <Row label="Display" value={powered ? appLabel : 'Off'} />
        <Row label="FPS" value={fps} />
      </div>

      <div className="dock">
        <div className="seg">
          {MODES.map(([m, label]) => (
            <button key={m} className={mode === m ? 'on' : ''} onClick={() => setMode(m)}>
              {label}
            </button>
          ))}
        </div>
        <button className={powered ? 'on' : ''} onClick={togglePower}>
          {powered ? 'Display On' : 'Display Off'}
        </button>
        <button onClick={cycleApp}>Cycle app</button>
        <button className={autoOrbit ? 'on' : ''} onClick={toggleOrbit}>
          Auto-orbit
        </button>
      </div>
    </>
  );
}
