#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>

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
        [[NSUserDefaults alloc] initWithSuiteName:SHA_PREFS_SUITE];

    if (![defaults objectForKey:SHA_STATUS_KEY])
        return 30.0;

    NSInteger value =
        [defaults integerForKey:SHA_STATUS_KEY];

    return (CGFloat)MAX(0, MIN(120, value));
}

static CGFloat SHAHomeHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:SHA_PREFS_SUITE];

    if (![defaults objectForKey:SHA_HOME_KEY])
        return 30.0;

    NSInteger value =
        [defaults integerForKey:SHA_HOME_KEY];

    return (CGFloat)MAX(0, MIN(120, value));
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
    double original = %orig;

    if (!SHAIsPortrait())
        return original;

    return SHAStatusHeight();
}

- (double)defaultStatusBarHeightForOrientation:(NSInteger)orientation
{
    double original = %orig(orientation);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

    return SHAStatusHeight();
}

- (double)homeAffordanceOverlayAllowance
{
    double original = %orig;

    if (!SHAIsPortrait())
        return original;

    return SHAHomeHeight();
}

%end


#pragma mark -
#pragma mark _UIStatusBar

@interface _UIStatusBar : UIView
+ (double)heightForOrientation:(NSInteger)orientation;
@end

%hook _UIStatusBar

+ (double)heightForOrientation:(NSInteger)orientation
{
    double original = %orig(orientation);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return original;
    }

    return SHAStatusHeight();
}

%end


#pragma mark -
#pragma mark Home Bar

@interface SBHomeGrabberView : UIView
@end

%hook SBHomeGrabberView

- (void)layoutSubviews
{
    %orig;

    if (!SHAIsPortrait())
        return;

    UIView *pill = nil;

    @try
    {
        pill = [self valueForKey:@"_pillView"];
    }
    @catch (__unused NSException *exception)
    {
        return;
    }

    if (!pill)
        return;

    /*
     * Chỉ ẩn indicator khi Home Bar = 0.
     *
     * Không scale pill.
     * Không sửa frame.
     * Không sửa bounds.
     * Không sửa transform.
     * Không đụng gesture.
     */
    pill.hidden = (SHAHomeHeight() <= 0.0);
}

%end


#pragma mark -
#pragma mark Safe Area

%hook UIView

- (UIEdgeInsets)safeAreaInsets
{
    UIEdgeInsets original = %orig;

    if (!SHAIsPortrait())
        return original;

    /*
     * Không can thiệp chính Home Grabber.
     */
    if ([self isKindOfClass:
            NSClassFromString(@"SBHomeGrabberView")])
    {
        return original;
    }

    CGFloat homeHeight = SHAHomeHeight();

    if (homeHeight <= 0.0)
    {
        original.bottom = 0.0;
        return original;
    }

    if (original.bottom > 0.0)
        original.bottom = homeHeight;

    return original;
}

%end


#pragma mark -
#pragma mark UIWindow

%hook UIWindow

- (UIEdgeInsets)safeAreaInsets
{
    UIEdgeInsets original = %orig;

    if (!SHAIsPortrait())
        return original;

    CGFloat homeHeight = SHAHomeHeight();

    if (homeHeight <= 0.0)
    {
        original.bottom = 0.0;
        return original;
    }

    if (original.bottom > 0.0)
        original.bottom = homeHeight;

    return original;
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

                    [window.rootViewController
                        viewSafeAreaInsetsDidChange];
                }
            }

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
                    NSMutableArray *stack =
                        [NSMutableArray arrayWithObject:window];

                    while (stack.count)
                    {
                        UIView *view =
                            [stack lastObject];

                        [stack removeLastObject];

                        if ([view isKindOfClass:grabberClass])
                        {
                            [view setNeedsLayout];
                        }

                        for (UIView *subview in view.subviews)
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
        [[NSBundle mainBundle] bundleIdentifier];

    if (!bundleIdentifier)
        return;

    /*
     * Tweak chỉ chạy trong SpringBoard.
     *
     * Đây là nơi chứa:
     * _UIStatusBar
     * UIApplicationSceneSettings
     * SBHomeGrabberView
     */
    if (![bundleIdentifier
            isEqualToString:@"com.apple.springboard"])
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
