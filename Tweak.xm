#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>


#pragma mark -
#pragma mark Constants

static NSString * const SHA_PREFS_SUITE =
    @"com.congtu.statushomebaradjuster";

static NSString * const SHA_STATUS_KEY =
    @"StatusBarHeight";

static NSString * const SHA_HOME_KEY =
    @"HomeBarHeight";

static const NSInteger SHA_MIN_VALUE = 0;
static const NSInteger SHA_MAX_VALUE = 120;

static const CGFloat SHA_DEFAULT_STATUS_HEIGHT = 30.0;
static const CGFloat SHA_DEFAULT_HOME_HEIGHT = 30.0;

static const char *SHA_SETTINGS_CHANGED =
    "com.congtu.statushomebaradjuster.settingsChanged";


#pragma mark -
#pragma mark Preferences

static CGFloat SHAStatusBarHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:SHA_PREFS_SUITE];

    if (![defaults objectForKey:SHA_STATUS_KEY])
        return SHA_DEFAULT_STATUS_HEIGHT;

    NSInteger value =
        [defaults integerForKey:SHA_STATUS_KEY];

    value = MAX(SHA_MIN_VALUE,
                MIN(SHA_MAX_VALUE, value));

    return (CGFloat)value;
}


static CGFloat SHAHomeBarHeight(void)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:SHA_PREFS_SUITE];

    if (![defaults objectForKey:SHA_HOME_KEY])
        return SHA_DEFAULT_HOME_HEIGHT;

    NSInteger value =
        [defaults integerForKey:SHA_HOME_KEY];

    value = MAX(SHA_MIN_VALUE,
                MIN(SHA_MAX_VALUE, value));

    return (CGFloat)value;
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
#pragma mark UIApplicationSceneSettings

@interface UIApplicationSceneSettings : NSObject
@end


%group SHAUIKitSceneSettings

%hook UIApplicationSceneSettings


/*
 ============================================================
 STATUS BAR
 ============================================================

 Giá trị chính là HEIGHT.

 0   = ẩn
 30  = mặc định
 60  = cao 60 px
 90  = cao 90 px
 120 = cao 120 px

 Không scale icon.
 */

- (double)statusBarHeight
{
    double original = %orig;

    if (!SHAIsPortrait())
        return original;

    return (double)SHAStatusBarHeight();
}


/*
 Một số phiên bản UIKit lấy chiều cao mặc định
 theo orientation.
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
 ============================================================
 HOME BAR
 ============================================================

 0   = vùng Home Bar gần như bằng 0
 30  = mặc định
 60  = cao 60 px
 90  = cao 90 px
 120 = cao 120 px

 BOTTOM được hệ thống giữ ở đáy.
 */

- (double)homeAffordanceOverlayAllowance
{
    double original = %orig;

    if (!SHAIsPortrait())
        return original;

    return (double)SHAHomeBarHeight();
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

    return (double)SHAStatusBarHeight();
}


%end

%end


#pragma mark -
#pragma mark Home Bar

@interface SBHomeGrabberView : UIView
@end


%group SHASpringBoard

%hook SBHomeGrabberView


- (void)layoutSubviews
{
    %orig;

    /*
     * Landscape: hoàn toàn không làm gì.
     */

    if (!SHAIsPortrait())
        return;


    /*
     * KHÔNG sửa:
     *
     * frame
     * bounds
     * center
     * transform
     * layer.transform
     *
     * của SBHomeGrabberView.
     *
     * Điều này tránh vòng lặp layout và black screen.
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
     * Chỉ xử lý trạng thái visual ở mức 0.
     *
     * Không thay đổi gesture.
     */

    if (SHAHomeBarHeight() <= 0.0)
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
             * Yêu cầu các window layout lại.
             *
             * Không tự sửa frame/bounds.
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
             * Yêu cầu Home Grabber layout lại.
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


    BOOL isSpringBoard =
        [bundleIdentifier
            isEqualToString:@"com.apple.springboard"];

    BOOL isUIKit =
        [bundleIdentifier
            isEqualToString:@"com.apple.UIKit"];


    /*
     * Không inject vào app thông thường.
     */

    if (!isSpringBoard && !isUIKit)
        return;


    /*
     * UIKit metrics.
     */

    if (isUIKit)
    {
        %init(SHAUIKitSceneSettings);
        %init(SHAStatusBar);
    }


    /*
     * SpringBoard Home Bar.
     */

    if (isSpringBoard)
    {
        %init(SHASpringBoard);
    }


    /*
     * Preferences notification.
     */

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
