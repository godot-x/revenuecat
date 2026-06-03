#import "godotx_revenuecat.h"
#import "godotx_revenuecat_paywall_delegate.h"
#import <Foundation/Foundation.h>

@import RevenueCat;
@import RevenueCatUI;

GodotxRevenueCat *GodotxRevenueCat::instance = nullptr;

// Builds the customer-info payload shared by customer_info / customer_info_changed.
// active_ids carries the identifiers of every active entitlement so GDScript can gate
// on a specific entitlement instead of a bare count.
static Dictionary godotx_customer_info_dict(RCCustomerInfo *info) {
    Dictionary d;
    d["active_entitlements"] = info ? (int)info.entitlements.active.count : 0;
    Array ids;
    if (info) {
        for (NSString *key in info.entitlements.active.allKeys) {
            ids.append(String::utf8(key.UTF8String));
        }
    }
    d["active_ids"] = ids;
    return d;
}

@interface GodotxRevenueCatDelegate : NSObject <RCPurchasesDelegate>
@end

@implementation GodotxRevenueCatDelegate

static GodotxRevenueCatDelegate *s_delegate = nullptr;
static GodotxRevenueCatPaywallDelegate *pw_delegate = nullptr;
static RCCustomerInfo *currentCustomerInfo = nullptr;

- (void)purchases:(RCPurchases *)purchases receivedUpdatedCustomerInfo:(RCCustomerInfo *)info {
    currentCustomerInfo = info;

    dispatch_async(dispatch_get_main_queue(), ^{
        GodotxRevenueCat::get_singleton()->emit_signal("customer_info_changed", godotx_customer_info_dict(info));
    });
}

@end

GodotxRevenueCat *GodotxRevenueCat::get_singleton() {
    return instance;
}

GodotxRevenueCat::GodotxRevenueCat() {
    if (instance != nullptr) {
        ERR_FAIL_MSG("Instance already exists");
    }
    instance = this;
    currentCustomerInfo = nullptr;
}

GodotxRevenueCat::~GodotxRevenueCat() {
    if (instance == this) {
        instance = nullptr;
    }
    
    currentCustomerInfo = nullptr;
}

