#import "godotx_revenuecat.h"

#import <Foundation/Foundation.h>

@import RevenueCat;
@import RevenueCatUI;

GodotxRevenueCat *GodotxRevenueCat::instance = nullptr;

#pragma mark - Delegate

@interface GodotxRevenueCatDelegate : NSObject <RCPurchasesDelegate>
@end

@implementation GodotxRevenueCatDelegate

- (void)purchases:(RCPurchases *)purchases receivedUpdatedCustomerInfo:(RCCustomerInfo *)info {
    if (!info) return;
    
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"active_entitlements"] = @(info.entitlements.active.count);
    
    GodotxRevenueCat::get_singleton()->emit_signal("customer_info_changed", d);
}

@end

static GodotxRevenueCatDelegate *s_delegate = nil;

#pragma mark - Class Setup

GodotxRevenueCat *GodotxRevenueCat::get_singleton() {
    return instance;
}

GodotxRevenueCat::GodotxRevenueCat() {
    ERR_FAIL_COND(instance != nullptr);
    instance = this;
}

GodotxRevenueCat::~GodotxRevenueCat() {
    if (instance == this) {
        instance = nullptr;
    }
}

#pragma mark - Bind

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
}

#pragma mark - API Implementations

void GodotxRevenueCat::initialize(String api_key, String user_id, bool debug) {
    RCPurchases.logLevel = debug ? RCLogLevelDebug : RCLogLevelError;
    
    NSString *api = @(api_key.utf8().get_data());
    NSString *uid = user_id.is_empty() ? nil : @(user_id.utf8().get_data());
    
    [RCPurchases configureWithAPIKey:api appUserID:uid];
    
    if (!s_delegate) {
        s_delegate = [GodotxRevenueCatDelegate new];
    }
    
    [RCPurchases sharedPurchases].delegate = s_delegate;
}

#pragma mark - Customer Info

void GodotxRevenueCat::get_customer_info() {
    [[RCPurchases sharedPurchases] getCustomerInfoWithCompletion:^(RCCustomerInfo *info, NSError *error) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        
        if (info) {
            d[@"active_entitlements"] = @(info.entitlements.active.count);
        }
        
        if (error) {
            d[@"error"] = error.localizedDescription;
        }
        
        emit_signal("customer_info", d);
    }];
}

#pragma mark - Purchase

void GodotxRevenueCat::purchase(String pid) {
    NSString *productId = @(pid.utf8().get_data());
    
    [[RCPurchases sharedPurchases] getProductsWithIdentifiers:@[productId] completion:^(NSArray<RCStoreProduct *> *products) {
        if (products.count == 0) {
            emit_signal("purchase_result", @{@"error": @"not_found"});
        } else {
            RCStoreProduct *p = products.firstObject;
            
            [[RCPurchases sharedPurchases] purchaseProduct:p withCompletion:^(RCStoreTransaction *tx, RCCustomerInfo *info, NSError *error, BOOL cancelled) {
                NSMutableDictionary *d = [NSMutableDictionary dictionary];
                d[@"cancelled"] = @(cancelled);
                
                if (error) {
                    d[@"error"] = error.localizedDescription;
                }
                
                if (info) {
                    d[@"active_entitlements"] = @(info.entitlements.active.count);
                }
                
                if (tx) {
                    d[@"productId"] = tx.productIdentifier ?: @"";
                    d[@"transactionId"] = tx.transactionIdentifier ?: @"";
                }
                
                emit_signal("purchase_result", d);
            }];
        }
    }];
}

#pragma mark - Offerings

void GodotxRevenueCat::fetch_offerings() {
    [[RCPurchases sharedPurchases] getOfferingsWithCompletion:^(RCOfferings *offers, NSError *error) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        
        if (error) {
            d[@"error"] = error.localizedDescription;
        } else if (offers.current) {
            d[@"identifier"] = offers.current.identifier;
            d[@"packages_count"] = @(offers.current.availablePackages.count);
        }
        
        emit_signal("offerings", d);
    }];
}

#pragma mark - Products

