#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

static CGFloat SHAStatusOffset = 0.0;
static CGFloat SHAHomeOffset = 0.0;

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

#pragma mark - Status Bar

static void SHA_MoveStatusBar(UIView *view)
{
    if (!view)
        return;

    if (SHAStatusOffset == 0.0)
        return;

    CGRect frame = view.frame;

    frame.origin.y += SHAStatusOffset;

    view.frame = frame;
}

#pragma mark - Home Bar

static void SHA_MoveHomeBar(UIView *view)
{
    if (!view)
        return;

    if (SHAHomeOffset == 0.0)
        return;

    CGRect frame = view.frame;

    frame.origin.y += SHAHomeOffset;

    view.frame = frame;
}

#pragma mark - Recursive Home Search

static void SHA_FindHomeBar(UIView *view)
{
    if (!view)
        return;

    NSString *name =
        NSStringFromClass([view class]);

    if (name)
    {
        BOOL found =
            ([name rangeOfString:@"HomeIndicator"
                          options:NSCaseInsensitiveSearch].location
                != NSNotFound);

        if (!found)
        {
            found =
                ([name rangeOfString:@"HomeBar"
                              options:NSCaseInsensitiveSearch].location
                    != NSNotFound);
        }

        if (!found)
        {
            found =
                ([name rangeOfString:@"LumaDodgePill"
                              options:NSCaseInsensitiveSearch].location
                    != NSNotFound);
        }

        if (found)
        {
            CGRect frame = view.frame;

            if (frame.size.height > 1.0 &&
                frame.size.height < 100.0)
            {
                SHA_MoveHomeBar(view);
            }
        }
    }

    NSArray *children =
        [view.subviews copy];

    for (UIView *child in children)
    {
        SHA_FindHomeBar(child);
    }
}

#pragma mark - Scene Scan

static void SHA_ScanSpringBoardWindows(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIApplication *app =
                [UIApplication sharedApplication];

            if (!app)
                return;

            if (@available(iOS 13.0, *))
            {
                for (UIScene *scene
                     in app.connectedScenes)
                {
                    if (![scene
                            isKindOfClass:[UIWindowScene class]])
                    {
                        continue;
                    }

                    UIWindowScene *sceneWindow =
                        (UIWindowScene *)scene;

                    for (UIWindow *window
                         in sceneWindow.windows)
                    {
                        if (!window)
                            continue;

                        if (SHAHomeOffset != 0.0)
                        {
                            SHA_FindHomeBar(window);
                        }
                    }
                }
            }
        }
    );
}

#pragma mark - _UIStatusBar

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_MoveStatusBar((UIView *)self);
}

%end

#pragma mark - UIStatusBar

%hook UIStatusBar

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_MoveStatusBar((UIView *)self);
}

%end

#pragma mark - SB Status Bar

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_MoveStatusBar((UIView *)self);
}

%end

#pragma mark - Home Indicator

%hook _UIHomeIndicatorView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    SHA_MoveHomeBar((UIView *)self);
}

%end

#pragma mark - Home Indicator Container

%hook _UIHomeIndicatorViewController

- (void)viewDidLayoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAHomeOffset != 0.0)
    {
        UIView *view = self.view;

        if (view)
        {
            CGRect frame = view.frame;

            frame.origin.y += SHAHomeOffset;

            view.frame = frame;
        }
    }
}

%end

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

    SHA_ScanSpringBoardWindows();
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
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
