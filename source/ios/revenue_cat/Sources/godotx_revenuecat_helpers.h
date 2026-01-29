#ifndef GODOTX_REVENUECAT_HELPERS_H
#define GODOTX_REVENUECAT_HELPERS_H

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/object.hpp>

#include "godotx_revenuecat.h"

using namespace godot;

inline GodotxRevenueCat *getRevenueCatSingleton() {
    return Object::cast_to<GodotxRevenueCat>(
        Engine::get_singleton()->get_singleton("GodotxRevenueCat")
    );
}

#endif
