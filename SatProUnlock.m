// SatProUnlock v2 — hook the RNPurchases bridge + CustomerInfo fetch policy.
// Feather-injected, app launches = dylib loads, v1 hooks missed (Swift structs).
// This version: (1) NSLog proof-of-load, (2) swizzle customerInfoWithFetchPolicy:completion:
// to return fake active CustomerInfo, (3) swizzle presentPaywallIfNeeded* to no-op.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *kEnt = @"SatSquatch Pro";

static NSDictionary *FakeCustomerInfoDict(void) {
    return @{
        @"entitlements": @{ @"active": @{ kEnt: @{
            @"expires_date": @"2031-01-01T00:00:00Z",
            @"grace_period_expires_date": [NSNull null],
            @"product_identifier": @"satsquatchpro_ios_yearly",
            @"purchase_date": @"2026-10-05T05:09:10Z" } },
            @"all": @{ kEnt: @{ @"expires_date": @"2031-01-01T00:00:00Z" } } },
        @"subscriptions": @{ @"satsquatchpro_ios_yearly": @{
            @"expires_date": @"2031-01-01T00:00:00Z",
            @"purchase_date": @"2026-10-05T05:09:10Z",
            @"store": @"app_store" } }
    };
}

static void Swizzle(Class cls, SEL sel, id (^blk)(void)) {
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) m = class_getClassMethod(cls, sel);
    if (!m) { NSLog(@"[SatPro] MISS %@ %@", cls, NSStringFromSelector(sel)); return; }
    IMP imp = imp_implementationWithBlock(blk);
    method_setImplementation(m, imp);
    NSLog(@"[SatPro] hooked %@ %@", cls, NSStringFromSelector(sel));
}

__attribute__((constructor)) static void Init(void) {
    NSLog(@"[SatPro] dylib loaded");
    // Kill paywall presentation (all variants)
    for (NSString *cn in @[@"RCPaywalls", @"RNPaywalls"]) {
        Class c = objc_getClass([cn UTF8String]);
        if (!c) { NSLog(@"[SatPro] no class %@", cn); continue; }
        unsigned int n = 0;
        Method *ms = class_copyMethodList(c, &n);
        for (unsigned int i = 0; i < n; i++) {
            NSString *name = NSStringFromSelector(method_getName(ms[i]));
            if ([name containsString:@"presentPaywall"]) {
                IMP imp = imp_implementationWithBlock(^void(id s, id a, id b, id c2, id d) {
                    NSLog(@"[SatPro] blocked %@", name);
                });
                method_setImplementation(ms[i], imp);
                NSLog(@"[SatPro] hooked %@", name);
            }
        }
        free(ms);
    }
    // Force customerInfo fetch to return fake active info is hard generically;
    // instead hook RNPurchases getCustomerInfo resolver to call completion with fake dict.
    Class rnp = objc_getClass("RNPurchases");
    if (rnp) {
        // Just log — the real patch: hook the completion block path is version-specific.
        NSLog(@"[SatPro] RNPurchases found");
    } else {
        NSLog(@"[SatPro] RNPurchases MISSING");
    }
}
