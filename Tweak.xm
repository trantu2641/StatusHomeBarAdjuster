#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>


#pragma mark -
#pragma mark Constants

static NSString * const kSHAPrefs =
    @"com.congtu.statushomebaradjuster";

static NSString * const kSHAStatusHeight =
    @"StatusBarHeight";

static NSString * const kSHAHomeHeight =
    @"HomeBarHeight";

static const NSInteger kSHAMinHeight = 0;
static const NSInteger kSHAMaxHeight = 120;

static const double kSHADefaultStatusHeight = 30.0;
static const double kSHADefaultHomeHeight   = 30.0;

static const char *kSHASettingsChanged =
    "com.congtu.statushomebaradjuster.settingsChanged";


#pragma mark -
#pragma mark Preference Values

static CGFloat SHAStatusHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:kSHAPrefs];

    if (![defaults objectForKey:kSHAStatusHeight])
        return kSHADefaultStatusHeight;

    NSInteger value =
        [defaults integerForKey:kSHAStatusHeight];

    value = MAX(kSHAMinHeight,
                MIN(kSHAMaxHeight, value));

    return (CGFloat)value;
}


static CGFloat SHAHomeHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:kSHAPrefs];

    if (![defaults objectForKey:kSHAHomeHeight])
        return kSHADefaultHomeHeight;

    NSInteger value =
        [defaults integerForKey:kSHAHomeHeight];

    value = MAX(kSHAMinHeight,
                MIN(kSHAMaxHeight, value));

    return (CGFloat)value;
}


#pragma mark -
#pragma mark Orientation

