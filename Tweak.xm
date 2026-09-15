#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma mark - Preferences

static NSString * const kStatusBarKey = @"StatusBarHeight";
static NSString * const kHomeBarKey   = @"HomeBarHeight";

static CGFloat SHAClamp(CGFloat value)
{
    if (value < 0.0)
        return 0.0;

    if (value > 120.0)
        return 120.0;

    return value;
}

static CGFloat SHAReadValue(NSString *key, CGFloat fallback)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    id value =
        [defaults objectForKey:key];

    CGFloat result = fallback;

    if ([value isKindOfClass:[NSNumber class]]) {

        result = [(NSNumber *)value doubleValue];

    } else if ([value isKindOfClass:[NSString class]]) {

        result = [(NSString *)value doubleValue];
    }

    return SHAClamp(result);
}

static CGFloat SHAStatusHeight(void)
{
    return SHAReadValue(kStatusBarKey, 30.0);
}

static CGFloat SHAHomeHeight(void)
{
    return SHAReadValue(kHomeBarKey, 30.0);
}

#pragma mark - Orientation

static BOOL SHAPortraitOrientation(NSInteger orientation)
{
    return
        orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown;
}

static BOOL SHAPortrait(void)
{
    /*
     * Không dùng UIApplication.statusBarOrientation vì
     * iOS 16 SDK đánh dấu deprecated và Theos đang dùng
     * -Werror.
     */

    UIWindowScene *scene = nil;

    for (UIScene *candidate in
         [UIApplication sharedApplication].connectedScenes) {

        if ([candidate isKindOfClass:[UIWindowScene class]]) {

            UIWindowScene *windowScene =
                (UIWindowScene *)candidate;

            if (windowScene.activationState !=
                UISceneActivationStateUnattached) {

                scene = windowScene;
                break;
            }
        }
    }

    if (scene) {

        UIInterfaceOrientation orientation =
            scene.interfaceOrientation;

        if (orientation != UIInterfaceOrientationUnknown)
            return SHAPortraitOrientation(orientation);
    }

    /*
     * SpringBoard portrait mặc định cho thiết bị này.
     */
    return YES;
}

#pragma mark - Status Bar

%hook SBMainDisplaySceneLayoutStatusBarView

- (CGRect)_statusBarFrameForOrientation:(NSInteger)orientation
{
    CGRect frame =
        %orig(orientation);

    if (!SHAPortraitOrientation(orientation))
        return frame;

    CGFloat height =
        SHAStatusHeight();

    /*
     * TOP cố định.
     * BOTTOM thay đổi theo height.
     */
    frame.origin.y = 0.0;
    frame.size.height = height;

    return frame;
}

- (void)_layoutStatusBarForOrientation:(NSInteger)orientation
{
    /*
     * Gọi layout gốc trước.
     */
    %orig(orientation);

    if (!SHAPortraitOrientation(orientation))
        return;

    /*
     * Dùng id để tránh lỗi forward declaration.
     */
    id receiver = (id)self;

    @try {

        SEL selector =
            NSSelectorFromString(
                @"_statusBarFrameForOrientation:"
            );

        if (![receiver respondsToSelector:selector])
            return;

        CGRect frame =
            ((CGRect (*)(id, SEL, NSInteger))
                objc_msgSend)(
                    receiver,
                    selector,
                    orientation
                );

        /*
         * Không resize SBMainDisplaySceneLayoutStatusBarView.
         * Diagnostic đã chứng minh nó là 428x926 full-screen.
         *
         * Chỉ tìm status-bar child thật sự.
         */
        UIView *root =
            (UIView *)receiver;

        for (UIView *subview in root.subviews) {

            NSString *className =
                NSStringFromClass([subview class]);

            if ([className isEqualToString:@"_UIStatusBar"] ||
                [className isEqualToString:@"UIStatusBar_Modern"]) {

                CGRect childFrame =
                    subview.frame;

                childFrame.origin.y = 0.0;
                childFrame.size.height =
                    frame.size.height;

                subview.frame =
                    childFrame;
            }
        }
    }
    @catch (__unused NSException *exception) {
    }
}

