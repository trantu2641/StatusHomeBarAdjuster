#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#pragma mark - Preferences

static CGFloat SHAStatusDelta = 0.0;
static CGFloat SHAHomeDelta = 0.0;

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

    SHAStatusDelta = 0.0;
    SHAHomeDelta = 0.0;

    if (statusValue &&
        CFGetTypeID(statusValue) == CFNumberGetTypeID())
    {
        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)statusValue,
            kCFNumberDoubleType,
            &value
        );

        SHAStatusDelta =
            (CGFloat)MAX(-120.0, MIN(120.0, value));
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

        SHAHomeDelta =
            (CGFloat)MAX(-120.0, MIN(120.0, value));
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Portrait

static BOOL SHA_IsPortraitForWindow(UIWindow *window)
{
    if (!window)
        return NO;

    if (@available(iOS 13.0, *))
    {
        UIWindowScene *scene =
            window.windowScene;

        if (!scene)
            return NO;

        UIInterfaceOrientation orientation =
            scene.interfaceOrientation;

        return
            orientation == UIInterfaceOrientationPortrait ||
            orientation == UIInterfaceOrientationPortraitUpsideDown;
    }

    return NO;
}

#pragma mark - Class Name

static BOOL SHA_ClassIs(
    UIView *view,
    NSString *name
)
{
    if (!view || !name)
        return NO;

    return
        [NSStringFromClass([view class])
            isEqualToString:name];
}

#pragma mark - Home Bar

/*
 * Trim bắt Home visual khi nó được
 * đưa vào UIWindow thông qua didMoveToWindow.
 *
 * Chúng ta giữ đúng điểm hook này.
 */

static void SHA_ApplyHomeVisual(
    UIView *pill
)
{
    if (!pill)
        return;

    UIWindow *window =
        pill.window;

    if (!window)
        return;

    if (!SHA_IsPortraitForWindow(window))
        return;

    if (SHAHomeDelta == 0.0)
        return;

    /*
     * KHÔNG thay:
     *
     * - SBHomeGrabberView.frame
     * - SBHomeGrabberView.bounds
     * - safeAreaInsets
     * - gesture recognizer
     *
     * Thay đổi visual geometry của chính
     * Home indicator thông qua layer bounds.
     *
     * Layer chỉ là rendering geometry,
     * không thay đổi vùng touch của
     * gesture container.
     */

    CALayer *layer =
        pill.layer;

    if (!layer)
        return;

    CGRect bounds =
        layer.bounds;

    CGFloat oldHeight =
        CGRectGetHeight(bounds);

    if (oldHeight <= 0.0)
        return;

    /*
     * Tránh cộng dồn.
     *
     * Lấy giá trị gốc được lưu trên layer.
     */

    NSNumber *originalNumber =
        objc_getAssociatedObject(
            pill,
            "SHAOriginalHomeHeight"
        );

    CGFloat originalHeight;

    if (originalNumber)
    {
        originalHeight =
            [originalNumber doubleValue];
    }
    else
    {
        originalHeight =
            oldHeight;

        objc_setAssociatedObject(
            pill,
            "SHAOriginalHomeHeight",
            @(originalHeight),
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }

    CGFloat newHeight =
        originalHeight + SHAHomeDelta;

    if (newHeight < 1.0)
        newHeight = 1.0;

    /*
     * Giữ cạnh dưới.
     */
    CGFloat bottom =
        CGRectGetMaxY(bounds);

    bounds.size.height =
        newHeight;

    bounds.origin.y =
        bottom - newHeight;

    [CATransaction begin];

    [CATransaction setDisableActions:YES];

    layer.bounds =
        bounds;

    [CATransaction commit];
}

#pragma mark - Home Bar Visual Classes

@interface MTLumaDodgePillView : UIView
@end

@interface MTStaticColorPillView : UIView
@end

%hook MTLumaDodgePillView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyHomeVisual(
        (UIView *)self
    );
}

%end

%hook MTStaticColorPillView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyHomeVisual(
        (UIView *)self
    );
}

%end

#pragma mark - Reapply Home Visual

/*
 * UIKit có thể layout lại visual sau
 * didMoveToWindow.
 *
 * Vì vậy chỉ gọi lại visual object,
 * không đụng parent container.
 */

%hook MTLumaDodgePillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyHomeVisual(
        (UIView *)self
    );
}

%end

%hook MTStaticColorPillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyHomeVisual(
        (UIView *)self
    );
}

%end

#pragma mark - Status Bar UIKit Window

/*
 * Status Bar không dùng Home Grabber.
 *
 * Ở đây không đụng private SpringBoard
 * container nữa.
 *
 * Tìm system status visual trong UIWindow
 * và thay đổi bounds height.
 */

static BOOL SHA_IsStatusVisual(
    UIView *view
)
{
    if (!view)
        return NO;

    NSString *name =
        NSStringFromClass([view class]);

    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"statusBar"])
        return YES;

    return NO;
}

static void SHA_ResizeStatusVisual(
    UIView *view
)
{
    if (!view)
        return;

    UIWindow *window =
        view.window;

    if (!window)
        return;

    if (!SHA_IsPortraitForWindow(window))
        return;

    if (SHAStatusDelta == 0.0)
        return;

    CGRect bounds =
        view.bounds;

    CGFloat height =
        CGRectGetHeight(bounds);

    if (height <= 0.0)
        return;

    NSNumber *originalNumber =
        objc_getAssociatedObject(
            view,
            "SHAOriginalStatusHeight"
        );

    CGFloat originalHeight;

    if (originalNumber)
    {
        originalHeight =
            [originalNumber doubleValue];
    }
    else
    {
        originalHeight =
            height;

        objc_setAssociatedObject(
            view,
            "SHAOriginalStatusHeight",
            @(originalHeight),
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }

    CGFloat newHeight =
        originalHeight + SHAStatusDelta;

    if (newHeight < 1.0)
        newHeight = 1.0;

    CGFloat bottom =
        CGRectGetMaxY(bounds);

    bounds.size.height =
        newHeight;

    bounds.origin.y =
        bottom - newHeight;

    view.bounds =
        bounds;
}

#pragma mark - Status Bar Views

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ResizeStatusVisual(
        (UIView *)self
    );
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

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            /*
             * Không force frame của system views.
             *
             * Chỉ yêu cầu UIKit layout lại.
             */
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

                    for (UIWindow *window
                         in windowScene.windows)
                    {
                        [window setNeedsLayout];
                    }
                }
            }
        }
    );
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
    }
}
