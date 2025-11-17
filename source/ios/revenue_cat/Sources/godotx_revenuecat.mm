#import "godotx_revenuecat.h"
#import "godotx_revenuecat_paywall_delegate.h"
#import <Foundation/Foundation.h>

@import RevenueCat;
@import RevenueCatUI;

GodotxRevenueCat *GodotxRevenueCat::instance = nullptr;

@interface GodotxRevenueCatDelegate : NSObject <RCPurchasesDelegate>
@end

@implementation GodotxRevenueCatDelegate

static GodotxRevenueCatDelegate *s_delegate = nullptr;
static GodotxRevenueCatPaywallDelegate *pw_delegate = nullptr;
static RCCustomerInfo *currentCustomerInfo = nullptr;

- (void)purchases:(RCPurchases *)purchases receivedUpdatedCustomerInfo:(RCCustomerInfo *)info {
    currentCustomerInfo = info;
    int count = info ? (int)info.entitlements.active.count : 0;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        Dictionary d;
        d["active_entitlements"] = count;
        GodotxRevenueCat::get_singleton()->emit_signal("customer_info_changed", d);
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
    ADD_SIGNAL(MethodInfo("products", PropertyInfo(Variant::ARRAY, "items")));
    ADD_SIGNAL(MethodInfo("login_finished", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("logout_finished", PropertyInfo(Variant::DICTIONARY, "data")));
    ADD_SIGNAL(MethodInfo("subscriber", PropertyInfo(Variant::BOOL, "value")));
    ADD_SIGNAL(MethodInfo("entitlement", PropertyInfo(Variant::STRING, "id"), PropertyInfo(Variant::BOOL, "active")));
    ADD_SIGNAL(MethodInfo("paywall_result", PropertyInfo(Variant::DICTIONARY, "data")));
    
    ClassDB::bind_method(D_METHOD("initialize", "api_key", "user_id", "debug"), &GodotxRevenueCat::initialize);
    ClassDB::bind_method(D_METHOD("get_customer_info"), &GodotxRevenueCat::get_customer_info);
    ClassDB::bind_method(D_METHOD("purchase", "product_id"), &GodotxRevenueCat::purchase);
    ClassDB::bind_method(D_METHOD("fetch_offerings"), &GodotxRevenueCat::fetch_offerings);
    ClassDB::bind_method(D_METHOD("fetch_products", "ids"), &GodotxRevenueCat::fetch_products);
    ClassDB::bind_method(D_METHOD("login", "user_id"), &GodotxRevenueCat::login);
    ClassDB::bind_method(D_METHOD("logout"), &GodotxRevenueCat::logout);
    ClassDB::bind_method(D_METHOD("is_subscriber"), &GodotxRevenueCat::is_subscriber);
    ClassDB::bind_method(D_METHOD("has_entitlement", "entitlement_id"), &GodotxRevenueCat::has_entitlement);
    ClassDB::bind_method(D_METHOD("present_paywall", "offering_id"), &GodotxRevenueCat::present_paywall);
    ClassDB::bind_method(D_METHOD("check_entitlement", "entitlement_id"), &GodotxRevenueCat::check_entitlement);
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
        currentCustomerInfo = info;
        int count = info ? (int)info.entitlements.active.count : 0;
        String err = error ? String(error.localizedDescription.UTF8String) : "";
        
        dispatch_async(dispatch_get_main_queue(), ^{
            Dictionary d;
            d["active_entitlements"] = count;
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
            currentCustomerInfo = info;
            int count = info ? (int)info.entitlements.active.count : 0;
            String err = error ? String(error.localizedDescription.UTF8String) : "";
            String tid = tx && tx.transactionIdentifier ? String(tx.transactionIdentifier.UTF8String) : "";
            
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

void GodotxRevenueCat::fetch_offerings() {
    [[RCPurchases sharedPurchases] getOfferingsWithCompletion:^(RCOfferings *offers, NSError *error) {
        String identifier = "";
        int count = 0;
        String err = error ? String(error.localizedDescription.UTF8String) : "";
        
        if (!error && offers && offers.current) {
            identifier = String(offers.current.identifier.UTF8String);
            count = (int)offers.current.availablePackages.count;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            Dictionary d;
            if (error) d["error"] = err;
            d["identifier"] = identifier;
            d["packages_count"] = count;
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
                o["id"] = p.productIdentifier ? String(p.productIdentifier.UTF8String) : "";
                o["title"] = p.localizedTitle ? String(p.localizedTitle.UTF8String) : "";
                o["description"] = p.localizedDescription ? String(p.localizedDescription.UTF8String) : "";
                o["price"] = p.localizedPriceString ? String(p.localizedPriceString.UTF8String) : "";
                o["amount"] = (double)p.price.doubleValue;
                arr.append(o);
            }
            emit_signal("products", arr);
        });
    }];
}

void GodotxRevenueCat::login(String user_id) {
    NSString *uid = @(user_id.utf8().get_data());
    
    [[RCPurchases sharedPurchases] logIn:uid completion:^(RCCustomerInfo *info, BOOL created, NSError *error) {
        currentCustomerInfo = info;
        int count = info ? (int)info.entitlements.active.count : 0;
        bool success = error == nil;
        String err = error ? String(error.localizedDescription.UTF8String) : "";
        
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
        currentCustomerInfo = info;
        int count = info ? (int)info.entitlements.active.count : 0;
        bool success = error == nil;
        String err = error ? String(error.localizedDescription.UTF8String) : "";
        
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
        currentCustomerInfo = info;
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
