#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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
 * _UIStatusBar
 * ============================================================
 *
 * Hướng mới:
 *
 * intrinsicContentSize
 *
 * Không:
 * - CATransform3D
 * - setFrame
 * - bounds
 * - center
 * - avoidanceFrame
 * - UIApplicationSceneSettings
 * - Home Bar
 */


/*
 * ------------------------------------------------------------
 * Class method
 *
 * + intrinsicContentSizeForTargetScreen:
 *     orientation:
 *     onLockScreen:
 * ------------------------------------------------------------
 */

%hook _UIStatusBar


+ (CGSize)intrinsicContentSizeForTargetScreen:(id)targetScreen
                                   orientation:(long long)orientation
                                  onLockScreen:(BOOL)onLockScreen
{
    CGSize original =
        %orig(
            targetScreen,
            orientation,
            onLockScreen
        );


    /*
     * Portrait
     */
    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        CGFloat customHeight =
            SHAGetStatusBarHeight();

        /*
         * Chỉ thay HEIGHT.
         *
         * Width giữ nguyên hệ thống.
         */
        original.height =
            customHeight;
    }


    /*
     * Landscape:
     * giữ nguyên intrinsic size gốc.
     */

    return original;
}


/*
 * ------------------------------------------------------------
 * Class method có isAzulBLinked
 * ------------------------------------------------------------
 */

+ (CGSize)intrinsicContentSizeForTargetScreen:(id)targetScreen
                                   orientation:(long long)orientation
                                  onLockScreen:(BOOL)onLockScreen
                              isAzulBLinked:(BOOL)isAzulBLinked
{
    CGSize original =
        %orig(
            targetScreen,
            orientation,
            onLockScreen,
            isAzulBLinked
        );


    /*
     * Chỉ Portrait.
     */
    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        CGFloat customHeight =
            SHAGetStatusBarHeight();

        original.height =
            customHeight;
    }


    return original;
}


%end


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
     * Chỉ SpringBoard.
     */
    if (![bundleID isEqualToString:@"com.apple.springboard"]) {
        return;
    }


    %init;
}
