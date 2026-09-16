#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>

#define SHA_STATUS_BAR_PREFS @"StatusBarHeight"

static CGFloat SHAClamp(CGFloat value, CGFloat minValue, CGFloat maxValue) {
    if (value < minValue) {
        return minValue;
    }

    if (value > maxValue) {
        return maxValue;
    }

    return value;
}

static CGFloat SHAStatusBarHeight(void) {
    id value = [[NSUserDefaults standardUserDefaults]
        objectForKey:SHA_STATUS_BAR_PREFS];

    CGFloat height = 30.0;

    if ([value isKindOfClass:[NSNumber class]]) {
        height = [(NSNumber *)value doubleValue];
    }
    else if ([value isKindOfClass:[NSString class]]) {
        height = [(NSString *)value doubleValue];
    }

    /*
     * Giá trị Settings là CHIỀU CAO THỰC TẾ:
     *
     * 0   = 0 px
     * 10  = 10 px
     * 20  = 20 px
     * 30  = 30 px
     * 49  = 49 px
     * 120 = 120 px
     */
    return SHAClamp(height, 0.0, 120.0);
}


/*
 * Dùng UIView * thay vì _UIStatusBar *
 * để tránh lỗi kiểu dữ liệu khi gọi từ %hook.
 */
static void SHAApplyStatusBarTransform(id statusBarObject) {
    UIView *statusBar = (UIView *)statusBarObject;

    if (!statusBar) {
        return;
    }

    UIWindow *window = statusBar.window;

    /*
     * Chỉ tác động Portrait.
     * Landscape hoàn toàn giữ nguyên.
     */
    UIInterfaceOrientation orientation =
        UIInterfaceOrientationPortrait;

    if (window.windowScene) {
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
     * Giá trị nhập là chiều cao trực tiếp.
     *
     * Không còn cơ chế:
     *     targetHeight = originalHeight + offset
     *
     * nữa.
     */
    CGFloat scaleY = targetHeight / originalHeight;

    /*
     * Cho phép scale = 0 khi Settings = 0.
     */
    scaleY = SHAClamp(
        scaleY,
        0.0,
        120.0 / originalHeight
    );

    /*
     * Giữ cơ chế transform của bản 1.1.5.
     *
     * Không thay đổi frame.
     * Không thay đổi bounds.
     * Không đụng Home Bar.
     */
    statusBar.layer.transform =
        CATransform3DMakeScale(
            1.0,
            scaleY,
            1.0
        );
}


/*
 * Tìm _UIStatusBar trong các window hiện tại.
 *
 * Dùng UIWindowScene.windows thay cho
 * UIApplication.windows để tránh warning/deprecated
 * trên iOS 15+.
 */
static void SHAPapplyToAllStatusBars(void) {
    UIApplication *application =
        [UIApplication sharedApplication];

    for (UIScene *scene in application.connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        for (UIWindow *window in windowScene.windows) {

            UIView *rootView = window.rootViewController.view;

            if (!rootView) {
                continue;
            }

            NSMutableArray<UIView *> *queue =
                [NSMutableArray arrayWithObject:rootView];

            while (queue.count > 0) {

                UIView *view = queue.firstObject;
                [queue removeObjectAtIndex:0];

                Class statusBarClass =
                    NSClassFromString(@"_UIStatusBar");

                if (statusBarClass &&
                    [view isKindOfClass:statusBarClass]) {

                    SHAApplyStatusBarTransform(view);
                }

                for (UIView *subview in view.subviews) {
                    [queue addObject:subview];
                }
            }
        }
    }
}


/*
 * ================================
 * STATUS BAR
 * ================================
 */

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
 * ================================
 * HOME BAR
 * ================================
 *
 * KHÔNG thay đổi gì ở Home Bar.
 *
 * Các hook này chỉ giữ nguyên hành vi gốc.
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


/*
 * ================================
 * PREFERENCE CHANGE
 * ================================
 */

static void SHAStatusBarPreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
) {
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SHAPapplyToAllStatusBars();
        }
    );
}


/*
 * ================================
 * CONSTRUCTOR
 * ================================
 */

%ctor {
    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];

    /*
     * Chỉ chạy trong SpringBoard.
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
