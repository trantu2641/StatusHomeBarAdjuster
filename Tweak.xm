#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#pragma mark - Constants

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

#pragma mark - Preferences

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

#pragma mark - Status Bar

%group SHAStatusBarOnly

%hook UIStatusBar_Modern

/*
 * iOS 16.4 diagnostic đã xác nhận method này tồn tại:
 *
 * + _heightForStyle:orientation:forStatusBarFrame:inWindow:isAzulBLinked:
 *
 * Bản test này CHỈ thay đổi giá trị height.
 *
 * Không:
 * - sửa frame
 * - sửa bounds
 * - sửa center
 * - sửa transform
 * - gọi layoutSubviews
 * - sửa safe area
 * - sửa icon
 */

+ (CGFloat)_heightForStyle:(NSInteger)style
                orientation:(NSInteger)orientation
       forStatusBarFrame:(CGRect)statusBarFrame
                  inWindow:(UIWindow *)window
             isAzulBLinked:(BOOL)isAzulBLinked
{
    if (!SHAPortrait()) {
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

        /*
         * Chỉ cài hook nếu class và method thực sự tồn tại.
         *
         * Nếu không tồn tại:
         *     tweak không làm gì cả.
         */

        Class cls = NSClassFromString(@"UIStatusBar_Modern");

        SEL selector =
            @selector(_heightForStyle:
                      orientation:
                      forStatusBarFrame:
                      inWindow:
                      isAzulBLinked:);

        if (cls &&
            [cls respondsToSelector:selector]) {

            %init(SHAStatusBarOnly);
        }
    }
}
