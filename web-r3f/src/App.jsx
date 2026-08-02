import { Suspense, useEffect, useState } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Environment, Lightformer, OrbitControls } from '@react-three/drei';
import * as THREE from 'three';
import { RenderPipeline, WebGPURenderer } from 'three/webgpu';
import { pass } from 'three/tsl';
import { bloom } from 'three/addons/tsl/display/BloomNode.js';

import Switch2 from './scene/Switch2';
import Overlay from './ui/Overlay';
import { APP_LABELS, APPS } from './scene/useScreenTexture';

// ---------------------------------------------------------------------------
// Renderer. One code path: WebGPURenderer picks the WebGPU backend when the
// browser has an adapter and silently falls back to its WebGL2 backend when it
// doesn't. Because the post-processing below is written in TSL (Three Shading
// Language), the very same bloom graph compiles to WGSL or GLSL depending on
// which backend won — no second implementation to maintain.
// ---------------------------------------------------------------------------
async function createRenderer(props) {
  const renderer = new WebGPURenderer({ ...props, antialias: true });
  await renderer.init();
  return renderer;
}

/**
 * TSL bloom. The console's display is the only emissive surface in the scene
 * and is rendered with `toneMapped={false}`, so it is the one thing that
 * crosses the bloom threshold — which is what makes the panel read as OLED
 * rather than as a bright grey rectangle.
 */
function Bloom() {
  const gl = useThree((s) => s.gl);
  const scene = useThree((s) => s.scene);
  const camera = useThree((s) => s.camera);
  const [post, setPost] = useState(null);

  useEffect(() => {
    let created;
    try {
      created = new RenderPipeline(gl);
      const scenePass = pass(scene, camera);
      const color = scenePass.getTextureNode('output');
      // strength / radius / threshold. The threshold matters more than it
      // looks: the display's brightest tiles sit around 0.5 luminance, so a
      // threshold above that makes the bloom silently do nothing.
      created.outputNode = color.add(bloom(color, 1.0, 0.5, 0.52));
      setPost(created);
    } catch (err) {
      // Degrade to the plain render path rather than showing nothing.
      console.warn('[web-r3f] bloom unavailable, rendering without it:', err);
      return undefined;
    }
    return () => {
      setPost(null);
      created?.dispose?.();
    };
  }, [gl, scene, camera]);

  // A priority > 0 takes over the render loop from R3F; at 0 R3F keeps drawing
  // normally, which is exactly what we want while `post` is still null.
  useFrame(() => {
    if (post) post.render();
  }, post ? 1 : 0);

  return null;
}

/** Reports which backend actually won, so the UI can state it honestly. */
function BackendProbe({ onDetect }) {
  const gl = useThree((s) => s.gl);
  useEffect(() => {
    const isWebGPU = Boolean(gl?.backend?.isWebGPUBackend);
    onDetect(isWebGPU ? 'WebGPU' : 'WebGL2');
  }, [gl, onDetect]);
  return null;
}

export default function App() {
  const [mode, setMode] = useState('handheld');
  const [powered, setPowered] = useState(true);
  const [appIndex, setAppIndex] = useState(0);
  const [autoOrbit, setAutoOrbit] = useState(true);
  const [backend, setBackend] = useState('…');
  const [fps, setFps] = useState(0);

  const cycleApp = () => {
    if (!powered) setPowered(true);
    setAppIndex((i) => (i + 1) % APPS.length);
  };

  return (
    <>
      <Canvas
        shadows
        dpr={[1, 2]}
        gl={createRenderer}
        camera={{ position: [7.4, 5.2, 12.4], fov: 50, near: 0.1, far: 200 }}
        onCreated={({ gl }) => {
          gl.toneMapping = THREE.ACESFilmicToneMapping;
          gl.toneMappingExposure = 1.05;
          if (gl.shadowMap) gl.shadowMap.type = THREE.PCFSoftShadowMap;
        }}
      >
        <color attach="background" args={['#080a10']} />

        {/* Key / fill / rim — the same three directions the hand-written GLSL
            hard-coded, now real lights that also cast the shadow. */}
        <directionalLight position={[-5, 9, 7]} intensity={2.6} color="#fffaf0" castShadow
          shadow-mapSize={[2048, 2048]} shadow-camera-near={1} shadow-camera-far={40}
          shadow-camera-left={-14} shadow-camera-right={14}
          shadow-camera-top={14} shadow-camera-bottom={-14} shadow-bias={-0.0012} />
        <directionalLight position={[8, 3.5, -5]} intensity={1.1} color="#8caeff" />
        <directionalLight position={[1, -4, -9]} intensity={0.7} color="#ff8f96" />
        <ambientLight intensity={0.12} />

        <Suspense fallback={null}>
          <Switch2 mode={mode} powered={powered} appIndex={appIndex} autoOrbit={autoOrbit} />

          {/* Image-based lighting built from light shapes instead of an
              downloaded .hdr — real IBL, zero network requests. This is the
              declarative stand-in for Fluorite's IBL .hdr environment. */}
          <Environment resolution={256}>
            <Lightformer intensity={2.2} color="#fff4e0" position={[-4, 5, 4]} scale={[8, 8, 1]} />
            <Lightformer intensity={1.1} color="#8fb4ff" position={[6, 2, -4]} scale={[8, 8, 1]} />
            <Lightformer intensity={0.8} color="#ff9aa2" position={[0, -4, -7]} scale={[10, 4, 1]} />
            <Lightformer intensity={0.5} color="#ffffff" form="ring" position={[0, 6, 0]} scale={[6, 6, 1]} />
          </Environment>

        </Suspense>

        {/* Floor. Grounding comes from the key light's own shadow map rather
            than drei's <ContactShadows/>: that helper renders its depth pass
            with MeshDepthMaterial and blurs it with ShaderMaterial, and the
            node-based renderer rejects both ("Material ... is not compatible").
            A plain receiveShadow plane is node-safe and works on either
            backend. See README.md → "What didn't port cleanly". */}
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -3.5, 0]} receiveShadow>
          <planeGeometry args={[60, 60]} />
          <meshStandardMaterial color="#0d0e12" roughness={0.9} metalness={0} />
        </mesh>

        <OrbitControls
          makeDefault
          target={[0, 0.2, 0]}
          enablePan={false}
          minDistance={7}
          maxDistance={30}
          minPolarAngle={0.15}
          maxPolarAngle={Math.PI / 2 - 0.02}
          enableDamping
          dampingFactor={0.08}
        />

        <Bloom />
        <BackendProbe onDetect={setBackend} />
        <FpsMeter onSample={setFps} />
      </Canvas>

      <Overlay
        mode={mode}
        setMode={setMode}
        powered={powered}
        togglePower={() => setPowered((p) => !p)}
        appLabel={APP_LABELS[appIndex]}
        cycleApp={cycleApp}
        autoOrbit={autoOrbit}
        toggleOrbit={() => setAutoOrbit((v) => !v)}
        backend={backend}
        fps={fps}
      />
    </>
  );
}

function FpsMeter({ onSample }) {
  const [acc] = useState(() => ({ t: 0, n: 0 }));
  useFrame((_, delta) => {
    acc.t += delta;
    acc.n += 1;
    if (acc.t >= 0.25) {
      onSample(Math.round(acc.n / acc.t));
      acc.t = 0;
      acc.n = 0;
    }
  });
  return null;
}
