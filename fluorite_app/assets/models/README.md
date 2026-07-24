# Models (GLB)

- **`switch2_body.glb`** — the rounded-edge console body, loaded by
  `switch2_scene.dart` as a `GlbModel` and used as the root of the scene
  hierarchy. It's **generated and committed** here; the 9.4 × 4.7 × 0.62
  dimensions and a dark PBR material are baked in, so it loads at scale
  `(1,1,1)`. Regenerate it any time with:

  ```bash
  node tools/gen_body_glb.mjs
  ```

  (Same rounded-box construction as the WebGL build — flat faces, cylindrical
  edges, spherical corners.)

Optional further upgrades you can drop in and load via `SceneView(models: …)`:

- `joycon_left.glb` / `joycon_right.glb` — rounded Joy-Con shells to replace the
  cube Joy-Cons (author in Blender, or extend `tools/gen_body_glb.mjs`).
- `joycon_stick.glb` — detailed analog sticks.

Fluorite's asset workflow is Blender → glTF/GLB → `GlbModel.asset('assets/models/…')`.
To render the animated home menu from the WebGL build on the screen, bake frames
to textures and bind them with `MaterialParameter.texture(...)` on `unlit.filmat`.
