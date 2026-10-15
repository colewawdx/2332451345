// SatProUnlock v11
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <stdarg.h>

static NSMutableArray *gLog;
static NSTimeInterval gT0;

static void L(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    @synchronized(gLog) {
        if (gLog.count < 100) {
            [gLog addObject:[NSString stringWithFormat:@"%5.1fs %@", [NSDate timeIntervalSinceReferenceDate] - gT0, s]];
        }
    }
}

static NSDictionary *FakeInfo(void) {
    return @{
        @"request_date": @"2031-01-01T00:00:00Z",
        @"request_date_ms": @1924992000000,
        @"subscriber": @{
            @"original_app_user_id": @"$RCAnonymousID:b63febf0c871455cae15ccfed203fb27c",
            @"first_seen": @"2026-10-05T05:09:10Z",
            @"last_seen": @"2031-01-01T00:00:00Z",
            @"management_url": [NSNull null],
            @"original_application_version": @"330",
            @"original_purchase_date": @"2026-10-05T05:09:10Z",
            @"other_purchases": @{},
            @"non_subscriptions": @{},
            @"subscriptions": @{ @"satsquatchpro_ios_yearly": @{
                @"auto_resume_date": [NSNull null],
                @"billing_issues_detected_at": [NSNull null],
                @"expires_date": @"2031-01-01T00:00:00Z",
                @"grace_period_expires_date": [NSNull null],
                @"is_sandbox": @YES,
                @"original_purchase_date": @"2026-10-05T05:09:10Z",
                @"ownership_type": @"PURCHASED",
                @"period_type": @"trial",
                @"purchase_date": @"2026-10-05T05:09:10Z",
                @"refunded_at": [NSNull null],
                @"store": @"app_store",
                @"store_transaction_id": @"1",
                @"unsubscribe_detected_at": [NSNull null] } },
            @"entitlements": @{ @"SatSquatch Pro": @{
                @"expires_date": @"2031-01-01T00:00:00Z",
                @"grace_period_expires_date": [NSNull null],
                @"product_identifier": @"satsquatchpro_ios_yearly",
                @"purchase_date": @"2026-10-05T05:09:10Z" } } }
    };
}

static IMP gSend;

static void SendHook(id self, SEL _cmd, NSString *name, id body) {
    @try {
        if (name && [name containsString:@"CustomerInfo"]) {
            if ([body isKindOfClass:[NSDictionary class]]) {
                L(@"SEND %@ keys=%@", name, [[(NSDictionary *)body allKeys] componentsJoinedByString:@"|"]);
            }
            L(@"SEND %@ -> swapped", name);
            if (gSend) {
                @try { ((void(*)(id,SEL,id,id))gSend)(self, _cmd, name, FakeInfo()); }
                @catch (NSException *e) { L(@"EX fwdSwap %@: %@", e.name, e.reason); }
            }
            return;
        }
        static int cnt = 0;
        if (cnt++ < 25) L(@"SEND %@", name);
        if (gSend) {
            @try { ((void(*)(id,SEL,id,id))gSend)(self, _cmd, name, body); }
            @catch (NSException *e) { L(@"EX fwd %@: %@", e.name, e.reason); }
        }
    } @catch (NSException *e) { L(@"EX sendHook %@: %@", e.name, e.reason); }
}

static void PromiseHook(id self, SEL _cmd, id resolve, id reject) {
    @try {
        L(@"PROMISE customerInfo -> fake");
        if (resolve) ((void(^)(id))resolve)(FakeInfo());
    } @catch (NSException *e) { L(@"EX promise %@: %@", e.name, e.reason); }
}

static void PaywallNoop(id self, SEL _cmd) {
    @try { L(@"PAYWALL call blocked"); } @catch (NSException *e) { }
}

static void UncaughtHandler(NSException *e) {
    NSMutableString *full = [NSMutableString string];
    @try {
        @synchronized(gLog) { [full appendString:[gLog componentsJoinedByString:@"\n"]]; }
        [full appendFormat:@"\nUNCAUGHT %@: %@", e.name, e.reason];
        NSArray *cs = [e callStackSymbols];
        for (NSString *line in cs) {
            [full appendFormat:@"\n%@", line];
            if (full.length > 4000) break;
        }
    } @catch (NSException *e2) { }
    @try { [[UIPasteboard generalPasteboard] setString:full]; } @catch (NSException *e2) { }
}

