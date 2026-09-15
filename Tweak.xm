#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>

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

static CGFloat SHAReadPreference(NSString *key, CGFloat fallback)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    id value = [defaults objectForKey:key];

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
    return SHAReadPreference(kStatusBarKey, 30.0);
}

static CGFloat SHAHomeHeight(void)
{
    return SHAReadPreference(kHomeBarKey, 30.0);
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
    UIInterfaceOrientation orientation =
        [UIApplication sharedApplication].statusBarOrientation;

    if (orientation == UIInterfaceOrientationUnknown)
        return YES;

    return SHAPortraitOrientation(orientation);
}

#pragma mark - Status Bar

/*
 * This is the important SpringBoard layout owner.
 *
 * SBMainDisplaySceneLayoutStatusBarView has:
 *
 *   _statusBarFrameForOrientation:
 *   _layoutStatusBarForOrientation:
 *   _statusBarAvoidanceFrame
 *
 * The old implementation changed UIKit intrinsic size,
 * but iOS 16's encapsulated layout height constraint won.
 *
 * Here we modify the actual frame returned by SpringBoard.
 */

%hook SBMainDisplaySceneLayoutStatusBarView

- (CGRect)_statusBarFrameForOrientation:(NSInteger)orientation
{
    CGRect frame = %orig;

    if (!SHAPortraitOrientation(orientation))
        return frame;

    CGFloat height = SHAStatusHeight();

    /*
     * Keep TOP edge fixed.
     *
     * x       unchanged
     * y       unchanged
     * width   unchanged
     * height  user selected
     */
    frame.origin.y = 0.0;
    frame.size.height = height;

    return frame;
}

- (void)_layoutStatusBarForOrientation:(NSInteger)orientation
{
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    /*
     * Re-apply the requested status bar geometry after
     * SpringBoard performs its normal layout.
     */
    @try {

        SEL selector =
            NSSelectorFromString(
                @"_statusBarFrameForOrientation:"
            );

        if ([self respondsToSelector:selector]) {

            CGRect frame =
                ((CGRect (*)(id, SEL, NSInteger))
                    objc_msgSend)(
                        self,
                        selector,
                        orientation
                    );

            UIView *view = (UIView *)self;

            /*
             * Only adjust the actual status-bar child.
             * Do NOT modify this 926pt root view itself.
             */
            for (UIView *subview in view.subviews) {

                NSString *name =
                    NSStringFromClass([subview class]);

                if ([name isEqualToString:@"_UIStatusBar"] ||
                    [name isEqualToString:@"UIStatusBar_Modern"]) {

                    CGRect current =
                        subview.frame;

                    current.origin.y = 0.0;
                    current.size.height =
                        frame.size.height;

                    subview.frame = current;
                }
            }
        }
    }
    @catch (__unused NSException *exception) {
    }
}

- (CGRect)_statusBarAvoidanceFrame
{
    CGRect frame = %orig;

    if (!SHAPortrait())
        return frame;

    CGFloat height = SHAStatusHeight();

    /*
     * Avoidance region must follow the new status-bar
     * bottom edge, otherwise applications will still
     * layout underneath the enlarged status bar.
     */
    frame.origin.y = 0.0;
    frame.size.height = height;

    return frame;
}

%end

#pragma mark - UIKit Status Bar

%hook _UIStatusBar

- (CGSize)intrinsicContentSize
{
    CGSize size = %orig;

    if (!SHAPortrait())
        return size;

    CGFloat height = SHAStatusHeight();

    if (height >= 0.0)
        size.height = height;

    return size;
}

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                    orientation:(NSInteger)orientation
                                  onLockScreen:(BOOL)lockScreen
{
    CGSize size =
        %orig(screen, orientation, lockScreen);

    if (!SHAPortraitOrientation(orientation))
        return size;

    size.height = SHAStatusHeight();

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

    size.height = SHAStatusHeight();

    return size;
}

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    CGFloat height = SHAStatusHeight();

    /*
     * _UIStatusBar itself is the 49pt object seen in the
     * diagnostic dump.
     *
     * TOP remains fixed.
     */
    CGRect frame = self.frame;

    frame.origin.y = 0.0;
    frame.size.height = height;

    /*
     * Only perform this on the status-bar object.
     */
    self.frame = frame;
}

