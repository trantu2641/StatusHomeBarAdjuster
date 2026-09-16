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

static CGFloat SHAReadHeight(NSString *key)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:@"com.congtu.statushomebaradjuster"];

    id value = [defaults objectForKey:key];

    /*
     PSEditTextCell có thể lưu giá trị dưới dạng NSString.
     Vì vậy phải hỗ trợ cả NSString và NSNumber.
    */

    CGFloat result = 30.0;

    if ([value isKindOfClass:[NSNumber class]]) {
        result = [value doubleValue];
    }
    else if ([value isKindOfClass:[NSString class]]) {
        result = [(NSString *)value doubleValue];
    }

    return SHAClampHeight(result);
}

static CGFloat SHAStatusBarHeight(void)
{
    return SHAReadHeight(@"StatusBarHeight");
}

static CGFloat SHAHomeBarHeight(void)
{
    return SHAReadHeight(@"HomeBarHeight");
}

#pragma mark - Orientation

static BOOL SHAPortrait(void)
{
    UIScreen *screen = UIScreen.mainScreen;

    if (!screen) {
        return YES;
    }

    CGSize size = screen.bounds.size;

    /*
     iPhone 11 Pro Max portrait:
     428 x 926

     Landscape:
     926 x 428

     Không dựa vào orientation API để tránh tác động
     tới các quá trình khởi động sớm của SpringBoard.
    */

    return size.height >= size.width;
}

#pragma mark - Status Bar

%group SHAStatusBarGroup

%hook UIStatusBar_Modern

/*
 * iOS 16.4:
 *
 * + _heightForStyle:orientation:forStatusBarFrame:inWindow:isAzulBLinked:
 *
 * Đây là method mà diagnostic đã xác nhận tồn tại.
 *
 * KHÔNG sửa frame.
 * KHÔNG gọi layoutSubviews.
 * KHÔNG di chuyển icon.
 * Chỉ thay giá trị height mà UIStatusBar tự sử dụng.
 */

+ (CGFloat)_heightForStyle:(NSInteger)style
                orientation:(NSInteger)orientation
       forStatusBarFrame:(CGRect)statusBarFrame
                  inWindow:(UIWindow *)window
             isAzulBLinked:(BOOL)isAzulBLinked
{
    /*
     Chỉ tác động portrait.
     Landscape trả nguyên giá trị hệ thống.
    */

    if (!SHAPortrait()) {
        return %orig;
    }

    CGFloat height = SHAStatusBarHeight();

    return height;
}

%end

%end

#pragma mark - Home Bar Content Area

%group SHAHomeBarGroup

%hook SBDeviceApplicationSceneView

/*
 * Đây là đường layout dành cho phần content của application scene.
 *
 * Không sửa SBHomeGrabberView.
 * Không sửa pill.
 * Không sửa gesture.
 * Không sửa frame của SpringBoard window.
 *
 * Chỉ yêu cầu content tránh vùng Home Bar.
 */

- (UIEdgeInsets)_contentContainerEdgeInsets
{
    UIEdgeInsets insets = %orig;

    if (!SHAPortrait()) {
        return insets;
    }

    CGFloat homeHeight = SHAHomeBarHeight();

    /*
     * Bottom edge của màn hình vẫn cố định.
     *
     * HomeBarHeight = 30:
     *     content tránh 30pt phía dưới.
     *
     * HomeBarHeight = 0:
     *     content được phép xuống sát đáy.
     *
     * HomeBarHeight = 120:
     *     content tránh 120pt phía dưới.
     */

    insets.bottom = homeHeight;

    return insets;
}

%end

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        /*
         * Không init hook tùy tiện.
         * Kiểm tra class trước khi khởi tạo từng group.
         */

        Class statusModern =
            NSClassFromString(@"UIStatusBar_Modern");

        if (statusModern &&
            [statusModern respondsToSelector:
                @selector(_heightForStyle:orientation:forStatusBarFrame:inWindow:isAzulBLinked:)]) {

            %init(SHAStatusBarGroup);

        }

        Class applicationSceneView =
            NSClassFromString(@"SBDeviceApplicationSceneView");

        if (applicationSceneView &&
            [applicationSceneView instancesRespondToSelector:
                @selector(_contentContainerEdgeInsets)]) {

            %init(SHAHomeBarGroup);

        }
    }
}
