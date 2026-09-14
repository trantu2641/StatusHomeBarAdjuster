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

#pragma mark - Orientation

static BOOL SHA_IsPortrait(void)
{
    UIApplication *app =
        [UIApplication sharedApplication];

    if (!app)
        return NO;

    if (@available(iOS 13.0, *))
    {
        for (UIScene *scene in app.connectedScenes)
        {
            if (![scene isKindOfClass:[UIWindowScene class]])
                continue;

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            UIInterfaceOrientation orientation =
                windowScene.interfaceOrientation;

            if (orientation == UIInterfaceOrientationPortrait ||
                orientation == UIInterfaceOrientationPortraitUpsideDown)
            {
                return YES;
            }
        }
    }

    return NO;
}

#pragma mark - Original Frame

static CGRect SHA_OriginalFrame(UIView *view)
{
    if (!view)
        return CGRectZero;

    if (!SHAOriginalFrames)
    {
        SHAOriginalFrames =
            [NSMapTable weakToStrongObjectsMapTable];
    }

    NSValue *value =
        [SHAOriginalFrames objectForKey:view];

    if (value)
        return [value CGRectValue];

    CGRect frame =
        view.frame;

    [SHAOriginalFrames
        setObject:[NSValue valueWithCGRect:frame]
        forKey:view];

    return frame;
}

#pragma mark - Set Visual Frame

static void SHA_SetVisualY(
    UIView *view,
    CGFloat offset
)
{
    if (!view)
        return;

    CGRect original =
        SHA_OriginalFrame(view);

    CGRect frame =
        original;

    frame.origin.y =
        original.origin.y + offset;

    view.frame = frame;
}

#pragma mark - Home Bar Visual

static BOOL SHA_IsHomePill(
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
            @"MTLumaDodgePillView"])
    {
        return YES;
    }

    if ([name isEqualToString:
            @"MTStaticColorPillView"])
    {
        return YES;
    }

    return NO;
}

#pragma mark - Find Home Visual Container

static UIView *SHA_FindHomeVisualContainer(
    UIView *pill
)
{
    if (!pill)
        return nil;

    UIWindow *window =
        pill.window;

    if (!window)
        return pill;

    CGFloat screenWidth =
        window.bounds.size.width;

    UIView *candidate =
        pill;

    UIView *current =
        pill.superview;

    while (current &&
           current != window)
    {
        CGRect bounds =
            current.bounds;

        CGFloat width =
            bounds.size.width;

        CGFloat height =
            bounds.size.height;

        /*
         * Home Bar visual container:
         *
         * gần bằng chiều rộng màn hình
         * nhưng chiều cao không quá lớn.
         */

        if (screenWidth > 0.0 &&
            width >= screenWidth * 0.80 &&
            height >= 20.0 &&
            height <= 160.0)
        {
            candidate = current;
        }

        current =
            current.superview;
    }

    return candidate;
}

#pragma mark - Apply Home Visual

static void SHA_ApplyHomeVisual(
    UIView *pill
)
{
    if (!pill)
        return;

    if (!SHA_IsPortrait())
        return;

    if (SHAHomeOffset == 0.0)
        return;

    UIView *visualContainer =
        SHA_FindHomeVisualContainer(pill);

    if (!visualContainer)
        return;

    /*
     * Chỉ thay đổi visual frame.
     *
     * Không thay:
     * - safeAreaInsets
     * - additionalSafeAreaInsets
     * - gesture recognizer
     * - hitTest
     * - system gesture region
     */

    SHA_SetVisualY(
        visualContainer,
        SHAHomeOffset
    );
}

#pragma mark - Recursive Home Search

static void SHA_SearchHomeVisual(
    UIView *root
)
{
    if (!root)
        return;

    if (SHA_IsHomePill(root))
    {
        SHA_ApplyHomeVisual(root);
        return;
    }

    NSArray *children =
        [root.subviews copy];

    for (UIView *child in children)
    {
        SHA_SearchHomeVisual(child);
    }
}

#pragma mark - Status Bar

static BOOL SHA_IsStatusContainer(
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

static void SHA_ApplyStatusVisual(
    UIView *view
)
{
    if (!view)
        return;

    if (!SHA_IsPortrait())
        return;

    if (SHAStatusOffset == 0.0)
        return;

    SHA_SetVisualY(
        view,
        SHAStatusOffset
    );
}

static void SHA_SearchStatusVisual(
    UIView *root
)
{
    if (!root)
        return;

    if (SHA_IsStatusContainer(root))
    {
        SHA_ApplyStatusVisual(root);
        return;
    }

    NSArray *children =
        [root.subviews copy];

    for (UIView *child in children)
    {
        SHA_SearchStatusVisual(child);
    }
}

#pragma mark - Apply All Scenes

static void SHA_ApplyAll(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIApplication *app =
                [UIApplication sharedApplication];

            if (!app)
                return;

            /*
             * Landscape:
             * không làm gì.
             */

            if (!SHA_IsPortrait())
                return;

            if (@available(iOS 13.0, *))
            {
                for (UIScene *scene
                     in app.connectedScenes)
                {
                    if (![scene
                            isKindOfClass:
                                [UIWindowScene class]])
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

                        SHA_SearchStatusVisual(window);

                        SHA_SearchHomeVisual(window);
                    }
                }
            }
        }
    );
}

#pragma mark - MTLumaDodgePillView

%hook MTLumaDodgePillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHA_IsPortrait())
    {
        SHA_ApplyHomeVisual(
            (UIView *)self
        );
    }
}

%end

#pragma mark - MTStaticColorPillView

%hook MTStaticColorPillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHA_IsPortrait())
    {
        SHA_ApplyHomeVisual(
            (UIView *)self
        );
    }
}

%end

#pragma mark - _UIStatusBar

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHA_IsPortrait())
    {
        SHA_ApplyStatusVisual(
            (UIView *)self
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

    if (SHA_IsPortrait())
    {
        SHA_ApplyStatusVisual(
            (UIView *)self
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

    if (SHA_IsPortrait())
    {
        SHA_ApplyStatusVisual(
            (UIView *)self
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

    SHA_ApplyAll();

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            250 * NSEC_PER_MSEC
        ),
        dispatch_get_main_queue(),
        ^{
            SHA_LoadPreferences();
            SHA_ApplyAll();
        }
    );

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            750 * NSEC_PER_MSEC
        ),
        dispatch_get_main_queue(),
        ^{
            SHA_LoadPreferences();
            SHA_ApplyAll();
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
                SHA_ApplyAll();
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
                SHA_ApplyAll();
            }
        );
    }
}