%end

#pragma mark - UIApplicationSceneSettings

/*
 * This is used by UIKit/SpringBoard to communicate the
 * status-bar geometry to application scenes.
 */

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

    insets.top = SHAStatusHeight();

    return insets;
}

- (UIEdgeInsets)safeAreaInsetsPortraitUpsideDown
{
    UIEdgeInsets insets =
        %orig;

    insets.top = SHAStatusHeight();

    return insets;
}

- (CGRect)statusBarAvoidanceFrame
{
    CGRect frame =
        %orig;

    if (!SHAPortrait())
        return frame;

    frame.origin.y = 0.0;
    frame.size.height = SHAStatusHeight();

    return frame;
}

#pragma mark - Home Bar

/*
 * This value is much more important than the frame of
 * SBHomeGrabberRotationView.
 *
 * SpringBoard uses the home-affordance overlay allowance
 * to reserve the bottom region.
 *
 * Bottom edge stays at physical screen bottom.
 * Increasing the value moves the usable content boundary
 * upward.
 */

- (CGFloat)homeAffordanceOverlayAllowance
{
    if (!SHAPortrait())
        return %orig;

    return SHAHomeHeight();
}

%end

#pragma mark - Home Bar Grabber

%hook SBHomeGrabberView

- (CGRect)grabberFrameForBounds:(CGRect)bounds
{
    CGRect frame =
        %orig(bounds);

    if (!SHAPortrait())
        return frame;

    CGFloat height =
        SHAHomeHeight();

    /*
     * The grabber itself is NOT the full home-bar container.
     *
     * Keep its actual visual width/height relationship,
     * but anchor its bottom edge to the physical bottom.
     */
    CGFloat originalHeight =
        frame.size.height;

    if (originalHeight < 1.0)
        originalHeight = 5.0;

    /*
     * At height 0 the home affordance is collapsed.
     *
     * For non-zero values, use the requested height as
     * the available bottom region while preserving the
     * original pill geometry when possible.
     */
    if (height <= 0.0) {

        frame.origin.y =
            CGRectGetHeight(bounds);

        frame.size.height = 0.0;

    } else {

        frame.origin.y =
            CGRectGetHeight(bounds) - height;

        frame.size.height = height;
    }

    return frame;
}

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    /*
     * Do NOT change SBHomeGrabberView itself.
     *
     * Its diagnostic frame is 428x926 and belongs to the
     * full-screen interaction layer.
     *
     * Only adjust its visual grabber subview(s).
     */
    CGFloat height =
        SHAHomeHeight();

    if (height <= 0.0) {

        for (UIView *subview in self.subviews) {

            NSString *name =
                NSStringFromClass([subview class]);

            if ([name containsString:@"Pill"] ||
                [name containsString:@"Grabber"]) {

                subview.hidden = YES;
            }
        }

        return;
    }

    /*
     * Keep visual Home Bar attached to the bottom.
     */
    for (UIView *subview in self.subviews) {

        NSString *name =
            NSStringFromClass([subview class]);

        if ([name containsString:@"Pill"] ||
            [name containsString:@"Grabber"]) {

            CGRect frame =
                subview.frame;

            /*
             * Only reposition vertically.
             * Do not scale the pill.
             */
            CGFloat bottom =
                CGRectGetHeight(self.bounds);

            CGFloat desiredBottom =
                bottom - 0.0;

            frame.origin.y =
                desiredBottom -
                frame.size.height;

            if (frame.origin.y < bottom - height)
                frame.origin.y = bottom - height;

            subview.frame = frame;

            subview.hidden = NO;
        }
    }
}

%end

#pragma mark - Home Rotation Wrapper

%hook SBHomeGrabberRotationView

- (void)layoutSubviews
{
    %orig;

    /*
     * This view is 428x926 according to the diagnostic.
     * Therefore DO NOT resize it.
     *
     * Its job is rotation/coordinate wrapping.
     * The actual home-bar allowance is controlled above.
     */
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        NSString *bundleID =
            [[NSBundle mainBundle] bundleIdentifier];

        /*
         * This tweak is intended for SpringBoard only.
         */
        if (![bundleID
            isEqualToString:@"com.apple.springboard"]) {

            return;
        }

        %init;
    }
}
