// SatProUnlock v10
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

static IMP Replace(Class c, SEL sel, IMP newImp) {
    Method m = class_getInstanceMethod(c, sel);
    if (!m) return NULL;
    IMP old = method_getImplementation(m);
    const char *types = method_getTypeEncoding(m);
    if (class_addMethod(c, sel, newImp, types)) {
        return old;
    }
    method_setImplementation(m, newImp);
    return old;
}

static IMP gSend, gUpdated;

static void SendHook(id self, SEL _cmd, NSString *name, id body) {
    if ([name containsString:@"CustomerInfo"]) {
        if ([body isKindOfClass:[NSDictionary class]]) {
            L(@"SEND %@ keys=%@", name, [[(NSDictionary *)body allKeys] componentsJoinedByString:@"|"]);
        }
        L(@"SEND %@ -> swapped", name);
        if (gSend) ((void(*)(id,SEL,id,id))gSend)(self, _cmd, name, FakeInfo());
    } else {
        static int cnt = 0;
        if (cnt++ < 25) L(@"SEND %@", name);
        if (gSend) ((void(*)(id,SEL,id,id))gSend)(self, _cmd, name, body);
    }
}

static void UpdatedHook(id self, SEL _cmd, id purchases, id info) {
    L(@"DELEGATE receivedUpdatedCustomerInfo");
    if (gUpdated) ((void(*)(id,SEL,id,id))gUpdated)(self, _cmd, purchases, info);
}

static void PromiseHook(id self, SEL _cmd, id resolve, id reject) {
    L(@"PROMISE customerInfo -> fake");
    if (resolve) ((void(^)(id))resolve)(FakeInfo());
}

static void PaywallNoop(id self, SEL _cmd) { L(@"PAYWALL call blocked"); }
static void InvalidateNoop(id self, SEL _cmd) { L(@"invalidateCache called"); }

static void Show(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg;
        @synchronized(gLog) { msg = [gLog componentsJoinedByString:@"\n"]; }
        [[UIPasteboard generalPasteboard] setString:msg];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"SatPro v10"
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
    L(@"v10 loaded");

    int num = objc_getClassList(NULL, 0);
    Class *all = malloc(sizeof(Class) * num);
    objc_getClassList(all, num);
    for (int i = 0; i < num; i++) {
        unsigned int mn = 0;
        Method *ms = class_copyMethodList(all[i], &mn);
        for (unsigned int j = 0; j < mn; j++) {
            NSString *name = NSStringFromSelector(method_getName(ms[j]));
            if ([name isEqualToString:@"encodeCustomerInfo:"]) {
                L(@"encodeCustomerInfo: ON %s types %s", class_getName(all[i]), method_getTypeEncoding(ms[j]));
            }
        }
        free(ms);
    }
    free(all);

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

    Class rnp = objc_getClass("RNPurchases");
    L(rnp ? @"RNPurchases found" : @"RNPurchases MISSING");
    if (!rnp) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ Show(); }); return; }

    gSend = Replace(rnp, sel_registerName("sendEventWithName:body:"), (IMP)SendHook);
    gUpdated = Replace(rnp, sel_registerName("purchases:receivedUpdatedCustomerInfo:"), (IMP)UpdatedHook);
    Replace(rnp, sel_registerName("invalidateCustomerInfoCache"), (IMP)InvalidateNoop);
    L(@"hooks: send=%@ delegate=%@", gSend?@"ok":@"MISSING", gUpdated?@"ok":@"MISSING");

    Method mp = class_getInstanceMethod(rnp, sel_registerName("customerInfoWithResolve:reject:"));
    if (mp) { method_setImplementation(mp, (IMP)PromiseHook); L(@"promise hooked"); }
    else L(@"promise method MISSING");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ Show(); });
}
