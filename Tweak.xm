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

        value = MAX(-120.0, MIN(120.0, value));

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

        value = MAX(-120.0, MIN(120.0, value));

        SHAHomeOffset = (CGFloat)value;
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Status Bar

static void SHA_ApplyStatusBar(UIView *view)
{
    if (!view)
        return;

    if (SHAStatusOffset == 0.0)
        return;

    CGRect frame = view.frame;

    frame.origin.y += SHAStatusOffset;

    view.frame = frame;
}

#pragma mark - Home Bar

static void SHA_ApplyHomeBar(UIView *view)
{
    if (!view)
        return;

    if (SHAHomeOffset == 0.0)
        return;

    CGRect frame = view.frame;

    frame.origin.y += SHAHomeOffset;

    view.frame = frame;
}

#pragma mark - Recursive Home Indicator Search

static void SHA_SearchHomeIndicator(UIView *view)
{
    if (!view)
        return;

    NSString *className =
        NSStringFromClass([view class]);

    if (className)
    {
        BOOL isHomeIndicator =
            [className rangeOfString:
                @"HomeIndicator"
                options:NSCaseInsensitiveSearch].location
                != NSNotFound;

        BOOL isHomeBar =
            [className rangeOfString:
                @"HomeBar"
                options:NSCaseInsensitiveSearch].location
                != NSNotFound;

        BOOL isPill =
            [className rangeOfString:
                @"LumaDodgePill"
                options:NSCaseInsensitiveSearch].location
                != NSNotFound;

        if (isHomeIndicator ||
            isHomeBar ||
            isPill)
        {
            CGRect frame = view.frame;

            if (frame.size.height >= 2.0 &&
                frame.size.height <= 100.0)
            {
                SHA_ApplyHomeBar(view);
            }
        }
    }

    for (UIView *subview in view.subviews)
    {
        SHA_SearchHomeIndicator(subview);
    }
}

#pragma mark - Find Windows

static void SHA_ApplyHomeBarToScenes(void)
{
    if (SHAHomeOffset == 0.0)
        return;

    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application)
        return;

    if (@available(iOS 13.0, *))
    {
        NSSet<UIScene *> *scenes =
            application.connectedScenes;

        for (UIScene *scene in scenes)
        {
            if (![scene
                    isKindOfClass:[UIWindowScene class]])
            {
                continue;
            }

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            for (UIWindow *window
                 in windowScene.windows)
            {
                if (!window)
                    continue;

                SHA_SearchHomeIndicator(window);
            }
        }
    }
}

#pragma mark - _UIStatusBar

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyStatusBar((UIView *)self);
}

%end

#pragma mark - UIStatusBar

%hook UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyStatusBar((UIView *)self);
}

%end

#pragma mark - SpringBoard Status Bar

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyStatusBar((UIView *)self);
}

%end

#pragma mark - Home Indicator

%hook _UIHomeIndicatorView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyHomeBar((UIView *)self);
}

%end

#pragma mark - Settings Changed

static void SHA_SettingsChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SHA_LoadPreferences();

    SHA_ApplyHomeBarToScenes();
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
            SHA_SettingsChanged,
            CFSTR(
                "com.congtu.statushomebaradjuster.settingsChanged"
            ),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        /*
         * Đợi SpringBoard dựng UI hoàn chỉnh.
         */

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                2 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                SHA_LoadPreferences();

                SHA_ApplyHomeBarToScenes();
            }
        );

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                5 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                SHA_LoadPreferences();

                SHA_ApplyHomeBarToScenes();
            }
        );
    }
}
