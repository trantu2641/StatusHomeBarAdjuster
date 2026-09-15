#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <notify.h>
#import <dispatch/dispatch.h>

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

#pragma mark - Home Bar

/*
 * Home Bar visual.
 *
 * Giữ nguyên kiến trúc an toàn:
 *
 * - Không hook SBHomeGrabberView
 * - Không thay safeAreaInsets
 * - Không thay gesture recognizer
 * - Không thay frame của gesture container
 *
 * Chỉ tác động visual layer của MTLumaDodgePillView /
 * MTStaticColorPillView.
 */

static void SHA_ApplyHomeVisual(UIView *pill)
{
    if (!pill)
        return;

    UIWindow *window =
        pill.window;

    if (!window)
        return;

    if (!SHA_IsPortraitForWindow(window))
        return;

    /*
     * Offset = 0:
     * trả visual về kích thước gốc nếu trước đó
     * tweak đã từng thay đổi nó.
     */

    CALayer *layer =
        pill.layer;

    if (!layer)
        return;

    CGRect bounds =
        layer.bounds;

    CGFloat currentHeight =
        CGRectGetHeight(bounds);

    if (currentHeight <= 0.0)
        return;

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
            currentHeight;

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
     * Giữ cạnh dưới cố định.
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

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyHomeVisual(
        (UIView *)self
    );
}

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyHomeVisual(
        (UIView *)self
    );
}

%end

#pragma mark - Status Bar

/*
 * Status Bar.
 *
 * Không sử dụng SHA_ClassIs.
 * Không hook _UIStatusBar class method.
 *
 * Chỉ xử lý instance layout.
 */

static void SHA_ResizeStatusVisual(UIView *view)
{
    if (!view)
        return;

    UIWindow *window =
        view.window;

    if (!window)
        return;

    if (!SHA_IsPortraitForWindow(window))
        return;

    CALayer *layer =
        view.layer;

    if (!layer)
        return;

    CGRect bounds =
        view.bounds;

    CGFloat currentHeight =
        CGRectGetHeight(bounds);

    if (currentHeight <= 0.0)
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
            currentHeight;

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

    [CATransaction begin];

    [CATransaction setDisableActions:YES];

    layer.bounds =
        bounds;

    [CATransaction commit];
}

#pragma mark - UIKit Status Bar

@interface _UIStatusBar : UIView
@end

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
