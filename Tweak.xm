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

%group SHAUIApplicationSceneSettings

%hook UIApplicationSceneSettings

/*
 * iOS 16.4 diagnostic:
 *
 * - statusBarHeight
 *
 * Chỉ thay đổi giá trị height được Settings cung cấp.
 *
 * Không:
 * - sửa frame
 * - sửa bounds
 * - sửa safeAreaInsets
 * - gọi layoutSubviews
 * - hook UIStatusBar
 * - hook SpringBoard window
 */

- (CGFloat)statusBarHeight
{
    /*
     * Chỉ áp dụng portrait.
     *
     * Không dùng UIScreen orientation API ở đây.
     * UIApplicationSceneSettings là object của scene,
     * nên kiểm tra kích thước scene/window nếu có thể.
     */

    CGFloat original = %orig;

    /*
     * Bản đầu tiên vẫn giữ nguyên nếu giá trị preference
     * chưa hợp lệ.
     */

    CGFloat customHeight = SHAStatusBarHeight();

    if (!isfinite(customHeight)) {
        return original;
    }

    return customHeight;
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
            @selector(statusBarHeight);

        /*
         * Chỉ cài hook nếu class và instance method tồn tại.
         */

        if (cls &&
            [cls instancesRespondToSelector:selector]) {

            %init(SHAUIApplicationSceneSettings);
        }
    }
}
