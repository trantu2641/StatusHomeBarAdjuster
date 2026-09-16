#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString * const kSHAPrefDomain = @"com.congtu.statushomebaradjuster";
static NSString * const kSHAStatusKey  = @"StatusBarHeight";
static NSString * const kSHAHomeKey    = @"HomeBarHeight";

#pragma mark - Preferences

static CGFloat SHAReadValue(NSString *key, CGFloat fallback) {
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:kSHAPrefDomain];

    id obj = [defaults objectForKey:key];

    CGFloat value = fallback;

    if ([obj isKindOfClass:[NSNumber class]]) {
        value = [(NSNumber *)obj doubleValue];
    } else if ([obj isKindOfClass:[NSString class]]) {
        value = [(NSString *)obj doubleValue];
    } else {
        return fallback;
    }

    if (isnan(value) || isinf(value))
        return fallback;

    return MAX(0.0, MIN(120.0, value));
}

static CGFloat SHAStatusHeight(void) {
    return SHAReadValue(kSHAStatusKey, 30.0);
}

static CGFloat SHAHomeHeight(void) {
    return SHAReadValue(kSHAHomeKey, 30.0);
}

#pragma mark - Orientation

static BOOL SHAPortrait(void) {
    UIApplication *app = UIApplication.sharedApplication;

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIInterfaceOrientation orientation =
            ((UIWindowScene *)scene).interfaceOrientation;

        if (orientation == UIInterfaceOrientationPortrait ||
            orientation == UIInterfaceOrientationPortraitUpsideDown) {
            return YES;
        }

        if (orientation == UIInterfaceOrientationLandscapeLeft ||
            orientation == UIInterfaceOrientationLandscapeRight) {
            return NO;
        }
    }

    return YES;
}