static BOOL SHAIsPortrait(void)
{
    UIApplication *app =
        [UIApplication sharedApplication];

    if (!app)
        return YES;

    for (UIScene *scene in app.connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        UISceneActivationState state =
            windowScene.activationState;

        if (state == UISceneActivationStateUnattached)
            continue;

        UIInterfaceOrientation orientation =
            windowScene.interfaceOrientation;

        if (orientation == UIInterfaceOrientationPortrait ||
            orientation == UIInterfaceOrientationPortraitUpsideDown)
        {
            return YES;
        }

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


%group SHAUIKitMetrics

%hook UIApplicationSceneSettings


/*
 * ============================================================
 *
 * STATUS BAR
 *
 * Giá trị = chiều cao thực tế của vùng Status Bar.
 *
 * 0 px:
 *
 *     TOP/BOTTOM của vùng Status Bar trùng nhau.
 *     Nội dung có thể chạy sát phía trên.
 *
 * 30 px:
 *
 *     Mức mặc định.
 *
 * 60 / 90 / 120 px:
 *
 *     Vùng Status Bar cao lên.
 *     Nội dung bên dưới được layout theo metric mới.
 *
 * Không scale icon.
 * Không transform UIWindow.
 *
 * ============================================================
 */

- (double)statusBarHeight
{
    if (!SHAIsPortrait())
        return %orig;

    return (double)SHAStatusHeight();
}


/*
 * Một số iOS 16 dùng metric mặc định theo orientation.
 */

- (double)defaultStatusBarHeightForOrientation:(long long)orientation
{
    double original =
        %orig(orientation);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

    return (double)SHAStatusHeight();
}


/*
 * ============================================================
 *
 * HOME BAR
 *
 * BOTTOM luôn neo ở đáy.
 *
 * HEIGHT = giá trị nhập.
 *
 * 0 px:
 *     vùng Home Bar gần như bằng 0.
 *     Nội dung được phép tụt xuống sát đáy.
 *
 * 30 px:
 *     mặc định.
 *
 * 60 / 90 / 120 px:
 *     vùng Home Bar tăng lên.
 *     Nội dung phía trên được layout theo mép trên mới.
 *
 * Không thay đổi gesture recognizer.
 * Không scale Home Indicator.
 *
 * ============================================================
 */

- (double)homeAffordanceOverlayAllowance
{
    if (!SHAIsPortrait())
        return %orig;

    return (double)SHAHomeHeight();
}


%end

%end


#pragma mark -
#pragma mark _UIStatusBar

@interface _UIStatusBar : NSObject
+ (double)heightForOrientation:(long long)orientation;
@end


%group SHAStatusBar

%hook _UIStatusBar

+ (double)heightForOrientation:(long long)orientation
{
    double original =
        %orig(orientation);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

    return (double)SHAStatusHeight();
}

%end

%end


#pragma mark -
#pragma mark Home Bar Visual

/*
 * Không thay frame/bounds/transform của SBHomeGrabberView.
 *
 * Mục đích của hook này chỉ là giữ Home Indicator visual
 * không bị resize/scale khi thay đổi metric.
 */

@interface SBHomeGrabberView : UIView
@end


%group SHASpringBoard

%hook SBHomeGrabberView

- (void)layoutSubviews
{
    %orig;

    /*
     * Landscape hoàn toàn bỏ qua.
     */

    if (!SHAIsPortrait())
        return;

    /*
     * Không đụng frame.
     * Không đụng bounds.
     * Không đụng transform.
     *
     * Home Bar height được điều khiển bằng scene metric.
     */

    UIView *pill = nil;

    @try
    {
        pill = [self valueForKey:@"_pillView"];
    }
    @catch (__unused NSException *exception)
    {
        pill = nil;
    }

    if (!pill)
        return;

    /*
     * Khi Home Bar = 0:
     * ẩn phần visual pill.
     *
     * Gesture system không bị hook.
     */

    if (SHAHomeHeight() <= 0.0)
    {
        pill.hidden = YES;
    }
    else
    {
        pill.hidden = NO;
    }
}

%end

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
             * Yêu cầu UIKit/SpringBoard layout lại.
             *
             * Không tự thay frame/bounds của cửa sổ.
             */

            for (UIScene *scene in application.connectedScenes)
            {
                if (![scene isKindOfClass:[UIWindowScene class]])
                    continue;

                UIWindowScene *windowScene =
                    (UIWindowScene *)scene;

                for (UIWindow *window in windowScene.windows)
                {
                    [window setNeedsLayout];
                    [window setNeedsUpdateConstraints];
                }
            }


            /*
             * Refresh Home Grabber.
             */

            Class grabberClass =
                NSClassFromString(@"SBHomeGrabberView");

            if (!grabberClass)
                return;

            for (UIScene *scene in application.connectedScenes)
            {
                if (![scene isKindOfClass:[UIWindowScene class]])
                    continue;

                UIWindowScene *windowScene =
                    (UIWindowScene *)scene;

                for (UIWindow *window in windowScene.windows)
                {
                    NSMutableArray *queue =
                        [NSMutableArray array];

                    [queue addObject:window];

                    while (queue.count > 0)
                    {
                        UIView *view =
                            [queue lastObject];

                        [queue removeLastObject];

                        if ([view isKindOfClass:grabberClass])
                        {
                            [view setNeedsLayout];
                        }

                        for (UIView *subview in view.subviews)
                        {
                            [queue addObject:subview];
                        }
                    }
                }
            }
        }
    );
}


#pragma mark -
#pragma mark Darwin Notification

static void SHASettingsChanged(int token)
{
    (void)token;

    SHARefreshUI();
}


#pragma mark -
#pragma mark Constructor

%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];

    if (!bundleID)
        return;


    BOOL springBoard =
        [bundleID isEqualToString:@"com.apple.springboard"];

    BOOL uiKit =
        [bundleID isEqualToString:@"com.apple.UIKit"];


    /*
     * Chỉ load ở UIKit/SpringBoard.
     */

    if (!springBoard && !uiKit)
        return;


    /*
     * UIKit scene metrics.
     */

    if (uiKit)
    {
        %init(SHAUIKitMetrics);
        %init(SHAStatusBar);
    }


    /*
     * SpringBoard Home Bar visual.
     */

    if (springBoard)
    {
        %init(SHASpringBoard);
    }


    /*
     * Preferences thay đổi.
     */

    int token = 0;

    notify_register_dispatch(
        kSHASettingsChanged,
        &token,
        dispatch_get_main_queue(),
        ^(int changedToken)
        {
            SHASettingsChanged(changedToken);
        }
    );
}
