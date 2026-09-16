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

static BOOL SHAPortraitOrientation(UIInterfaceOrientation o)
{
    return o == UIInterfaceOrientationPortrait ||
           o == UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Status content

static void SHAAdjustStatusContent(UIView *statusBar,
                                   CGFloat targetHeight)
{
    if (!statusBar)
        return;

    if (targetHeight < 0.0)
        targetHeight = 0.0;

    /*
     * Các thành phần con của UIStatusBar thường nằm
     * trong vùng 30pt mặc định.
     *
     * Không scale.
     * Chỉ dịch theo thay đổi của vùng.
     */

    CGFloat currentHeight = statusBar.bounds.size.height;

    if (currentHeight <= 0.0)
        currentHeight = 30.0;

    CGFloat delta = targetHeight - currentHeight;

    for (UIView *subview in statusBar.subviews) {

        NSString *name =
            NSStringFromClass(subview.class);

        /*
         * Không đụng background/overlay.
         */
        if ([name containsString:@"Background"] ||
            [name containsString:@"Backdrop"]) {
            continue;
        }

        CGRect f = subview.frame;

        f.origin.y += delta;

        subview.frame = f;
    }
}

#pragma mark - UIApplicationSceneSettings

%hook UIApplicationSceneSettings

- (CGFloat)statusBarHeight
{
    if (SHAPortrait())
        return SHAStatusHeight();

    return %orig;
}

- (CGFloat)defaultStatusBarHeightForOrientation:(UIInterfaceOrientation)o
{
    if (SHAPortraitOrientation(o))
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

- (CGRect)_statusBarFrameForOrientation:(UIInterfaceOrientation)o
{
    CGRect frame = %orig;

    if (SHAPortraitOrientation(o)) {

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

- (void)statusBar:(id)statusBar
didAnimateFromHeight:(CGFloat)oldHeight
          toHeight:(CGFloat)newHeight
         animation:(id)animation
{
    if (SHAPortrait()) {

        CGFloat target = SHAStatusHeight();

        %orig(statusBar,
              oldHeight,
              target,
              animation);

        return;
    }

    %orig;
}

- (void)statusBar:(id)statusBar
willAnimateFromHeight:(CGFloat)oldHeight
           toHeight:(CGFloat)newHeight
          duration:(CGFloat)duration
          animation:(id)animation
{
    if (SHAPortrait()) {

        CGFloat target = SHAStatusHeight();

        %orig(statusBar,
              oldHeight,
              target,
              duration,
              animation);

        return;
    }

    %orig;
}

- (void)_layoutStatusBarForOrientation:(UIInterfaceOrientation)o
{
    %orig;

    if (!SHAPortraitOrientation(o))
        return;

    CGFloat target = SHAStatusHeight();

    UIView *container = (UIView *)self;

    for (UIView *view in container.subviews) {

        NSString *name =
            NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {

            CGRect frame = view.frame;

            frame.origin.y = 0.0;
            frame.size.height = target;

            view.frame = frame;

            SHAAdjustStatusContent(view, target);
        }
    }
}

- (void)layoutStatusBarForSpringBoardRotationToOrientation:(UIInterfaceOrientation)o
{
    %orig;

    if (!SHAPortraitOrientation(o))
        return;

    CGFloat target = SHAStatusHeight();

    UIView *container = (UIView *)self;

    for (UIView *view in container.subviews) {

        NSString *name =
            NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {

            CGRect frame = view.frame;

            frame.origin.y = 0.0;
            frame.size.height = target;

            view.frame = frame;

            SHAAdjustStatusContent(view, target);
        }
    }
}

%end

#pragma mark - UIStatusBar_Modern
//
// Đây là phần mới quan trọng.
//
// Runtime dump trước cho thấy:
//
// _UIStatusBar
//      ↓
// UIStatusBar_Modern
//      ↓
// UIStatusBarWindow
//
// _UIStatusBar bị:
// UIView-Encapsulated-Layout-Height
// == 49
//
// UIStatusBar_Modern là container cần xử lý.
//

%hook UIStatusBar_Modern

- (CGSize)intrinsicContentSize
{
    CGSize size = %orig;

    if (SHAPortrait())
        size.height = SHAStatusHeight();

    return size;
}

- (void)updateConstraints
{
    %orig;

    if (!SHAPortrait())
        return;

    CGFloat target = SHAStatusHeight();

    /*
     * Tìm constraint height của chính status bar.
     *
     * Không xoá tất cả constraint.
     * Chỉ xử lý height constraint có liên quan.
     */

    NSArray *constraints =
        [(UIView *)self constraints];

    for (NSLayoutConstraint *constraint in constraints) {

        if (constraint.firstAttribute != NSLayoutAttributeHeight)
            continue;

        UIView *first =
            (UIView *)constraint.firstItem;

        if (first != (UIView *)self)
            continue;

        /*
         * Không can thiệp constraint encapsulated.
         * Chỉ cập nhật constraint nội bộ nếu có.
         */
        if (constraint.identifier &&
            [constraint.identifier containsString:@"Encapsulated"]) {
            continue;
        }

        if (constraint.priority < UILayoutPriorityRequired) {

            constraint.constant = target;
        }
    }
}

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    CGFloat target = SHAStatusHeight();

    UIView *modern = (UIView *)self;

    CGRect frame = modern.frame;

    frame.origin.y = 0.0;
    frame.size.height = target;

    modern.frame = frame;

    for (UIView *view in modern.subviews) {

        NSString *name =
            NSStringFromClass(view.class);

        if ([name isEqualToString:@"_UIStatusBar"] ||
            [name containsString:@"UIStatusBar"]) {

            CGRect f = view.frame;

            f.origin.y = 0.0;
            f.size.height = target;

            view.frame = f;

            SHAAdjustStatusContent(view, target);
        }
    }
}

%end

#pragma mark - _UIStatusBar

%hook _UIStatusBar

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                   orientation:(UIInterfaceOrientation)o
                                  onLockScreen:(BOOL)lockScreen
                                isAzulBLinked:(BOOL)azul
{
    CGSize size =
        %orig(screen,
              o,
              lockScreen,
              azul);

    if (SHAPortraitOrientation(o))
        size.height = SHAStatusHeight();

    return size;
}

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                   orientation:(UIInterfaceOrientation)o
                                  onLockScreen:(BOOL)lockScreen
{
    CGSize size =
        %orig(screen,
              o,
              lockScreen);

    if (SHAPortraitOrientation(o))
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

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    UIView *statusBar = (UIView *)self;

    CGFloat target = SHAStatusHeight();

    CGRect frame = statusBar.frame;

    frame.origin.y = 0.0;
    frame.size.height = target;

    statusBar.frame = frame;

    SHAAdjustStatusContent(statusBar, target);
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

        %orig(frame,
              settings,
              options);

        return;
    }

    %orig;
}

%end

#pragma mark - Home: SBDeviceApplicationSceneView

%hook SBDeviceApplicationSceneView

/*
 * Không còn override safeAreaInsets.
 *
 * iOS 16.4 không lấy Home Bar height từ đây theo cách
 * chúng ta cần.
 */

%end

#pragma mark - Home: SBHomeGrabberView

%hook SBHomeGrabberView

/*
 * Tuyệt đối không sửa:
 *
 * grabberFrameForBounds:
 *
 * vì đó là frame của Home Indicator/Pill.
 */

- (void)layoutSubviews
{
    %orig;
}

%end

#pragma mark - Home: SBHomeGrabberRotationView

%hook SBHomeGrabberRotationView

- (void)layoutSubviews
{
    %orig;
}

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
