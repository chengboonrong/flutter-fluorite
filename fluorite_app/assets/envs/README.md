# Environments (image-based lighting)

`switch2_scene.dart` loads `studio_soft.hdr` via
`HdrIndirectLight.asset('assets/envs/studio_soft.hdr')` for soft, realistic
ambient reflections.

Drop any equirectangular `.hdr` here and update the path. The `filament_scene`
example ships a `courtyard.hdr` you can reuse
(`packages/filament_scene/example/assets/envs/`).
