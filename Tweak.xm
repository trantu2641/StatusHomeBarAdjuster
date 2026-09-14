#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

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

#pragma mark - Class Name Helpers

static BOOL SHA_ClassNameContains(
    UIView *view,
    NSString *text
)
{
    if (!view)
        return NO;

    NSString *className =
        NSStringFromClass([view class]);

    if (!className)
        return NO;

    return
        [className rangeOfString:text
                          options:NSCaseInsensitiveSearch].location
        != NSNotFound;
}

#pragma mark - Apply View

static void SHA_ApplyStatusToView(
    UIView *view
)
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

static void SHA_ApplyHomeToView(
    UIView *view
)
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

#pragma mark - Recursive View Search

static void SHA_SearchViewTree(
    UIView *view
)
{
    if (!view)
        return;

    NSString *className =
        NSStringFromClass([view class]);

    /*
     * STATUS BAR
     */

    if (
        [className
            isEqualToString:@"SBMainDisplaySceneLayoutStatusBarView"] ||

        [className
            isEqualToString:@"_UIStatusBar"] ||

        [className
            isEqualToString:@"UIStatusBar"] ||

        [className
            rangeOfString:@"StatusBar"
            options:NSCaseInsensitiveSearch].location
            != NSNotFound
    )
    {
        /*
         * Không động vào các view phụ kiểu
         * background / separator.
         *
         * Chỉ ưu tiên những view có kích thước
         * giống một status bar.
         */

        CGRect frame = view.frame;

        if (
            frame.size.height >= 15.0 &&
            frame.size.height <= 80.0
        )
        {
            SHA_ApplyStatusToView(view);
        }
    }

    /*
     * HOME INDICATOR
     */

    if (
        [className
            rangeOfString:@"HomeIndicator"
            options:NSCaseInsensitiveSearch].location
            != NSNotFound ||

        [className
            rangeOfString:@"LumaDodgePill"
            options:NSCaseInsensitiveSearch].location
            != NSNotFound ||

        [className
            rangeOfString:@"HomeBar"
            options:NSCaseInsensitiveSearch].location
            != NSNotFound
    )
    {
        CGRect frame = view.frame;

        /*
         * Home indicator thường rất thấp,
         * chiều cao nhỏ.
         */

        if (
            frame.size.height >= 2.0 &&
            frame.size.height <= 80.0
        )
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

#pragma mark - Find All Windows

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
             * iOS 13+
             */

            if (@available(iOS 13.0, *))
            {
                for (UIScene *scene
                     in application.connectedScenes)
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
                        SHA_SearchViewTree(window);
                    }
                }
            }

            /*
             * Fallback cho những window không nằm
             * trong connectedScenes.
             */

            for (UIWindow *window
                 in application.windows)
            {
                SHA_SearchViewTree(window);
            }
        }
    );
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

    /*
     * Quan trọng:
     * bản cũ chỉ reload giá trị nhưng không
     * áp dụng lại vị trí.
     */

    SHA_ApplyToAllWindows();
}

#pragma mark - _UIStatusBar

%hook _UIStatusBar

- (void)didMoveToWindow
{
    %orig;

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
         * Chờ SpringBoard tạo xong window/view hierarchy.
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

        /*
         * Một lần nữa sau khi SpringBoard ổn định.
         */

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
