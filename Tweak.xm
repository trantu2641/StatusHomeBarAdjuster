#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - Preferences

static NSString * const kSHAPrefDomain = @"com.congtu.statushomebaradjuster";
static NSString * const kSHAStatusKey  = @"StatusBarHeight";
static NSString * const kSHAHomeKey    = @"HomeBarHeight";

static CGFloat SHAReadValue(NSString *key, CGFloat fallback) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kSHAPrefDomain];

    id obj = [defaults objectForKey:key];

    if ([obj isKindOfClass:[NSNumber class]]) {
        CGFloat value = [obj doubleValue];

        if (isnan(value) || isinf(value))
            return fallback;

        return MAX(0.0, MIN(120.0, value));
    }

    if ([obj isKindOfClass:[NSString class]]) {
        CGFloat value = [(NSString *)obj doubleValue];

        if (isnan(value) || isinf(value))
            return fallback;

        return MAX(0.0, MIN(120.0, value));
    }

    return fallback;
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

        UIInterfaceOrientation o =
            ((UIWindowScene *)scene).interfaceOrientation;

        if (o == UIInterfaceOrientationPortrait ||
            o == UIInterfaceOrientationPortraitUpsideDown) {
            return YES;
        }

        if (o == UIInterfaceOrientationLandscapeLeft ||
            o == UIInterfaceOrientationLandscapeRight) {
            return NO;
        }
    }

    return YES;
}

static BOOL SHAPortraitOrientation(UIInterfaceOrientation o) {
    return o == UIInterfaceOrientationPortrait ||
           o == UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Helpers

static CGRect SHAStatusFrame(CGRect original, CGFloat height) {
    CGRect r = original;

    r.origin.y = 0.0;
    r.size.height = height;

    return r;
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
        CGFloat h = SHAStatusHeight();

        %orig(statusBar, oldHeight, h, animation);
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
        CGFloat h = SHAStatusHeight();

        %orig(statusBar, oldHeight, h, duration, animation);
        return;
    }

    %orig;
}

- (void)_layoutStatusBarForOrientation:(UIInterfaceOrientation)orientation {
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    CGFloat h = SHAStatusHeight();

    NSArray *children = self.subviews;

    for (UIView *view in children) {
        NSString *name = NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {
            CGRect frame = view.frame;

            frame.origin.y = 0.0;
            frame.size.height = h;

            view.frame = frame;
        }
    }
}

- (void)layoutStatusBarForSpringBoardRotationToOrientation:(UIInterfaceOrientation)orientation {
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    CGFloat h = SHAStatusHeight();

    for (UIView *view in self.subviews) {
        NSString *name = NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {
            CGRect frame = view.frame;

            frame.origin.y = 0.0;
            frame.size.height = h;

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

    if (SHAPortraitOrientation(orientation)) {
        result.height = SHAStatusHeight();
    }

    return result;
}

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                   orientation:(UIInterfaceOrientation)orientation
                                  onLockScreen:(BOOL)lockScreen {

    CGSize result =
        %orig(screen, orientation, lockScreen);

    if (SHAPortraitOrientation(orientation)) {
        result.height = SHAStatusHeight();
    }

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

    CGFloat h = SHAStatusHeight();

    CGRect frame = self.frame;

    if (fabs(frame.size.height - h) > 0.1) {
        frame.origin.y = 0.0;
        frame.size.height = h;

        self.frame = frame;
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
//
// Không đụng frame của SBHomeGrabberView.
// Chỉ thay bottom safe-area của vùng scene.
//

%hook SBDeviceApplicationSceneView

- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets result = %orig;

    if (SHAPortrait()) {
        result = SHAReplaceBottom(result, SHAHomeHeight());
    }

    return result;
}

- (void)safeAreaInsetsDidChange {
    %orig;

    if (!SHAPortrait())
        return;

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

%end

#pragma mark - SBHomeGrabberView
//
// QUAN TRỌNG:
// Không thay grabberFrameForBounds:
// Không scale pill.
// Không di chuyển pill.
// Không thay gesture recognizer.
//

%hook SBHomeGrabberView

- (void)layoutSubviews {
    %orig;
}

%end

#pragma mark - SBHomeGrabberRotationView
//
// Giữ nguyên wrapper full-screen và gesture.
//

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