static BOOL SHAPortraitOrientation(UIInterfaceOrientation orientation) {
    return orientation == UIInterfaceOrientationPortrait ||
           orientation == UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Frame helpers

static CGRect SHAStatusFrame(CGRect frame, CGFloat height) {
    frame.origin.y = 0.0;
    frame.size.height = height;
    return frame;
}

static UIEdgeInsets SHAReplaceTop(UIEdgeInsets insets, CGFloat top) {
    insets.top = top;
    return insets;
}

static UIEdgeInsets SHAReplaceBottom(UIEdgeInsets insets, CGFloat bottom) {
    insets.bottom = bottom;
    return insets;
}

#pragma mark - UIApplicationSceneSettings

%hook UIApplicationSceneSettings

- (CGFloat)statusBarHeight {
    if (SHAPortrait())
        return SHAStatusHeight();

    return %orig;
}

- (CGFloat)defaultStatusBarHeightForOrientation:(UIInterfaceOrientation)orientation {
    if (SHAPortraitOrientation(orientation))
        return SHAStatusHeight();

    return %orig;
}

- (UIEdgeInsets)safeAreaInsetsPortrait {
    UIEdgeInsets result = %orig;

    if (SHAPortrait())
        result = SHAReplaceTop(result, SHAStatusHeight());

    return result;
}

- (UIEdgeInsets)safeAreaInsetsPortraitUpsideDown {
    UIEdgeInsets result = %orig;

    if (SHAPortrait())
        result = SHAReplaceTop(result, SHAStatusHeight());

    return result;
}

- (CGFloat)homeAffordanceOverlayAllowance {
    if (SHAPortrait())
        return SHAHomeHeight();

    return %orig;
}

- (CGRect)statusBarAvoidanceFrame {
    CGRect result = %orig;

    if (SHAPortrait()) {
        result.origin.y = 0.0;
        result.size.height = SHAStatusHeight();
    }

    return result;
}

%end

#pragma mark - SBMainDisplaySceneLayoutStatusBarView

%hook SBMainDisplaySceneLayoutStatusBarView

- (CGRect)_statusBarFrameForOrientation:(UIInterfaceOrientation)orientation {
    CGRect result = %orig;

    if (SHAPortraitOrientation(orientation)) {
        result = SHAStatusFrame(result, SHAStatusHeight());
    }

    return result;
}

- (CGRect)_statusBarAvoidanceFrame {
    CGRect result = %orig;

    if (SHAPortrait()) {
        result.origin.y = 0.0;
        result.size.height = SHAStatusHeight();
    }

    return result;
}

- (void)_applyStatusBarAvoidanceFrame:(CGRect)frame
                 toSceneWithIdentifier:(NSString *)identifier {

    if (SHAPortrait()) {
        CGRect modified = frame;

        modified.origin.y = 0.0;
        modified.size.height = SHAStatusHeight();

        %orig(modified, identifier);
        return;
    }

    %orig;
}

- (void)sceneWithIdentifier:(NSString *)identifier
didChangeStatusBarAvoidanceFrameTo:(CGRect)frame {

    if (SHAPortrait()) {
        CGRect modified = frame;

        modified.origin.y = 0.0;
        modified.size.height = SHAStatusHeight();

        %orig(identifier, modified);
        return;
    }

    %orig;
}

- (void)statusBar:(id)statusBar
didAnimateFromHeight:(CGFloat)oldHeight
          toHeight:(CGFloat)newHeight
         animation:(id)animation {

    if (SHAPortrait()) {
        CGFloat height = SHAStatusHeight();

        %orig(statusBar, oldHeight, height, animation);
        return;
    }

    %orig;
}

- (void)statusBar:(id)statusBar
willAnimateFromHeight:(CGFloat)oldHeight
           toHeight:(CGFloat)newHeight
          duration:(CGFloat)duration
          animation:(id)animation {

    if (SHAPortrait()) {
        CGFloat height = SHAStatusHeight();

        %orig(statusBar, oldHeight, height, duration, animation);
        return;
    }

    %orig;
}

- (void)_layoutStatusBarForOrientation:(UIInterfaceOrientation)orientation {
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    CGFloat height = SHAStatusHeight();

    /*
     * SBMainDisplaySceneLayoutStatusBarView là private class.
     * Ép về UIView trước khi truy cập subviews để tránh
     * lỗi "forward class object".
     */
    UIView *statusContainer = (UIView *)self;

    for (UIView *view in statusContainer.subviews) {
        NSString *className = NSStringFromClass([view class]);

        if ([className containsString:@"UIStatusBar"]) {
            CGRect frame = view.frame;

            frame.origin.y = 0.0;
            frame.size.height = height;

            view.frame = frame;
        }
    }
}

- (void)layoutStatusBarForSpringBoardRotationToOrientation:(UIInterfaceOrientation)orientation {
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    CGFloat height = SHAStatusHeight();

    UIView *statusContainer = (UIView *)self;

    for (UIView *view in statusContainer.subviews) {
        NSString *className = NSStringFromClass([view class]);

        if ([className containsString:@"UIStatusBar"]) {
            CGRect frame = view.frame;

            frame.origin.y = 0.0;
            frame.size.height = height;

            view.frame = frame;
        }
    }
}

%end

#pragma mark - _UIStatusBar

%hook _UIStatusBar

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                   orientation:(UIInterfaceOrientation)orientation
                                  onLockScreen:(BOOL)lockScreen
                                isAzulBLinked:(BOOL)azul {

    CGSize result =
        %orig(screen, orientation, lockScreen, azul);

    if (SHAPortraitOrientation(orientation))
        result.height = SHAStatusHeight();

    return result;
}

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                   orientation:(UIInterfaceOrientation)orientation
                                  onLockScreen:(BOOL)lockScreen {

    CGSize result =
        %orig(screen, orientation, lockScreen);

    if (SHAPortraitOrientation(orientation))
        result.height = SHAStatusHeight();

    return result;
}

- (CGSize)intrinsicContentSize {
    CGSize result = %orig;

    if (SHAPortrait())
        result.height = SHAStatusHeight();

    return result;
}

- (void)layoutSubviews {
    %orig;

    if (!SHAPortrait())
        return;

    CGFloat height = SHAStatusHeight();

    /*
     * _UIStatusBar là forward-declared private class,
     * nên cast sang UIView trước khi truy cập frame.
     */
    UIView *statusBarView = (UIView *)self;

    CGRect frame = statusBarView.frame;

    if (fabs(frame.size.height - height) > 0.1) {
        frame.origin.y = 0.0;
        frame.size.height = height;

        statusBarView.frame = frame;
    }
}

- (void)setAvoidanceFrame:(CGRect)frame {
    if (SHAPortrait()) {
        CGRect modified = frame;

        modified.origin.y = 0.0;
        modified.size.height = SHAStatusHeight();

        %orig(modified);
        return;
    }

    %orig;
}

- (void)setAvoidanceFrame:(CGRect)frame
       animationSettings:(id)settings
                 options:(NSUInteger)options {

    if (SHAPortrait()) {
        CGRect modified = frame;

        modified.origin.y = 0.0;
        modified.size.height = SHAStatusHeight();

        %orig(modified, settings, options);
        return;
    }

    %orig;
}

%end

#pragma mark - SBDeviceApplicationSceneView

%hook SBDeviceApplicationSceneView

- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets result = %orig;

    if (SHAPortrait())
        result = SHAReplaceBottom(result, SHAHomeHeight());

    return result;
}

- (void)safeAreaInsetsDidChange {
    %orig;

    if (!SHAPortrait())
        return;

    /*
     * Cast sang UIView để compiler không coi self
     * là forward-declared private class.
     */
    UIView *sceneView = (UIView *)self;

    [sceneView setNeedsLayout];
}

%end

#pragma mark - SBHomeGrabberView

%hook SBHomeGrabberView

/*
 * Không sửa grabberFrameForBounds:
 *
 * Đây là phần tính frame của Home Grabber/Pill.
 * Yêu cầu của tweak là thay vùng Home Bar chứ không
 * scale hoặc di chuyển pill.
 */

- (void)layoutSubviews {
    %orig;
}

%end

#pragma mark - SBHomeGrabberRotationView

%hook SBHomeGrabberRotationView

- (void)layoutSubviews {
    %orig;
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        NSString *bundleID =
            NSBundle.mainBundle.bundleIdentifier;

        if ([bundleID isEqualToString:@"com.apple.springboard"]) {
            %init;
        }
    }
}
