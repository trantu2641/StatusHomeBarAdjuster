#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define SHA_PREFS_DOMAIN "com.congtu.statushomebaradjuster"
#define SHA_STATUS_HEIGHT_KEY "StatusBarHeight"


static CGFloat SHAStatusBarHeight(void)
{
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        CFSTR(SHA_STATUS_HEIGHT_KEY),
        CFSTR(SHA_PREFS_DOMAIN)
    );

    CGFloat height = 30.0;

    if (value != NULL) {

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

            height =
                (CGFloat)CFStringGetDoubleValue(
                    (CFStringRef)value
                );
        }

        CFRelease(value);
    }

    /*
     * Người dùng nhập trực tiếp chiều cao:
     *
     * 0   = 0 px
     * 10  = 10 px
     * 20  = 20 px
     * 30  = 30 px
     * 49  = 49 px
     * 120 = 120 px
     */

    if (height < 0.0) {
        height = 0.0;
    }

    if (height > 120.0) {
        height = 120.0;
    }

    return height;
}


/*
 * ============================================================
 * UIApplicationSceneSettings
 * ============================================================
 *
 * Không scale Status Bar.
 * Không thay đổi frame.
 * Không đụng Home Bar.
 *
 * Chỉ thay đổi giá trị mà scene settings báo cho hệ thống.
 */

%hook UIApplicationSceneSettings


- (double)statusBarHeight
{
    /*
     * Chỉ Portrait mới dùng giá trị custom.
     *
     * Không thể đọc orientation trực tiếp ở đây một cách
     * an toàn nên giữ nguyên logic của hệ thống cho những
     * trường hợp không liên quan.
     */
    return (double)SHAStatusBarHeight();
}


- (double)defaultStatusBarHeightForOrientation:(long long)orientation
{
    /*
     * UIInterfaceOrientation:
     *
     * 1 = Portrait
     * 2 = PortraitUpsideDown
     * 3 = LandscapeLeft
     * 4 = LandscapeRight
     */

    if (orientation == 1 || orientation == 2) {
        return (double)SHAStatusBarHeight();
    }

    return %orig;
}


%end


/*
 * ============================================================
 * SBMainDisplaySceneLayoutStatusBarView
 * ============================================================
 *
 * Đây là phần xử lý avoidance frame.
 *
 * Không dùng self.window.
 * Không dùng CATransform3D.
 * Không scale icon.
 * Không đụng Home Bar.
 */

%hook SBMainDisplaySceneLayoutStatusBarView


- (CGRect)_statusBarAvoidanceFrame
{
    CGRect frame = %orig;

    CGFloat height = SHAStatusBarHeight();

    /*
     * Status Bar luôn bắt đầu từ cạnh TOP.
     *
     * Height:
     *     0   -> 0
     *     30  -> 30
     *     49  -> 49
     *     120 -> 120
     */

    frame.origin.y = 0.0;
    frame.size.height = height;

    return frame;
}


%end


/*
 * ============================================================
 * Preference notification
 * ============================================================
 *
 * Khi thay đổi Settings, báo cho SpringBoard.
 *
 * Không thay đổi Home Bar.
 */

static void SHAStatusBarPreferencesChanged(
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
            /*
             * Không tự ý chỉnh frame/view ở đây.
             *
             * UIKit/SpringBoard sẽ đọc lại SceneSettings
             * khi layout được cập nhật.
             */
        }
    );
}


/*
 * ============================================================
 * Constructor
 * ============================================================
 */

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
        SHAStatusBarPreferencesChanged,
        CFSTR("com.congtu.statushomebaradjuster/preferenceschanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );


    %init;
}
