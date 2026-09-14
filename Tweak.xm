#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

static CGFloat SHAStatusOffset = 0.0;
static CGFloat SHAHomeOffset = 0.0;

static NSMapTable *SHAOriginalFrames;

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

#pragma mark - Original Frame

static CGRect SHA_GetOriginalFrame(UIView *view)
{
    if (!view)
        return CGRectZero;

    if (!SHAOriginalFrames)
    {
        SHAOriginalFrames =
            [NSMapTable weakToStrongObjectsMapTable];
    }

    NSValue *stored =
        [SHAOriginalFrames objectForKey:view];

    if (stored)
    {
        return [stored CGRectValue];
    }

    CGRect frame = view.frame;

    [SHAOriginalFrames
        setObject:[NSValue valueWithCGRect:frame]
        forKey:view];

    return frame;
}

#pragma mark - Move View

static void SHA_MoveView(
    UIView *view,
    CGFloat offset
)
{
    if (!view)
        return;

    CGRect original =
        SHA_GetOriginalFrame(view);

    CGRect frame =
        original;

    frame.origin.y =
        original.origin.y + offset;

    view.frame = frame;
}

#pragma mark - Status Bar Detection

static BOOL SHA_IsStatusView(
    UIView *view
)
{
    if (!view)
        return NO;

    NSString *name =
        NSStringFromClass([view class]);

    if (!name)
        return NO;

    if ([name isEqualToString:
            @"SBMainDisplaySceneLayoutStatusBarView"])
    {
        return YES;
    }

    if ([name isEqualToString:
            @"_UIStatusBar"])
    {
        return YES;
    }

    if ([name isEqualToString:
            @"UIStatusBar"])
    {
        return YES;
    }

    return NO;
}

#pragma mark - Home Bar Detection

static BOOL SHA_IsHomeView(
    UIView *view
)
{
    if (!view)
        return NO;

    NSString *name =
        NSStringFromClass([view class]);

    if (!name)
        return NO;

    if ([name rangeOfString:
            @"HomeIndicator"
            options:NSCaseInsensitiveSearch].location
        != NSNotFound)
    {
        return YES;
    }

    if ([name rangeOfString:
            @"HomeBar"
            options:NSCaseInsensitiveSearch].location
        != NSNotFound)
    {
        return YES;
    }

    if ([name rangeOfString:
            @"LumaDodgePill"
            options:NSCaseInsensitiveSearch].location
        != NSNotFound)
    {
        return YES;
    }

    return NO;
}

#pragma mark - Recursive Status Search

static void SHA_SearchStatus(
    UIView *root
)
{
    if (!root)
        return;

    if (SHA_IsStatusView(root))
    {
        if (SHAStatusOffset != 0.0)
        {
            SHA_MoveView(
                root,
                SHAStatusOffset
            );
        }

        return;
    }

    NSArray *children =
        [root.subviews copy];

    for (UIView *child in children)
    {
        SHA_SearchStatus(child);
    }
}

#pragma mark - Recursive Home Search

static void SHA_SearchHome(
    UIView *root
)
{
    if (!root)
        return;

    if (SHA_IsHomeView(root))
    {
        if (SHAHomeOffset != 0.0)
        {
            /*
             * Không chỉ di chuyển pill.
             *
             * Đi lên hierarchy để tìm container
             * lớn hơn chứa toàn bộ Home Bar.
             */

            UIView *container =
                root.superview;

            UIWindow *window =
                root.window;

            UIView *best =
                root;

            if (window)
            {
                CGFloat screenWidth =
                    window.bounds.size.width;

                while (container &&
                       container != window)
                {
                    CGRect bounds =
                        container.bounds;

                    CGFloat width =
                        bounds.size.width;

                    CGFloat height =
                        bounds.size.height;

                    /*
                     * Container ngang gần toàn màn hình
                     * và không quá cao.
                     */

                    if (screenWidth > 0.0 &&
                        width >= screenWidth * 0.70 &&
                        height >= 20.0 &&
                        height <= 200.0)
                    {
                        best = container;
                    }

                    container =
                        container.superview;
                }
            }

            SHA_MoveView(
                best,
                SHAHomeOffset
            );
        }

        /*
         * Đã xử lý container rồi,
         * không tiếp tục dịch các con của nó.
         */

        return;
    }

    NSArray *children =
        [root.subviews copy];

    for (UIView *child in children)
    {
        SHA_SearchHome(child);
    }
}

#pragma mark - Apply To Windows

static void SHA_ApplyToAllWindows(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIApplication *application =
                [UIApplication sharedApplication];

            if (!application)
                return;

            if (@available(iOS 13.0, *))
            {
                for (UIScene *scene
                     in application.connectedScenes)
                {
                    if (![scene
                            isKindOfClass:
                                [UIWindowScene class]])
                    {
                        continue;
                    }

                    UIWindowScene *windowScene =
                        (UIWindowScene *)scene;

                    NSArray *windows =
                        windowScene.windows;

                    for (UIWindow *window
                         in windows)
                    {
                        if (!window)
                            continue;

                        if (SHAStatusOffset != 0.0)
                        {
                            SHA_SearchStatus(window);
                        }

                        if (SHAHomeOffset != 0.0)
                        {
                            SHA_SearchHome(window);
                        }
                    }
                }
            }
        }
    );
}

#pragma mark - _UIStatusBar

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_MoveView(
            (UIView *)self,
            SHAStatusOffset
        );
    }
}

%end

#pragma mark - UIStatusBar

%hook UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_MoveView(
            (UIView *)self,
            SHAStatusOffset
        );
    }
}

%end

#pragma mark - SpringBoard Status Bar

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_MoveView(
            (UIView *)self,
            SHAStatusOffset
        );
    }
}

%end

#pragma mark - Home Indicator

%hook _UIHomeIndicatorView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAHomeOffset != 0.0)
    {
        UIView *container =
            [(UIView *)self superview];

        UIWindow *window =
            [(UIView *)self window];

        UIView *best =
            (UIView *)self;

        if (window)
        {
            CGFloat screenWidth =
                window.bounds.size.width;

            while (container &&
                   container != window)
            {
                CGRect bounds =
                    container.bounds;

                if (screenWidth > 0.0 &&
                    bounds.size.width >=
                        screenWidth * 0.70 &&
                    bounds.size.height >= 20.0 &&
                    bounds.size.height <= 200.0)
                {
                    best = container;
                }

                container =
                    container.superview;
            }
        }

        SHA_MoveView(
            best,
            SHAHomeOffset
        );
    }
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

    SHA_ApplyToAllWindows();

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            300 * NSEC_PER_MSEC
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
            1 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(),
        ^{
            SHA_LoadPreferences();
            SHA_ApplyToAllWindows();
        }
    );
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        SHAOriginalFrames =
            [NSMapTable weakToStrongObjectsMapTable];

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
