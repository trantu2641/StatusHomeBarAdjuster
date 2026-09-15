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


static CGFloat SHAStatusHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:SHA_PREFS_SUITE];

    id value =
        [defaults objectForKey:SHA_STATUS_KEY];

    NSInteger result = 30;

    if ([value respondsToSelector:@selector(integerValue)])
        result = [value integerValue];

    result = MAX(0, MIN(120, result));

    return (CGFloat)result;
}


static CGFloat SHAHomeHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:SHA_PREFS_SUITE];

    id value =
        [defaults objectForKey:SHA_HOME_KEY];

    NSInteger result = 30;

    if ([value respondsToSelector:@selector(integerValue)])
        result = [value integerValue];

    result = MAX(0, MIN(120, result));

    return (CGFloat)result;
}


#pragma mark -
#pragma mark Orientation

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


%hook UIApplicationSceneSettings


- (double)statusBarHeight
{
    double original =
        %orig;

    if (!SHAIsPortrait())
        return original;

    return SHAStatusHeight();
}


- (double)defaultStatusBarHeightForOrientation:
    (NSInteger)orientation
{
    double original =
        %orig(orientation);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

    return SHAStatusHeight();
}


- (UIEdgeInsets)safeAreaInsetsPortrait
{
    UIEdgeInsets original =
        %orig;

    if (!SHAIsPortrait())
        return original;

    original.top =
        SHAStatusHeight();

    original.bottom =
        SHAHomeHeight();

    return original;
}


- (UIEdgeInsets)safeAreaInsetsPortraitUpsideDown
{
    UIEdgeInsets original =
        %orig;

    if (!SHAIsPortrait())
        return original;

    original.top =
        SHAStatusHeight();

    original.bottom =
        SHAHomeHeight();

    return original;
}


- (double)homeAffordanceOverlayAllowance
{
    double original =
        %orig;

    if (!SHAIsPortrait())
        return original;

    return SHAHomeHeight();
}


- (CGRect)statusBarAvoidanceFrame
{
    CGRect original =
        %orig;

    if (!SHAIsPortrait())
        return original;

    original.origin.y = 0.0;
    original.size.height =
        SHAStatusHeight();

    return original;
}


%end


#pragma mark -
#pragma mark _UIStatusBar

@interface _UIStatusBar : UIView
@end


%hook _UIStatusBar


+ (double)heightForOrientation:
    (NSInteger)orientation
{
    double original =
        %orig(orientation);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

    return SHAStatusHeight();
}


+ (CGSize)intrinsicContentSizeForTargetScreen:
    (UIScreen *)screen
    orientation:(NSInteger)orientation
    onLockScreen:(BOOL)lockScreen
{
    CGSize original =
        %orig(screen,
              orientation,
              lockScreen);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

    original.height =
        SHAStatusHeight();

    return original;
}


+ (CGSize)intrinsicContentSizeForTargetScreen:
    (UIScreen *)screen
    orientation:(NSInteger)orientation
    onLockScreen:(BOOL)lockScreen
    isAzulBLinked:(BOOL)linked
{
    CGSize original =
        %orig(screen,
              orientation,
              lockScreen,
              linked);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

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

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

    original.height =
        SHAStatusHeight();

    return original;
}


%end


#pragma mark -
#pragma mark Status Bar Split Provider

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

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

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

@end


%hook SBHomeGrabberView


- (CGRect)grabberFrameForBounds:
    (CGRect)bounds
{
    CGRect original =
        %orig(bounds);

    if (!SHAIsPortrait())
        return original;

    CGFloat height =
        SHAHomeHeight();

    /*
     * Home Bar bottom luôn cố định.
     */
    CGFloat bottom =
        CGRectGetMaxY(bounds);

    /*
     * 0 = collapse.
     */
    if (height <= 0.0)
    {
        original.origin.y =
            bottom;

        original.size.height =
            0.0;

        return original;
    }

    /*
     * Top thay đổi.
     * Bottom cố định.
     */
    original.origin.y =
        bottom - height;

    original.size.height =
        height;

    return original;
}


- (CGSize)suggestedSizeForContentWidth:
    (CGFloat)width
{
    CGSize original =
        %orig(width);

    if (!SHAIsPortrait())
        return original;

    original.height =
        SHAHomeHeight();

    return original;
}


%end


#pragma mark -
#pragma mark Home Grabber Rotation Wrapper

@interface SBHomeGrabberRotationView : UIView

- (UIView *)grabberView;

@end


%hook SBHomeGrabberRotationView


- (void)layoutSubviews
{
    %orig;

    if (!SHAIsPortrait())
        return;


    UIView *grabber =
        [self grabberView];

    if (!grabber)
        return;


    CGFloat requested =
        SHAHomeHeight();


    /*
     * Lấy geometry mà wrapper vừa layout.
     */
    CGRect frame =
        grabber.frame;


    /*
     * Không đổi X.
     * Không đổi Width.
     *
     * Bottom cố định theo wrapper.
     */
    CGFloat bottom =
        CGRectGetMaxY(self.bounds);


    if (requested <= 0.0)
    {
        frame.origin.y =
            bottom;

        frame.size.height =
            0.0;
    }
    else
    {
        frame.origin.y =
            bottom - requested;

        frame.size.height =
            requested;
    }


    /*
     * Chỉ chỉnh geometry của grabber
     * sau khi wrapper đã hoàn tất layout.
     *
     * Không transform.
     * Không layer transform.
     */
    grabber.frame =
        frame;
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
             * Force scene metrics/layout.
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
                }
            }


            /*
             * Home Grabber rotation views.
             */
            Class rotationClass =
                NSClassFromString(
                    @"SBHomeGrabberRotationView"
                );

            if (!rotationClass)
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


                    while (stack.count)
                    {
                        UIView *view =
                            stack.lastObject;

                        [stack removeLastObject];


                        if ([view isKindOfClass:
                                rotationClass])
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
