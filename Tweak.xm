#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>

#pragma mark -
#pragma mark Constants

static NSString * const SHA_PREFS_SUITE =
    @"com.congtu.statushomebaradjuster";

static NSString * const SHA_STATUS_KEY =
    @"StatusBarHeight";

static NSString * const SHA_HOME_KEY =
    @"HomeBarHeight";

static NSString * const SHA_CHANGED_NOTIFICATION =
    @"com.congtu.statushomebaradjuster.settingsChanged";


#pragma mark -
#pragma mark Helpers

static CGFloat SHAClampHeight(NSInteger value)
{
    if (value < 0)
        return 0.0;

    if (value > 120)
        return 120.0;

    return (CGFloat)value;
}


static CGFloat SHAStatusBarHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:SHA_PREFS_SUITE];

    if (![defaults objectForKey:SHA_STATUS_KEY])
        return 30.0;

    return SHAClampHeight(
        [defaults integerForKey:SHA_STATUS_KEY]
    );
}


static CGFloat SHAHomeBarHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:SHA_PREFS_SUITE];

    if (![defaults objectForKey:SHA_HOME_KEY])
        return 30.0;

    return SHAClampHeight(
        [defaults integerForKey:SHA_HOME_KEY]
    );
}


static BOOL SHAPortraitOrientation(void)
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

        if (windowScene.activationState ==
            UISceneActivationStateUnattached)
        {
            continue;
        }

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
#pragma mark UIKit Scene Settings

/*
 *
 *  iOS scene metrics
 *
 *  Status Bar:
 *
 *      TOP
 *      ┌─────────────────────┐
 *      │                     │
 *      │       STATUS        │
 *      │                     │
 *      └─────────────────────┘
 *             BOTTOM
 *
 *  BOTTOM remains the content boundary.
 *  Increasing the height moves the boundary downward.
 *
 *
 *  Home Bar:
 *
 *      ┌─────────────────────┐
 *      │                     │
 *      │       CONTENT       │
 *      │                     │
 *      ├─────────────────────┤ ← TOP
 *      │      HOME BAR       │
 *      │                     │
 *      └─────────────────────┘ ← BOTTOM FIXED
 *
 *  Increasing Home Bar height moves TOP upward.
 *
 */

@interface UIApplicationSceneSettings : NSObject
@end


%group SHAUIKitSceneMetrics

%hook UIApplicationSceneSettings


/*
 * Home Bar / Home Affordance height.
 *
 * 0 px   = content can reach the bottom
 * 30 px  = normal reference
 * 60 px  = 60 px reserved visual/content region
 * 120 px = maximum
 */

- (double)homeAffordanceOverlayAllowance
{
    double original = %orig;

    if (!SHAPortraitOrientation())
        return original;

    return (double)SHAHomeBarHeight();
}


/*
 * Status Bar height.
 */

- (double)statusBarHeight
{
    double original = %orig;

    if (!SHAPortraitOrientation())
        return original;

    return (double)SHAStatusBarHeight();
}


/*
 * Default Status Bar height for a particular orientation.
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

    return (double)SHAStatusBarHeight();
}


/*
 * Status Bar avoidance frame.
 *
 * TOP remains at 0.
 * BOTTOM changes according to the selected height.
 */

- (CGRect)statusBarAvoidanceFrame
{
    CGRect frame = %orig;

    if (!SHAPortraitOrientation())
        return frame;

    frame.origin.y = 0.0;
    frame.size.height = SHAStatusBarHeight();

    return frame;
}

%end

%end


#pragma mark -
#pragma mark _UIStatusBar metric

/*
 * This hook changes the reported Status Bar height.
 *
 * IMPORTANT:
 * We do NOT change:
 *
 *   - frame
 *   - bounds
 *   - transform
 *   - layer.transform
 *   - icon scale
 *
 * UIKit therefore gets the requested height as a layout metric.
 */

@interface _UIStatusBar : NSObject

+ (double)heightForOrientation:(long long)orientation;

@end


%group SHAStatusBarMetric

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

    return (double)SHAStatusBarHeight();
}

%end

%end


#pragma mark -
#pragma mark Home Grabber

/*
 * We deliberately DO NOT modify the frame/bounds/transform of:
 *
 *   SBHomeGrabberView
 *   MTLumaDodgePillView
 *   MTStaticColorPillView
 *
 * This avoids the black-screen problem caused by directly resizing
 * SpringBoard's Home Grabber hierarchy.
 *
 * At 0 px we only hide the visual pill.
 * Gesture handling itself is untouched.
 */

@interface SBHomeGrabberView : UIView
@end


%group SHASpringBoard

%hook SBHomeGrabberView

- (void)layoutSubviews
{
    %orig;

    if (!SHAPortraitOrientation())
        return;

    CGFloat height =
        SHAHomeBarHeight();

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
     * Never resize the pill.
     *
     * Only hide it when Home Bar = 0.
     */

    if (height <= 0.0)
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
#pragma mark Settings Refresh

static void SHARefreshWindows(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^
        {
            UIApplication *application =
                [UIApplication sharedApplication];

            if (!application)
                return;

            /*
             * Force UIKit to recalculate layouts using the
             * new scene metrics.
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
             * Refresh Home Grabber visual state.
             *
             * No frame/bounds/transform modification.
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
                    NSMutableArray *stack =
                        [NSMutableArray array];

                    [stack addObject:window];


                    while (stack.count > 0)
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
#pragma mark Darwin Notification

static void SHASettingsChanged(int token)
{
    (void)token;

    SHARefreshWindows();
}


#pragma mark -
#pragma mark Constructor

%ctor
{
    NSString *bundleIdentifier =
        [[NSBundle mainBundle] bundleIdentifier];

    if (!bundleIdentifier)
        return;


    BOOL isSpringBoard =
        [bundleIdentifier
            isEqualToString:@"com.apple.springboard"];

    BOOL isUIKit =
        [bundleIdentifier
            isEqualToString:@"com.apple.UIKit"];


    /*
     * Only SpringBoard / UIKit-related processes.
     */

    if (!isSpringBoard && !isUIKit)
        return;


    /*
     * UIKit scene metrics.
     */

    if (isUIKit)
    {
        %init(SHAUIKitSceneMetrics);
        %init(SHAStatusBarMetric);
    }


    /*
     * SpringBoard Home Grabber.
     */

    if (isSpringBoard)
    {
        %init(SHASpringBoard);
    }


    /*
     * Listen for Preference changes.
     */

    int token = 0;

    notify_register_dispatch(
        SHA_CHANGED_NOTIFICATION.UTF8String,
        &token,
        dispatch_get_main_queue(),
        ^(int changedToken)
        {
            SHASettingsChanged(changedToken);
        }
    );
}
