#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define SHA_PREFS_DOMAIN "com.congtu.statushomebaradjuster"
#define SHA_STATUS_BAR_HEIGHT "StatusBarHeight"

static CGFloat SHAGetStatusBarHeight(void)
{
    CFPreferencesAppSynchronize(
        CFSTR(SHA_PREFS_DOMAIN)
    );

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            CFSTR(SHA_STATUS_BAR_HEIGHT),
            CFSTR(SHA_PREFS_DOMAIN)
        );

    CGFloat height = 30.0;

    if (value != NULL) {

        if (CFGetTypeID(value) == CFNumberGetTypeID()) {

            double number = 30.0;

            if (CFNumberGetValue(
                    (CFNumberRef)value,
                    kCFNumberDoubleType,
                    &number)) {

                height = (CGFloat)number;
            }
        }
        else if (CFGetTypeID(value) == CFStringGetTypeID()) {

            height =
                (CGFloat)CFStringGetDoubleValue(
                    (CFStringRef)value
                );
        }

        CFRelease(value);
    }

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
 * Đây là class mà binary 1.2.2 thực sự hook.
 *
 * Không dùng transform.
 * Không đổi frame.
 * Không đụng Home Bar.
 */

%hook UIApplicationSceneSettings


- (double)statusBarHeight
{
    return (double)SHAGetStatusBarHeight();
}


- (double)defaultStatusBarHeightForOrientation:(long long)orientation
{
    /*
     * Portrait:
     * 1 = UIInterfaceOrientationPortrait
     * 2 = UIInterfaceOrientationPortraitUpsideDown
     *
     * Landscape:
     * 3 / 4
     */

    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        return (double)SHAGetStatusBarHeight();
    }

    return %orig;
}


%end


/*
 * ============================================================
 * SpringBoard notification
 * ============================================================
 *
 * Preferences bundle của 1.2.2 gửi:
 *
 * com.congtu.statushomebaradjuster.settingsChanged
 *
 * Không trực tiếp thay frame ở đây.
 *
 * Notification này chỉ được dùng để làm SpringBoard
 * invalidate scene/layout ở mức an toàn.
 */

static int SHASettingsNotifyToken = 0;

static void SHASettingsChanged(
    int token
)
{
    /*
     * Không hook Home Bar.
     *
     * Khi Settings thay đổi, giá trị mới sẽ được đọc
     * ở lần SpringBoard hỏi lại UIApplicationSceneSettings.
     *
     * Chỉ đảm bảo callback chạy trong SpringBoard.
     */
}


%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];

    /*
     * Chỉ inject SpringBoard.
     */
    if (![bundleID isEqualToString:@"com.apple.springboard"]) {
        return;
    }

    %init;
}
