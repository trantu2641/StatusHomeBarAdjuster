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

        CFNumberGetValue(
            (CFNumberRef)statusValue,
            kCFNumberDoubleType,
            &value
        );

        SHAStatusDelta =
            (CGFloat)MAX(
                SHA_MIN_DELTA,
                MIN(SHA_MAX_DELTA, value)
            );
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
            (CGFloat)MAX(
                SHA_MIN_DELTA,
                MIN(SHA_MAX_DELTA, value)
            );
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

#pragma mark - Original Transform

static const void *SHAHomeTransformKey =
    &SHAHomeTransformKey;

static const void *SHAStatusTransformKey =
    &SHAStatusTransformKey;

static CGAffineTransform SHA_GetOriginalTransform(
    UIView *view,
    const void *key
)
{
    NSValue *value =
        objc_getAssociatedObject(
            view,
            key
        );

    if (!value)
        return CGAffineTransformIdentity;

    return [value CGAffineTransformValue];
}

static void SHA_SaveOriginalTransform(
    UIView *view,
    const void *key
)
{
    if (!view)
        return;

    NSValue *value =
        objc_getAssociatedObject(
            view,
            key
        );

    if (value)
        return;

    CGAffineTransform transform =
        view.layer.affineTransform;

    objc_setAssociatedObject(
        view,
        key,
        [NSValue valueWithCGAffineTransform:transform],
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

#pragma mark - Home Container Search

static UIView *SHA_FindHomeContainer(
    UIView *pill
)
{
    if (!pill)
        return nil;

    UIView *current =
        pill.superview;

    UIView *grabber =
        nil;

    /*
     * Tìm SBHomeGrabberView trước.
     *
     * KHÔNG scale chính SBHomeGrabberView.
     */
    NSInteger depth = 0;

    while (current && depth < 8)
    {
        NSString *name =
            NSStringFromClass(
                [current class]
            );

        if ([name isEqualToString:
                @"SBHomeGrabberView"])
        {
            grabber = current;
            break;
        }

        current =
            current.superview;

        depth++;
    }

    if (!grabber)
        return nil;

    /*
     * Lấy parent của SBHomeGrabberView.
     *
     * Đây là visual host chúng ta muốn thử
     * thay vì đụng trực tiếp gesture container.
     */
    UIView *candidate =
        grabber.superview;

    if (!candidate)
        return nil;

    UIWindow *window =
        pill.window;

    if (!window)
        return nil;

    NSString *candidateName =
        NSStringFromClass(
            [candidate class]
        );

    /*
     * Tuyệt đối không chọn các container
     * rõ ràng là gesture/touch.
     */
    if ([candidateName containsString:@"Gesture"] ||
        [candidateName containsString:@"Touch"])
    {
        candidate =
            candidate.superview;
    }

    if (!candidate ||
        candidate == window)
    {
        return nil;
    }

    CGRect frame =
        [candidate convertRect:
            candidate.bounds
            toView:window];

    CGFloat width =
        CGRectGetWidth(frame);

    CGFloat height =
        CGRectGetHeight(frame);

    CGFloat screenWidth =
        CGRectGetWidth(window.bounds);

    /*
     * Container phải là một vùng ngang,
     * không phải pill.
     */
    if (width < screenWidth * 0.40)
        return nil;

    if (height < 8.0 ||
        height > 300.0)
        return nil;

    return candidate;
}

#pragma mark - Apply Home Container

static void SHA_ApplyHomeContainer(
    UIView *container
)
{
    if (!container)
        return;

    if (!container.window)
        return;

    if (!SHA_IsPortrait(container))
        return;

    CGFloat delta =
        SHAHomeDelta;

    SHA_SaveOriginalTransform(
        container,
        SHAHomeTransformKey
    );

    CGAffineTransform original =
        SHA_GetOriginalTransform(
            container,
            SHAHomeTransformKey
        );

    /*
     * 0 = khôi phục.
     */
    if (fabs(delta) < 0.001)
    {
        [CATransaction begin];

        [CATransaction setDisableActions:YES];

        container.layer.affineTransform =
            original;

        [CATransaction commit];

        return;
    }

    CGRect bounds =
        container.bounds;

    CGFloat height =
        CGRectGetHeight(bounds);

    if (height <= 8.0)
        return;

    CGFloat targetHeight =
        height + delta;

    if (targetHeight < 1.0)
        targetHeight = 1.0;

    CGFloat scaleY =
        targetHeight / height;

    /*
     * Giới hạn an toàn.
     */
    if (scaleY < 0.10)
        scaleY = 0.10;

    if (scaleY > 10.0)
        scaleY = 10.0;

    /*
     * Scale quanh tâm visual container.
     *
     * Không thay:
     * - frame
     * - bounds
     * - safe area
     * - gesture recognizer
     */
    CGAffineTransform extra =
        CGAffineTransformMakeScale(
            1.0,
            scaleY
        );

    CGAffineTransform result =
        CGAffineTransformConcat(
            original,
            extra
        );

    [CATransaction begin];

    [CATransaction setDisableActions:YES];

    container.layer.affineTransform =
        result;

    [CATransaction commit];
}

#pragma mark - Home Bar Classes

@interface MTLumaDodgePillView : UIView
@end

@interface MTStaticColorPillView : UIView
@end

%hook MTLumaDodgePillView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    if (!self.window)
        return;

    UIView *container =
        SHA_FindHomeContainer(
            (UIView *)self
        );

    if (container)
    {
        SHA_ApplyHomeContainer(
            container
        );
    }
}

%end

%hook MTStaticColorPillView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    if (!self.window)
        return;

    UIView *container =
        SHA_FindHomeContainer(
            (UIView *)self
        );

    if (container)
    {
        SHA_ApplyHomeContainer(
            container
        );
    }
}

