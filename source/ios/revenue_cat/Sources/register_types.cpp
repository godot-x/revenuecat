#include "godotx_revenuecat.h"

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

// single source of truth for the singleton
static GodotxRevenueCat *godotx_revenuecat = nullptr;

void initialize_godotx_revenuecat_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    // register the class so it is available to scripts
    ClassDB::register_class<GodotxRevenueCat>();

    // create and register the singleton instance
    godotx_revenuecat = memnew(GodotxRevenueCat);
    Engine::get_singleton()->register_singleton(
        "GodotxRevenueCat",
        godotx_revenuecat
    );
}

void uninitialize_godotx_revenuecat_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    // unregister singleton
    Engine::get_singleton()->unregister_singleton("GodotxRevenueCat");

    // destroy instance
    if (godotx_revenuecat) {
        memdelete(godotx_revenuecat);
        godotx_revenuecat = nullptr;
    }
}

extern "C" {

GDExtensionBool GDE_EXPORT godotx_revenuecat_library_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization
) {
    GDExtensionBinding::InitObject init_obj(
        p_get_proc_address,
        p_library,
        r_initialization
    );

    init_obj.register_initializer(initialize_godotx_revenuecat_module);
    init_obj.register_terminator(uninitialize_godotx_revenuecat_module);
    init_obj.set_minimum_library_initialization_level(
        MODULE_INITIALIZATION_LEVEL_SCENE
    );

    return init_obj.init();
}

} // extern "C"
