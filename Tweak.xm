#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#pragma mark - Preferences

static CGFloat SHAClampHeight(CGFloat value)
{
    if (!isfinite(value)) {
        return 30.0;
    }

    if (value < 0.0) {
        return 0.0;
    }

    if (value > 120.0) {
        return 120.0;
    }

    return value;
}

static CGFloat SHAStatusBarHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:@"com.congtu.statushomebaradjuster"];

    id value = [defaults objectForKey:@"StatusBarHeight"];

    CGFloat height = 30.0;

    if ([value isKindOfClass:[NSNumber class]]) {
        height = [(NSNumber *)value doubleValue];
    }
    else if ([value isKindOfClass:[NSString class]]) {
        height = [(NSString *)value doubleValue];
    }

    return SHAClampHeight(height);
}

#pragma mark - UIApplicationSceneSettings

%group SHAStatusBarDefaultHeight

%hook UIApplicationSceneSettings

/*
 * Runtime iOS 16.4 của máy:
 *
 * - defaultStatusBarHeightForOrientation:
 *
 * Signature:
 *
 * [d24@0:8q16]
 *
 * return: double
 * arg: UIInterfaceOrientation
 *
 * Đây là bản thử nghiệm chỉ thay đổi giá trị DEFAULT
 * mà UIApplicationSceneSettings cung cấp cho Status Bar.
 *
 * Không sửa:
 * - frame
 * - bounds
 * - transform
 * - layoutSubviews
 * - safeAreaInsets
 * - UIStatusBar_Modern
 * - SBMainDisplaySceneLayoutStatusBarView
 * - Home Bar
 */

- (CGFloat)defaultStatusBarHeightForOrientation:(NSInteger)orientation
{
    /*
     * Chỉ thay đổi Portrait.
     *
     * UIInterfaceOrientation:
     *
     * 1 = Portrait
     * 2 = PortraitUpsideDown
     * 3 = LandscapeLeft
     * 4 = LandscapeRight
     */

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {

        return %orig;
    }

    CGFloat height = SHAStatusBarHeight();

    return height;
}

%end

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        Class cls =
            NSClassFromString(@"UIApplicationSceneSettings");

        SEL selector =
            @selector(defaultStatusBarHeightForOrientation:);

        /*
         * Chỉ hook khi method tồn tại đúng trên runtime.
         */

        if (cls &&
            [cls instancesRespondToSelector:selector]) {

            %init(SHAStatusBarDefaultHeight);
        }
    }
}
