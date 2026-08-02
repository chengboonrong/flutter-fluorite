# Switch 2 — React Three Fiber + WebGPU

The third build of the same console. Where [`../web`](../web) is hand-written
imperative WebGL2 and [`../fluorite_app`](../fluorite_app) is the engine-native
Fluorite/Flutter port, this one is the **declarative** build — and it turns out
to be the closest structural analogue to Fluorite of the three.

```bash
npm install
npm run dev        # http://localhost:5173
npm run build      # → dist/  (static, relative paths)
```

## Why R3F mirrors Fluorite

Fluorite (`filament_scene`) and React Three Fiber solve the same problem the
same way: a declarative, reactive component tree wrapping an imperative
modern-GPU PBR renderer.

| Fluorite (`filament_scene`) | This build | `../web` (imperative) |
|---|---|---|
| `SceneView` widget in a Flutter tree | `<Canvas>` in a React tree | raw `gl.*` calls |
| entities parented by `parentId` | nested `<group>` | `M4.mul(root, …)` by hand |
| `GlbModel.asset(...)` | `useGLTF(...)` | hand-built geometry |
| Filament PBR over **Vulkan** | three.js PBR over **WebGPU** | hand-written GLSL |
| `Ticker` → `setLocalPosition` | `useFrame` | manual `ease()` per entity |
| Flutter widgets over the SceneView | React over the `<Canvas>` | imperative DOM listeners |

The parenting row is the substantive one. In `../web`, "the Joy-Con's analog
stick follows the Joy-Con" is enforced by remembering to multiply by the right
matrix. Here — and in Fluorite — it is enforced by the tree:

```jsx
<group ref={leftJoy}>          {/* detaching moves everything below with it */}
  <RB … />                     {/* shell   */}
  <group position={[0, 1.15, 0.34]}>…</group>   {/* stick */}
  <RB … />                     {/* trigger */}
</group>
```

It also loads **the same `switch2_body.glb`** the Flutter app loads, so the two
builds share an asset rather than merely resembling each other.

## What the ecosystem adds

- **Bloom (TSL)** — the display is the only emissive surface and is drawn with
  `toneMapped={false}`, so it is the one thing crossing the bloom threshold.
  That halo is what makes the panel read as OLED instead of a bright grey
  rectangle.
- **Real IBL** — `<Environment>` built from `<Lightformer>` shapes replaces the
  `0.5 + 0.5*N.y` hemisphere approximation in the GLSL build. It is genuine
  image-based lighting with **no HDR download** (drei's `preset=` would fetch
  one from a CDN; the light shapes keep this build self-contained).
- **Transmission** — the front glass gets a real transmission/IOR lobe instead
  of a fresnel fudge.
- **Shadows** — the console is grounded; the imperative build floats.
- **Declarative state** — mode / power / app are React state, and the HUD is
  ordinary React rather than hand-wired DOM listeners.

## WebGPU, honestly

The renderer is **always** `WebGPURenderer`. It selects the WebGPU backend when
the browser exposes an adapter and silently falls back to its **WebGL2 backend**
when it doesn't. Because the post-processing is written in **TSL** (Three
Shading Language), the same bloom graph compiles to WGSL *or* GLSL — one code
path, no second implementation. The HUD's `Renderer` row reports which backend
actually won.

Two things worth being clear about:

- **WebGPU buys no FPS here.** This scene is ~30 draw calls and a few thousand
  triangles; it is nowhere near GPU-bound. The wins are authoring (TSL beats
  GLSL template strings) and access to the modern pipeline — not speed.
- **The screenshots in this repo's history were captured under the WebGL2
  fallback**, in headless Chromium with SwiftShader (no GPU). That path is
  therefore the well-tested one; the WebGPU backend is exercised by the same
  code but was not verifiable in CI.

### What didn't port cleanly

drei's **`<ContactShadows/>`** is not usable here. It renders its depth pass
with `MeshDepthMaterial` and blurs it with `ShaderMaterial`, and the node-based
renderer rejects both:

```
THREE.NodeBuilder: Material "MeshDepthMaterial" is not compatible.
THREE.NodeBuilder: Material "ShaderMaterial" is not compatible.
```

It also left a large dark quad across the frame. Grounding now comes from the
key light's own shadow map onto a `receiveShadow` plane, which is node-safe on
both backends. **This is the general caveat for R3F + WebGPU today: the core
(`@react-three/fiber`, most of drei) works, but any helper that reaches for a
classic `ShaderMaterial` needs a node-based replacement.** `@react-three/post-
processing` is in the same category — hence TSL bloom rather than that library.

## Cost

The dependency-free build in `../web` is ~800 lines that you can open straight
from disk. This one is a Vite app that bundles to roughly **1.9 MB raw /
530 KB gzipped**. That is the trade: the ecosystem gives you bloom, IBL,
shadows and a real scene graph for a fraction of the code, and takes the
"just open index.html" property away. Both builds are kept for that reason.
