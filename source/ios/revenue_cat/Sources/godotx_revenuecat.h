#ifndef GODOTX_REVENUECAT_H
#define GODOTX_REVENUECAT_H

#include "core/object/class_db.h"
#include "core/variant/variant.h"

class GodotxRevenueCat : public Object {
    GDCLASS(GodotxRevenueCat, Object);
    
protected:
    static void _bind_methods();
    
public:
    static GodotxRevenueCat *instance;
    static GodotxRevenueCat *get_singleton();
    
    void initialize(String api_key, String user_id, bool debug);
    void get_customer_info();
    void purchase(String product_id);
    void fetch_offerings();
    void fetch_products(Array ids);
    void login(String user_id);
    void logout();
    void is_subscriber();
    void check_entitlement(String entitlement_id);
    void present_paywall(String offering_id);
    bool has_entitlement(String entitlement_id);
    
    GodotxRevenueCat();
    ~GodotxRevenueCat();
};

#endif
