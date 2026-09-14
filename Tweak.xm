#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#pragma mark - Preferences

static CGFloat SHAStatusHeightDelta = 0.0;
static CGFloat SHAHomeHeightDelta = 0.0;

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

    SHAStatusHeightDelta = 0.0;
    SHAHomeHeightDelta = 0.0;

    if (statusValue &&
        CFGetTypeID(statusValue) == CFNumberGetTypeID())
    {
        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)statusValue,
            kCFNumberDoubleType,
            &value
        );

        value =
            MAX(-120.0, MIN(120.0, value));

        SHAStatusHeightDelta =
            (CGFloat)value;
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

        value =
            MAX(-120.0, MIN(120.0, value));

        SHAHomeHeightDelta =
            (CGFloat)value;
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

            UIInterfaceOrientation orientation =
                windowScene.interfaceOrientation;

            if (orientation ==
                    UIInterfaceOrientationPortrait ||
                orientation ==
                    UIInterfaceOrientationPortraitUpsideDown)
            {
                return YES;
            }
        }
    }

    return NO;
}

#pragma mark - Status Bar Height

/*
 * Đây là phần quan trọng nhất.
 *
 * Không scale icon.
 * Không đổi frame icon.
 *
 * Thay đổi trực tiếp chiều cao mà
 * UIKit dùng để layout Status Bar.
 */

%hook _UIStatusBar

+ (double)heightForOrientation:(long long)orientation
{
    double original =
        %orig;

    SHA_LoadPreferences();

    /*
     * iOS:
     * 1 = Portrait
     * 2 = Portrait Upside Down
     *
     * Landscape:
     * giữ nguyên hoàn toàn.
     */

    if (orientation == 1 ||
        orientation == 2)
    {
        double result =
            original + SHAStatusHeightDelta;

        /*
         * Không cho height <= 1.
         */
        if (result < 1.0)
            result = 1.0;

        return result;
    }

    return original;
}

%end

#pragma mark - Modern Status Bar Provider

/*
 * Một số iOS 16 dùng visual provider
 * để bố trí nội dung Status Bar.
 *
 * Sau khi _UIStatusBar trả về height mới,
 * provider sẽ layout lại toàn bộ nội dung.
 */

%hook _UIStatusBarVisualProvider_iOS

- (double)statusBarHeight
{
    double original =
        %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return original;

    double result =
        original + SHAStatusHeightDelta;

    if (result < 1.0)
        result = 1.0;

    return result;
}

%end

#pragma mark - Home Bar Container

/*
 * MTLumaDodgePillView chỉ là visual pill.
 *
 * KHÔNG scale nó.
 *
 * SBHomeGrabberView là container chứa
 * Home Indicator.
 */

%hook SBHomeGrabberView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAHomeHeightDelta == 0.0)
        return;

    UIView *pill =
        nil;

    /*
     * Tìm MTLumaDodgePillView.
     */
    for (UIView *subview in self.subviews)
    {
        NSString *name =
            NSStringFromClass(
                [subview class]
            );

        if ([name isEqualToString:
                @"MTLumaDodgePillView"] ||
            [name isEqualToString:
                @"MTStaticColorPillView"])
        {
            pill = subview;
            break;
        }
    }

    if (!pill)
        return;

    /*
     * KHÔNG thay đổi:
     *
     * pill.frame
     * pill.bounds
     * pill.transform
     *
     * Vì như vậy chỉ làm icon/pill dày lên.
     *
     * Thay vào đó lấy container.
     */

    UIView *container =
        self;

    CGRect frame =
        container.frame;

    CGFloat originalHeight =
        frame.size.height;

    if (originalHeight <= 0.0)
        return;

    /*
     * Thay đổi chiều cao của visual
     * container.
     */

    CGFloat newHeight =
        originalHeight +
        SHAHomeHeightDelta;

    if (newHeight < 1.0)
        newHeight = 1.0;

    /*
     * Giữ đáy nguyên vị trí.
     *
     * Nghĩa là:
     *
     * +30
     * -> vùng Home Bar cao thêm 30 px
     *    lên phía trên.
     *
     * -30
     * -> vùng thấp xuống 30 px.
     */

    CGFloat bottom =
        frame.origin.y +
        frame.size.height;

    frame.size.height =
        newHeight;

    frame.origin.y =
        bottom - newHeight;

    /*
     * Chỉ layout visual container.
     *
     * Không thay safe area.
     * Không thay gesture recognizer.
     */

    [UIView performWithoutAnimation:
        ^{
            container.frame =
                frame;

            [container setNeedsLayout];

            [container layoutIfNeeded];
        }
    ];
}

%end

#pragma mark - Home Bar Visual Container Search

/*
 * Một số iOS 16 đặt pill sâu hơn một cấp.
 *
 * Hook này tìm SBHomeGrabberView trong
 * hierarchy của SpringBoard nhưng KHÔNG
 * đụng vào MTLumaDodgePillView.
 */

static void SHA_FindHomeGrabber(
    UIView *root
)
{
    if (!root)
        return;

    NSString *name =
        NSStringFromClass(
            [root class]
        );

    if ([name isEqualToString:
            @"SBHomeGrabberView"])
    {
        [root setNeedsLayout];
        return;
    }

    NSArray *children =
        [[root subviews] copy];

    for (UIView *child in children)
    {
        SHA_FindHomeGrabber(child);
    }
}

#pragma mark - SpringBoard Windows

%hook UIWindow

- (void)layoutSubviews
{
    %orig;

    /*
     * Chỉ SpringBoard/Home UI.
     *
     * Không xử lý landscape.
     */

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAHomeHeightDelta == 0.0)
        return;

    SHA_FindHomeGrabber(
        (UIView *)self
    );
}

%end

#pragma mark - Settings Notification

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
             * Trigger layout lại.
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
