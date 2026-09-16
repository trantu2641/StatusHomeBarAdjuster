#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define SHA_PREFS_DOMAIN "com.congtu.statushomebaradjuster"
#define SHA_STATUS_BAR_HEIGHT_KEY "StatusBarHeight"

static CGFloat SHAGetStatusBarHeight(void)
{
    /*
     * 1.2.2 baseline:
     *
     * Settings lưu:
     *     StatusBarHeight
     *
     * Giá trị người dùng nhập:
     *     0 - 120 px
     *
     * Không phải offset.
     */

    CFPreferencesAppSynchronize(
        CFSTR(SHA_PREFS_DOMAIN)
    );

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            CFSTR(SHA_STATUS_BAR_HEIGHT_KEY),
            CFSTR(SHA_PREFS_DOMAIN)
        );

    CGFloat height = 30.0;

    if (value == NULL) {
        return height;
    }


    /*
     * NSNumber
     */
    if (CFGetTypeID(value) == CFNumberGetTypeID()) {

        double number = 30.0;

        Boolean success =
            CFNumberGetValue(
                (CFNumberRef)value,
                kCFNumberDoubleType,
                &number
            );

        if (success) {
            height = (CGFloat)number;
        }
    }


    /*
     * NSString
     *
     * PSEditTextCell thường có thể lưu
     * giá trị dưới dạng NSString.
     */
    else if (CFGetTypeID(value) == CFStringGetTypeID()) {

        height =
            (CGFloat)CFStringGetDoubleValue(
                (CFStringRef)value
            );
    }


    CFRelease(value);


    /*
     * Clamp đúng 0 - 120 px.
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
 * Đây là đúng hướng của bản 1.2.2.
 *
 * Không:
 * - scale Status Bar
 * - đổi frame Status Bar
 * - đổi icon
 * - đổi Home Bar
 * - hook SBHomeGrabberView
 */

%hook UIApplicationSceneSettings


/*
 * Status Bar height hiện tại.
 *
 * Settings:
 *
 * 0   -> 0 px
 * 10  -> 10 px
 * 20  -> 20 px
 * 30  -> 30 px
 * 49  -> 49 px
 * 60  -> 60 px
 * 100 -> 100 px
 * 120 -> 120 px
 */

- (double)statusBarHeight
{
    return (double)SHAGetStatusBarHeight();
}


/*
 * Default Status Bar height theo orientation.
 *
 * Chỉ thay Portrait.
 *
 * Landscape trả lại giá trị gốc.
 */

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

    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        return (double)SHAGetStatusBarHeight();
    }


    return %orig;
}


%end


/*
 * ============================================================
 * Constructor
 * ============================================================
 *
 * Chỉ SpringBoard.
 */

%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];


    if (![bundleID isEqualToString:@"com.apple.springboard"]) {
        return;
    }


    %init;
}
