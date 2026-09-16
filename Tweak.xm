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

#pragma mark - Status Bar content positioning

/*
 * iOS có xu hướng giữ minimum height ~30pt cho UIStatusBar.
 *
 * Ta không scale icon.
 *
 * Khi vùng Status Bar thay đổi:
 *
 *     height = 60
 *
 * content được đặt gần đáy:
 *
 *     ┌────────────────────┐
 *     │                    │
 *     │                    │
 *     │       ICONS        │
 *     └────────────────────┘
 *
 * Khi:
 *
 *     height = 10
 *
 * content vẫn giữ kích thước gốc nhưng được dịch
 * theo cạnh dưới của vùng Status Bar.
 */

static void SHAMoveStatusContent(UIView *statusBar,
                                  CGFloat newHeight)
{
    if (!statusBar)
        return;

    /*
     * Không làm gì nếu iOS đang layout một view
     * không có chiều cao hợp lệ.
     */
    if (statusBar.bounds.size.height <= 0.0)
        return;

    CGFloat oldHeight = statusBar.bounds.size.height;

    /*
     * Duyệt các direct subview của _UIStatusBar.
     *
     * Không scale.
     * Chỉ dịch Y để content bám theo cạnh dưới.
     */
    for (UIView *view in statusBar.subviews) {

        NSString *name = NSStringFromClass(view.class);

        /*
         * Bỏ qua các container có khả năng là background/
         * overlay toàn vùng.
         */
        if ([name containsString:@"Background"] ||
            [name containsString:@"Backdrop"]) {
            continue;
        }

        CGRect frame = view.frame;

        /*
         * Chỉ dịch content theo chênh lệch chiều cao.
         *
         * Ví dụ:
         *
         * old = 30
         * new = 60
         * delta = +30
         *
         * old = 30
         * new = 10
         * delta = -20
         */
        CGFloat delta = newHeight - oldHeight;

        /*
         * Các container content thường có anchor ở trên.
         * Đưa chúng xuống theo delta.
         */
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

/*
 * Đây là metric liên quan trực tiếp tới vùng
 * Home Affordance.
 *
 * Không thay frame của pill.
 */
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

- (void)statusBar:(id)statusBar
didAnimateFromHeight:(CGFloat)oldHeight
          toHeight:(CGFloat)newHeight
         animation:(id)animation
{
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
          animation:(id)animation
{
    if (SHAPortrait()) {

        CGFloat height = SHAStatusHeight();

        %orig(statusBar,
              oldHeight,
              height,
              duration,
              animation);

        return;
    }

    %orig;
}

- (void)_layoutStatusBarForOrientation:(UIInterfaceOrientation)orientation
{
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    CGFloat height = SHAStatusHeight();

    UIView *container = (UIView *)self;

    for (UIView *view in container.subviews) {

        NSString *name = NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {

            CGRect frame = view.frame;

            frame.origin.y = 0.0;
            frame.size.height = height;

            view.frame = frame;

            /*
             * Quan trọng:
             * lấy UIStatusBar thực tế rồi dịch content.
             */
            if ([name containsString:@"Modern"] ||
                [name isEqualToString:@"_UIStatusBar"]) {

                SHAMoveStatusContent(view, height);
            }
        }
    }
}

- (void)layoutStatusBarForSpringBoardRotationToOrientation:(UIInterfaceOrientation)orientation
{
    %orig;

    if (!SHAPortraitOrientation(orientation))
        return;

    CGFloat height = SHAStatusHeight();

    UIView *container = (UIView *)self;

    for (UIView *view in container.subviews) {

        NSString *name = NSStringFromClass(view.class);

        if ([name containsString:@"UIStatusBar"]) {

            CGRect frame = view.frame;

            frame.origin.y = 0.0;
            frame.size.height = height;

            view.frame = frame;

            if ([name containsString:@"Modern"] ||
                [name isEqualToString:@"_UIStatusBar"]) {

                SHAMoveStatusContent(view, height);
            }
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

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortrait())
        return;

    UIView *statusBar = (UIView *)self;

    CGFloat height = SHAStatusHeight();

    CGRect frame = statusBar.frame;

    /*
     * Ép lại height sau Auto Layout.
     *
     * Điều này đặc biệt quan trọng với giá trị <30,
     * vì iOS có encapsulated height constraint.
     */
    frame.origin.y = 0.0;
    frame.size.height = height;

    statusBar.frame = frame;

    SHAMoveStatusContent(statusBar, height);
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

#pragma mark - SBHomeGrabberView

%hook SBHomeGrabberView

/*
 * KHÔNG hook grabberFrameForBounds:
 *
 * Không scale.
 * Không di chuyển.
 * Không thay đổi kích thước Home Indicator.
 *
 * Gesture area của iOS được giữ nguyên.
 */

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
