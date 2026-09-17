#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define SHA_PREFS_DOMAIN "com.congtu.statushomebaradjuster"
#define SHA_STATUS_BAR_HEIGHT "StatusBarHeight"

#pragma mark -
#pragma mark Preferences
#pragma mark -

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

    if (height < 0.0)
        height = 0.0;

    if (height > 120.0)
        height = 120.0;

    return height;
}


#pragma mark -
#pragma mark UIApplicationSceneSettings
#pragma mark -

@interface UIApplicationSceneSettings : NSObject

- (double)statusBarHeight;

- (double)defaultStatusBarHeightForOrientation:
    (long long)orientation;

- (UIEdgeInsets)safeAreaInsetsPortrait;

- (CGRect)statusBarAvoidanceFrame;

@end


%hook UIApplicationSceneSettings


/*
 * ============================================================
 * safeAreaInsetsPortrait
 * ============================================================
 *
 * Đây là phần quan trọng nhất của bản này.
 *
 * Không sửa UIView.
 * Không sửa UIWindow.
 *
 * Cho UIKit biết rằng vùng trên của scene chỉ cao
 * bằng giá trị người dùng đặt.
 */

- (UIEdgeInsets)safeAreaInsetsPortrait
{
    UIEdgeInsets original =
        %orig;

    CGFloat height =
        SHAGetStatusBarHeight();

    /*
     * Chỉ thay vùng 0...29.
     *
     * 30...120 giữ nguyên cơ chế cũ.
     */
    if (height < 30.0) {

        original.top =
            height;

        if (original.top < 0.0)
            original.top = 0.0;
    }

    return original;
}


/*
 * ============================================================
 * statusBarAvoidanceFrame
 * ============================================================
 *
 * Đây là frame mà scene dùng để tránh Status Bar.
 *
 * Khi Status Bar < 30, giảm chiều cao avoidance
 * xuống đúng giá trị người dùng đặt.
 */

- (CGRect)statusBarAvoidanceFrame
{
    CGRect original =
        %orig;

    CGFloat height =
        SHAGetStatusBarHeight();

    if (height < 30.0) {

        /*
         * Giữ X và Width.
         *
         * Mép trên cố định tại 0.
         */
        original.origin.y =
            0.0;

        original.size.height =
            height;
    }

    return original;
}


/*
 * ============================================================
 * statusBarHeight
 * ============================================================
 *
 * Giữ cơ chế đang hoạt động 30...120.
 *
 * Đồng thời cung cấp giá trị 0...29.
 */

- (double)statusBarHeight
{
    double original =
        %orig;

    CGFloat height =
        SHAGetStatusBarHeight();

    /*
     * Chỉ thay khi dưới 30.
     *
     * Từ 30 trở lên trả nguyên giá trị hệ thống,
     * tránh phá cơ chế 30...120 hiện tại.
     */
    if (height < 30.0) {

        return (double)height;
    }

    return original;
}


/*
 * ============================================================
 * defaultStatusBarHeightForOrientation:
 * ============================================================
 *
 * Một số UIKit component lấy minimum Status Bar height
 * thông qua method này thay vì statusBarHeight.
 */

- (double)defaultStatusBarHeightForOrientation:
    (long long)orientation
{
    double original =
        %orig(
            orientation
        );

    /*
     * Chỉ Portrait.
     */
    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {

        return original;
    }

    CGFloat height =
        SHAGetStatusBarHeight();

    /*
     * Chỉ xử lý 0...29.
     */
    if (height < 30.0) {

        return (double)height;
    }

    return original;
}


%end


#pragma mark -
#pragma mark _UIStatusBar
#pragma mark -

/*
 * Giữ nguyên cơ chế Status Bar đã có.
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

    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        original.height =
            SHAGetStatusBarHeight();
    }

    return original;
}


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

    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        original.height =
            SHAGetStatusBarHeight();
    }

    return original;
}


%end


#pragma mark -
#pragma mark Constructor
#pragma mark -

%ctor
{
    @autoreleasepool {

        /*
         * Một %init duy nhất.
         */
        %init;
    }
}
