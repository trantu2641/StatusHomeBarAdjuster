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

#pragma mark - Status Bar Content

/*
 * Không scale icon.
 *
 * Status Bar content được giữ nguyên kích thước,
 * chỉ điều chỉnh vị trí theo cạnh dưới của vùng
 * Status Bar mới.
 */
static void SHARepositionStatusContent(UIView *statusBar,
                                       CGFloat targetHeight)
{
    if (!statusBar)
        return;

    NSArray *subviews = [statusBar subviews];

    for (UIView *view in subviews) {

        NSString *name =
            NSStringFromClass(view.class);

        /*
         * Không di chuyển background.
         */
        if ([name containsString:@"Background"] ||
            [name containsString:@"Backdrop"]) {
            continue;
        }

        CGRect frame = view.frame;

        /*
         * Lấy đáy hiện tại của content.
         *
         * Không thay width / height.
         */
        CGFloat contentBottom =
            CGRectGetMaxY(frame);

        /*
         * Đưa đáy content về vùng Status Bar mới.
         *
         * Margin nhỏ giữ cách bố trí tự nhiên.
         */
        CGFloat desiredBottom =
            targetHeight;

        CGFloat delta =
            desiredBottom - contentBottom;

        frame.origin.y += delta;

        view.frame = frame;
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

#pragma mark - UIStatusBar_Modern
//
// Đây là hook quan trọng mới.
//
// iOS 16.4 có:
//
// + _heightForStyle:orientation:forStatusBarFrame:inWindow:isAzulBLinked:
//
// Đây là tầng tính height của Modern Status Bar.
//

%hook UIStatusBar_Modern

+ (CGFloat)_heightForStyle:(NSInteger)style
               orientation:(UIInterfaceOrientation)orientation
     forStatusBarFrame:(CGRect)statusBarFrame
               inWindow:(UIWindow *)window
        isAzulBLinked:(BOOL)isAzulBLinked
{
    CGFloat original =
        %orig(style,
              orientation,
              statusBarFrame,
              window,
              isAzulBLinked);

    if (SHAPortraitOrientation(orientation)) {

        CGFloat target = SHAStatusHeight();

        /*
         * Cho phép cả 0 -> 29.
         *
         * Không còn dùng MAX(30).
         */
        return target;
    }

    return original;
}

- (CGSize)intrinsicContentSize
{
    CGSize size = %orig;

    if (SHAPortrait())
        size.height = SHAStatusHeight();

    return size;
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

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    UIView *modern =
        (UIView *)self;

    CGFloat target =
        SHAStatusHeight();

    CGRect frame =
        modern.frame;

    frame.origin.y = 0.0;
    frame.size.height = target;

    modern.frame = frame;

    /*
     * Tìm _UIStatusBar bên trong.
     */
    for (UIView *view in modern.subviews) {

        NSString *name =
            NSStringFromClass(view.class);

        if ([name isEqualToString:@"_UIStatusBar"]) {

            CGRect statusFrame =
                view.frame;

            statusFrame.origin.y = 0.0;
            statusFrame.size.height = target;

            view.frame = statusFrame;

            SHARepositionStatusContent(view, target);
        }
    }
}

%end

#pragma mark - UIStatusBarWindow

%hook UIStatusBarWindow

+ (CGRect)statusBarWindowFrame
{
    CGRect frame = %orig;

    if (SHAPortrait()) {

        frame.origin.y = 0.0;

        /*
         * Window vẫn full-screen.
         *
         * Chỉ đảm bảo status bar geometry
         * bắt đầu từ cạnh trên.
         */
        frame.origin.x = 0.0;
    }

    return frame;
}

- (CGRect)_statusBarFrameForOrientation:(UIInterfaceOrientation)orientation
{
    CGRect frame = %orig;

    if (SHAPortraitOrientation(orientation)) {

        frame.origin.y = 0.0;
        frame.size.height = SHAStatusHeight();
    }

    return frame;
}

- (CGRect)statusBarWindowFrame
{
    CGRect frame = %orig;

    if (SHAPortrait()) {
        frame.origin.y = 0.0;
    }

    return frame;
}

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    UIView *window =
        (UIView *)self;

    CGFloat target =
        SHAStatusHeight();

    /*
     * Tìm UIStatusBar_Modern.
     */
    for (UIView *view in window.subviews) {

        NSString *name =
            NSStringFromClass(view.class);

        if ([name isEqualToString:@"UIStatusBar_Modern"]) {

            CGRect frame =
                view.frame;

            frame.origin.y = 0.0;
            frame.size.height = target;

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
        %orig(screen,
              orientation,
              lockScreen,
              azul);

    if (SHAPortraitOrientation(orientation))
        size.height = SHAStatusHeight();

    return size;
}

+ (CGSize)intrinsicContentSizeForTargetScreen:(UIScreen *)screen
                                   orientation:(UIInterfaceOrientation)orientation
                                  onLockScreen:(BOOL)lockScreen
{
    CGSize size =
        %orig(screen,
              orientation,
              lockScreen);

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

        %orig(frame,
              settings,
              options);

        return;
    }

    %orig;
}

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    UIView *statusBar =
        (UIView *)self;

    CGFloat target =
        SHAStatusHeight();

    CGRect frame =
        statusBar.frame;

    frame.origin.y = 0.0;
    frame.size.height = target;

    statusBar.frame = frame;

    SHARepositionStatusContent(statusBar,
                               target);
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

        %orig(frame,
              identifier);

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

        %orig(identifier,
              frame);

        return;
    }

    %orig;
}

