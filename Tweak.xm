#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>

#pragma mark -
#pragma mark Preferences

static NSString * const SHA_PREFS_SUITE =
    @"com.congtu.statushomebaradjuster";

static NSString * const SHA_STATUS_KEY =
    @"StatusBarHeight";

static NSString * const SHA_HOME_KEY =
    @"HomeBarHeight";

static const char *SHA_SETTINGS_CHANGED =
    "com.congtu.statushomebaradjuster.settingsChanged";

static const CGFloat SHA_DEFAULT_HEIGHT = 30.0;
static const CGFloat SHA_MIN_HEIGHT = 0.0;
static const CGFloat SHA_MAX_HEIGHT = 120.0;


static CGFloat SHAClamp(CGFloat value)
{
    return MAX(SHA_MIN_HEIGHT,
               MIN(SHA_MAX_HEIGHT, value));
}


static CGFloat SHAStatusHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:SHA_PREFS_SUITE];

    if (![defaults objectForKey:SHA_STATUS_KEY])
        return SHA_DEFAULT_HEIGHT;

    return SHAClamp(
        (CGFloat)[defaults integerForKey:SHA_STATUS_KEY]
    );
}


static CGFloat SHAHomeHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:SHA_PREFS_SUITE];

    if (![defaults objectForKey:SHA_HOME_KEY])
        return SHA_DEFAULT_HEIGHT;

    return SHAClamp(
        (CGFloat)[defaults integerForKey:SHA_HOME_KEY]
    );
}


#pragma mark -
#pragma mark Orientation

static BOOL SHAIsPortraitOrientation(NSInteger orientation)
{
    return
        orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown;
}


static BOOL SHAIsPortrait(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application)
        return YES;

    for (UIScene *scene in application.connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        UIInterfaceOrientation orientation =
            windowScene.interfaceOrientation;

        if (SHAIsPortraitOrientation(orientation))
            return YES;

        if (orientation == UIInterfaceOrientationLandscapeLeft ||
            orientation == UIInterfaceOrientationLandscapeRight)
        {
            return NO;
        }
    }

    return YES;
}


#pragma mark -
#pragma mark UIApplicationSceneSettings

@interface UIApplicationSceneSettings : NSObject
@end


%hook UIApplicationSceneSettings

/*
 * Status Bar height.
 */
- (double)statusBarHeight
{
    double original = %orig;

    if (!SHAIsPortrait())
        return original;

    return SHAStatusHeight();
}


/*
 * Default Status Bar height.
 */
- (double)defaultStatusBarHeightForOrientation:
    (NSInteger)orientation
{
    double original =
        %orig(orientation);

    if (!SHAIsPortraitOrientation(orientation))
        return original;

    return SHAStatusHeight();
}


/*
 * Home Affordance height.
 */
- (double)homeAffordanceOverlayAllowance
{
    double original = %orig;

    if (!SHAIsPortrait())
        return original;

    return SHAHomeHeight();
}


/*
 * Đây mới là safe-area metric thực tế của SceneSettings.
 *
 * Top    = Status Bar
 * Bottom = Home Bar
 */
- (UIEdgeInsets)safeAreaInsetsPortrait
{
    UIEdgeInsets original = %orig;

    original.top =
        SHAStatusHeight();

    original.bottom =
        SHAHomeHeight();

    return original;
}


- (UIEdgeInsets)safeAreaInsetsPortraitUpsideDown
{
    UIEdgeInsets original = %orig;

    /*
     * Upside-down:
     * Status Bar vẫn ở phía trên logical interface,
     * Home Bar ở phía dưới.
     */
    original.top =
        SHAStatusHeight();

    original.bottom =
        SHAHomeHeight();

    return original;
}


#pragma mark Status Bar avoidance

- (CGRect)statusBarAvoidanceFrame
{
    CGRect original = %orig;

    if (!SHAIsPortrait())
        return original;

    /*
     * Giữ nguyên X / Width.
     *
     * TOP cố định.
     * BOTTOM thay đổi theo Status Bar Height.
     */
    original.origin.y = 0.0;
    original.size.height = SHAStatusHeight();

    return original;
}

%end


#pragma mark -
#pragma mark _UIStatusBar

