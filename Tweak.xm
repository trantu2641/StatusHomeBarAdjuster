#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>
#import <objc/message.h>

static NSString * const kPrefsSuite =
    @"com.congtu.statushomebaradjuster";

static NSString * const kStatusKey =
    @"StatusBarOffset";

static NSString * const kHomeKey =
    @"HomeBarOffset";

static NSString * const kChangedDarwin =
    @"com.congtu.statushomebaradjuster.settingsChanged";

static CGFloat gStatusBarOffset = 0.0;
static CGFloat gHomeBarOffset = 0.0;

#pragma mark -
#pragma mark Preferences
#pragma mark -

static CGFloat SHAReadNumber(CFPropertyListRef value)
{
    if (!value)
        return 0.0;

    if (CFGetTypeID(value) == CFNumberGetTypeID())
    {
        double number = 0.0;

        if (CFNumberGetValue(
                (CFNumberRef)value,
                kCFNumberDoubleType,
                &number))
        {
            return (CGFloat)number;
        }
    }

    if (CFGetTypeID(value) == CFStringGetTypeID())
    {
        return (CGFloat)CFStringGetDoubleValue(
            (CFStringRef)value
        );
    }

    return 0.0;
}

static void SHAReadPreferences(void)
{
    CFStringRef suite =
        CFSTR("com.congtu.statushomebaradjuster");

    CFPreferencesAppSynchronize(suite);

    CFPropertyListRef status =
        CFPreferencesCopyAppValue(
            CFSTR("StatusBarOffset"),
            suite
        );

    CFPropertyListRef home =
        CFPreferencesCopyAppValue(
            CFSTR("HomeBarOffset"),
            suite
        );

    gStatusBarOffset = SHAReadNumber(status);
    gHomeBarOffset = SHAReadNumber(home);

    if (status)
        CFRelease(status);

    if (home)
        CFRelease(home);

    /*
     * BẢN 1.1.5 CŨ:
     *
     * StatusBarOffset >= -36
     *
     * Ta bỏ giới hạn -36 để Status Bar có thể đi xuống
     * tới 0 px.
     *
     * Giữ giới hạn trên +120 như bản gốc.
     */
    if (gStatusBarOffset < -120.0)
        gStatusBarOffset = -120.0;

    if (gStatusBarOffset > 120.0)
        gStatusBarOffset = 120.0;

    /*
     * Home Bar CHƯA ĐỤNG TỚI.
     *
     * Giữ nguyên giới hạn cũ.
     */
    if (gHomeBarOffset < -36.0)
        gHomeBarOffset = -36.0;

    if (gHomeBarOffset > 120.0)
        gHomeBarOffset = 120.0;
}

#pragma mark -
#pragma mark Portrait
#pragma mark -

static BOOL SHAPortrait(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    if (application)
    {
        NSSet *scenes = application.connectedScenes;

        for (UIScene *scene in scenes)
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
    }

    CGRect screenBounds =
        [UIScreen mainScreen].bounds;

    return screenBounds.size.height >=
           screenBounds.size.width;
}

#pragma mark -
#pragma mark Status Bar Transform
#pragma mark -

static void SHAApplyStatusBarTransform(UIView *view)
{
    if (!view)
        return;

    if (!SHAPortrait())
        return;

    CGRect bounds = view.bounds;

    CGFloat originalHeight =
        CGRectGetHeight(bounds);

    if (originalHeight <= 0.0)
        return;

    CGFloat offset =
        gStatusBarOffset;

    /*
     * Bản 1.1.5:
     *
     * targetHeight = originalHeight + offset
     *
     * Ví dụ với Status Bar 49 px:
     *
     * offset  0   -> 49
     * offset -19  -> 30
     * offset -30  -> 19
     * offset -49  -> 0
     */
    CGFloat targetHeight =
        originalHeight + offset;

    /*
     * Không cho chiều cao âm.
     */
    if (targetHeight < 0.0)
        targetHeight = 0.0;

    /*
     * Giữ đúng tinh thần bản 1.1.5:
     * scale tối đa 8 lần.
     *
     * Nhưng KHÔNG còn minimum 0.1.
     *
     * Đây là phần quan trọng để cho phép 0...30 px.
     */
    CGFloat scaleY =
        targetHeight / originalHeight;

    if (scaleY > 8.0)
        scaleY = 8.0;

    if (scaleY < 0.0)
        scaleY = 0.0;

    CATransform3D transform =
        CATransform3DMakeScale(
            1.0,
            scaleY,
            1.0
        );

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    view.layer.transform = transform;

    [CATransaction commit];
}

#pragma mark -
#pragma mark MTLumaDodgePillView
#pragma mark -

/*
 * Giữ hook này giống bản 1.1.5 để không phá cơ chế
 * đang hoạt động.
 *
 * Tuy nhiên trong phiên bản này KHÔNG thay đổi Home Bar.
 */
%hook MTLumaDodgePillView

- (void)didMoveToWindow
{
    %orig;

    /*
     * Home Bar tạm thời không xử lý.
     */
}

%end

#pragma mark -
#pragma mark MTStaticColorPillView
#pragma mark -

%hook MTStaticColorPillView

- (void)didMoveToWindow
{
    %orig;

    /*
     * Home Bar tạm thời không xử lý.
     */
}

%end

#pragma mark -
#pragma mark _UIStatusBar
#pragma mark -

%hook _UIStatusBar

- (void)didMoveToWindow
{
    %orig;

    SHAReadPreferences();

    SHAApplyStatusBarTransform(self);
}

%end

#pragma mark -
#pragma mark Preferences changed
#pragma mark -

static void SHASettingsChanged(int token)
{
    (void)token;

    SHAReadPreferences();

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIApplication *application =
                [UIApplication sharedApplication];

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

                        /*
                         * Chỉ xử lý _UIStatusBar.
                         *
                         * Home Bar chưa đụng.
                         */
                        if ([view isKindOfClass:
                             NSClassFromString(@"_UIStatusBar")])
                        {
                            SHAApplyStatusBarTransform(view);
                        }

                        for (UIView *subview in view.subviews)
                        {
                            [stack addObject:subview];
                        }
                    }

                    [window setNeedsLayout];
                }
            }
        }
    );
}

#pragma mark -
#pragma mark Constructor
#pragma mark -

%ctor
{
    NSString *bundleID =
        [NSBundle mainBundle].bundleIdentifier ?: @"";

    /*
     * Bản 1.1.5 inject SpringBoard.
     */
    if (![bundleID isEqualToString:
          @"com.apple.springboard"])
    {
        return;
    }

    SHAReadPreferences();

    int token = 0;

    notify_register_dispatch(
        kChangedDarwin.UTF8String,
        &token,
        dispatch_get_main_queue(),
        ^(int t)
        {
            SHASettingsChanged(t);
        }
    );
}
