#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define SHA_PREFS_DOMAIN @"com.congtu.statushomebaradjuster"
#define SHA_STATUS_HEIGHT_KEY @"StatusBarHeight"

static CGFloat SHAStatusBarHeight(void)
{
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        CFSTR(SHA_STATUS_HEIGHT_KEY),
        CFSTR(SHA_PREFS_DOMAIN)
    );

    CGFloat height = 30.0;

    if (value) {
        if (CFGetTypeID(value) == CFNumberGetTypeID()) {
            double number = 30.0;
            CFNumberGetValue(
                (CFNumberRef)value,
                kCFNumberDoubleType,
                &number
            );
            height = (CGFloat)number;
        }
        else if (CFGetTypeID(value) == CFStringGetTypeID()) {
            height = (CGFloat)CFStringGetDoubleValue(
                (CFStringRef)value
            );
        }

        CFRelease(value);
    }

    if (height < 0.0)
        height = 0.0;

    if (height > 120.0)
        height = 120.0;

    return height;
}


/*
 * UIApplicationSceneSettings
 *
 * Không thay đổi frame của Status Bar.
 * Không scale Status Bar.
 * Không đụng Home Bar.
 *
 * Chỉ cung cấp chiều cao Status Bar mà hệ thống
 * dùng cho scene/layout.
 */

%hook UIApplicationSceneSettings

- (double)statusBarHeight
{
    return (double)SHAStatusBarHeight();
}

- (double)defaultStatusBarHeightForOrientation:(long long)orientation
{
    /*
     * Chỉ thay đổi Portrait.
     *
     * UIInterfaceOrientation:
     * 1 = Portrait
     * 2 = PortraitUpsideDown
     * 3/4 = Landscape
     */

    if (orientation == 1 || orientation == 2) {
        return (double)SHAStatusBarHeight();
    }

    return %orig;
}

%end


/*
 * SBMainDisplaySceneLayoutStatusBarView
 *
 * Không sửa frame trực tiếp.
 * Không scale.
 *
 * Chỉ thay đổi avoidance frame của Status Bar
 * để hệ thống biết vùng phía trên cần tránh.
 */

%hook SBMainDisplaySceneLayoutStatusBarView

- (CGRect)_statusBarAvoidanceFrame
{
    CGRect frame = %orig;

    UIInterfaceOrientation orientation =
        UIInterfaceOrientationPortrait;

    UIWindow *window = self.window;

    if (window.windowScene) {
        orientation =
            window.windowScene.interfaceOrientation;
    }

    /*
     * Landscape giữ nguyên hoàn toàn.
     */
    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {
        return frame;
    }

    CGFloat height = SHAStatusBarHeight();

    /*
     * Chỉ thay đổi chiều cao vùng tránh.
     *
     * TOP = 0
     * BOTTOM = height
     */
    frame.origin.y = 0.0;
    frame.size.height = height;

    return frame;
}

%end


/*
 * Preference thay đổi
 *
 * Reload SpringBoard layout để giá trị mới
 * được áp dụng mà không đụng Home Bar.
 */

static void SHAPreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:
                    @"SHAStatusHomeBarAdjusterPreferencesChanged"
                object:nil];
        }
    );
}


%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];

    /*
     * Chỉ chạy trong SpringBoard.
     */
    if (![bundleID isEqualToString:@"com.apple.springboard"]) {
        return;
    }

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        SHAPreferencesChanged,
        CFSTR("com.congtu.statushomebaradjuster/preferenceschanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );

    %init;
}
