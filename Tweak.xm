#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

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
        }
    }

    return NO;
}

#pragma mark - Original Frame

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
        return [stored CGRectValue];

    CGRect frame =
        view.frame;

    [SHAOriginalFrames
        setObject:[NSValue valueWithCGRect:frame]
        forKey:view];

    return frame;
}

#pragma mark - Move Visual Only

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

    NSString *className =
        NSStringFromClass([view class]);

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

#pragma mark - Settings Changed

static void SHA_SettingsChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SHA_LoadPreferences();
}

#pragma mark - Home Bar Hooks

%hook MTLumaDodgePillView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
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

    SHA_ApplyHomeBar(
        (UIView *)self
    );
}

%end

#pragma mark - Status Bar Hooks

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
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

    SHA_ApplyStatusBar(
        (UIView *)self
    );
}

%end


%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (!SHA_IsPortrait())
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
