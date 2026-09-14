#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

static CGFloat SHAStatusOffset = 0.0;
static CGFloat SHAHomeOffset = 0.0;

#pragma mark - Preferences

static void SHA_LoadPreferences(void)
{
    CFStringRef domain =
        CFSTR("com.congtu.statushomebaradjuster");

    CFPreferencesAppSynchronize(domain);

    CFPropertyListRef statusValue =
        CFPreferencesCopyAppValue(
            CFSTR("StatusBarOffset"),
            domain
        );

    CFPropertyListRef homeValue =
        CFPreferencesCopyAppValue(
            CFSTR("HomeBarOffset"),
            domain
        );

    SHAStatusOffset = 0.0;
    SHAHomeOffset = 0.0;

    if (statusValue &&
        CFGetTypeID(statusValue) == CFNumberGetTypeID())
    {
        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)statusValue,
            kCFNumberDoubleType,
            &value
        );

        if (value < -120.0)
            value = -120.0;

        if (value > 120.0)
            value = 120.0;

        SHAStatusOffset = (CGFloat)value;
    }

    if (homeValue &&
        CFGetTypeID(homeValue) == CFNumberGetTypeID())
    {
        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)homeValue,
            kCFNumberDoubleType,
            &value
        );

        if (value < -120.0)
            value = -120.0;

        if (value > 120.0)
            value = 120.0;

        SHAHomeOffset = (CGFloat)value;
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Settings Notification

static void SHA_PreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SHA_LoadPreferences();
}

#pragma mark - Status Bar

%hook UIStatusBar

- (void)setFrame:(CGRect)frame
{
    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        frame.origin.y += SHAStatusOffset;
    }

    %orig(frame);
}

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    UIView *view = (UIView *)self;

    if (SHAStatusOffset == 0.0)
    {
        view.transform = CGAffineTransformIdentity;
    }
    else
    {
        view.transform =
            CGAffineTransformMakeTranslation(
                0.0,
                SHAStatusOffset
            );
    }
}

%end

#pragma mark - Home Indicator

%hook _UIHomeIndicatorView

- (void)setFrame:(CGRect)frame
{
    SHA_LoadPreferences();

    if (SHAHomeOffset != 0.0)
    {
        frame.origin.y += SHAHomeOffset;
    }

    %orig(frame);
}

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    UIView *view = (UIView *)self;

    if (SHAHomeOffset == 0.0)
    {
        view.transform = CGAffineTransformIdentity;
    }
    else
    {
        view.transform =
            CGAffineTransformMakeTranslation(
                0.0,
                SHAHomeOffset
            );
    }
}

%end

#pragma mark - Runtime Status Bar Fallback

static void SHA_AdjustStatusBarViews(void)
{
    if (SHAStatusOffset == 0.0)
        return;

    Class statusClass =
        NSClassFromString(@"SBMainDisplaySceneLayoutStatusBarView");

    if (!statusClass)
        return;

    NSArray *windows = nil;

    if (@available(iOS 13.0, *))
    {
        NSMutableArray *allWindows =
            [NSMutableArray array];

        for (UIScene *scene in
             [UIApplication sharedApplication].connectedScenes)
        {
            if (![scene isKindOfClass:[UIWindowScene class]])
                continue;

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            [allWindows addObjectsFromArray:
                windowScene.windows];
        }

        windows = [allWindows copy];
    }

    for (UIWindow *window in windows)
    {
        for (UIView *subview in window.subviews)
        {
            if ([subview isKindOfClass:statusClass])
            {
                subview.transform =
                    CGAffineTransformMakeTranslation(
                        0.0,
                        SHAStatusOffset
                    );
            }
        }
    }
}

#pragma mark - Runtime Home Indicator Fallback

static void SHA_AdjustHomeIndicatorViews(void)
{
    if (SHAHomeOffset == 0.0)
        return;

    if (!@available(iOS 13.0, *))
        return;

    for (UIScene *scene in
         [UIApplication sharedApplication].connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        for (UIWindow *window in windowScene.windows)
        {
            NSArray *subviews =
                [window.subviews copy];

            for (UIView *view in subviews)
            {
                NSString *className =
                    NSStringFromClass([view class]);

                if ([className rangeOfString:@"HomeIndicator"
                                      options:NSCaseInsensitiveSearch].location
                    != NSNotFound)
                {
                    view.transform =
                        CGAffineTransformMakeTranslation(
                            0.0,
                            SHAHomeOffset
                        );
                }
            }
        }
    }
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        SHA_LoadPreferences();

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            SHA_PreferencesChanged,
            CFSTR(
                "com.congtu.statushomebaradjuster.settingsChanged"
            ),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                1 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                SHA_LoadPreferences();

                SHA_AdjustStatusBarViews();
                SHA_AdjustHomeIndicatorViews();
            }
        );
    }
}
