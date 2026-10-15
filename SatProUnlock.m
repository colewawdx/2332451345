// SatProUnlock v6 — no block swizzles. Only: (1) log classes, (2) kill paywall presentation (void methods only).
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSMutableArray *gLog;
static void L(NSString *s) { [gLog addObject:s]; NSLog(@"[SatPro] %@", s); }

static void Show(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = [gLog componentsJoinedByString:@"\n"];
        [[UIPasteboard generalPasteboard] setString:msg];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"SatPro v6"
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
    gLog = [NSMutableArray arrayWithObject:@"v6 loaded"];
    // Hook ONLY void-returning present/dismiss methods (no blocks => no crash)
    for (NSString *cn in @[@"RCPaywalls", @"RNPaywalls"]) {
        Class c = objc_getClass([cn UTF8String]);
        if (!c) { L([@"no class " stringByAppendingString:cn]); continue; }
        for (NSNumber *isMeta in @[@0, @1]) {
            Class k = [isMeta boolValue] ? object_getClass(c) : c;
            unsigned int n = 0;
            Method *ms = class_copyMethodList(k, &n);
            for (unsigned int i = 0; i < n; i++) {
                NSString *name = NSStringFromSelector(method_getName(ms[i]));
                char ret = *method_copyReturnType(ms[i]);
                if (([name containsString:@"presentPaywall"] || [name containsString:@"PresentPaywall"]) && (ret == 'v')) {
                    method_setImplementation(ms[i], imp_implementationWithBlock(^void(id s){ L([@"blocked " stringByAppendingString:name]); }));
                    L([@"HOOKED " stringByAppendingString:name]);
                }
            }
            free(ms);
        }
    }
    // Log RNPurchases resolvers WITHOUT hooking (diagnostic only)
    Class rnp = objc_getClass("RNPurchases");
    if (rnp) {
        unsigned int n = 0;
        Method *ms = class_copyMethodList(rnp, &n);
        for (unsigned int i = 0; i < n; i++) {
            NSString *name = NSStringFromSelector(method_getName(ms[i]));
            if ([name containsString:@"ustomerInfo"]) L([@"RNP " stringByAppendingString:name]);
        }
        free(ms);
    } else L(@"no RNPurchases");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ Show(); });
}
