#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <substrate.h>

#pragma mark - Preferences

static NSString * const SHA_DOMAIN = @"com.congtu.statushomebaradjuster";
static NSString * const SHA_STATUS_KEY = @"StatusBarHeight";

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
            CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &v);
            height = (CGFloat)v;
        }
        else if (CFGetTypeID(value) == CFStringGetTypeID()) {
            height = (CGFloat)CFStringGetDoubleValue((CFStringRef)value);
        }

        CFRelease(value);
    }

    if (height < 0.0)
        height = 0.0;

    if (height > 120.0)
        height = 120.0;

    return height;
}

static BOOL SHAPortrait(void)
{
    UIInterfaceOrientation orientation =
        [UIApplication sharedApplication].statusBarOrientation;

    return orientation == UIInterfaceOrientationPortrait ||
           orientation == UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - SBMainDisplaySceneLayoutStatusBarView

@interface SBMainDisplaySceneLayoutStatusBarView : UIView
- (CGRect)_statusBarFrameForOrientation:(NSInteger)orientation;
@end

static CGRect (*orig_SBMSLSBV_statusBarFrameForOrientation)
    (SBMainDisplaySceneLayoutStatusBarView *, SEL, NSInteger);

static CGRect hook_SBMSLSBV_statusBarFrameForOrientation(
    SBMainDisplaySceneLayoutStatusBarView *self,
    SEL _cmd,
    NSInteger orientation)
{
    CGRect frame =
        orig_SBMSLSBV_statusBarFrameForOrientation(
            self,
            _cmd,
            orientation
        );

    /*
     * Chỉ can thiệp Portrait.
     * Landscape trả nguyên frame hệ thống.
     */
    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {
        return frame;
    }

    CGFloat targetHeight = SHAStatusBarHeight();

    /*
     * Mép trên cố định.
     *
     * Không scale.
     * Không thay width.
     * Không thay x.
     */
    frame.origin.y = 0.0;
    frame.size.height = targetHeight;

    return frame;
}

#pragma mark - Initialization

%ctor
{
    @autoreleasepool {

        Class cls =
            objc_getClass(
                "SBMainDisplaySceneLayoutStatusBarView"
            );

        if (cls) {
            MSHookMessageEx(
                cls,
                @selector(_statusBarFrameForOrientation:),
                (IMP)hook_SBMSLSBV_statusBarFrameForOrientation,
                (IMP *)&orig_SBMSLSBV_statusBarFrameForOrientation
            );
        }
    }
}
