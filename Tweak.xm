#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

static CGFloat SHAStatusOffset = 0.0;
static CGFloat SHAHomeOffset = 0.0;

static NSMutableSet *SHAAdjustedViews;

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

#pragma mark - Reset

static void SHA_ResetAdjustedViews(void)
{
    if (!SHAAdjustedViews)
        return;

    for (UIView *view in [SHAAdjustedViews allObjects])
    {
        if ([view isKindOfClass:[UIView class]])
        {
            view.transform = CGAffineTransformIdentity;
        }
    }

    [SHAAdjustedViews removeAllObjects];
}

#pragma mark - Apply

static void SHA_ApplyStatusToView(UIView *view)
{
    if (!view)
        return;

    if (SHAStatusOffset == 0.0)
        return;

    view.transform =
        CGAffineTransformMakeTranslation(
            0.0,
            SHAStatusOffset
        );

    if (!SHAAdjustedViews)
        SHAAdjustedViews = [NSMutableSet set];

    [SHAAdjustedViews addObject:view];
}

static void SHA_ApplyHomeToView(UIView *view)
{
    if (!view)
        return;

    if (SHAHomeOffset == 0.0)
        return;

    view.transform =
        CGAffineTransformMakeTranslation(
            0.0,
            SHAHomeOffset
        );

    if (!SHAAdjustedViews)
        SHAAdjustedViews = [NSMutableSet set];

    [SHAAdjustedViews addObject:view];
}

#pragma mark - Recursive Search

static void SHA_SearchViewTree(UIView *view)
{
    if (!view)
        return;

    NSString *className =
        NSStringFromClass([view class]);

    if (!className)
        return;

    /*
     * STATUS BAR
     */

    BOOL isStatusBar =
        [className isEqualToString:
            @"SBMainDisplaySceneLayoutStatusBarView"] ||

        [className isEqualToString:
            @"_UIStatusBar"] ||

        [className isEqualToString:
            @"UIStatusBar"];

    if (isStatusBar)
    {
        CGRect frame = view.frame;

        if (frame.size.height >= 15.0 &&
            frame.size.height <= 80.0)
        {
            SHA_ApplyStatusToView(view);
        }
    }

    /*
     * HOME INDICATOR
     */

    BOOL isHomeIndicator =
        [className rangeOfString:
            @"HomeIndicator"
            options:NSCaseInsensitiveSearch].location
            != NSNotFound;

    BOOL isLumaPill =
        [className rangeOfString:
            @"LumaDodgePill"
            options:NSCaseInsensitiveSearch].location
            != NSNotFound;

    BOOL isHomeBar =
        [className rangeOfString:
            @"HomeBar"
            options:NSCaseInsensitiveSearch].location
            != NSNotFound;

    if (isHomeIndicator ||
        isLumaPill ||
        isHomeBar)
    {
        CGRect frame = view.frame;

        if (frame.size.height >= 2.0 &&
            frame.size.height <= 80.0)
        {
            SHA_ApplyHomeToView(view);
        }
    }

    /*
     * Tìm sâu toàn bộ hierarchy.
     */

    for (UIView *subview in view.subviews)
    {
        SHA_SearchViewTree(subview);
    }
}

#pragma mark - Apply To Scene Windows

static void SHA_ApplyToAllWindows(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIApplication *application =
                [UIApplication sharedApplication];

            if (!application)
                return;

            SHA_ResetAdjustedViews();

            if (SHAStatusOffset == 0.0 &&
                SHAHomeOffset == 0.0)
            {
                return;
            }

            /*
             * iOS 13+:
             * Chỉ sử dụng UIWindowScene.windows.
             */

            if (@available(iOS 13.0, *))
            {
                NSSet<UIScene *> *scenes =
                    application.connectedScenes;

                for (UIScene *scene in scenes)
                {
                    if (![scene
                            isKindOfClass:
                                [UIWindowScene class]])
                    {
                        continue;
                    }

                    UIWindowScene *windowScene =
                        (UIWindowScene *)scene;

                    NSArray<UIWindow *> *windows =
                        windowScene.windows;

                    for (UIWindow *window in windows)
                    {
                        if (!window)
                            continue;

                        SHA_SearchViewTree(window);
                    }
                }
            }
        }
    );
}

#pragma mark - Notification

static void SHA_PreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SHA_LoadPreferences();

    /*
     * Apply ngay sau khi bấm Apply.
     */

    SHA_ApplyToAllWindows();
}

#pragma mark - _UIStatusBar

%hook _UIStatusBar

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_ApplyStatusToView((UIView *)self);
    }
}

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_ApplyStatusToView((UIView *)self);
    }
}

%end

#pragma mark - UIStatusBar

%hook UIStatusBar

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_ApplyStatusToView((UIView *)self);
    }
}

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_ApplyStatusToView((UIView *)self);
    }
}

%end

#pragma mark - SBMainDisplaySceneLayoutStatusBarView

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_ApplyStatusToView((UIView *)self);
    }
}

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_ApplyStatusToView((UIView *)self);
    }
}

%end

#pragma mark - Home Indicator

%hook _UIHomeIndicatorView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    if (SHAHomeOffset != 0.0)
    {
        SHA_ApplyHomeToView((UIView *)self);
    }
}

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAHomeOffset != 0.0)
    {
        SHA_ApplyHomeToView((UIView *)self);
    }
}

%end

#pragma mark - Luma Dodge Pill

%hook MTLumaDodgePillView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    if (SHAHomeOffset != 0.0)
    {
        SHA_ApplyHomeToView((UIView *)self);
    }
}

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAHomeOffset != 0.0)
    {
        SHA_ApplyHomeToView((UIView *)self);
    }
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        SHAAdjustedViews =
            [NSMutableSet set];

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

        /*
         * SpringBoard cần thời gian dựng UI.
         */

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                2 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                SHA_LoadPreferences();
                SHA_ApplyToAllWindows();
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
                SHA_ApplyToAllWindows();
            }
        );
    }
}