void GodotxRevenueCat::_bind_methods() {
    ADD_SIGNAL(MethodInfo("customer_info_changed", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("customer_info", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("purchase_result", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("offerings", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("products", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("login_finished", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("logout_finished", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("subscriber", PropertyInfo(Variant::BOOL, "value")));
    ADD_SIGNAL(MethodInfo("entitlement", PropertyInfo(Variant::STRING, "id"), PropertyInfo(Variant::BOOL, "active")));
    ADD_SIGNAL(MethodInfo("paywall_result", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("restore_finished", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("manage_subscriptions_finished", PropertyInfo(Variant::DICTIONARY, "data")));

    ClassDB::bind_method(D_METHOD("initialize", "api_key", "user_id", "debug"), &GodotxRevenueCat::initialize);
    ClassDB::bind_method(D_METHOD("get_customer_info"), &GodotxRevenueCat::get_customer_info);
    ClassDB::bind_method(D_METHOD("purchase", "product_id"), &GodotxRevenueCat::purchase);
    ClassDB::bind_method(D_METHOD("purchase_package", "offering_id", "package_id"), &GodotxRevenueCat::purchase_package);
    ClassDB::bind_method(D_METHOD("fetch_offerings"), &GodotxRevenueCat::fetch_offerings);
    ClassDB::bind_method(D_METHOD("fetch_products", "ids"), &GodotxRevenueCat::fetch_products);
    ClassDB::bind_method(D_METHOD("login", "user_id"), &GodotxRevenueCat::login);
    ClassDB::bind_method(D_METHOD("logout"), &GodotxRevenueCat::logout);
    ClassDB::bind_method(D_METHOD("is_subscriber"), &GodotxRevenueCat::is_subscriber);
    ClassDB::bind_method(D_METHOD("has_entitlement", "entitlement_id"), &GodotxRevenueCat::has_entitlement);
    ClassDB::bind_method(D_METHOD("present_paywall", "offering_id"), &GodotxRevenueCat::present_paywall);
    ClassDB::bind_method(D_METHOD("check_entitlement", "entitlement_id"), &GodotxRevenueCat::check_entitlement);
    ClassDB::bind_method(D_METHOD("restore_purchases"), &GodotxRevenueCat::restore_purchases);
    ClassDB::bind_method(D_METHOD("show_manage_subscriptions"), &GodotxRevenueCat::show_manage_subscriptions);
    ClassDB::bind_method(D_METHOD("set_attributes", "attributes"), &GodotxRevenueCat::set_attributes);
}

void GodotxRevenueCat::initialize(String api_key, String user_id, bool debug) {
    if (debug) {
        RCPurchases.logLevel = RCLogLevelDebug;
    } else {
        RCPurchases.logLevel = RCLogLevelError;
    }
    
    NSString *api = @(api_key.utf8().get_data());
    NSString *uid = user_id.is_empty() ? nil : @(user_id.utf8().get_data());
    
    [RCPurchases configureWithAPIKey:api appUserID:uid];
    
    if (!s_delegate) {
        s_delegate = [GodotxRevenueCatDelegate new];
    }
    
    [RCPurchases sharedPurchases].delegate = s_delegate;
    currentCustomerInfo = nullptr;
}

void GodotxRevenueCat::get_customer_info() {
    [[RCPurchases sharedPurchases] getCustomerInfoWithCompletion:^(RCCustomerInfo *info, NSError *error) {
        if (info) currentCustomerInfo = info;
        String err = error ? String::utf8(error.localizedDescription.UTF8String) : "";

        dispatch_async(dispatch_get_main_queue(), ^{
            Dictionary d = godotx_customer_info_dict(info);
            if (error) d["error"] = err;
            emit_signal("customer_info", d);
        });
    }];
}

void GodotxRevenueCat::purchase(String pid) {
    NSString *productId = @(pid.utf8().get_data());
    
    [[RCPurchases sharedPurchases] getProductsWithIdentifiers:@[productId] completion:^(NSArray<RCStoreProduct *> *products) {
        if (products.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Dictionary d;
                d["cancelled"] = false;
                d["active_entitlements"] = 0;
                d["error"] = "not_found";
                d["product_id"] = pid;
                d["transaction_id"] = "";
                emit_signal("purchase_result", d);
            });
            return;
        }
        
        RCStoreProduct *p = products.firstObject;
        
        [[RCPurchases sharedPurchases] purchaseProduct:p withCompletion:^(RCStoreTransaction *tx, RCCustomerInfo *info, NSError *error, BOOL cancelled) {
            if (info) currentCustomerInfo = info;
            int count = info ? (int)info.entitlements.active.count : 0;
            String err = error ? String::utf8(error.localizedDescription.UTF8String) : "";
            String tid = tx && tx.transactionIdentifier ? String::utf8(tx.transactionIdentifier.UTF8String) : "";
            
            dispatch_async(dispatch_get_main_queue(), ^{
                Dictionary d;
                d["cancelled"] = cancelled;
                d["active_entitlements"] = count;
                d["error"] = error ? err : "";
                d["product_id"] = pid;
                d["transaction_id"] = tid;
                emit_signal("purchase_result", d);
            });
        }];
    }];
}

// Matches PackageType.name on Android (the Kotlin enum constant name), so package_type is
// the same string on both platforms. Not RCPackage.stringFrom:, which yields "$rc_monthly".
static String godotx_revenuecat_package_type_name(RCPackageType type) {
    switch (type) {
        case RCPackageTypeCustom: return "CUSTOM";
        case RCPackageTypeLifetime: return "LIFETIME";
        case RCPackageTypeAnnual: return "ANNUAL";
        case RCPackageTypeSixMonth: return "SIX_MONTH";
        case RCPackageTypeThreeMonth: return "THREE_MONTH";
        case RCPackageTypeTwoMonth: return "TWO_MONTH";
        case RCPackageTypeMonthly: return "MONTHLY";
        case RCPackageTypeWeekly: return "WEEKLY";
        default: return "UNKNOWN";
    }
}

static Dictionary godotx_revenuecat_product_dict(RCStoreProduct *p) {
    Dictionary o;
    o["id"] = p.productIdentifier ? String(p.productIdentifier.UTF8String) : "";
    o["title"] = p.localizedTitle ? String(p.localizedTitle.UTF8String) : "";
    o["description"] = p.localizedDescription ? String(p.localizedDescription.UTF8String) : "";
    o["price"] = p.localizedPriceString ? String(p.localizedPriceString.UTF8String) : "";
    o["amount"] = (double)p.price.doubleValue;
    o["currency"] = p.currencyCode ? String(p.currencyCode.UTF8String) : "";
    return o;
}

static Array godotx_revenuecat_packages_array(NSArray<RCPackage *> *packages) {
    Array arr;
    for (RCPackage *pkg in packages) {
        Dictionary d;
        d["identifier"] = pkg.identifier ? String(pkg.identifier.UTF8String) : "";
        d["package_type"] = godotx_revenuecat_package_type_name(pkg.packageType);
        d["product"] = godotx_revenuecat_product_dict(pkg.storeProduct);
        arr.append(d);
    }
    return arr;
}

void GodotxRevenueCat::fetch_offerings() {
    [[RCPurchases sharedPurchases] getOfferingsWithCompletion:^(RCOfferings *offers, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            Dictionary d;
            d["error"] = error ? String(error.localizedDescription.UTF8String) : "";
            d["identifier"] = "";
            d["packages"] = Array();
            d["offerings"] = Array();

            if (!error && offers) {
                Array all;
                for (NSString *key in offers.all) {
                    RCOffering *off = offers.all[key];
                    Dictionary o;
                    o["identifier"] = off.identifier ? String(off.identifier.UTF8String) : "";
                    o["packages"] = godotx_revenuecat_packages_array(off.availablePackages);
                    all.append(o);
                }
                d["offerings"] = all;

                if (offers.current) {
                    d["identifier"] = String(offers.current.identifier.UTF8String);
                    d["packages"] = godotx_revenuecat_packages_array(offers.current.availablePackages);
                }
            }

            emit_signal("offerings", d);
        });
    }];
}

void GodotxRevenueCat::fetch_products(Array ids) {
    NSMutableArray *native = [NSMutableArray array];
    for (int i = 0; i < ids.size(); i++) {
        String s = ids[i];
        [native addObject:@(s.utf8().get_data())];
    }
    
    [[RCPurchases sharedPurchases] getProductsWithIdentifiers:native completion:^(NSArray<RCStoreProduct *> *products) {
        dispatch_async(dispatch_get_main_queue(), ^{
            Array arr;
            for (RCStoreProduct *p in products) {
                Dictionary o;
                o["id"] = p.productIdentifier ? String::utf8(p.productIdentifier.UTF8String) : "";
                o["title"] = p.localizedTitle ? String::utf8(p.localizedTitle.UTF8String) : "";
                o["description"] = p.localizedDescription ? String::utf8(p.localizedDescription.UTF8String) : "";
                o["price"] = p.localizedPriceString ? String::utf8(p.localizedPriceString.UTF8String) : "";
                o["amount"] = (double)p.price.doubleValue;
                arr.append(o);
            }
            
            Dictionary result;
            result["products"] = arr;
            result["error"] = "";
            emit_signal("products", result);
        });
    }];
}

void GodotxRevenueCat::login(String user_id) {
    NSString *uid = @(user_id.utf8().get_data());
    
    [[RCPurchases sharedPurchases] logIn:uid completion:^(RCCustomerInfo *info, BOOL created, NSError *error) {
        if (info) currentCustomerInfo = info;
        int count = info ? (int)info.entitlements.active.count : 0;
        bool success = error == nil;
        String err = error ? String::utf8(error.localizedDescription.UTF8String) : "";
        
        dispatch_async(dispatch_get_main_queue(), ^{
            Dictionary d;
            d["success"] = success;
            d["created"] = created;
            if (error) d["error"] = err;
            d["active_entitlements"] = count;
            emit_signal("login_finished", d);
        });
    }];
}

void GodotxRevenueCat::logout() {
    [[RCPurchases sharedPurchases] logOutWithCompletion:^(RCCustomerInfo *info, NSError *error) {
        if (info) currentCustomerInfo = info;
        int count = info ? (int)info.entitlements.active.count : 0;
        bool success = error == nil;
        String err = error ? String::utf8(error.localizedDescription.UTF8String) : "";
        
        dispatch_async(dispatch_get_main_queue(), ^{
            Dictionary d;
            d["success"] = success;
            if (error) d["error"] = err;
            d["active_entitlements"] = count;
            emit_signal("logout_finished", d);
        });
    }];
}

void GodotxRevenueCat::is_subscriber() {
    bool active = currentCustomerInfo && ((RCCustomerInfo *)currentCustomerInfo).entitlements.active.count > 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        emit_signal("subscriber", active);
    });
}

void GodotxRevenueCat::check_entitlement(String entitlement_id) {
    NSString *eid = @(entitlement_id.utf8().get_data());
    
    [[RCPurchases sharedPurchases] getCustomerInfoWithCompletion:^(RCCustomerInfo *info, NSError *error) {
        if (info) currentCustomerInfo = info;
        bool active = false;
        
        if (info) {
            RCEntitlementInfo *e = info.entitlements[eid];
            if (e && e.isActive) active = true;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            emit_signal("entitlement", entitlement_id, active);
        });
    }];
}

bool GodotxRevenueCat::has_entitlement(String entitlement_id) {
    if (!currentCustomerInfo) return false;
    
    NSString *eid = @(entitlement_id.utf8().get_data());
    RCEntitlementInfo *ent = ((RCCustomerInfo*)currentCustomerInfo).entitlements[eid];
    return ent && ent.isActive;
}

void GodotxRevenueCat::restore_purchases() {
    [[RCPurchases sharedPurchases] restorePurchasesWithCompletion:^(RCCustomerInfo *info, NSError *error) {
        if (info) currentCustomerInfo = info;

        int count = info ? (int)info.entitlements.active.count : 0;
        String err = error ? String::utf8(error.localizedDescription.UTF8String) : "";
        bool success = error == nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            Dictionary d;
            d["success"] = success;
            d["restored"] = count > 0;
            d["active_entitlements"] = count;
            d["error"] = err;
            emit_signal("restore_finished", d);
        });
    }];
}

