# Assets

Drop the display textures and any GLB models here before running the
Fluorite‑native build. `switch2_scene.dart` expects these emissive screen
textures (KTX2 or PNG):

- `screen_home.ktx2` — Switch 2 home menu
- `screen_mariokart.ktx2` — Mario Kart World splash
- `screen_zelda.ktx2` — Zelda splash
- `screen_settings.ktx2` — System Settings

The web build renders these live from a `<canvas>` (see `drawScreen()` in
`../../web/index.html`); you can bake frames from it to produce the textures.
