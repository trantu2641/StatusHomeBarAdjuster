#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

static CGFloat SHAStatusHeightDelta = 0.0;
static CGFloat SHAHomeHeightDelta = 0.0;

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

        value = MAX(-120.0, MIN(120.0, value));

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

        value = MAX(-120.0, MIN(120.0, value));

        SHAHomeHeightDelta =
            (CGFloat)value;
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Portrait

static BOOL SHA_IsPortrait(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application)
        return NO;

    if (@available(iOS 13.0, *))
    {
        for (UIScene *scene in
             application.connectedScenes)
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

#pragma mark - Status Bar

/*
 * Không đụng icon.
 *
 * Thay đổi height mà Status Bar dùng
 * cho quá trình layout.
 */

%hook _UIStatusBar

+ (double)heightForOrientation:(long long)orientation
{
    double original =
        %orig;

    SHA_LoadPreferences();

    if (orientation != 1 &&
        orientation != 2)
    {
        return original;
    }

    double height =
        original +
        SHAStatusHeightDelta;

    if (height < 1.0)
        height = 1.0;

    return height;
}

%end

#pragma mark - Status Bar Visual Provider

%hook _UIStatusBarVisualProvider_iOS

- (double)statusBarHeight
{
    double original =
        %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return original;

    double height =
        original +
        SHAStatusHeightDelta;

    if (height < 1.0)
        height = 1.0;

    return height;
}

%end

#pragma mark - Home Bar

/*
 * Quan trọng:
 *
 * Không scale MTLumaDodgePillView.
 *
 * Không thay đổi pill.frame.
 *
 * Không thay đổi pill.transform.
 *
 * Chỉ thay đổi layout height của
 * SBHomeGrabberView.
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

    /*
     * SBHomeGrabberView là private class.
     *
     * Ép sang UIView để compiler biết
     * đây là UIView.
     */

    UIView *container =
        (UIView *)self;

    if (!container)
        return;

    CGRect frame =
        container.frame;

    CGFloat originalHeight =
        frame.size.height;

    if (originalHeight <= 0.0)
        return;

    /*
     * Height thay đổi trực tiếp theo px.
     *
     * +30 = cao thêm 30 px
     * -30 = thấp đi 30 px
     */

    CGFloat newHeight =
        originalHeight +
        SHAHomeHeightDelta;

    if (newHeight < 1.0)
        newHeight = 1.0;

    /*
     * Giữ mép dưới.
     *
     * Phần visual mở rộng lên trên.
     */

    CGFloat bottom =
        frame.origin.y +
        frame.size.height;

    frame.size.height =
        newHeight;

    frame.origin.y =
        bottom - newHeight;

    /*
     * Chỉ thay frame của container.
     *
     * Không thay:
     * safeAreaInsets
     * additionalSafeAreaInsets
     * gesture recognizer
     * hitTest
     */

    container.frame =
        frame;
}

%end

#pragma mark - Home Bar Visual Layout

/*
 * Một số phiên bản iOS layout lại
 * Home Grabber ngay sau khi window layout.
 */

%hook UIWindow

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    /*
     * Không scale UIWindow.
     *
     * Không thay safe area.
     */

    if (SHAHomeHeightDelta == 0.0 &&
        SHAStatusHeightDelta == 0.0)
    {
        return;
    }

    /*
     * Cho UIKit/SpringBoard hoàn thành
     * layout tự nhiên.
     */
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
                for (UIScene *scene in
                     application.connectedScenes)
                {
                    if (![scene
                            isKindOfClass:
                                [UIWindowScene class]])
                    {
                        continue;
                    }

                    UIWindowScene *windowScene =
                        (UIWindowScene *)scene;

                    for (UIWindow *window in
                         windowScene.windows)
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