static void Show(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg;
        @synchronized(gLog) { msg = [gLog componentsJoinedByString:@"\n"]; }
        [[UIPasteboard generalPasteboard] setString:msg];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"SatPro v11"
            message:[msg stringByAppendingString:@"\n(copied)"] preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"Refresh" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act){ Show(); }]];
        UIWindow *w = nil;
        for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
            if ([sc isKindOfClass:[UIWindowScene class]]) { w = ((UIWindowScene *)sc).keyWindow; if (w) break; }
        }
        if (!w) w = [UIApplication sharedApplication].windows.firstObject;
        if (w && w.rootViewController) [w.rootViewController presentViewController:a animated:YES completion:nil];
    });
}

__attribute__((constructor)) static void Init(void) {
    gLog = [NSMutableArray array];
    gT0 = [NSDate timeIntervalSinceReferenceDate];
    L(@"v11 loaded");
    NSSetUncaughtExceptionHandler(UncaughtHandler);

    @try {
        Class rnp = objc_getClass("RNPurchases");
        L(rnp ? @"RNPurchases found" : @"RNPurchases MISSING");
        if (rnp) {
            unsigned int n = 0;
            Method *ms = class_copyMethodList(rnp, &n);
            NSMutableString *names = [NSMutableString string];
            for (unsigned int i = 0; i < n && i < 120; i++) {
                [names appendFormat:@"%@ | ", NSStringFromSelector(method_getName(ms[i]))];
            }
            L(@"RNP methods: %@", names);
            free(ms);

            unsigned int n2 = 0;
            Method *ms2 = class_copyMethodList(object_getClass(rnp), &n2);
            NSMutableString *cnames = [NSMutableString string];
            for (unsigned int i = 0; i < n2 && i < 60; i++) {
                [cnames appendFormat:@"%@ | ", NSStringFromSelector(method_getName(ms2[i]))];
            }
            L(@"RNP class methods: %@", cnames);
            free(ms2);

            Method mSen = class_getInstanceMethod(rnp, sel_registerName("sendEventWithName:body:"));
            if (mSen) {
                gSend = method_getImplementation(mSen);
                if (class_addMethod(rnp, sel_registerName("sendEventWithName:body:"), (IMP)SendHook, method_getTypeEncoding(mSen))) {
                    L(@"send hook added");
                } else {
                    method_setImplementation(mSen, (IMP)SendHook);
                    L(@"send hook replaced");
                }
            } else {
                L(@"sendEventWithName MISSING");
            }

            Method mp = class_getInstanceMethod(rnp, sel_registerName("customerInfoWithResolve:reject:"));
            if (mp) { method_setImplementation(mp, (IMP)PromiseHook); L(@"promise hooked"); }
            else L(@"promise method MISSING");
        }

        int paywallHooks = 0;
        for (NSString *cn in @[@"RCPaywalls", @"RNPaywalls"]) {
            Class c = objc_getClass([cn UTF8String]);
            if (!c) { L(@"no class %@", cn); continue; }
            for (NSNumber *isMeta in @[@0, @1]) {
                Class k = [isMeta boolValue] ? object_getClass(c) : c;
                unsigned int n = 0;
                Method *ms = class_copyMethodList(k, &n);
                for (unsigned int i = 0; i < n; i++) {
                    NSString *name = NSStringFromSelector(method_getName(ms[i]));
                    char *rt = method_copyReturnType(ms[i]);
                    char ret = *rt;
                    free(rt);
                    if (([name containsString:@"presentPaywall"] || [name containsString:@"PresentPaywall"]) && ret == 'v') {
                        method_setImplementation(ms[i], (IMP)PaywallNoop);
                        paywallHooks++;
                    }
                }
                free(ms);
            }
        }
        L(@"paywall hooks: %d", paywallHooks);
    } @catch (NSException *e) {
        L(@"EX init %@: %@", e.name, e.reason);
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ Show(); });
}
