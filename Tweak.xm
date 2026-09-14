#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

static CGFloat SHAStatusOffset = 0.0;
static CGFloat SHAHomeOffset = 0.0;

static NSMapTable *SHAOriginalFrames;

#pragma mark - Preferences

static void SHA_LoadPreferences(void)
{
    CFStringRef domain =
        CFSTR("com.congtu.statushomebaradjuster");

    CFPreferencesAppSynchronize(domain);

    CFPropertyListRef statusValue =
        CFPreferencesCopyAppValue(
            CFSTR("StatusBarOffset"),
            domain
        );

    CFPropertyListRef homeValue =
        CFPreferencesCopyAppValue(
            CFSTR("HomeBarOffset"),
            domain
        );

    SHAStatusOffset = 0.0;
    SHAHomeOffset = 0.0;

    if (statusValue &&
        CFGetTypeID(statusValue) == CFNumberGetTypeID())
    {
        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)statusValue,
            kCFNumberDoubleType,
            &value
        );

        value = MAX(-120.0, MIN(120.0, value));

        SHAStatusOffset = (CGFloat)value;
    }

    if (homeValue &&
        CFGetTypeID(homeValue) == CFNumberGetTypeID())
    {
        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)homeValue,
            kCFNumberDoubleType,
            &value
        );

        value = MAX(-120.0, MIN(120.0, value));

        SHAHomeOffset = (CGFloat)value;
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Orientation

static BOOL SHA_IsPortrait(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application)
        return NO;

    if (@available(iOS 13.0, *))
    {
        NSSet *scenes =
            application.connectedScenes;

        for (UIScene *scene in scenes)
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
        }
    }

    return NO;
}

#pragma mark - Original Frame Storage

static CGRect SHA_GetOriginalFrame(UIView *view)
{
    if (!view)
        return CGRectZero;

    if (!SHAOriginalFrames)
    {
        SHAOriginalFrames =
            [NSMapTable weakToStrongObjectsMapTable];
    }

    NSValue *stored =
        [SHAOriginalFrames objectForKey:view];

    if (stored)
    {
        return [stored CGRectValue];
    }

    CGRect frame =
        view.frame;

    [SHAOriginalFrames
        setObject:[NSValue valueWithCGRect:frame]
        forKey:view];

    return frame;
}

static void SHA_ResetOriginalFrame(UIView *view)
{
    if (!view || !SHAOriginalFrames)
        return;

    [SHAOriginalFrames removeObjectForKey:view];
}

#pragma mark - Apply Visual Offset

static void SHA_MoveViewVisual(
    UIView *view,
    CGFloat offset
)
{
    if (!view)
        return;

    CGRect original =
        SHA_GetOriginalFrame(view);

    CGRect frame =
        original;

    frame.origin.y =
        original.origin.y + offset;

    view.frame =
        frame;
}

#pragma mark - Home Bar Detection

static BOOL SHA_IsHomeBarView(UIView *view)
{
    if (!view)
        return NO;

    Class cls =
        object_getClass(view);

    if (!cls)
        return NO;

    NSString *className =
        NSStringFromClass(cls);

    if (!className)
        return NO;

    if ([className isEqualToString:@"MTLumaDodgePillView"])
    {
        return YES;
    }

    if ([className isEqualToString:@"MTStaticColorPillView"])
    {
        return YES;
    }

    return NO;
}

#pragma mark - Home Bar

static void SHA_ApplyHomeBar(UIView *view)
{
    if (!view)
        return;

    if (!SHA_IsPortrait())
        return;

    SHA_MoveViewVisual(
        view,
        SHAHomeOffset
    );
}

#pragma mark - Status Bar Detection

static BOOL SHA_IsStatusBarView(UIView *view)
{
    if (!view)
        return NO;

    NSString *name =
        NSStringFromClass([view class]);

    if (!name)
        return NO;

    if ([name isEqualToString:
            @"SBMainDisplaySceneLayoutStatusBarView"])
    {
        return YES;
    }

    if ([name isEqualToString:@"_UIStatusBar"])
    {
        return YES;
    }

    if ([name isEqualToString:@"UIStatusBar"])
    {
        return YES;
    }

    if ([name isEqualToString:@"UIStatusBar_Modern"])
    {
        return YES;
    }

    return NO;
}

#pragma mark - Status Bar

static void SHA_ApplyStatusBar(UIView *view)
{
    if (!view)
        return;

    if (!SHA_IsPortrait())
        return;

    SHA_MoveViewVisual(
        view,
        SHAStatusOffset
    );
}

#pragma mark - Settings Notification

static void SHA_SettingsChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SHA_LoadPreferences();

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            /*
             * UIKit/SpringBoard sẽ tự layout lại.
             * Các hook layoutSubviews sẽ áp dụng
             * offset mới ngay sau đó.
             */
        }
    );
}

#pragma mark - UIKit Home Bar

%hook MTLumaDodgePillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAHomeOffset == 0.0)
        return;

    SHA_ApplyHomeBar(
        (UIView *)self
    );
}

%end

%hook MTStaticColorPillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAHomeOffset == 0.0)
        return;

    SHA_ApplyHomeBar(
        (UIView *)self
    );
}

%end

#pragma mark - UIKit Window

%hook UIWindow

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    /*
     * Tìm Home Bar visual trong UIWindow.
     *
     * Không thay đổi:
     * safeAreaInsets
     * gesture
     * hitTest
     */

    NSArray *subviews =
        [[self subviews] copy];

    for (UIView *view in subviews)
    {
        NSString *name =
            NSStringFromClass([view class]);

        if ([name isEqualToString:@"MTLumaDodgePillView"] ||
            [name isEqualToString:@"MTStaticColorPillView"])
        {
            SHA_ApplyHomeBar(view);
        }
    }
}

%end

#pragma mark - UIKit Status Bar

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAStatusOffset == 0.0)
        return;

    SHA_ApplyStatusBar(
        (UIView *)self
    );
}

%end

%hook UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAStatusOffset == 0.0)
        return;

    SHA_ApplyStatusBar(
        (UIView *)self
    );
}

%end

#pragma mark - SpringBoard Status Bar

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
        return;

    if (SHAStatusOffset == 0.0)
        return;

    SHA_ApplyStatusBar(
        (UIView *)self
    );
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        SHAOriginalFrames =
            [NSMapTable weakToStrongObjectsMapTable];

        SHA_LoadPreferences();

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            SHA_SettingsChanged,
            CFSTR(
                "com.congtu.statushomebaradjuster.settingsChanged"
            ),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }
}
