#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

static CGFloat SHAStatusDelta = 0.0;
static CGFloat SHAHomeDelta = 0.0;

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

#pragma mark - Resize Bounds

static void SHA_ResizeHeight(
    UIView *view,
    CGFloat delta
)
{
    if (!view)
        return;

    if (delta == 0.0)
        return;

    CGRect bounds =
        view.bounds;

    CGFloat oldHeight =
        CGRectGetHeight(bounds);

    if (oldHeight <= 0.0)
        return;

    CGFloat newHeight =
        oldHeight + delta;

    if (newHeight < 1.0)
        newHeight = 1.0;

    CGFloat centerY =
        CGRectGetMidY(bounds);

    bounds.size.height =
        newHeight;

    bounds.origin.y =
        centerY - (newHeight / 2.0);

    view.bounds =
        bounds;
}

#pragma mark - Status Bar

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAStatusDelta == 0.0)
        return;

    UIView *view =
        (UIView *)self;

    SHA_ResizeHeight(
        view,
        SHAStatusDelta
    );
}

%end

#pragma mark - SpringBoard Status Bar

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAStatusDelta == 0.0)
        return;

    UIView *view =
        (UIView *)self;

    SHA_ResizeHeight(
        view,
        SHAStatusDelta
    );
}

%end

#pragma mark - Home Bar Visual

static void SHA_FindHomeVisual(
    UIView *root
)
{
    if (!root)
        return;

    NSArray *children =
        [[root subviews] copy];

    for (UIView *child in children)
    {
        NSString *className =
            NSStringFromClass([child class]);

        if ([className isEqualToString:
                @"MTLumaDodgePillView"] ||
            [className isEqualToString:
                @"MTStaticColorPillView"])
        {
            /*
             * Không thay frame.
             *
             * Không thay transform.
             *
             * Không thay gesture.
             *
             * Chỉ thay bounds height của
             * visual object.
             */
            SHA_ResizeHeight(
                child,
                SHAHomeDelta
            );

            continue;
        }

        /*
         * Tìm sâu hơn.
         */
        SHA_FindHomeVisual(child);
    }
}

#pragma mark - Home Bar Hook

%hook UIWindow

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAHomeDelta == 0.0)
        return;

    /*
     * Chỉ tìm visual Home Bar.
     *
     * Không resize UIWindow.
     * Không resize SBHomeGrabberView.
     */
    SHA_FindHomeVisual(
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
            UIApplication *app =
                [UIApplication sharedApplication];

            if (!app)
                return;

            if (@available(iOS 13.0, *))
            {
                for (UIScene *scene in app.connectedScenes)
                {
                    if (![scene isKindOfClass:
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
