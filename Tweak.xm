#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

#pragma mark - Preferences

static CGFloat SHAStatusBarHeight(void)
{
    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            CFSTR("StatusBarHeight"),
            CFSTR("com.congtu.statushomebaradjuster")
        );

    CGFloat height = 30.0;

    if (value) {

        if (CFGetTypeID(value) == CFNumberGetTypeID()) {

            double v = 30.0;

            CFNumberGetValue(
                (CFNumberRef)value,
                kCFNumberDoubleType,
                &v
            );

            height = (CGFloat)v;
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
     * Giới hạn:
     *
     * 0   = ẩn hoàn toàn
     * 30  = mặc định
     * 120 = tối đa
     */

    if (height < 0.0)
        height = 0.0;

    if (height > 120.0)
        height = 120.0;

    return height;
}

#pragma mark - SBMainDisplaySceneLayoutStatusBarView

@interface SBMainDisplaySceneLayoutStatusBarView : UIView

- (CGRect)_statusBarFrameForOrientation:(NSInteger)orientation;

@end

static CGRect (*orig_SHA_statusBarFrameForOrientation)(
    SBMainDisplaySceneLayoutStatusBarView *self,
    SEL _cmd,
    NSInteger orientation
);

static CGRect hook_SHA_statusBarFrameForOrientation(
    SBMainDisplaySceneLayoutStatusBarView *self,
    SEL _cmd,
    NSInteger orientation
)
{
    /*
     * Lấy frame gốc của SpringBoard trước.
     */
    CGRect frame =
        orig_SHA_statusBarFrameForOrientation(
            self,
            _cmd,
            orientation
        );

    /*
     * Chỉ Portrait.
     *
     * Landscape giữ nguyên hoàn toàn.
     */
    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {

        return frame;
    }

    /*
     * Đọc giá trị 0...120 từ Preferences.
     */
    CGFloat targetHeight = SHAStatusBarHeight();

    /*
     * GIỮ NGUYÊN:
     *
     * x
     * width
     *
     * CHỈ THAY:
     *
     * y    = 0
     * height = targetHeight
     */
    frame.origin.y = 0.0;
    frame.size.height = targetHeight;

    return frame;
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        Class statusBarLayoutClass =
            objc_getClass(
                "SBMainDisplaySceneLayoutStatusBarView"
            );

        if (!statusBarLayoutClass) {
            return;
        }

        MSHookMessageEx(
            statusBarLayoutClass,
            @selector(_statusBarFrameForOrientation:),
            (IMP)hook_SHA_statusBarFrameForOrientation,
            (IMP *)&orig_SHA_statusBarFrameForOrientation
        );
    }
}
