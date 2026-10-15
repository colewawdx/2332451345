// SatProUnlock v3 — on-screen status (no PC tools needed) + presentPaywall kill + entitlement hooks.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

static NSMutableArray *gLog;

static void Log(NSString *s) {
    [gLog addObject:s];
    NSLog(@"[SatPro] %@", s);
}

static void ShowAlert(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = [gLog componentsJoinedByString:@"\n"];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"SatPro v3"
            message:msg preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIWindow *w = nil;
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
            if ([sc isKindOfClass:[UIWindowScene class]]) {
                w = ((UIWindowScene *)sc).keyWindow;
                if (w) break;
            }
        }
        if (!w) w = [UIApplication sharedApplication].keyWindow;
        [w.rootViewController presentViewController:a animated:YES completion:nil];
        // show again after 5s in case missed
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [w.rootViewController presentViewController:a animated:YES completion:nil];
        });
    });
}

static NSDictionary *FakeActive(void) {
    return @{ @"SatSquatch Pro": @{
        @"expires_date": @"2031-01-01T00:00:00Z",
        @"product_identifier": @"satsquatchpro_ios_yearly",
        @"purchase_date": @"2026-10-05T05:09:10Z" } };
}

__attribute__((constructor)) static void Init(void) {
    gLog = [NSMutableArray array];
    [gLog addObject:@"loaded"];
    // Hook every presentPaywall* on RCPaywalls/RNPaywalls to no-op
    int hooked = 0;
    for (NSString *cn in @[@"RCPaywalls", @"RNPaywalls"]) {
        Class c = objc_getClass([cn UTF8String]);
        if (!c) { [gLog addObject:[@"no class " stringByAppendingString:cn]]; continue; }
        unsigned int n = 0;
        Method *ms = class_copyMethodList(object_getClass(c), &n);
        // class methods (presentPaywall* are usually class funcs on RCPaywalls)
        for (unsigned int i = 0; i < n; i++) {
            NSString *name = NSStringFromSelector(method_getName(ms[i]));
            if ([name containsString:@"presentPaywall"] || [name containsString:@"Paywall"]) {
                method_setImplementation(ms[i], imp_implementationWithBlock(^void(id s){ }));
                hooked++;
                [gLog addObject:[@"hooked " stringByAppendingString:name]];
            }
        }
        free(ms);
        ms = class_copyMethodList(c, &n);
        for (unsigned int i = 0; i < n; i++) {
            NSString *name = NSStringFromSelector(method_getName(ms[i]));
            if ([name containsString:@"presentPaywall"]) {
                method_setImplementation(ms[i], imp_implementationWithBlock(^void(id s){ }));
                hooked++;
                [gLog addObject:[@"hooked inst " stringByAppendingString:name]];
            }
        }
        free(ms);
    }
    // Hook RCEntitlementInfos.active + all + RCCustomerInfo.entitlements
    Class ei = objc_getClass("RCEntitlementInfos");
    if (!ei) ei = objc_getClass("RevenueCat.EntitlementInfos");
    if (ei) {
        for (NSString *mn in @[@"active", @"all", @"allEntitlements"]) {
            SEL sel = sel_registerName([mn UTF8String]);
            Method m = class_getInstanceMethod(ei, sel);
            if (m) {
                method_setImplementation(m, imp_implementationWithBlock(^id(id s){ return FakeActive(); }));
                hooked++;
                [gLog addObject:[@"hooked EI." stringByAppendingString:mn]];
            } else {
                [gLog addObject:[@"miss EI." stringByAppendingString:mn]];
            }
        }
    } else {
        [gLog addObject:@"no RCEntitlementInfos class"];
    }
    [gLog addObject:[NSString stringWithFormat:@"total %d", hooked]];
    // show 3s after launch
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ ShowAlert(); });
}
