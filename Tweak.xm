#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define SHA_STATUS_BAR_PREFS @"StatusBarHeight"

static CGFloat SHAClamp(CGFloat value, CGFloat min, CGFloat max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

static CGFloat SHAStatusBarHeight(void) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:SHA_STATUS_BAR_PREFS];

    CGFloat height = 30.0;

    if ([value isKindOfClass:[NSNumber class]]) {
        height = [(NSNumber *)value doubleValue];
    } else if ([value isKindOfClass:[NSString class]]) {
        height = [(NSString *)value doubleValue];
    }

    /*
     * Người dùng nhập trực tiếp chiều cao:
     *
     * 0   = ẩn
     * 30  = mặc định
     * 49  = chiều cao hệ thống hiện tại trên iPhone 11 Pro Max
     * 120 = tối đa
     */
    return SHAClamp(height, 0.0, 120.0);
}

static void SHAApplyStatusBarTransform(UIView *statusBar) {
    if (!statusBar) {
        return;
    }

    /*
     * Chỉ xử lý Portrait.
     * Landscape giữ nguyên hoàn toàn.
     */
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;

    UIWindow *window = statusBar.window;
    if (window) {
        orientation = window.windowScene.interfaceOrientation;
    }

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {
        statusBar.layer.transform = CATransform3DIdentity;
        return;
    }

    CGFloat originalHeight = statusBar.bounds.size.height;

    if (originalHeight <= 0.0) {
        originalHeight = statusBar.frame.size.height;
    }

    if (originalHeight <= 0.0) {
        return;
    }

    CGFloat targetHeight = SHAStatusBarHeight();

    /*
     * 1.1.5 vốn dùng transform theo chiều Y.
     *
     * Điểm quan trọng ở bản này:
     *
     *     targetHeight = giá trị người dùng nhập
     *
     * KHÔNG còn:
     *
     *     targetHeight = originalHeight + offset
     *
     * Vì vậy Settings thực sự là 0–120 px.
     */
    CGFloat scaleY = targetHeight / originalHeight;

    scaleY = SHAClamp(scaleY, 0.0, 120.0 / originalHeight);

    /*
     * Giữ nguyên cơ chế transform của bản 1.1.5.
     * Không đụng tới Home Bar.
     */
    CATransform3D transform = CATransform3DMakeScale(
        1.0,
        scaleY,
        1.0
    );

    statusBar.layer.transform = transform;
}

static void SHAResetStatusBarTransform(UIView *statusBar) {
    if (!statusBar) {
        return;
    }

    statusBar.layer.transform = CATransform3DIdentity;
}


%hook _UIStatusBar

- (void)didMoveToWindow {
    %orig;

    SHAApplyStatusBarTransform(self);
}

- (void)layoutSubviews {
    %orig;

    SHAApplyStatusBarTransform(self);
}

%end


/*
 * Giữ nguyên các view liên quan Home Bar.
 * Không scale, không đổi frame, không đổi pill.
 *
 * Chúng chỉ được hook để đảm bảo bản sửa Status Bar
 * không can thiệp vào Home Bar.
 */

%hook MTLumaDodgePillView

- (void)didMoveToWindow {
    %orig;
}

- (void)layoutSubviews {
    %orig;
}

%end


%hook MTStaticColorPillView

- (void)didMoveToWindow {
    %orig;
}

- (void)layoutSubviews {
    %orig;
}

%end


%hook SBHomeGrabberView

- (void)didMoveToWindow {
    %orig;
}

- (void)layoutSubviews {
    %orig;
}

%end


static void SHAStatusBarPreferencesChanged(CFNotificationCenterRef center,
                                            void *observer,
                                            CFStringRef name,
                                            const void *object,
                                            CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            [window.subviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
                if ([view isKindOfClass:NSClassFromString(@"_UIStatusBar")]) {
                    SHAApplyStatusBarTransform(view);
                }

                for (UIView *subview in view.subviews) {
                    if ([subview isKindOfClass:NSClassFromString(@"_UIStatusBar")]) {
                        SHAApplyStatusBarTransform(subview);
                    }
                }
            }];
        }
    });
}


%ctor {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

    /*
     * Chỉ inject SpringBoard.
     * Không inject app bên thứ ba.
     */
    if (![bundleID isEqualToString:@"com.apple.springboard"]) {
        return;
    }

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        SHAStatusBarPreferencesChanged,
        CFSTR("com.congtu.statushomebaradjuster/preferenceschanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );

    %init;
}
