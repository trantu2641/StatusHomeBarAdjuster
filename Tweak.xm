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


    /*
     * Settings = chiều cao thực tế.
     *
     * 0   -> 0 px
     * 10  -> 10 px
     * 20  -> 20 px
     * 30  -> 30 px
     * 49  -> 49 px
     * 120 -> 120 px
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
 * _UIStatusBar
 * ============================================================
 *
 * Không scale Status Bar.
 *
 * Không thay frame/bounds/center.
 *
 * Chúng ta tác động vào AVOIDANCE FRAME mà SpringBoard
 * truyền cho Status Bar.
 *
 * Mục tiêu:
 *
 * TOP cố định = 0
 * BOTTOM = StatusBarHeight
 */

%hook _UIStatusBar


- (void)setAvoidanceFrame:(CGRect)avoidanceFrame
{
    /*
     * Lấy orientation từ window của Status Bar.
     *
     * _UIStatusBar kế thừa UIView nên có window.
     */
    UIWindow *window = self.window;

    UIInterfaceOrientation orientation =
        UIInterfaceOrientationPortrait;

    if (window.windowScene != nil) {

        orientation =
            window.windowScene.interfaceOrientation;
    }


    /*
     * Landscape:
     * hoàn toàn giữ nguyên hệ thống.
     */
    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {

        %orig(avoidanceFrame);
        return;
    }


    /*
     * Lấy chiều cao trực tiếp từ Settings.
     */
    CGFloat height =
        SHAGetStatusBarHeight();


    /*
     * Giữ nguyên X/W của avoidance frame.
     *
     * Chỉ sửa:
     *
     *     y = 0
     *     height = giá trị Settings
     *
     * TOP edge cố định.
     * BOTTOM thay đổi.
     */
    CGRect customFrame = avoidanceFrame;

    customFrame.origin.y = 0.0;
    customFrame.size.height = height;


    %orig(customFrame);
}


- (void)setAvoidanceFrame:(CGRect)avoidanceFrame
     animationSettings:(id)animationSettings
               options:(NSUInteger)options
{
    UIWindow *window = self.window;

    UIInterfaceOrientation orientation =
        UIInterfaceOrientationPortrait;

    if (window.windowScene != nil) {

        orientation =
            window.windowScene.interfaceOrientation;
    }


    /*
     * Landscape giữ nguyên.
     */
    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {

        %orig(
            avoidanceFrame,
            animationSettings,
            options
        );

        return;
    }


    CGFloat height =
        SHAGetStatusBarHeight();


    CGRect customFrame = avoidanceFrame;

    customFrame.origin.y = 0.0;
    customFrame.size.height = height;


    %orig(
        customFrame,
        animationSettings,
        options
    );
}


%end


/*
 * ============================================================
 * Constructor
 * ============================================================
 *
 * Chỉ SpringBoard.
 *
 * Không inject vào app.
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
