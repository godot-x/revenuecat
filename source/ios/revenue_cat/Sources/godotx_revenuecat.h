#ifndef GODOTX_REVENUECAT_H
#define GODOTX_REVENUECAT_H

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class GodotxRevenueCat : public Object {
    GDCLASS(GodotxRevenueCat, Object);

protected:
    static void _bind_methods();

public:
    void initialize(String api_key, String user_id, bool debug);
    void get_customer_info();
    void purchase(String product_id);
    void fetch_offerings();
    void fetch_products(Array ids);
    void login(String user_id);
    void logout();
    void is_subscriber();
    bool has_entitlement(String entitlement_id);
    void check_entitlement(String entitlement_id);
    void present_paywall(String offering_id);
    void restore_purchases();

    GodotxRevenueCat() = default;
    ~GodotxRevenueCat() = default;
};

#endif
