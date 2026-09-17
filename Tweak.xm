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
 * _UIStatusBar
 * ============================================================
 *
 * Mục tiêu:
 *
 * 30 -> 120:
 *     giữ cơ chế chiều cao hiện tại.
 *
 * 0 -> 30:
 *     thu nhỏ container thật sự.
 *     Sau đó đưa các Status Bar parts xuống đáy container.
 *
 * Không:
 *     CATransform3D
 *     setFrame:
 *     setBounds:
 *     Home Bar
 */


/*
 * ------------------------------------------------------------
 * intrinsicContentSize
 * ------------------------------------------------------------
 */

%hook _UIStatusBar


- (CGSize)intrinsicContentSize
{
    CGSize size = %orig;

    CGFloat targetHeight =
        SHAGetStatusBarHeight();

    /*
     * Chỉ thay chiều cao.
     *
     * Width giữ nguyên.
     */
    size.height = targetHeight;

    return size;
}


/*
 * ------------------------------------------------------------
 * updateConstraints
 * ------------------------------------------------------------
 *
 * Cho phép Auto Layout cập nhật lại chiều cao sau khi
 * intrinsicContentSize thay đổi.
 */

- (void)updateConstraints
{
    %orig;
}


/*
 * ------------------------------------------------------------
 * frameForPartWithIdentifier:
 * ------------------------------------------------------------
 *
 * Đây là phần mới để xử lý icon.
 *
 * Khi Status Bar < 30 px, frame gốc của icon có thể vẫn
 * nằm theo layout 49 px.
 *
 * Ta giữ nguyên X / Width / Height của từng part,
 * chỉ dịch Y để đáy của part nằm sát đáy Status Bar.
 */

- (CGRect)frameForPartWithIdentifier:(id)identifier
{
    CGRect frame = %orig(identifier);

    CGFloat statusHeight =
        SHAGetStatusBarHeight();

    /*
     * Chỉ cần xử lý khi chiều cao nhỏ hơn mức bình thường.
     *
     * 30 -> 120:
     * giữ nguyên frame gốc để không phá cơ chế đang chạy.
     */
    if (statusHeight >= 30.0) {
        return frame;
    }


    /*
     * Nếu part cao hơn vùng Status Bar mới,
     * đặt phần trên tại 0.
     *
     * Tránh tạo Y âm.
     */
    if (frame.size.height >= statusHeight) {

        frame.origin.y = 0.0;

        return frame;
    }


    /*
     * Đặt BOTTOM của part đúng vào BOTTOM
     * của Status Bar mới.
     *
     * Ví dụ:
     *
     * Status Bar = 20
     * icon height = 12
     *
     * Y = 20 - 12 = 8
     */
    frame.origin.y =
        statusHeight - frame.size.height;


    return frame;
}


/*
 * ------------------------------------------------------------
 * frameForDisplayItemWithIdentifier:
 * ------------------------------------------------------------
 *
 * Một số thành phần Status Bar không đi qua
 * frameForPartWithIdentifier: mà dùng display item.
 *
 * Dùng cùng nguyên tắc.
 */

- (CGRect)frameForDisplayItemWithIdentifier:(id)identifier
{
    CGRect frame =
        %orig(identifier);

    CGFloat statusHeight =
        SHAGetStatusBarHeight();


    /*
     * 30–120:
     * không thay đổi layout hiện tại.
     */
    if (statusHeight >= 30.0) {
        return frame;
    }


    if (frame.size.height >= statusHeight) {

        frame.origin.y = 0.0;

        return frame;
    }


    frame.origin.y =
        statusHeight - frame.size.height;


    return frame;
}


%end


/*
 * ============================================================
 * UIApplicationSceneSettings
 * ============================================================
 *
 * Giữ lại phần đã có tác dụng 30–120.
 *
 * Không đụng Home Bar.
 */

%hook UIApplicationSceneSettings


- (double)statusBarHeight
{
    return (double)SHAGetStatusBarHeight();
}


- (double)defaultStatusBarHeightForOrientation:(long long)orientation
{
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
