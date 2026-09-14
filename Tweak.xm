#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>

static CGFloat SHAStatusDelta = 0.0;
static CGFloat SHAHomeDelta = 0.0;

static NSMapTable *SHAOriginalTransforms;
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

        value = MAX(-120.0, MIN(120.0, value));

        SHAStatusDelta = (CGFloat)value;
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

        SHAHomeDelta = (CGFloat)value;
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Orientation

static BOOL SHA_IsPortrait(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application)
        return NO;

    if (@available(iOS 13.0, *))
    {
        for (UIScene *scene in application.connectedScenes)
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

#pragma mark - Original Transform

static CGAffineTransform SHA_GetOriginalTransform(
    UIView *view
)
{
    if (!view)
        return CGAffineTransformIdentity;

    if (!SHAOriginalTransforms)
    {
        SHAOriginalTransforms =
            [NSMapTable weakToStrongObjectsMapTable];
    }

    NSValue *value =
        [SHAOriginalTransforms objectForKey:view];

    if (value)
    {
        return [value CGAffineTransformValue];
    }

    CGAffineTransform transform =
        view.transform;

    [SHAOriginalTransforms
        setObject:
            [NSValue valueWithCGAffineTransform:transform]
        forKey:view];

    return transform;
}

#pragma mark - Original Bounds

static CGRect SHA_GetOriginalBounds(
    UIView *view
)
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
    {
        return [value CGRectValue];
    }

    CGRect bounds =
        view.bounds;

    [SHAOriginalFrames
        setObject:
            [NSValue valueWithCGRect:bounds]
        forKey:view];

    return bounds;
}

#pragma mark - Vertical Scale

static CGFloat SHA_ScaleForHeight(
    CGFloat height,
    CGFloat delta
)
{
    if (height <= 0.0)
        return 1.0;

    CGFloat newHeight =
        height + delta;

    /*
     * Không cho chiều cao <= 1 px.
     */
    if (newHeight < 1.0)
        newHeight = 1.0;

    return newHeight / height;
}

#pragma mark - Status Bar Scale

static void SHA_ApplyStatusScale(
    UIView *view
)
{
    if (!view)
        return;

    if (!SHA_IsPortrait())
        return;

    CGRect bounds =
        SHA_GetOriginalBounds(view);

    CGFloat height =
        bounds.size.height;

    if (height <= 0.0)
        return;

    CGFloat scaleY =
        SHA_ScaleForHeight(
            height,
            SHAStatusDelta
        );

    CGAffineTransform original =
        SHA_GetOriginalTransform(view);

    /*
     * Chỉ scale theo chiều dọc.
     *
     * Không thay đổi:
     * - X
     * - Y
     * - safeArea
     * - gesture
     */

    CGAffineTransform transform =
        CGAffineTransformScale(
            original,
            1.0,
            scaleY
        );

    view.transform =
        transform;
}

#pragma mark - Find Status Bar

static BOOL SHA_IsStatusClass(
    UIView *view
)
{
    if (!view)
        return NO;

    NSString *name =
        NSStringFromClass([view class]);

    if ([name isEqualToString:@"_UIStatusBar"])
        return YES;

    if ([name isEqualToString:@"UIStatusBar"])
        return YES;

    if ([name isEqualToString:@"UIStatusBar_Modern"])
        return YES;

    if ([name isEqualToString:
            @"SBMainDisplaySceneLayoutStatusBarView"])
        return YES;

    return NO;
}

static void SHA_SearchStatusBar(
    UIView *root
)
{
    if (!root)
        return;

    if (SHA_IsStatusClass(root))
    {
        SHA_ApplyStatusScale(root);
        return;
    }

    NSArray *children =
        [[root subviews] copy];

    for (UIView *child in children)
    {
        SHA_SearchStatusBar(child);
    }
}

#pragma mark - Home Bar Detection

static BOOL SHA_IsHomePill(
    UIView *view
)
{
    if (!view)
        return NO;

    NSString *name =
        NSStringFromClass([view class]);

    if ([name isEqualToString:
            @"MTLumaDodgePillView"])
        return YES;

    if ([name isEqualToString:
            @"MTStaticColorPillView"])
        return YES;

    return NO;
}

#pragma mark - Home Visual Scale

static void SHA_ApplyHomeVisualScale(
    UIView *view
)
{
    if (!view)
        return;

    if (!SHA_IsPortrait())
        return;

    CGRect bounds =
        SHA_GetOriginalBounds(view);

    CGFloat height =
        bounds.size.height;

    if (height <= 0.0)
        return;

    /*
     * Home indicator visual thường rất thấp.
     *
     * Vì vậy delta được chuyển thành
     * một hệ số an toàn thay vì trực tiếp
     * cộng hàng chục pixel vào pill.
     */

    CGFloat visualDelta =
        SHAHomeDelta * 0.10;

    CGFloat scaleY =
        SHA_ScaleForHeight(
            height,
            visualDelta
        );

    CGAffineTransform original =
        SHA_GetOriginalTransform(view);

    view.transform =
        CGAffineTransformScale(
            original,
            1.0,
            scaleY
        );
}

#pragma mark - Home Bar Recursive Visual

static void SHA_SearchHomeVisual(
    UIView *root
)
{
    if (!root)
        return;

    if (SHA_IsHomePill(root))
    {
        SHA_ApplyHomeVisualScale(root);
        return;
    }

    NSArray *children =
        [[root subviews] copy];

    for (UIView *child in children)
    {
        SHA_SearchHomeVisual(child);
    }
}

#pragma mark - UIKit Home Indicator

%hook MTLumaDodgePillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    SHA_ApplyHomeVisualScale(
        (UIView *)self
    );
}

%end


%hook MTStaticColorPillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    SHA_ApplyHomeVisualScale(
        (UIView *)self
    );
}

%end

#pragma mark - Home Grabber Container

%hook SBHomeGrabberView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    /*
     * Không transform SBHomeGrabberView itself.
     *
     * Nó có thể liên quan tới gesture.
     *
     * Chỉ tìm các visual descendants.
     */

    SHA_SearchHomeVisual(
        (UIView *)self
    );
}

%end

#pragma mark - Status Bar

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    SHA_ApplyStatusScale(
        (UIView *)self
    );
}

%end


%hook UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    SHA_ApplyStatusScale(
        (UIView *)self
    );
}

%end


%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    SHA_ApplyStatusScale(
        (UIView *)self
    );
}

%end

#pragma mark - Window Search

%hook UIWindow

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    /*
     * Chỉ tìm Status Bar.
     */
    SHA_SearchStatusBar(
        (UIView *)self
    );

    /*
     * Home Bar visual.
     *
     * Không chỉnh UIWindow.
     * Không chỉnh safeArea.
     */
    SHA_SearchHomeVisual(
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
             * Các view sẽ tự layout lại.
             * Hook layoutSubviews sẽ áp dụng
             * scale mới.
             */
        }
    );
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        SHAOriginalTransforms =
            [NSMapTable weakToStrongObjectsMapTable];

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
    }
}