@interface _UIStatusBar : UIView
@end


%hook _UIStatusBar


/*
 * iOS 16.x dùng class method này làm một trong
 * những nguồn height chính.
 */
+ (double)heightForOrientation:
    (NSInteger)orientation
{
    double original =
        %orig(orientation);

    if (!SHAIsPortraitOrientation(orientation))
        return original;

    return SHAStatusHeight();
}


/*
 * Actual intrinsic size API trên runtime của máy.
 */
+ (CGSize)intrinsicContentSizeForTargetScreen:
    (UIScreen *)screen
    orientation:(NSInteger)orientation
    onLockScreen:(BOOL)lockScreen
{
    CGSize original =
        %orig(screen,
              orientation,
              lockScreen);

    if (!SHAIsPortraitOrientation(orientation))
        return original;

    original.height =
        SHAStatusHeight();

    return original;
}


+ (CGSize)intrinsicContentSizeForTargetScreen:
    (UIScreen *)screen
    orientation:(NSInteger)orientation
    onLockScreen:(BOOL)lockScreen
    isAzulBLinked:(BOOL)azulBLinked
{
    CGSize original =
        %orig(screen,
              orientation,
              lockScreen,
              azulBLinked);

    if (!SHAIsPortraitOrientation(orientation))
        return original;

    original.height =
        SHAStatusHeight();

    return original;
}


%end


#pragma mark -
#pragma mark Status Bar Visual Provider

@interface _UIStatusBarVisualProvider_iOS : NSObject
@end


%hook _UIStatusBarVisualProvider_iOS


+ (CGFloat)height
{
    CGFloat original =
        %orig;

    if (!SHAIsPortrait())
        return original;

    return SHAStatusHeight();
}


+ (CGSize)intrinsicContentSizeForOrientation:
    (NSInteger)orientation
{
    CGSize original =
        %orig(orientation);

    if (!SHAIsPortraitOrientation(orientation))
        return original;

    original.height =
        SHAStatusHeight();

    return original;
}

%end


@interface _UIStatusBarVisualProvider_Split : NSObject
@end


%hook _UIStatusBarVisualProvider_Split


+ (CGFloat)height
{
    CGFloat original =
        %orig;

    if (!SHAIsPortrait())
        return original;

    return SHAStatusHeight();
}


+ (CGSize)intrinsicContentSizeForOrientation:
    (NSInteger)orientation
{
    CGSize original =
        %orig(orientation);

    if (!SHAIsPortraitOrientation(orientation))
        return original;

    original.height =
        SHAStatusHeight();

    return original;
}

%end


#pragma mark -
#pragma mark Home Grabber

@interface SBHomeGrabberView : UIView

- (CGRect)grabberFrameForBounds:
    (CGRect)bounds;

- (CGSize)suggestedSizeForContentWidth:
    (CGFloat)width;

- (CGRect)_calculatePillFrame;

@end


%hook SBHomeGrabberView


/*
 * ĐÂY LÀ HOOK QUAN TRỌNG NHẤT CHO HOME BAR.
 *
 * Không sửa self.frame.
 * Không sửa self.bounds.
 * Không dùng transform.
 *
 * Ta thay geometry được SBHomeGrabberView
 * tự tính ra.
 */
- (CGRect)grabberFrameForBounds:
    (CGRect)bounds
{
    CGRect original =
        %orig(bounds);

    if (!SHAIsPortrait())
        return original;

    CGFloat requestedHeight =
        SHAHomeHeight();


    /*
     * Giữ nguyên chiều rộng.
     *
     * Bottom của Home Bar phải cố định
     * tại đáy bounds.
     */
    CGFloat bottom =
        CGRectGetMaxY(bounds);


    /*
     * Nếu 0 px:
     * trả vùng có height = 0,
     * không đụng gesture recognizer.
     */
    if (requestedHeight <= 0.0)
    {
        original.origin.y =
            bottom;

        original.size.height =
            0.0;

        return original;
    }


    /*
     * Home Bar cao đúng giá trị yêu cầu.
     *
     * TOP thay đổi.
     * BOTTOM cố định.
     */
    original.origin.y =
        bottom - requestedHeight;

    original.size.height =
        requestedHeight;


    return original;
}


