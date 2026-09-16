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
     * Giá trị Settings là chiều cao thực tế:
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
 * _UIStatusBar
 * ============================================================
 *
 * Không scale.
 * Không setFrame.
 * Không đổi bounds.
 * Không đụng Home Bar.
 *
 * Chỉ thay avoidance frame.
 */

%hook _UIStatusBar


- (void)setAvoidanceFrame:(CGRect)avoidanceFrame
{
    /*
     * Không truy cập self.window ở đây.
     *
     * Tránh lỗi:
     *
     * "property 'window' cannot be found in forward
     *  class object '_UIStatusBar'"
     *
     *
     * Phân biệt Portrait / Landscape dựa trên frame.
     *
     * Portrait:
     *     width  > height
     *
     * Landscape:
     *     width  < height
     *
     * Tuy nhiên avoidance frame có thể có kích thước
     * đặc biệt tùy trạng thái SpringBoard, vì vậy chỉ
     * sửa khi frame hợp lý cho vùng Status Bar phía trên.
     */

    CGFloat width = avoidanceFrame.size.width;
    CGFloat height = avoidanceFrame.size.height;


    /*
     * Nếu frame có chiều ngang lớn hơn chiều cao,
     * đây là dạng vùng Status Bar Portrait thông thường.
     *
     * Nếu không, giữ nguyên để tránh tác động Landscape.
     */
    if (width <= height) {
        %orig(avoidanceFrame);
        return;
    }


    CGFloat customHeight =
        SHAGetStatusBarHeight();


    CGRect customFrame =
        avoidanceFrame;


    /*
     * TOP cố định.
     */
    customFrame.origin.y = 0.0;


    /*
     * BOTTOM thay đổi theo Settings.
     */
    customFrame.size.height =
        customHeight;


    %orig(customFrame);
}


- (void)setAvoidanceFrame:(CGRect)avoidanceFrame
     animationSettings:(id)animationSettings
               options:(NSUInteger)options
{
    CGFloat width =
        avoidanceFrame.size.width;

    CGFloat height =
        avoidanceFrame.size.height;


    /*
     * Giữ Landscape nguyên bản.
     */
    if (width <= height) {

        %orig(
            avoidanceFrame,
            animationSettings,
            options
        );

        return;
    }


    CGFloat customHeight =
        SHAGetStatusBarHeight();


    CGRect customFrame =
        avoidanceFrame;


    customFrame.origin.y = 0.0;

    customFrame.size.height =
        customHeight;


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
