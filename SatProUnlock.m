// SatProUnlock v5 — UIAlert status + bridge hooks (iOS SDK build).
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

static NSMutableArray *gLog;
static void L(NSString *s) { [gLog addObject:s]; NSLog(@"[SatPro] %@", s); }

static NSDictionary *FakeInfo(void) {
    return @{
        @"entitlements": @{ @"active": @{ @"SatSquatch Pro": @{
            @"expires_date": @"2031-01-01T00:00:00Z",
            @"product_identifier": @"satsquatchpro_ios_yearly",
            @"purchase_date": @"2026-10-05T05:09:10Z" } } }
    };
}

static void Show(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = [gLog componentsJoinedByString:@"\n"];
        [[UIPasteboard generalPasteboard] setString:msg];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"SatPro v5"
            message:[msg stringByAppendingString:@"\n(copied)"] preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIWindow *w = nil;
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
            if ([sc isKindOfClass:[UIWindowScene class]]) { w = ((UIWindowScene *)sc).keyWindow; if (w) break; }
        }
        if (w && w.rootViewController) [w.rootViewController presentViewController:a animated:YES completion:nil];
    });
}

__attribute__((constructor)) static void Init(void) {
    gLog = [NSMutableArray arrayWithObject:@"v5 loaded"];
    Class rnp = objc_getClass("RNPurchases");
    if (!rnp) [gLog addObject:@"no RNPurchases"];
    else {
        [gLog addObject:@"RNPurchases found"];
        unsigned int n = 0;
        Method *ms = class_copyMethodList(rnp, &n);
        for (unsigned int i = 0; i < n; i++) {
            NSString *name = NSStringFromSelector(method_getName(ms[i]));
            if ([name containsString:@"ustomerInfo"]) {
                [gLog addObject:[@"INST " stringByAppendingString:name]];
                if ([name containsString:@"resolve:"]) {
                    method_setImplementation(ms[i], imp_implementationWithBlock(^void(id s, id a, id r, id j) {
                        if (r) ((void(^)(id))r)(FakeInfo());
                    }));
                    [gLog addObject:[@"HOOKED " stringByAppendingString:name]];
                }
            }
        }
        free(ms);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ Show(); });
}
