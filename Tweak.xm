#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <notify.h>
#import <math.h>

#pragma mark - Preferences

static CGFloat SHAStatusDelta = 0.0;
static CGFloat SHAHomeDelta = 0.0;

static const CGFloat SHA_MIN_DELTA = -120.0;
static const CGFloat SHA_MAX_DELTA = 120.0;

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

        if (CFNumberGetValue(
                (CFNumberRef)statusValue,
                kCFNumberDoubleType,
                &value))
        {
            SHAStatusDelta =
                (CGFloat)MAX(
                    SHA_MIN_DELTA,
                    MIN(SHA_MAX_DELTA, value)
                );
        }
    }

    if (homeValue &&
        CFGetTypeID(homeValue) == CFNumberGetTypeID())
    {
        double value = 0.0;

        if (CFNumberGetValue(
                (CFNumberRef)homeValue,
                kCFNumberDoubleType,
                &value))
        {
            SHAHomeDelta =
                (CGFloat)MAX(
                    SHA_MIN_DELTA,
                    MIN(SHA_MAX_DELTA, value)
                );
        }
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Orientation

static BOOL SHA_IsPortrait(UIView *view)
{
    if (!view)
        return NO;

    UIWindow *window = view.window;

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

@interface MTLumaDodgePillView : UIView
@end

@interface MTStaticColorPillView : UIView
@end

/*
 * Tìm SBHomeGrabberView từ pill.
 *
 * Không thay frame/bounds của nó.
 * Chỉ dùng layer transform.
 */
static UIView *SHA_FindHomeGrabber(UIView *pill)
{
    if (!pill)
        return nil;

    UIView *current =
        pill.superview;

    NSInteger depth = 0;

    while (current && depth < 8)
    {
        NSString *className =
            NSStringFromClass(
                [current class]
            );

        if ([className isEqualToString:
                @"SBHomeGrabberView"])
        {
            return current;
        }

        current =
            current.superview;

        depth++;
    }

    return nil;
}

static void SHA_ApplyHomeBar(UIView *grabber)
{
    if (!grabber)
        return;

    if (!grabber.window)
        return;

    if (!SHA_IsPortrait(grabber))
        return;

    CGFloat delta =
        SHAHomeDelta;

    CALayer *layer =
        grabber.layer;

    if (!layer)
        return;

    /*
     * Lấy kích thước visual hiện tại.
     */
    CGFloat height =
        CGRectGetHeight(layer.bounds);

    if (height <= 0.0)
        return;

    /*
     * delta = 0:
     * khôi phục transform nguyên bản.
     */
    if (fabs(delta) < 0.001)
    {
        [CATransaction begin];

        [CATransaction setDisableActions:YES];

        layer.transform =
            CATransform3DIdentity;

        [CATransaction commit];

        return;
    }

    CGFloat targetHeight =
        height + delta;

    if (targetHeight < 1.0)
        targetHeight = 1.0;

    CGFloat scaleY =
        targetHeight / height;

    /*
     * Chống giá trị bất thường.
     */
    if (scaleY < 0.10)
        scaleY = 0.10;

    if (scaleY > 8.0)
        scaleY = 8.0;

    /*
     * QUAN TRỌNG:
     *
     * Không:
     * - setFrame
     * - setBounds
     * - safeAreaInsets
     * - gesture recognizer
     *
     * Chỉ thay rendering transform.
     */
    CATransform3D transform =
        CATransform3DMakeScale(
            1.0,
            scaleY,
            1.0
        );

    [CATransaction begin];

    [CATransaction setDisableActions:YES];

    layer.transform =
        transform;

    [CATransaction commit];
}

%hook MTLumaDodgePillView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    UIView *grabber =
        SHA_FindHomeGrabber(
            (UIView *)self
        );

    if (grabber)
    {
        SHA_ApplyHomeBar(
            grabber
        );
    }
}

%end

%hook MTStaticColorPillView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    UIView *grabber =
        SHA_FindHomeGrabber(
            (UIView *)self
        );

    if (grabber)
    {
        SHA_ApplyHomeBar(
            grabber
        );
    }
}

%end

#pragma mark - Status Bar

@interface _UIStatusBar : UIView
@end

/*
 * Chỉ scale visual layer.
 *
 * KHÔNG dùng layoutSubviews.
 */
static void SHA_ApplyStatusBar(UIView *statusBar)
{
    if (!statusBar)
        return;

    if (!statusBar.window)
        return;

    if (!SHA_IsPortrait(statusBar))
        return;

    CALayer *layer =
        statusBar.layer;

    if (!layer)
        return;

    CGFloat height =
        CGRectGetHeight(layer.bounds);

    if (height <= 0.0)
        return;

    if (fabs(SHAStatusDelta) < 0.001)
    {
        [CATransaction begin];

        [CATransaction setDisableActions:YES];

        layer.transform =
            CATransform3DIdentity;

        [CATransaction commit];

        return;
    }

    CGFloat targetHeight =
        height + SHAStatusDelta;

    if (targetHeight < 1.0)
        targetHeight = 1.0;

    CGFloat scaleY =
        targetHeight / height;

    if (scaleY < 0.10)
        scaleY = 0.10;

    if (scaleY > 8.0)
        scaleY = 8.0;

    CATransform3D transform =
        CATransform3DMakeScale(
            1.0,
            scaleY,
            1.0
        );

    [CATransaction begin];

    [CATransaction setDisableActions:YES];

    layer.transform =
        transform;

    [CATransaction commit];
}

%hook _UIStatusBar

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    SHA_ApplyStatusBar(
        (UIView *)self
    );
}

%end

#pragma mark - Settings

static void SHA_SettingsChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SHA_LoadPreferences();
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