void GodotxRevenueCat::show_manage_subscriptions() {
    [[RCPurchases sharedPurchases] showManageSubscriptionsWithCompletion:^(NSError *error) {
        String err = error ? String::utf8(error.localizedDescription.UTF8String) : "";
        bool success = error == nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            Dictionary d;
            d["success"] = success;
            if (error) d["error"] = err;
            emit_signal("manage_subscriptions_finished", d);
        });
    }];
}

void GodotxRevenueCat::set_attributes(Dictionary attributes) {
    NSMutableDictionary<NSString *, NSString *> *native = [NSMutableDictionary dictionary];
    Array keys = attributes.keys();
    for (int i = 0; i < keys.size(); i++) {
        String k = keys[i];
        String v = attributes[keys[i]];
        native[@(k.utf8().get_data())] = @(v.utf8().get_data());
    }
    [[[RCPurchases sharedPurchases] attribution] setAttributes:native];
}

static UIViewController *godotx_revenuecat_get_root_view_controller() {
    UIWindow *keyWindow = nil;
    
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) if (w.isKeyWindow) keyWindow = w;
        }
    }
    
    if (!keyWindow) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                if (ws.windows.count > 0) keyWindow = ws.windows.firstObject;
            }
        }
    }
    
    UIViewController *root = keyWindow.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    return root;
}

