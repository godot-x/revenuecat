#import "godotx_revenuecat_paywall_delegate.h"
#import "godotx_revenuecat.h"

@implementation GodotxRevenueCatPaywallDelegate

- (void)emit:(const String &)status reason:(const String &)reason entitlements:(int)entitlements {
    Dictionary d;
    d["status"] = status;
    if (!reason.is_empty()) {
        d["reason"] = reason;
    }
    d["entitlements"] = entitlements;
    GodotxRevenueCat::get_singleton()->emit_signal("paywall_result", d);
}

- (void)paywallViewControllerDidStartPurchase:(RCPaywallViewController *)controller {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"purchase_started" reason:"" entitlements:0];
    });
}

- (void)paywallViewController:(RCPaywallViewController *)controller didStartPurchaseWithPackage:(RCPackage *)package {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"purchase_started" reason:"" entitlements:0];
    });
}

- (void)paywallViewController:(RCPaywallViewController *)controller didFinishPurchasingWithCustomerInfo:(RCCustomerInfo *)customerInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"purchased" reason:"" entitlements:(int)customerInfo.entitlements.active.count];
    });
}

- (void)paywallViewController:(RCPaywallViewController *)controller didFinishPurchasingWithCustomerInfo:(RCCustomerInfo *)customerInfo transaction:(RCStoreTransaction *)transaction {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"purchased" reason:"" entitlements:(int)customerInfo.entitlements.active.count];
    });
}

- (void)paywallViewControllerDidCancelPurchase:(RCPaywallViewController *)controller {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"cancelled" reason:"" entitlements:0];
    });
}

- (void)paywallViewController:(RCPaywallViewController *)controller didFailPurchasingWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"error" reason:String(error.localizedDescription.UTF8String) entitlements:0];
    });
}

- (void)paywallViewControllerDidStartRestore:(RCPaywallViewController *)controller {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"restore_started" reason:"" entitlements:0];
    });
}

- (void)paywallViewController:(RCPaywallViewController *)controller didFinishRestoringWithCustomerInfo:(RCCustomerInfo *)customerInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"restored" reason:"" entitlements:(int)customerInfo.entitlements.active.count];
    });
}

- (void)paywallViewController:(RCPaywallViewController *)controller didFailRestoringWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"error" reason:String(error.localizedDescription.UTF8String) entitlements:0];
    });
}

- (void)paywallViewControllerWasDismissed:(RCPaywallViewController *)controller {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self emit:"dismissed" reason:"" entitlements:0];
    });
}

- (void)paywallViewController:(RCPaywallViewController *)controller didChangeSizeTo:(CGSize)size {
    dispatch_async(dispatch_get_main_queue(), ^{
        String msg = String("w=") + String::num(size.width) + ",h=" + String::num(size.height);
        [self emit:"size_changed" reason:msg entitlements:0];
    });
}

@end
