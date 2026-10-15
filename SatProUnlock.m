// SatProUnlock.m — swizzle RevenueCat CustomerInfo to force "SatSquatch Pro" active.
// Compile on macOS: clang -arch arm64 -dynamiclib -framework Foundation -o SatProUnlock.dylib SatProUnlock.m
// Inject via @rpath LC_LOAD_DYLIB (same technique as spoti.pw kit) + re-sign.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *kEnt = @"SatSquatch Pro";
static NSString *kProduct = @"satsquatchpro_ios_yearly";
static NSString *kExpiry = @"2031-01-01T00:00:00Z";

// Build fake active entitlement dict
static NSDictionary *FakeEntitlements(void) {
    return @{ kEnt: @{
        @"expires_date": kExpiry,
        @"grace_period_expires_date": [NSNull null],
        @"product_identifier": kProduct,
        @"purchase_date": @"2026-10-05T05:09:10Z"
    }};
}

// Swizzle -[RCEntitlementInfos active] — check actual class at runtime; fall back to CustomerInfo path
__attribute__((constructor)) static void Init(void) {
    // 1) Try RCEntitlementInfos.active getter -> return dict with our entitlement
    Class cls = objc_getClass("RCEntitlementInfos");
    if (cls) {
        SEL sel = sel_registerName("active");
        Method m = class_getInstanceMethod(cls, sel);
        if (m) {
            IMP imp = imp_implementationWithBlock(^NSDictionary *(id self_) {
                return FakeEntitlements();
            });
            method_setImplementation(m, imp);
        }
    }
    // 2) Try RCCustomerInfo.entitlements -> same
    Class ci = objc_getClass("RCCustomerInfo");
    if (!ci) ci = objc_getClass("RCustomerInfo");
    if (ci) {
        SEL sel = sel_registerName("entitlements");
        Method m = class_getInstanceMethod(ci, sel);
        if (m) {
            IMP imp = imp_implementationWithBlock(^id(id self_) {
                // Return an RCEntitlementInfos-shaped object: simplest is the active dict itself.
                // If the app reads .active off it, our FakeEntitlements covers it via (1).
                return FakeEntitlements();
            });
            method_setImplementation(m, imp);
        }
    }
    // 3) allEntitlements / all fallback
    if (cls) {
        for (const char *nm in (const char *[]){"all", "allEntitlements"}) {
            SEL sel = sel_registerName(nm);
            Method m = class_getInstanceMethod(cls, sel);
            if (m) {
                IMP imp = imp_implementationWithBlock(^NSDictionary *(id self_) {
                    return FakeEntitlements();
                });
                method_setImplementation(m, imp);
            }
        }
    }
}
