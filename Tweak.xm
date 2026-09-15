#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import <dispatch/dispatch.h>
#import <math.h>

#pragma mark - Preferences

static CGFloat SHAStatusDelta = 0.0;
static CGFloat SHAHomeDelta = 0.0;

static NSString * const SHAStatusKey = @"SHAStatusOriginalTransform";
static NSString * const SHAHomeKey = @"SHAHomeOriginalTransform";

static const CGFloat SHA_MIN = -120.0;
static const CGFloat SHA_MAX =  120.0;

#pragma mark - Preference Loader

static void SHA_LoadPreferences(void)
{
    CFStringRef domain =
        CFSTR("com.congtu.statushomebaradjuster");

    CFPreferencesAppSynchronize(domain);

    CFPropertyListRef status =
        CFPreferencesCopyAppValue(
            CFSTR("StatusBarOffset"),
            domain
        );

    CFPropertyListRef home =
        CFPreferencesCopyAppValue(
            CFSTR("HomeBarOffset"),
            domain
        );

    SHAStatusDelta = 0.0;
    SHAHomeDelta = 0.0;

    if (status &&
        CFGetTypeID(status) == CFNumberGetTypeID())
    {
        double value = 0.0;

        if (CFNumberGetValue(
                (CFNumberRef)status,
                kCFNumberDoubleType,
                &value))
        {
            SHAStatusDelta =
                (CGFloat)MAX(
                    SHA_MIN,
                    MIN(SHA_MAX, value)
                );
        }
    }

    if (home &&
        CFGetTypeID(home) == CFNumberGetTypeID())
    {
        double value = 0.0;

        if (CFNumberGetValue(
                (CFNumberRef)home,
                kCFNumberDoubleType,
                &value))
        {
            SHAHomeDelta =
                (CGFloat)MAX(
                    SHA_MIN,
                    MIN(SHA_MAX, value)
                );
        }
    }

    if (status)
        CFRelease(status);

    if (home)
        CFRelease(home);
}

#pragma mark - Portrait

static BOOL SHA_IsPortrait(UIWindow *window)
{
    if (!window)
        return NO;

    if (@available(iOS 13.0, *))
    {
        UIWindowScene *scene =
            window.windowScene;

        if (!scene)
            return NO;

        UIInterfaceOrientation o =
            scene.interfaceOrientation;

        return
            o == UIInterfaceOrientationPortrait ||
            o == UIInterfaceOrientationPortraitUpsideDown;
    }

    return NO;
}

#pragma mark - Transform Storage

static NSValue *SHA_GetOriginalTransform(
    UIView *view,
    NSString *key
)
{
    return objc_getAssociatedObject(
        view,
        (__bridge const void *)(key)
    );
}