/*
 * suggestedSizeForContentWidth:
 *
 * Đây là metric phụ của Grabber.
 *
 * Không thay đổi width.
 * Chỉ thay đổi height trong portrait.
 */
- (CGSize)suggestedSizeForContentWidth:
    (CGFloat)width
{
    CGSize original =
        %orig(width);

    if (!SHAIsPortrait())
        return original;

    CGFloat requestedHeight =
        SHAHomeHeight();

    if (requestedHeight <= 0.0)
    {
        original.height = 0.0;
        return original;
    }

    original.height =
        requestedHeight;

    return original;
}


/*
 * Đây là method mà SBHomeGrabberView dùng
 * để tính pill.
 *
 * KHÔNG scale pill.
 *
 * Chỉ bảo đảm khi Home Bar = 0 thì
 * indicator không còn hiển thị.
 */
- (CGRect)_calculatePillFrame
{
    CGRect original =
        %orig;

    if (!SHAIsPortrait())
        return original;

    if (SHAHomeHeight() <= 0.0)
    {
        original.size.height = 0.0;
    }

    return original;
}


- (void)layoutSubviews
{
    %orig;

    if (!SHAIsPortrait())
        return;

    UIView *pill = nil;

    @try
    {
        pill =
            [self valueForKey:@"_pillView"];
    }
    @catch (__unused NSException *exception)
    {
        pill = nil;
    }

    if (!pill)
        return;

    /*
     * Chỉ xử lý trạng thái 0.
     *
     * Không scale.
     * Không đổi frame.
     * Không đổi bounds.
     * Không đổi transform.
     */
    pill.hidden =
        (SHAHomeHeight() <= 0.0);
}

%end


#pragma mark -
#pragma mark Refresh

static void SHARefreshUI(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIApplication *application =
                [UIApplication sharedApplication];

            if (!application)
                return;


            /*
             * Force Scene layout.
             */
            for (UIScene *scene in
                 application.connectedScenes)
            {
                if (![scene isKindOfClass:
                        [UIWindowScene class]])
                {
                    continue;
                }

                UIWindowScene *windowScene =
                    (UIWindowScene *)scene;


                for (UIWindow *window in
                     windowScene.windows)
                {
                    [window setNeedsLayout];

                    [window setNeedsUpdateConstraints];


                    UIViewController *root =
                        window.rootViewController;

                    if (root)
                    {
                        [root
                            viewSafeAreaInsetsDidChange];

                        [root
                            viewWillLayoutSubviews];
                    }
                }
            }


            /*
             * Force Home Grabber layout.
             */
            Class grabberClass =
                NSClassFromString(
                    @"SBHomeGrabberView"
                );

            if (!grabberClass)
                return;


            for (UIScene *scene in
                 application.connectedScenes)
            {
                if (![scene isKindOfClass:
                        [UIWindowScene class]])
                {
                    continue;
                }

                UIWindowScene *windowScene =
                    (UIWindowScene *)scene;


                for (UIWindow *window in
                     windowScene.windows)
                {
                    NSMutableArray *stack =
                        [NSMutableArray
                            arrayWithObject:window];


                    while (stack.count > 0)
                    {
                        UIView *view =
                            stack.lastObject;

                        [stack removeLastObject];


                        if ([view isKindOfClass:
                                grabberClass])
                        {
                            [view setNeedsLayout];
                        }


                        for (UIView *subview in
                             view.subviews)
                        {
                            [stack addObject:subview];
                        }
                    }
                }
            }
        }
    );
}


#pragma mark -
#pragma mark Notification

static void SHASettingsChanged(int token)
{
    (void)token;

    SHARefreshUI();
}


#pragma mark -
#pragma mark Constructor

%ctor
{
    NSString *bundleIdentifier =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (![bundleIdentifier
            isEqualToString:
                @"com.apple.springboard"])
    {
        return;
    }


    /*
     * Tất cả class cần thiết đều đã được
     * xác nhận tồn tại trong runtime dump.
     */
    %init;


    int token = 0;

    notify_register_dispatch(
        SHA_SETTINGS_CHANGED,
        &token,
        dispatch_get_main_queue(),
        ^(int changedToken)
        {
            SHASettingsChanged(changedToken);
        }
    );
}
