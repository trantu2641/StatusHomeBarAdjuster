#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define SHA_PREFS_DOMAIN "com.congtu.statushomebaradjuster"
#define SHA_STATUS_BAR_HEIGHT "StatusBarHeight"


static CGFloat SHAGetStatusBarHeight(void)
{
    /*
     * Giá trị trong Settings là chiều cao thực tế:
     *
     * 0   = 0 px
     * 10  = 10 px
     * 20  = 20 px
     * 30  = 30 px
     * 49  = 49 px
     * 120 = 120 px
     */

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


    /*
     * Clamp 0 - 120.
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
 * Đây là cơ chế của baseline 1.2.2.
 *
 * Không:
 * - CATransform3D
 * - scale Status Bar
 * - setFrame:
 * - hook _UIStatusBar
 * - hook Home Bar
 * - hook SBHomeGrabberView
 */

%hook UIApplicationSceneSettings


- (double)statusBarHeight
{
    return (double)SHAGetStatusBarHeight();
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

    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        return (double)SHAGetStatusBarHeight();
    }


    /*
     * Landscape giữ nguyên giá trị hệ thống.
     */
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
