#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

static CGFloat SHAStatusDelta = 0.0;
static CGFloat SHAHomeDelta = 0.0;

#pragma mark - Preferences

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

        CFNumberGetValue(
            (CFNumberRef)status,
            kCFNumberDoubleType,
            &value
        );

        SHAStatusDelta =
            (CGFloat)MAX(-120.0, MIN(120.0, value));
    }

    if (home &&
        CFGetTypeID(home) == CFNumberGetTypeID())
    {
        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)home,
            kCFNumberDoubleType,
            &value
        );

        SHAHomeDelta =
            (CGFloat)MAX(-120.0, MIN(120.0, value));
    }

    if (status)
        CFRelease(status);

    if (home)
        CFRelease(home);
}

#pragma mark - Portrait

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

            UIWindowScene *ws =
                (UIWindowScene *)scene;

            UIInterfaceOrientation o =
                ws.interfaceOrientation;

            if (o == UIInterfaceOrientationPortrait ||
                o == UIInterfaceOrientationPortraitUpsideDown)
            {
                return YES;
            }
        }
    }

    return NO;
}

#pragma mark - Status Bar Height

/*
 * KHÔNG scale icon.
 *
 * Thay đổi chiều cao layout của Status Bar.
 */

%hook _UIStatusBar

+ (double)heightForOrientation:(long long)orientation
{
    double original =
        %orig;

    SHA_LoadPreferences();

    /*
     * Chỉ Portrait.
     */
    if (orientation != 1 &&
        orientation != 2)
    {
        return original;
    }

    double result =
        original + SHAStatusDelta;

    if (result < 1.0)
        result = 1.0;

    return result;
}

%end

#pragma mark - Status Bar Modern Provider

%hook _UIStatusBarVisualProvider_iOS

- (double)statusBarHeight
{
    double original =
        %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return original;

    double result =
        original + SHAStatusDelta;

    if (result < 1.0)
        result = 1.0;

    return result;
}

%end

#pragma mark - Home Bar Visual Only

/*
 * KHÔNG hook:
 *
 * SBHomeGrabberView
 *
 * KHÔNG thay frame của Home Grabber.
 *
 * KHÔNG thay safeAreaInsets.
 *
 * KHÔNG thay gesture.
 *
 * Chỉ xử lý visual pill.
 */

static void SHA_ResizeHomeVisual(UIView *view)
{
    if (!view)
        return;

    if (!SHA_IsPortrait())
        return;

    if (SHAHomeDelta == 0.0)
        return;

    CGRect bounds =
        view.bounds;

    CGFloat oldHeight =
        bounds.size.height;

    if (oldHeight <= 0.0)
        return;

    /*
     * Chiều cao mới theo đúng px.
     */
    CGFloat newHeight =
        oldHeight + SHAHomeDelta;

    if (newHeight < 1.0)
        newHeight = 1.0;

    /*
     * Giữ tâm visual.
     */
    CGFloat centerY =
        CGRectGetMidY(bounds);

    bounds.size.height =
        newHeight;

    bounds.origin.y =
        centerY - (newHeight / 2.0);

    /*
     * Chỉ thay bounds của visual.
     *
     * Không transform.
     * Không thay frame.
     * Không thay gesture.
     */
    view.bounds =
        bounds;
}

#pragma mark - Home Pill

%hook MTLumaDodgePillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ResizeHomeVisual(
        (UIView *)self
    );
}

%end

%hook MTStaticColorPillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_ResizeHomeVisual(
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
             * Chỉ yêu cầu layout lại.
             */
            UIApplication *app =
                [UIApplication sharedApplication];

            if (!app)
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

                    UIWindowScene *ws =
                        (UIWindowScene *)scene;

                    for (UIWindow *window
                         in ws.windows)
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
