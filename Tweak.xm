#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>
#import <objc/message.h>

// ============================================================
// StatusHomeBarAdjuster
// RootHide / arm64e / iOS 16.x
//
// Design:
//   Status Bar : height = 0...120 px, TOP moves, BOTTOM stays at 0.
//   Home Bar   : height = 0...120 px, TOP moves, BOTTOM stays at screen bottom.
//
// The tweak deliberately does NOT resize/scale the status-bar icons or
// the Home Indicator pill. It changes the system scene metrics that UIKit
// uses for content avoidance, then only hides the Home Grabber visually at
// exactly 0 px. Landscape is left completely untouched.
// ============================================================

static NSString * const kPrefsSuite = @"com.congtu.statushomebaradjuster";
static NSString * const kStatusKey  = @"StatusBarHeight";
static NSString * const kHomeKey    = @"HomeBarHeight";
static NSString * const kChangedDarwin = @"com.congtu.statushomebaradjuster.settingsChanged";

static NSInteger SHAClamp(NSInteger value)
{
    if (value < 0) return 0;
    if (value > 120) return 120;
    return value;
}

static NSInteger SHAStatusHeight(void)
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
    NSInteger value = [defaults objectForKey:kStatusKey] ? [defaults integerForKey:kStatusKey] : 30;
    return SHAClamp(value);
}

static NSInteger SHAHomeHeight(void)
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
    NSInteger value = [defaults objectForKey:kHomeKey] ? [defaults integerForKey:kHomeKey] : 30;
    return SHAClamp(value);
}

static BOOL SHAPortrait(void)
{
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;

    UIApplication *app = [UIApplication sharedApplication];
    if (app && app.connectedScenes.count > 0) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState == UISceneActivationStateUnattached) continue;
            orientation = windowScene.interfaceOrientation;
            break;
        }
    }

    if (orientation == UIInterfaceOrientationUnknown) {
        orientation = (UIInterfaceOrientation)[UIDevice currentDevice].orientation;
    }

    return orientation == UIInterfaceOrientationPortrait ||
           orientation == UIInterfaceOrientationPortraitUpsideDown;
}

// ------------------------------------------------------------
// UIKit scene metrics
// ------------------------------------------------------------

@interface UIApplicationSceneSettings : NSObject
- (double)homeAffordanceOverlayAllowance;
- (double)statusBarHeight;
- (double)defaultStatusBarHeightForOrientation:(long long)orientation;
- (CGRect)statusBarAvoidanceFrame;
@end

%group SHAUISceneMetrics

%hook UIApplicationSceneSettings

- (double)homeAffordanceOverlayAllowance
{
    double original = %orig;

    if (!SHAPortrait())
        return original;

    // This is the bottom visual/content allowance used by UIKit for the
    // Home Affordance. Returning 0 means the app content can reach the
    // physical bottom edge; 30 is the normal reference height.
    return (double)SHAHomeHeight();
}

- (double)statusBarHeight
{
    double original = %orig;

    if (!SHAPortrait())
        return original;

    return (double)SHAStatusHeight();
}

- (double)defaultStatusBarHeightForOrientation:(long long)orientation
{
    double original = %orig(orientation);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
        return original;

    return (double)SHAStatusHeight();
}

- (CGRect)statusBarAvoidanceFrame
{
    CGRect original = %orig;

    if (!SHAPortrait())
        return original;

    // Keep the top edge anchored. Only the height changes.
    original.origin.y = 0.0;
    original.size.height = (CGFloat)SHAStatusHeight();
    return original;
}

%end

%end

// ------------------------------------------------------------
// _UIStatusBar: report the requested portrait height to UIKit.
// This is a geometry metric hook, not a transform/frame mutation.
// ------------------------------------------------------------

@interface _UIStatusBar : NSObject
+ (double)heightForOrientation:(long long)orientation;
@end

%group SHAStatusBarMetric

%hook _UIStatusBar

+ (double)heightForOrientation:(long long)orientation
{
    double original = %orig(orientation);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
        return original;

    return (double)SHAStatusHeight();
}

%end

%end

// ------------------------------------------------------------
// Home Grabber visual handling
//
// SBHomeGrabberView owns the MTLumaDodgePillView. We never change the
// pill's bounds, transform, or gesture recognizer. At exactly 0 px the
// visual grabber is hidden, which gives the requested "almost completely
// hidden" state while leaving the system gesture machinery untouched.
// ------------------------------------------------------------

@interface SBHomeGrabberView : UIView
@end

%group SHASpringBoard

%hook SBHomeGrabberView

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    NSInteger height = SHAHomeHeight();

    // _pillView is a private ivar of SBHomeGrabberView on iPhone X-class
    // devices. Access it only when it is actually present.
    UIView *pill = nil;
    @try {
        pill = [self valueForKey:@"_pillView"];
    } @catch (__unused NSException *exception) {
        pill = nil;
    }

    if (!pill)
        return;

    // Do not resize or transform the pill.
    // 0 px = visual Home Bar is effectively hidden.
    pill.hidden = (height == 0);

    // Keep the pill exactly where SpringBoard placed it for all non-zero
    // values. The surrounding content metric changes independently.
}

%end

%end

// ------------------------------------------------------------
// Darwin preference-change notification.
// We only request layout; we do not mutate frames or safe-area values here.
// ------------------------------------------------------------

static void SHASettingsChanged(int token)
{
    (void)token;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                [window setNeedsLayout];
                [window setNeedsUpdateConstraints];
            }
        }

        // Refresh the Home Grabber without touching its geometry.
        Class grabberClass = NSClassFromString(@"SBHomeGrabberView");
        if (grabberClass) {
            for (UIWindow *window in UIApplication.sharedApplication.windows) {
                NSMutableArray *stack = [NSMutableArray arrayWithObject:window];
                while (stack.count) {
                    UIView *view = stack.lastObject;
                    [stack removeLastObject];
                    if ([view isKindOfClass:grabberClass]) {
                        [view setNeedsLayout];
                    }
                    for (UIView *subview in view.subviews)
                        [stack addObject:subview];
                }
            }
        }
    });
}

%ctor
{
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier ?: @"";

    // UIKitCore and SpringBoard are the only processes that should receive
    // these private metric hooks.
    BOOL isUIKit = [bundleID isEqualToString:@"com.apple.UIKit"];
    BOOL isSpringBoard = [bundleID isEqualToString:@"com.apple.springboard"];

    if (!isUIKit && !isSpringBoard)
        return;

    if (isUIKit) {
        %init(SHAUISceneMetrics);
        %init(SHAStatusBarMetric);
    }

    if (isSpringBoard) {
        %init(SHASpringBoard);
    }

    int token = 0;
    notify_register_dispatch(kChangedDarwin.UTF8String, &token,
                             dispatch_get_main_queue(),
                             ^(int t) {
        SHASettingsChanged(t);
    });
}
