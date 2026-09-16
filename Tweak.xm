#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString * const kSHADomain = @"com.congtu.statushomebaradjuster";
static NSString * const kStatusKey = @"StatusBarHeight";
static NSString * const kHomeKey   = @"HomeBarHeight";

#pragma mark - Preferences

static CGFloat SHAGetValue(NSString *key, CGFloat fallback)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:kSHADomain];

    id value = [defaults objectForKey:key];

    CGFloat result = fallback;

    if ([value isKindOfClass:[NSNumber class]]) {
        result = [(NSNumber *)value doubleValue];
    }
    else if ([value isKindOfClass:[NSString class]]) {
        result = [(NSString *)value doubleValue];
    }
    else {
        return fallback;
    }

    if (!isfinite(result))
        return fallback;

    return MIN(MAX(result, 0.0), 120.0);
}

static CGFloat SHAStatusHeight(void)
{
    return SHAGetValue(kStatusKey, 30.0);
}

static CGFloat SHAHomeHeight(void)
{
    return SHAGetValue(kHomeKey, 30.0);
}

#pragma mark - Orientation

static BOOL SHAPortrait(void)
{
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

static BOOL SHAPortraitOrientation(UIInterfaceOrientation orientation)
{
    return orientation == UIInterfaceOrientationPortrait ||
           orientation == UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - UIApplicationSceneSettings

%hook UIApplicationSceneSettings

- (CGFloat)statusBarHeight
{
    if (SHAPortrait())
        return SHAStatusHeight();

    return %orig;
}

- (CGFloat)defaultStatusBarHeightForOrientation:(UIInterfaceOrientation)orientation
{
    if (SHAPortraitOrientation(orientation))
        return SHAStatusHeight();

    return %orig;
}

- (CGRect)statusBarAvoidanceFrame
{
    CGRect frame = %orig;

    if (SHAPortrait()) {
        frame.origin.y = 0.0;
        frame.size.height = SHAStatusHeight();
    }

    return frame;
}

- (UIEdgeInsets)safeAreaInsetsPortrait
{
    UIEdgeInsets insets = %orig;

    if (SHAPortrait())
        insets.top = SHAStatusHeight();

    return insets;
}

- (UIEdgeInsets)safeAreaInsetsPortraitUpsideDown
{
    UIEdgeInsets insets = %orig;

    if (SHAPortrait())
        insets.top = SHAStatusHeight();

    return insets;
}

- (CGFloat)homeAffordanceOverlayAllowance
{
    if (SHAPortrait())
        return SHAHomeHeight();

    return %orig;
}

%end

#pragma mark - SBMainDisplaySceneLayoutStatusBarView

%hook SBMainDisplaySceneLayoutStatusBarView

- (CGRect)_statusBarFrameForOrientation:(UIInterfaceOrientation)orientation
{
    CGRect frame = %orig;

    if (SHAPortraitOrientation(orientation)) {
        frame.origin.y = 0.0;
        frame.size.height = SHAStatusHeight();
    }

    return frame;
}

- (CGRect)_statusBarAvoidanceFrame
{
    CGRect frame = %orig;

    if (SHAPortrait()) {
        frame.origin.y = 0.0;
        frame.size.height = SHAStatusHeight();
    }

    return frame;
}

- (void)_applyStatusBarAvoidanceFrame:(CGRect)frame
                 toSceneWithIdentifier:(NSString *)identifier
{
    if (SHAPortrait()) {
        frame.origin.y = 0.0;
        frame.size.height = SHAStatusHeight();

        %orig(frame, identifier);
        return;
    }

    %orig;
}

- (void)sceneWithIdentifier:(NSString *)identifier
didChangeStatusBarAvoidanceFrameTo:(CGRect)frame
{
    if (SHAPortrait()) {
        frame.origin.y = 0.0;
        frame.size.height = SHAStatusHeight();

        %orig(identifier, frame);
        return;
    }

    %orig;
}

- (void)_layoutStatusBarForOrientation:(UIInterfaceOrientation)orientation
{
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    UIView *container = (UIView *)self;
    CGFloat height = SHAStatusHeight();

    /*
     * Tìm UIStatusBar_Modern / _UIStatusBar
     * nhưng không thay đổi icon riêng lẻ.
     */
    for (UIView *view in container.subviews) {

        NSString *name = NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {

            CGRect frame = view.frame;

            frame.origin.y = 0.0;
            frame.size.height = height;

            view.frame = frame;
        }
    }
}

- (void)layoutStatusBarForSpringBoardRotationToOrientation:(UIInterfaceOrientation)orientation
{
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    UIView *container = (UIView *)self;
    CGFloat height = SHAStatusHeight();

    for (UIView *view in container.subviews) {

        NSString *name = NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {

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
                                isAzulBLinked:(BOOL)azul
{
    CGSize size =
        %orig(screen, orientation, lockScreen, azul);

    if (SHAPortraitOrientation(orientation))
        size.height = SHAStatusHeight();

    return size;
}

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                   orientation:(UIInterfaceOrientation)orientation
                                  onLockScreen:(BOOL)lockScreen
{
    CGSize size =
        %orig(screen, orientation, lockScreen);

    if (SHAPortraitOrientation(orientation))
        size.height = SHAStatusHeight();

    return size;
}

- (CGSize)intrinsicContentSize
{
    CGSize size = %orig;

    if (SHAPortrait())
        size.height = SHAStatusHeight();

    return size;
}

- (void)setAvoidanceFrame:(CGRect)frame
{
    if (SHAPortrait()) {
        frame.origin.y = 0.0;
        frame.size.height = SHAStatusHeight();

        %orig(frame);
        return;
    }

    %orig;
}

- (void)setAvoidanceFrame:(CGRect)frame
       animationSettings:(id)settings
                 options:(NSUInteger)options
{
    if (SHAPortrait()) {
        frame.origin.y = 0.0;
        frame.size.height = SHAStatusHeight();

        %orig(frame, settings, options);
        return;
    }

    %orig;
}

%end

#pragma mark - SBDeviceApplicationSceneView

%hook SBDeviceApplicationSceneView

- (UIEdgeInsets)safeAreaInsets
{
    UIEdgeInsets insets = %orig;

    if (SHAPortrait())
        insets.bottom = SHAHomeHeight();

    return insets;
}

%end

#pragma mark - Home Grabber

%hook SBHomeGrabberView

/*
 * Không thay đổi grabberFrameForBounds:
 *
 * Home Indicator / gesture area giữ nguyên.
 * Home Bar height được điều khiển thông qua
 * homeAffordanceOverlayAllowance + safe area.
 */

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        NSString *bundleID =
            NSBundle.mainBundle.bundleIdentifier;

        if ([bundleID isEqualToString:@"com.apple.springboard"]) {
            %init;
        }
    }
}
