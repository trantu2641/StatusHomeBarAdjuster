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

#pragma mark - Orientation

static BOOL SHAPortrait(void)
{
    UIScreen *screen = [UIScreen mainScreen];

    if (!screen) {
        return YES;
    }

    CGSize size = screen.bounds.size;

    return (size.height >= size.width);
}

#pragma mark - SBMainDisplaySceneLayoutStatusBarView

%group SHAStatusBarLayoutGroup

%hook SBMainDisplaySceneLayoutStatusBarView

/*
 * iOS 16.4 diagnostic:
 *
 * - statusBar:willAnimateFromHeight:toHeight:duration:animation:
 *
 * ĐÂY CHỈ LÀ CALLBACK THEO DÕI THAY ĐỔI HEIGHT.
 *
 * Không:
 * - sửa frame
 * - sửa bounds
 * - sửa center
 * - sửa transform
 * - gọi layoutSubviews
 * - sửa safeAreaInsets
 * - sửa UIStatusBar_Modern
 *
 * Mục tiêu của bản này là xác định rằng callback này có thể
 * được hook an toàn trên SpringBoard của máy.
 */

- (void)statusBar:(id)statusBar
willAnimateFromHeight:(CGFloat)fromHeight
      toHeight:(CGFloat)toHeight
      duration:(NSTimeInterval)duration
     animation:(id)animation
{
    /*
     * Không thay đổi geometry ở đây.
     *
     * Chỉ gọi implementation gốc.
     *
     * Việc đọc preference được giữ ở ngoài callback để tránh
     * can thiệp vào quá trình animation/layout của SpringBoard.
     */

    %orig(statusBar,
          fromHeight,
          toHeight,
          duration,
          animation);
}

%end

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        /*
         * Chỉ cài hook nếu class và selector thực sự tồn tại.
         */

        Class cls =
            NSClassFromString(
                @"SBMainDisplaySceneLayoutStatusBarView"
            );

        SEL selector =
            @selector(
                statusBar:
                willAnimateFromHeight:
                toHeight:
                duration:
                animation:
            );

        if (cls &&
            [cls instancesRespondToSelector:selector]) {

            %init(SHAStatusBarLayoutGroup);
        }
    }
}
