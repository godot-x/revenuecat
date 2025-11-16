
#include "godotx_revenuecat_module.h"
#include "godotx_revenuecat.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"

GodotxRevenueCat *godotx_revenuecat = nullptr;

void initialize_godotx_revenuecat_module() {
    godotx_revenuecat = memnew(GodotxRevenueCat);
    Engine::get_singleton()->add_singleton(Engine::Singleton("GodotxRevenueCat", godotx_revenuecat));
}

void uninitialize_godotx_revenuecat_module() {
    if (godotx_revenuecat) {
        memdelete(godotx_revenuecat);
        godotx_revenuecat = nullptr;
    }
}