void GodotxRevenueCat::present_paywall(String offering_id) {
    NSString *oid = offering_id.is_empty() ? nil : @(offering_id.utf8().get_data());
    
    [[RCPurchases sharedPurchases] getOfferingsWithCompletion:^(RCOfferings *offers, NSError *error) {
        if (error || !offers) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Dictionary out;
                out["status"] = "error";
                out["reason"] = "fetch_error";
                emit_signal("paywall_result", out);
            });
            return;
        }
        
        RCOffering *off = oid ? offers.all[oid] : offers.current;
        
        if (!off) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Dictionary out;
                out["status"] = "error";
                out["reason"] = "offering_not_found";
                emit_signal("paywall_result", out);
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *root = godotx_revenuecat_get_root_view_controller();
            
            if (!root) {
                Dictionary out;
                out["status"] = "error";
                out["reason"] = "no_root";
                emit_signal("paywall_result", out);
                return;
            }
            
            RCPaywallViewController *pw = [[RCPaywallViewController alloc] initWithOffering:off displayCloseButton:YES shouldBlockTouchEvents:NO dismissRequestedHandler:nil];
            
            if (pw_delegate == nullptr) {
                pw_delegate = [GodotxRevenueCatPaywallDelegate new];
            }
            
            pw.delegate = pw_delegate;
            
            [root presentViewController:pw animated:YES completion:nil];
        });
    }];
}

