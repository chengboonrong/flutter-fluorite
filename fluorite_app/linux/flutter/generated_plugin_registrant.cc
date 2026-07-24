//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <filament_scene/filament_view_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) filament_scene_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FilamentViewPlugin");
  filament_view_plugin_register_with_registrar(filament_scene_registrar);
}