- (void)_layoutStatusBarForOrientation:(UIInterfaceOrientation)orientation
{
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    UIView *container =
        (UIView *)self;

    CGFloat target =
        SHAStatusHeight();

    for (UIView *view in container.subviews) {

        NSString *name =
            NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {

            CGRect frame =
                view.frame;

            frame.origin.y = 0.0;
            frame.size.height = target;

            view.frame = frame;

            SHARepositionStatusContent(view,
                                       target);
        }
    }
}

- (void)layoutStatusBarForSpringBoardRotationToOrientation:(UIInterfaceOrientation)orientation
{
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    UIView *container =
        (UIView *)self;

    CGFloat target =
        SHAStatusHeight();

    for (UIView *view in container.subviews) {

        NSString *name =
            NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {

            CGRect frame =
                view.frame;

            frame.origin.y = 0.0;
            frame.size.height = target;

            view.frame = frame;

            SHARepositionStatusContent(view,
                                       target);
        }
    }
}

%end

#pragma mark - SBDeviceApplicationSceneView
//
// HOME BAR
//
// Runtime dump cho thấy:
//
// - isInsetForHomeAffordance
// - setInsetForHomeAffordance:
// - _contentContainerEdgeInsets
//
// Đây là đường layout quan trọng.
//

%hook SBDeviceApplicationSceneView

- (BOOL)isInsetForHomeAffordance
{
    /*
     * Luôn bật cơ chế inset của Home Affordance.
     */
    if (SHAPortrait())
        return YES;

    return %orig;
}

- (void)setInsetForHomeAffordance:(BOOL)inset
{
    if (SHAPortrait()) {
        %orig(YES);
        return;
    }

    %orig(inset);
}

- (UIEdgeInsets)_contentContainerEdgeInsets
{
    UIEdgeInsets insets =
        %orig;

    if (SHAPortrait()) {

        /*
         * TOP giữ nguyên.
         *
         * BOTTOM = Home Bar height.
         *
         * Mép dưới vật lý vẫn cố định.
         */
        insets.bottom =
            SHAHomeHeight();
    }

    return insets;
}

- (void)_updateEdgeProtectAndAutoHideOnHomeGrabberView
{
    %orig;

    if (!SHAPortrait())
        return;

    /*
     * Bắt SpringBoard cập nhật lại layout
     * sau khi Home Bar height thay đổi.
     */
    UIView *view =
        (UIView *)self;

    [view setNeedsLayout];
}

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    /*
     * Không thay frame của SBHomeGrabberView.
     *
     * Chỉ buộc content container layout lại.
     */
    UIView *view =
        (UIView *)self;

    [view setNeedsLayout];
}

%end

#pragma mark - SBHomeGrabberView
//
// Không đụng pill.
//
// Không đụng gesture.
//
// Không đụng grabberFrameForBounds.
//

%hook SBHomeGrabberView

- (void)layoutSubviews
{
    %orig;
}

%end

#pragma mark - SBHomeGrabberRotationView

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