void GodotxRevenueCat::fetch_products(Array ids) {
    NSMutableArray *native = [NSMutableArray array];
    
    for (int i = 0; i < ids.size(); i++) {
        [native addObject:@(String(ids[i]).utf8().get_data())];
    }
    
    [[RCPurchases sharedPurchases] getProductsWithIdentifiers:native completion:^(NSArray<RCStoreProduct *> *products) {
        NSMutableArray *arr = [NSMutableArray array];
        
        for (RCStoreProduct *p in products) {
            NSString *priceStr = p.localizedPriceString;
            
            NSMutableDictionary *o = [NSMutableDictionary dictionary];
            o[@"id"] = p.productIdentifier;
            o[@"title"] = p.localizedTitle ?: @"";
            o[@"description"] = p.localizedDescription ?: @"";
            o[@"price"] = priceStr;
            o[@"amount"] = [NSDecimalNumber decimalNumberWithDecimal: p.price.decimalValue];
            
            [arr addObject:o];
        }
        
        emit_signal("products", arr);
    }];
}

#pragma mark - Login

void GodotxRevenueCat::login(String user_id) {
    NSString *uid = @(user_id.utf8().get_data());
    
    [[RCPurchases sharedPurchases] logIn:uid completion:^(RCCustomerInfo *info, BOOL created, NSError *error) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        d[@"success"] = @(error == nil);
        d[@"created"] = @(created);
        
        if (error) {
            d[@"error"] = error.localizedDescription;
        }
        
        if (info) {
            d[@"active_entitlements"] = @(info.entitlements.active.count);
        }
        
        emit_signal("login_finished", d);
    }];
}

#pragma mark - Logout

void GodotxRevenueCat::logout() {
    [[RCPurchases sharedPurchases] logOutWithCompletion:^(RCCustomerInfo *info, NSError *error) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        d[@"success"] = @(error == nil);
        
        if (error) {
            d[@"error"] = error.localizedDescription;
        }
        
        if (info) {
            d[@"active_entitlements"] = @(info.entitlements.active.count);
        }
        
        emit_signal("logout_finished", d);
    }];
}

#pragma mark - Subscriber

void GodotxRevenueCat::is_subscriber() {
    [[RCPurchases sharedPurchases] getCustomerInfoWithCompletion:^(RCCustomerInfo *info, NSError *error) {
        BOOL active = info && info.entitlements.active.count > 0;
        emit_signal("subscriber", active);
    }];
}

#pragma mark - Entitlement

void GodotxRevenueCat::has_entitlement(String entitlement_id) {
    NSString *eid = @(entitlement_id.utf8().get_data());
    
    [[RCPurchases sharedPurchases] getCustomerInfoWithCompletion:^(RCCustomerInfo *info, NSError *error) {
        BOOL active = NO;
        
        if (info) {
            RCEntitlementInfo *e = info.entitlements[eid];
            if (e) active = e.isActive;
        }
        
        emit_signal("entitlement", entitlement_id, active);
    }];
}

#pragma mark - Paywall

static UIViewController *godotx_revenuecat_get_root_view_controller() {
    UIWindow *keyWindow = nil;
    
    // iterate over all connected scenes
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
        }
        if (keyWindow) break;
    }
    
    // fallback: get the first window if no keyWindow was found
    if (!keyWindow) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                if (windowScene.windows.count > 0) {
                    keyWindow = windowScene.windows.firstObject;
                    break;
                }
            }
        }
    }
    
    UIViewController *root = keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    return root;
}

void GodotxRevenueCat::present_paywall(String offering_id) {
    NSString *oid = offering_id.is_empty() ? nil : @(offering_id.utf8().get_data());
    
    [[RCPurchases sharedPurchases] getOfferingsWithCompletion:^(RCOfferings *offers, NSError *error) {
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        
        if (error || !offers) {
            out[@"status"] = @"error";
            out[@"reason"] = @"fetch_error";
            emit_signal("paywall_result", out);
            return;
        }
        
        RCOffering *off = oid ? offers.all[oid] : offers.current;
        
        if (!off) {
            out[@"status"] = @"error";
            out[@"reason"] = @"offering_not_found";
            emit_signal("paywall_result", out);
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *root = godotx_revenuecat_get_root_view_controller();
            
            if (!root) {
                out[@"status"] = @"error";
                out[@"reason"] = @"no_root";
                emit_signal("paywall_result", out);
                return;
            }
            
            RCPaywallViewController *pw = [[RCPaywallViewController alloc] initWithOffering:off
                                                                         displayCloseButton:YES
                                                                     shouldBlockTouchEvents:NO
                                                                    dismissRequestedHandler:^(RCPaywallViewController *vc) {
                [vc dismissViewControllerAnimated:YES completion:nil];
                
                emit_signal("paywall_result", @{@"status": @"cancelled"});
            }];
            
            [root presentViewController:pw animated:YES completion:nil];
        });
    }];
}