static void SHA_SaveOriginalTransform(
    UIView *view,
    NSString *key
)
{
    NSValue *saved =
        SHA_GetOriginalTransform(
            view,
            key
        );

    if (saved)
        return;

    CGAffineTransform transform =
        view.layer.affineTransform;

    objc_setAssociatedObject(
        view,
        (__bridge const void *)(key),
        [NSValue valueWithCGAffineTransform:transform],
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

static CGAffineTransform SHA_OriginalTransform(
    UIView *view,
    NSString *key
)
{
    NSValue *saved =
        SHA_GetOriginalTransform(
            view,
            key
        );

    if (!saved)
        return CGAffineTransformIdentity;

    return [saved CGAffineTransformValue];
}

#pragma mark - Safe Visual Test

static BOOL SHA_IsForbiddenHomeContainer(UIView *view)
{
    if (!view)
        return YES;

    NSString *name =
        NSStringFromClass([view class]);

    if ([name isEqualToString:@"SBHomeGrabberView"])
        return YES;

    if ([name containsString:@"Gesture"])
        return YES;

    if ([name containsString:@"Keyboard"])
        return YES;

    if ([name containsString:@"Touch"])
        return YES;

    if ([name containsString:@"Transition"])
        return YES;

    return NO;
}

static BOOL SHA_IsForbiddenStatusContainer(UIView *view)
{
    if (!view)
        return YES;

    NSString *name =
        NSStringFromClass([view class]);

    if ([name containsString:@"Keyboard"])
        return YES;

    if ([name containsString:@"Gesture"])
        return YES;

    if ([name containsString:@"Transition"])
        return YES;

    return NO;
}

#pragma mark - Home Visual Container

/*
 * Bắt đầu từ MTLumaDodgePillView /
 * MTStaticColorPillView.
 *
 * Không resize chính pill.
 *
 * Không resize SBHomeGrabberView.
 *
 * Đi lên hierarchy để tìm một visual ancestor
 * có kích thước hợp lý.
 */

static UIView *SHA_FindHomeVisualContainer(
    UIView *pill
)
{
    if (!pill)
        return nil;

    UIWindow *window =
        pill.window;

    if (!window)
        return nil;

    UIView *candidate =
        pill.superview;

    NSInteger depth = 0;

    while (candidate && depth < 6)
    {
        if (candidate == window)
            break;

        if (!SHA_IsForbiddenHomeContainer(candidate))
        {
            CGRect frame =
                [candidate.superview
                    convertRect:candidate.frame
                    toView:window];

            CGFloat width =
                CGRectGetWidth(frame);

            CGFloat height =
                CGRectGetHeight(frame);

            CGFloat screenWidth =
                CGRectGetWidth(window.bounds);

            /*
             * Home visual host thường nằm gần
             * toàn chiều rộng màn hình nhưng
             * có chiều cao nhỏ hơn màn hình.
             */
            if (width >= screenWidth * 0.55 &&
                width <= screenWidth * 1.05 &&
                height >= 5.0 &&
                height <= 250.0)
            {
                return candidate;
            }
        }

        candidate =
            candidate.superview;

        depth++;
    }

    return nil;
}

#pragma mark - Apply Home

static void SHA_ApplyHomeContainer(
    UIView *container
)
{
    if (!container)
        return;

    UIWindow *window =
        container.window;

    if (!window)
        return;

    if (!SHA_IsPortrait(window))
        return;

    /*
     * Tuyệt đối không động gesture container.
     */
    if (SHA_IsForbiddenHomeContainer(container))
        return;

    SHA_SaveOriginalTransform(
        container,
        SHAHomeKey
    );

    CGAffineTransform original =
        SHA_OriginalTransform(
            container,
            SHAHomeKey
        );

    /*
     * Offset 0 = nguyên trạng.
     */
    if (fabs(SHAHomeDelta) < 0.001)
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

    if (height <= 5.0)
        return;

    CGFloat target =
        height + SHAHomeDelta;

    if (target < 1.0)
        target = 1.0;

    CGFloat scale =
        target / height;

    if (scale < 0.10)
        scale = 0.10;

    if (scale > 10.0)
        scale = 10.0;

    /*
     * Giữ transform gốc của hệ thống,
     * sau đó scale Y thêm.
     */
    CGAffineTransform result =
        CGAffineTransformConcat(
            original,
            CGAffineTransformMakeScale(
                1.0,
                scale
            )
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

    UIView *container =
        SHA_FindHomeVisualContainer(
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

    UIView *container =
        SHA_FindHomeVisualContainer(
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

#pragma mark - Status Visual Search

static BOOL SHA_IsStatusView(
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

static UIView *SHA_FindStatusVisualContainer(
    UIView *statusView
)
{
    if (!statusView)
        return nil;

    UIWindow *window =
        statusView.window;

    if (!window)
        return nil;

    UIView *candidate =
        statusView;

    NSInteger depth = 0;

    while (candidate && depth < 4)
    {
        if (candidate == window)
            break;

        if (!SHA_IsForbiddenStatusContainer(candidate))
        {
            CGRect frame =
                [candidate.superview
                    convertRect:candidate.frame
                    toView:window];

            CGFloat width =
                CGRectGetWidth(frame);

            CGFloat height =
                CGRectGetHeight(frame);

            CGFloat screenWidth =
                CGRectGetWidth(window.bounds);

            if (width >= screenWidth * 0.70 &&
                width <= screenWidth * 1.05 &&
                height >= 5.0 &&
                height <= 150.0)
            {
                return candidate;
            }
        }

        candidate =
            candidate.superview;

        depth++;
    }

    return nil;
}

#pragma mark - Apply Status

static void SHA_ApplyStatusContainer(
    UIView *container
)
{
    if (!container)
        return;

    UIWindow *window =
        container.window;

    if (!window)
        return;

    if (!SHA_IsPortrait(window))
        return;

    if (SHA_IsForbiddenStatusContainer(container))
        return;

    SHA_SaveOriginalTransform(
        container,
        SHAStatusKey
    );

    CGAffineTransform original =
        SHA_OriginalTransform(
            container,
            SHAStatusKey
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

    CGRect bounds =
        container.bounds;

    CGFloat height =
        CGRectGetHeight(bounds);

    if (height <= 5.0)
        return;

    CGFloat target =
        height + SHAStatusDelta;

    if (target < 1.0)
        target = 1.0;

    CGFloat scale =
        target / height;

    if (scale < 0.10)
        scale = 0.10;

    if (scale > 10.0)
        scale = 10.0;

    CGAffineTransform result =
        CGAffineTransformConcat(
            original,
            CGAffineTransformMakeScale(
                1.0,
                scale
            )
        );

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    container.layer.affineTransform =
        result;

    [CATransaction commit];
}

#pragma mark - UIWindow

%hook UIWindow

- (void)didMoveToWindow
{
    %orig;

    /*
     * Giống điểm vào của Trim:
     * xử lý sau khi UIKit đưa view vào window.
     */

    SHA_LoadPreferences();

    if (!self.window)
        return;

    if (!SHA_IsPortrait(self))
        return;

    /*
     * Duyệt hierarchy mà không thay đổi
     * geometry trong quá trình layout.
     */

    NSMutableArray *queue =
        [NSMutableArray arrayWithObject:self];

    NSInteger processed = 0;

    while (queue.count > 0 &&
           processed < 250)
    {
        UIView *view =
            queue.firstObject;

        [queue removeObjectAtIndex:0];

        processed++;

        NSString *name =
            NSStringFromClass([view class]);

        /*
         * Home Bar.
         */
        if ([name isEqualToString:
                @"MTLumaDodgePillView"] ||
            [name isEqualToString:
                @"MTStaticColorPillView"])
        {
            UIView *container =
                SHA_FindHomeVisualContainer(view);

            if (container)
            {
                SHA_ApplyHomeContainer(
                    container
                );
            }
        }

        /*
         * Status Bar.
         */
        if (SHA_IsStatusView(view))
        {
            UIView *container =
                SHA_FindStatusVisualContainer(view);

            if (container)
            {
                SHA_ApplyStatusContainer(
                    container
                );
            }
        }

        for (UIView *subview in view.subviews)
        {
            if (subview)
                [queue addObject:subview];
        }
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

    /*
     * Không gọi setNeedsLayout toàn hệ thống.
     *
     * Chỉ re-apply khi các system windows
     * được đưa vào hierarchy lại.
     */
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
