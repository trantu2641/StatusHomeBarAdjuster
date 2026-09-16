#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define SHA_PREFS_DOMAIN "com.congtu.statushomebaradjuster"
#define SHA_STATUS_BAR_HEIGHT "StatusBarHeight"


static CGFloat SHAGetStatusBarHeight(void)
{
    /*
     * Giá trị trong Settings là CHIỀU CAO THỰC TẾ:
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
 * Đây vẫn là baseline 1.2.2.
 *
 * Không:
 * - CATransform3D
 * - setFrame:
 * - hook _UIStatusBar
 * - hook SBHomeGrabberView
 * - hook Home Bar
 *
 * Chỉ điều chỉnh các giá trị layout mà SpringBoard/UIKit
 * đã có sẵn cho Status Bar.
 */

%hook UIApplicationSceneSettings


/*
 * ------------------------------------------------------------
 * 1. Status Bar height
 * ------------------------------------------------------------
 */

- (double)statusBarHeight
{
    return (double)SHAGetStatusBarHeight();
}


/*
 * ------------------------------------------------------------
 * 2. Default Status Bar height
 * ------------------------------------------------------------
 */

- (double)defaultStatusBarHeightForOrientation:(long long)orientation
{
    /*
     * Portrait
     */
    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        return (double)SHAGetStatusBarHeight();
    }


    /*
     * Landscape giữ nguyên hệ thống.
     */
    return %orig;
}


/*
 * ------------------------------------------------------------
 * 3. Status Bar avoidance frame
 * ------------------------------------------------------------
 *
 * Đây là phần mà bản trước còn thiếu.
 *
 * statusBarHeight chỉ nói cho Status Bar biết nó cao bao nhiêu.
 *
 * statusBarAvoidanceFrame mới cho hệ thống biết:
 *
 *     "Nội dung phía dưới phải tránh vùng này."
 *
 */

- (CGRect)statusBarAvoidanceFrame
{
    CGRect frame = %orig;

    CGFloat height = SHAGetStatusBarHeight();


    /*
     * Xác định Portrait bằng hình dạng frame.
     *
     * iPhone 11 Pro Max Portrait:
     *
     * width  ≈ 428
     * height ≈ 49
     *
     * Landscape:
     *
     * width  > height
     *
     * Không cần truy cập self.window, tránh lỗi
     * forward declaration như bản trước.
     */

    if (frame.size.width > frame.size.height) {
        return frame;
    }


    /*
     * Giữ cạnh TOP cố định.
     *
     * Chỉ thay chiều cao.
     */
    frame.origin.y = 0.0;
    frame.size.height = height;


    return frame;
}


/*
 * ------------------------------------------------------------
 * 4. Portrait safe area
 * ------------------------------------------------------------
 *
 * Đây là phần rất quan trọng đối với:
 *
 *     content
 *     navigation bar
 *     app layout
 *     SpringBoard layout
 *
 * Khi Status Bar tăng:
 *
 *     safeArea.top tăng
 *
 * Khi Status Bar giảm:
 *
 *     safeArea.top giảm
 *
 */

- (UIEdgeInsets)safeAreaInsetsPortrait
{
    UIEdgeInsets insets = %orig;

    CGFloat height = SHAGetStatusBarHeight();


    /*
     * Chỉ thay TOP.
     *
     * LEFT / RIGHT / BOTTOM giữ nguyên hệ thống.
     */
    insets.top = height;


    return insets;
}


%end


/*
 * ============================================================
 * Constructor
 * ============================================================
 *
 * Chỉ SpringBoard.
 * Không inject vào ứng dụng bên thứ ba.
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
