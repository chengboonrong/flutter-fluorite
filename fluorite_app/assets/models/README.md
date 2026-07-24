# Models (optional GLB)

The scene is built entirely from `Cube` primitives, so **no models are
required to run**. This folder is for optional glTF/GLB upgrades loaded via
`filament_scene`'s `Model`/`GlbModel` and passed to `SceneView(models: [...])`:

- `switch2.glb` — a rounded-edge console body to replace the cube body for a
  more faithful silhouette.
- `joycon_stick.glb` — detailed analog sticks.

Fluorite's asset workflow is Blender → glTF/GLB → `Model.glb('assets/models/…')`.
The live display is a flat colored material here; to render the animated home
menu from the WebGL build, bake frames to textures and bind them with
`MaterialParameter.texture(...)` on `unlit.filmat`.
