#import "godotx_revenuecat_paywall_delegate.h"
#import "godotx_revenuecat.h"

@implementation GodotxRevenueCatPaywallDelegate

// called when the paywall fails to present (missing offering etc)
- (void)paywallViewControllerDidFailToPresent:(RCPaywallViewController *)viewController error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        Dictionary d;
        d["status"] = "error";
        d["reason"] = String(error.localizedDescription.UTF8String);
        GodotxRevenueCat::get_singleton()->emit_signal("paywall_result", d);
    });
}

// called when a purchase is completed inside the paywall
- (void)paywallViewController:(RCPaywallViewController *)viewController didCompletePurchaseWithCustomerInfo:(RCCustomerInfo *)customerInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        Dictionary d;
        d["status"] = "purchased";
        d["active_entitlements"] = (int)customerInfo.entitlements.active.count;
        GodotxRevenueCat::get_singleton()->emit_signal("paywall_result", d);
    });
}

// called when a restore is completed
- (void)paywallViewController:(RCPaywallViewController *)viewController didFinishRestoreWithCustomerInfo:(RCCustomerInfo *)customerInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        Dictionary d;
        d["status"] = "restored";
        d["active_entitlements"] = (int)customerInfo.entitlements.active.count;
        GodotxRevenueCat::get_singleton()->emit_signal("paywall_result", d);
    });
}

// called when the user closes/dismisses the paywall (same as cancelled)
- (void)paywallViewControllerDidDismiss:(RCPaywallViewController *)viewController {
    dispatch_async(dispatch_get_main_queue(), ^{
        Dictionary d;
        d["status"] = "cancelled";
        GodotxRevenueCat::get_singleton()->emit_signal("paywall_result", d);
    });
}

@end