static void godotx_revenuecat_emit_purchase_result(bool cancelled, int entitlements, const String &error, const String &product_id, const String &transaction_id) {
    Dictionary d;
    d["cancelled"] = cancelled;
    d["active_entitlements"] = entitlements;
    d["error"] = error;
    d["product_id"] = product_id;
    d["transaction_id"] = transaction_id;
    GodotxRevenueCat::get_singleton()->emit_signal("purchase_result", d);
}

void GodotxRevenueCat::purchase_package(String offering_id, String package_id) {
    NSString *oid = offering_id.is_empty() ? nil : @(offering_id.utf8().get_data());
    NSString *pkg_id = @(package_id.utf8().get_data());

    [[RCPurchases sharedPurchases] getOfferingsWithCompletion:^(RCOfferings *offers, NSError *error) {
        if (error || !offers) {
            String err = error ? String(error.localizedDescription.UTF8String) : "offering_not_found";

            dispatch_async(dispatch_get_main_queue(), ^{
                godotx_revenuecat_emit_purchase_result(false, 0, err, "", "");
            });
            return;
        }

        RCOffering *off = oid ? offers.all[oid] : offers.current;

        if (!off) {
            dispatch_async(dispatch_get_main_queue(), ^{
                godotx_revenuecat_emit_purchase_result(false, 0, "offering_not_found", "", "");
            });
            return;
        }

        RCPackage *pkg = nil;
        for (RCPackage *p in off.availablePackages) {
            if ([p.identifier isEqualToString:pkg_id]) {
                pkg = p;
                break;
            }
        }

        if (!pkg) {
            dispatch_async(dispatch_get_main_queue(), ^{
                godotx_revenuecat_emit_purchase_result(false, 0, "package_not_found", "", "");
            });
            return;
        }

        String pid = pkg.storeProduct.productIdentifier ? String(pkg.storeProduct.productIdentifier.UTF8String) : "";

        // Purchasing the Package (not a re-resolved product id) is what carries the
        // store-side subscription option that purchase(String) cannot express.
        [[RCPurchases sharedPurchases] purchasePackage:pkg withCompletion:^(RCStoreTransaction *tx, RCCustomerInfo *info, NSError *purchase_error, BOOL cancelled) {
            if (info) currentCustomerInfo = info;
            int count = info ? (int)info.entitlements.active.count : 0;
            String err = purchase_error ? String(purchase_error.localizedDescription.UTF8String) : "";
            String tid = tx && tx.transactionIdentifier ? String(tx.transactionIdentifier.UTF8String) : "";

            dispatch_async(dispatch_get_main_queue(), ^{
                godotx_revenuecat_emit_purchase_result(cancelled, count, err, pid, tid);
            });
        }];
    }];
}