%end

#pragma mark - Status Bar

/*
 * Không hook _UIStatusBar.layoutSubviews.
 *
 * Thay vào đó tìm status visual khi
 * UIWindow được đưa vào hierarchy.
 */

static UIView *SHA_FindStatusContainer(
    UIView *view
)
{
    if (!view)
        return nil;

    UIWindow *window =
        view.window;

    if (!window)
        return nil;

    UIView *current =
        view;

    NSInteger depth = 0;

    while (current && depth < 6)
    {
        NSString *name =
            NSStringFromClass(
                [current class]
            );

        if ([name containsString:@"StatusBar"] ||
            [name containsString:@"statusBar"])
        {
            UIView *parent =
                current.superview;

            if (!parent ||
                parent == window)
            {
                return current;
            }

            CGRect frame =
                [parent convertRect:
                    parent.bounds
                    toView:window];

            CGFloat width =
                CGRectGetWidth(frame);

            CGFloat height =
                CGRectGetHeight(frame);

            CGFloat screenWidth =
                CGRectGetWidth(window.bounds);

            if (width >= screenWidth * 0.50 &&
                height >= 8.0 &&
                height <= 180.0)
            {
                return parent;
            }

            return current;
        }

        current =
            current.superview;

        depth++;
    }

    return nil;
}

static void SHA_ApplyStatusContainer(
    UIView *container
)
{
    if (!container)
        return;

    if (!container.window)
        return;

    if (!SHA_IsPortrait(container))
        return;

    SHA_SaveOriginalTransform(
        container,
        SHAStatusTransformKey
    );

    CGAffineTransform original =
        SHA_GetOriginalTransform(
            container,
            SHAStatusTransformKey
        );

    if (fabs(SHAStatusDelta) < 0.001)
    {
        [CATransaction begin];

        [CATransaction setDisableActions:YES];

        container.layer.affineTransform =
            original;

        [CATransaction commit];

        return;
    }

    CGFloat height =
        CGRectGetHeight(
            container.bounds
        );

    if (height <= 8.0)
        return;

    CGFloat target =
        height + SHAStatusDelta;

    if (target < 1.0)
        target = 1.0;

    CGFloat scaleY =
        target / height;

    if (scaleY < 0.10)
        scaleY = 0.10;

    if (scaleY > 10.0)
        scaleY = 10.0;

    CGAffineTransform result =
        CGAffineTransformConcat(
            original,
            CGAffineTransformMakeScale(
                1.0,
                scaleY
            )
        );

    [CATransaction begin];

    [CATransaction setDisableActions:YES];

    container.layer.affineTransform =
        result;

    [CATransaction commit];
}

#pragma mark - Status Bar Visual Class

@interface _UIStatusBar : UIView
@end

%hook _UIStatusBar

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    if (!self.window)
        return;

    UIView *container =
        SHA_FindStatusContainer(
            (UIView *)self
        );

    if (container)
    {
        SHA_ApplyStatusContainer(
            container
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
