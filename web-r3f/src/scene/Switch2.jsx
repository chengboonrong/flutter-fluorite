import { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import { useGLTF, RoundedBox } from '@react-three/drei';
import * as THREE from 'three';

import { MAT, GLASS } from './materials';
import { useScreenTexture } from './useScreenTexture';

const MODEL_URL = `${import.meta.env.BASE_URL}models/switch2_body.glb`;

// ---------------------------------------------------------------------------
// Mode targets — identical numbers to the dependency-free WebGL build's
// setMode(), so both web builds animate to exactly the same poses.
// ---------------------------------------------------------------------------
const MODES = {
  handheld: { joyX: 0.0, drop: 0.0, kick: 0, tilt: 0.0, lift: 0.0 },
  tabletop: { joyX: 0.0, drop: 0.0, kick: 1, tilt: -0.28, lift: 1.4 },
  detached: { joyX: 3.2, drop: -1.2, kick: 1, tilt: -0.28, lift: 1.4 },
};

const JOY_BASE_X = 4.6; // attached lateral offset (∓ per side)

// Same smoothing curve as the WebGL build: k = 1 - 0.001^dt.
const ease = (cur, tgt, k) => cur + (tgt - cur) * k;

/**
 * RoundedBox with the radius clamped to what the box can actually support.
 * The hand-written `roundedBox()` in the WebGL build clamps internally; drei's
 * does not, and an over-large radius produces inverted geometry.
 */
function RB({ size, radius, smoothness = 5, children, ...props }) {
  const r = Math.min(radius, Math.min(...size) / 2 - 1e-3);
  return (
    <RoundedBox args={size} radius={r} smoothness={smoothness} {...props}>
      {children}
    </RoundedBox>
  );
}

/** A rounded rectangle as flat geometry — used for the emissive display. */
function useRoundedPlane(w, h, r) {
  return useMemo(() => {
    const s = new THREE.Shape();
    const x = -w / 2, y = -h / 2;
    s.moveTo(x + r, y);
    s.lineTo(x + w - r, y);
    s.quadraticCurveTo(x + w, y, x + w, y + r);
    s.lineTo(x + w, y + h - r);
    s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    s.lineTo(x + r, y + h);
    s.quadraticCurveTo(x, y + h, x, y + h - r);
    s.lineTo(x, y + r);
    s.quadraticCurveTo(x, y, x + r, y);
    const g = new THREE.ShapeGeometry(s, 12);
    // ShapeGeometry UVs are in world units — remap to 0..1 for the texture.
    const pos = g.attributes.position;
    const uv = new Float32Array(pos.count * 2);
    for (let i = 0; i < pos.count; i++) {
      uv[i * 2] = (pos.getX(i) - x) / w;
      uv[i * 2 + 1] = (pos.getY(i) - y) / h;
    }
    g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
    return g;
  }, [w, h, r]);
}

// ---------------------------------------------------------------------------
// Joy-Con 2 — one component, mirrored per side. Everything inside is a child
// of the Joy-Con group, so detaching it moves the stick, buttons and trigger
// with it. This is the R3F equivalent of Fluorite parenting entities by
// `parentId`: nesting *is* the transform hierarchy.
// ---------------------------------------------------------------------------
function JoyCon({ side, groupRef }) {
  const isLeft = side < 0;
  const mat = isLeft ? MAT.joyLeft : MAT.joyRight;
  const stickY = isLeft ? 1.15 : 0.55;

  return (
    <group ref={groupRef}>
      <RB size={[1.55, 4.7, 0.62]} radius={0.42} smoothness={6} castShadow>
        <meshPhysicalMaterial {...mat} />
      </RB>

      {/* magnetic rail on the inner edge */}
      <RB size={[0.14, 4.2, 0.3]} radius={0.05} position={[isLeft ? 0.8 : -0.8, 0, 0]}>
        <meshPhysicalMaterial {...MAT.rail} />
      </RB>

      {/* analog stick */}
      <group position={[0, stickY, 0.34]}>
        <mesh rotation={[Math.PI / 2, 0, 0]}>
          <cylinderGeometry args={[0.34, 0.4, 0.34, 26]} />
          <meshPhysicalMaterial {...MAT.stickRing} />
        </mesh>
        <mesh position={[0, 0, 0.16]} rotation={[Math.PI / 2, 0, 0]}>
          <cylinderGeometry args={[0.4, 0.4, 0.1, 26]} />
          <meshPhysicalMaterial {...MAT.stick} />
        </mesh>
      </group>

      {isLeft ? (
        <>
          {/* D-pad — two crossed bars */}
          <group position={[0, -0.95, 0.34]}>
            <RB size={[0.24, 0.72, 0.14]} radius={0.05}>
              <meshPhysicalMaterial {...MAT.btnDark} />
            </RB>
            <RB size={[0.24, 0.72, 0.14]} radius={0.05} rotation={[0, 0, Math.PI / 2]}>
              <meshPhysicalMaterial {...MAT.btnDark} />
            </RB>
          </group>
          <mesh position={[0.35, 1.85, 0.34]}>
            <sphereGeometry args={[0.13, 14, 14]} />
            <meshPhysicalMaterial {...MAT.btnDark} />
          </mesh>
        </>
      ) : (
        <>
          {/* ABXY */}
          <group position={[0, -0.95, 0.34]}>
            {[
              [0, 0.42],
              [0, -0.42],
              [-0.42, 0],
              [0.42, 0],
            ].map(([x, y], i) => (
              <mesh key={i} position={[x, y, 0]}>
                <sphereGeometry args={[0.2, 16, 16]} />
                <meshPhysicalMaterial {...MAT.btnLight} />
              </mesh>
            ))}
          </group>
          <mesh position={[-0.35, 1.85, 0.34]}>
            <sphereGeometry args={[0.13, 14, 14]} />
            <meshPhysicalMaterial {...MAT.btnDark} />
          </mesh>
          <mesh position={[-0.35, -1.85, 0.34]}>
            <sphereGeometry args={[0.13, 14, 14]} />
            <meshPhysicalMaterial {...MAT.metal} />
          </mesh>
          <mesh position={[0.35, -1.85, 0.34]}>
            <sphereGeometry args={[0.13, 14, 14]} />
            <meshPhysicalMaterial {...MAT.btnDark} />
          </mesh>
        </>
      )}

      {/* shoulder trigger */}
      <RB size={[1.5, 0.5, 0.55]} radius={0.2} position={[0, 2.35, 0.02]}>
        <meshPhysicalMaterial {...mat} />
      </RB>
    </group>
  );
}

// ---------------------------------------------------------------------------
// The console. One declarative tree; `useFrame` only nudges a handful of refs
// toward their mode targets — no per-frame rebuilding of the scene like the
// imperative build's buildEntities().
// ---------------------------------------------------------------------------
export default function Switch2({ mode, powered, appIndex, autoOrbit }) {
  const root = useRef();
  const turntable = useRef();
  const kickstand = useRef();
  const leftJoy = useRef();
  const rightJoy = useRef();

  const gltf = useGLTF(MODEL_URL);
  const bodyGeometry = useMemo(() => {
    let geo = null;
    gltf.scene.traverse((o) => {
      if (!geo && o.isMesh) geo = o.geometry;
    });
    return geo;
  }, [gltf]);

  const screenGeo = useRoundedPlane(8.05, 3.9, 0.16);
  const screenTex = useScreenTexture({ powered, appIndex });

  // Live eased state (mutable — never triggers a React re-render).
  const s = useRef({ joyX: 0, drop: 0, kick: 0, tilt: 0, lift: 0 });

  useFrame((_, delta) => {
    const dt = Math.min(delta, 0.05);
    const k = 1 - Math.pow(0.001, dt);
    const t = MODES[mode];
    const c = s.current;

    c.joyX = ease(c.joyX, t.joyX, k);
    c.drop = ease(c.drop, t.drop, k);
    c.kick = ease(c.kick, t.kick, k);
    c.tilt = ease(c.tilt, t.tilt, k);
    c.lift = ease(c.lift, t.lift, k);

    if (root.current) {
      root.current.position.y = c.lift;
      root.current.rotation.x = c.tilt;
    }
    if (turntable.current && autoOrbit) turntable.current.rotation.y += dt * 0.28;

    if (leftJoy.current) leftJoy.current.position.set(-JOY_BASE_X - c.joyX, c.drop, 0);
    if (rightJoy.current) rightJoy.current.position.set(JOY_BASE_X + c.joyX, c.drop, 0);

    if (kickstand.current) {
      kickstand.current.visible = c.kick > 0.001;
      kickstand.current.rotation.x = -(0.5 + c.kick * 0.55);
    }
  });

  return (
    <group ref={turntable}>
      <group ref={root}>
        {/* ---- Body: the SAME switch2_body.glb the Flutter/Fluorite app loads ---- */}
        <mesh geometry={bodyGeometry} castShadow receiveShadow>
          <meshPhysicalMaterial {...MAT.bodyBlack} />
        </mesh>

        {/* front glass — a real transmission lobe */}
        <RB size={[8.55, 4.35, 0.1]} radius={0.048} position={[0, 0, 0.3]}>
          <meshPhysicalMaterial {...GLASS} />
        </RB>

        {/* emissive display — this is what the bloom pass picks up */}
        <mesh geometry={screenGeo} position={[0, 0, 0.37]}>
          <meshStandardMaterial
            map={screenTex}
            emissiveMap={screenTex}
            emissive="#ffffff"
            emissiveIntensity={powered ? 1.35 : 0}
            toneMapped={false}
            roughness={0.2}
          />
        </mesh>

        {/* power + volume buttons on the top edge */}
        {[-1.0, -1.7, -2.3].map((x) => (
          <mesh key={x} position={[x, 2.42, 0]} rotation={[Math.PI / 2, 0, 0]}>
            <cylinderGeometry args={[0.12, 0.12, 0.1, 20]} />
            <meshPhysicalMaterial {...MAT.metal} />
          </mesh>
        ))}

        {/* kickstand — hinges from the back-bottom edge */}
        <group position={[0, -1.2, -0.32]} ref={kickstand}>
          <RB size={[3.6, 3.4, 0.08]} radius={0.038} position={[0, -1.5, 0]} castShadow>
            <meshPhysicalMaterial {...MAT.bodyDark} />
          </RB>
        </group>

        <JoyCon side={-1} groupRef={leftJoy} />
        <JoyCon side={+1} groupRef={rightJoy} />
      </group>
    </group>
  );
}

useGLTF.preload(MODEL_URL);
