// SatProUnlock FINAL — silent unlock, no popups, no logs.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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

__attribute__((constructor)) static void Init(void) {
    Class rnp = objc_getClass("RNPurchases");
    if (!rnp) return;
    SEL sel = sel_registerName("customerInfoWithResolve:reject:");
    Method m = class_getInstanceMethod(rnp, sel);
    if (!m) return;
    id blk = ^(id _s, id resolve, id reject) {
        if (resolve) ((void(^)(id))resolve)(FakeInfo());
    };
    method_setImplementation(m, imp_implementationWithBlock(blk));
}
