# Materials

Filament materials are **compiled** `.filmat` blobs (built from `.mat` sources
with Filament's `matc` compiler). `switch2_scene.dart` references two:

- `lit.filmat` — a standard PBR lit material exposing `baseColor`, `metallic`,
  and `roughness` parameters (used for the body, Joy-Cons, buttons, floor).
- `unlit.filmat` — an unlit/emissive material exposing `baseColor` (used for
  the screen so it reads as lit regardless of scene lighting).

Both ship with the `filament_scene` example
(`packages/filament_scene/example/assets/materials/`) in
[toyota-connected/tcna-packages](https://github.com/toyota-connected/tcna-packages).
Copy them here, or compile your own:

```bash
matc -a vulkan -a metal -a opengl -o lit.filmat lit.mat
```