- (CGRect)_statusBarAvoidanceFrame
{
    CGRect frame =
        %orig;

    if (!SHAPortrait())
        return frame;

    frame.origin.y = 0.0;
    frame.size.height =
        SHAStatusHeight();

    return frame;
}

%end

#pragma mark - UIKit Status Bar

%hook _UIStatusBar

- (CGSize)intrinsicContentSize
{
    CGSize size =
        %orig;

    if (!SHAPortrait())
        return size;

    size.height =
        SHAStatusHeight();

    return size;
}

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                    orientation:(NSInteger)orientation
                                  onLockScreen:(BOOL)lockScreen
{
    CGSize size =
        %orig(
            screen,
            orientation,
            lockScreen
        );

    if (!SHAPortraitOrientation(orientation))
        return size;

    size.height =
        SHAStatusHeight();

    return size;
}

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                    orientation:(NSInteger)orientation
                                  onLockScreen:(BOOL)lockScreen
                                  isAzulBLinked:(BOOL)isAzulBLinked
{
    CGSize size =
        %orig(
            screen,
            orientation,
            lockScreen,
            isAzulBLinked
        );

    if (!SHAPortraitOrientation(orientation))
        return size;

    size.height =
        SHAStatusHeight();

    return size;
}

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    /*
     * self là private class forward declaration,
     * nên cast sang UIView trước khi dùng frame.
     */
    UIView *statusBar =
        (UIView *)(id)self;

    CGRect frame =
        statusBar.frame;

    frame.origin.y = 0.0;
    frame.size.height =
        SHAStatusHeight();

    statusBar.frame =
        frame;
}

%end

#pragma mark - Scene Settings

%hook UIApplicationSceneSettings

- (CGFloat)statusBarHeight
{
    if (!SHAPortrait())
        return %orig;

    return SHAStatusHeight();
}

- (CGFloat)defaultStatusBarHeightForOrientation:(NSInteger)orientation
{
    CGFloat value =
        %orig(orientation);

    if (!SHAPortraitOrientation(orientation))
        return value;

    return SHAStatusHeight();
}

- (UIEdgeInsets)safeAreaInsetsPortrait
{
    UIEdgeInsets insets =
        %orig;

    insets.top =
        SHAStatusHeight();

    return insets;
}

- (UIEdgeInsets)safeAreaInsetsPortraitUpsideDown
{
    UIEdgeInsets insets =
        %orig;

    insets.top =
        SHAStatusHeight();

    return insets;
}

- (CGRect)statusBarAvoidanceFrame
{
    CGRect frame =
        %orig;

    if (!SHAPortrait())
        return frame;

    frame.origin.y = 0.0;
    frame.size.height =
        SHAStatusHeight();

    return frame;
}

#pragma mark - Home Bar allowance

- (CGFloat)homeAffordanceOverlayAllowance
{
    if (!SHAPortrait())
        return %orig;

    return SHAHomeHeight();
}

%end

#pragma mark - Home Bar

%hook SBHomeGrabberView

- (CGRect)grabberFrameForBounds:(CGRect)bounds
{
    CGRect frame =
        %orig(bounds);

    if (!SHAPortrait())
        return frame;

    CGFloat requested =
        SHAHomeHeight();

    /*
     * Không thay đổi chiều rộng của grabber.
     *
     * Home Bar giữ BOTTOM tại đáy màn hình.
     */
    if (requested <= 0.0) {

        frame.origin.y =
            CGRectGetHeight(bounds);

        frame.size.height = 0.0;

    } else {

        /*
         * Đây là vùng hình học Home Bar.
         * Không scale transform.
         */
        frame.origin.y =
            CGRectGetHeight(bounds) -
            requested;

        frame.size.height =
            requested;
    }

    return frame;
}

%end

#pragma mark - Home Rotation Wrapper

%hook SBHomeGrabberRotationView

- (void)layoutSubviews
{
    /*
     * RotationView là 428x926 full-screen wrapper.
     *
     * Tuyệt đối không resize nó.
     */
    %orig;
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        NSString *bundleID =
            [[NSBundle mainBundle]
                bundleIdentifier];

        if (![bundleID
            isEqualToString:@"com.apple.springboard"]) {

            return;
        }

        %init;
    }
}
