```objc
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

        if (value < -120.0)
            value = -120.0;

        if (value > 120.0)
            value = 120.0;

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

        if (value < -120.0)
            value = -120.0;

        if (value > 120.0)
            value = 120.0;

        SHAHomeOffset = (CGFloat)value;
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Original Frames

static void SHA_SaveOriginalFrame(UIView *view)
{
    if (!view)
        return;

    if (!SHAOriginalFrames)
    {
        SHAOriginalFrames =
            [NSMapTable
                weakToStrongObjectsMapTable];
    }

    if (![SHAOriginalFrames objectForKey:view])
    {
        [SHAOriginalFrames
            setObject:
                [NSValue valueWithCGRect:view.frame]
            forKey:view];
    }
}

static CGRect SHA_OriginalFrame(UIView *view)
{
    if (!view)
        return CGRectZero;

    SHA_SaveOriginalFrame(view);

    NSValue *value =
        [SHAOriginalFrames objectForKey:view];

    if (!value)
        return view.frame;

    return [value CGRectValue];
}

#pragma mark - Class Name

static NSString *SHA_ClassName(UIView *view)
{
    if (!view)
        return @"";

    NSString *name =
        NSStringFromClass([view class]);

    return name ?: @"";
}

static BOOL SHA_NameContains(
    UIView *view,
    NSString *text
)
{
    NSString *name =
        SHA_ClassName(view);

    return
        [name rangeOfString:text
                    options:NSCaseInsensitiveSearch].location
        != NSNotFound;
}

#pragma mark - Status Container Detection

static BOOL SHA_IsKnownStatusContainer(
    UIView *view
)
{
    if (!view)
        return NO;

    NSString *name =
        SHA_ClassName(view);

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

    if ([name rangeOfString:@"StatusBar"
                     options:NSCaseInsensitiveSearch].location
        != NSNotFound)
    {
        return YES;
    }

    return NO;
}

#pragma mark - Home Container Detection

static BOOL SHA_IsKnownHomeContainer(
    UIView *view
)
{
    if (!view)
        return NO;

    NSString *name =
        SHA_ClassName(view);

    if ([name rangeOfString:@"HomeIndicator"
                     options:NSCaseInsensitiveSearch].location
        != NSNotFound)
    {
        return YES;
    }

    if ([name rangeOfString:@"HomeBar"
                     options:NSCaseInsensitiveSearch].location
        != NSNotFound)
    {
        return YES;
    }

    if ([name rangeOfString:@"LumaDodgePill"
                     options:NSCaseInsensitiveSearch].location
        != NSNotFound)
    {
        return YES;
    }

    if ([name rangeOfString:@"Gesture"
                     options:NSCaseInsensitiveSearch].location
        != NSNotFound &&
        [name rangeOfString:@"Indicator"
                     options:NSCaseInsensitiveSearch].location
        != NSNotFound)
    {
        return YES;
    }

    return NO;
}

#pragma mark - Move Whole View

static void SHA_SetOffset(
    UIView *view,
    CGFloat offset
)
{
    if (!view || offset == 0.0)
        return;

    CGRect original =
        SHA_OriginalFrame(view);

    CGRect newFrame =
        original;

    newFrame.origin.y =
        original.origin.y + offset;

    view.frame = newFrame;
}

#pragma mark - Find Status Containers

static void SHA_FindStatusContainers(
    UIView *root,
    NSMutableArray *result
)
{
    if (!root)
        return;

    if (SHA_IsKnownStatusContainer(root))
    {
        CGRect frame =
            root.frame;

        /*
         * Status Bar container phải tương đối
         * gần phía trên màn hình.
         */

        if (frame.size.height >= 10.0 &&
            frame.size.height <= 150.0)
        {
            [result addObject:root];
        }
    }

    NSArray *children =
        [root.subviews copy];

    for (UIView *child in children)
    {
        SHA_FindStatusContainers(
            child,
            result
        );
    }
}

#pragma mark - Find Home Containers

static void SHA_FindHomeContainers(
    UIView *root,
    NSMutableArray *result
)
{
    if (!root)
        return;

    if (SHA_IsKnownHomeContainer(root))
    {
        CGRect frame =
            root.frame;

        if (frame.size.height >= 5.0 &&
            frame.size.height <= 250.0)
        {
            [result addObject:root];
        }
    }

    NSArray *children =
        [root.subviews copy];

    for (UIView *child in children)
    {
        SHA_FindHomeContainers(
            child,
            result
        );
    }
}

#pragma mark - Apply Status

static void SHA_ApplyStatusToWindow(
    UIWindow *window
)
{
    if (!window ||
        SHAStatusOffset == 0.0)
        return;

    NSMutableArray *views =
        [NSMutableArray array];

    SHA_FindStatusContainers(
        window,
        views
    );

    /*
     * Nếu tìm được nhiều tầng Status Bar,
     * ưu tiên container ngoài cùng.
     */

    for (UIView *view in views)
    {
        UIView *parent =
            view.superview;

        BOOL hasStatusParent = NO;

        while (parent &&
               parent != window)
        {
            if (SHA_IsKnownStatusContainer(parent))
            {
                hasStatusParent = YES;
                break;
            }

            parent =
                parent.superview;
        }

        if (!hasStatusParent)
        {
            SHA_SetOffset(
                view,
                SHAStatusOffset
            );
        }
    }
}

#pragma mark - Apply Home

static void SHA_ApplyHomeToWindow(
    UIWindow *window
)
{
    if (!window ||
        SHAHomeOffset == 0.0)
        return;

    NSMutableArray *views =
        [NSMutableArray array];

    SHA_FindHomeContainers(
        window,
        views
    );

    /*
     * Với Home Bar, chọn container ngoài cùng
     * có chứa Home Indicator.
     */

    for (UIView *view in views)
    {
        UIView *parent =
            view.superview;

        BOOL hasHomeParent = NO;

        while (parent &&
               parent != window)
        {
            if (SHA_IsKnownHomeContainer(parent))
            {
                hasHomeParent = YES;
                break;
            }

            parent =
                parent.superview;
        }

        if (!hasHomeParent)
        {
            SHA_SetOffset(
                view,
                SHAHomeOffset
            );
        }
    }
}

#pragma mark - Apply All

static void SHA_ApplyAll(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIApplication *application =
                [UIApplication sharedApplication];

            if (!application)
                return;

            if (@available(iOS 13.0, *))
            {
                for (UIScene *scene
                     in application.connectedScenes)
                {
                    if (![scene
                            isKindOfClass:
                                [UIWindowScene class]])
                    {
                        continue;
                    }

                    UIWindowScene *windowScene =
                        (UIWindowScene *)scene;

                    for (UIWindow *window
                         in windowScene.windows)
                    {
                        if (!window)
                            continue;

                        SHA_ApplyStatusToWindow(
                            window
                        );

                        SHA_ApplyHomeToWindow(
                            window
                        );
                    }
                }
            }
        }
    );
}

#pragma mark - Force Reapply

static void SHA_Reapply(void)
{
    SHA_LoadPreferences();

    SHA_ApplyAll();

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            100 * NSEC_PER_MSEC
        ),
        dispatch_get_main_queue(),
        ^{
            SHA_ApplyAll();
        }
    );

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            500 * NSEC_PER_MSEC
        ),
        dispatch_get_main_queue(),
        ^{
            SHA_ApplyAll();
        }
    );

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            1 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(),
        ^{
            SHA_ApplyAll();
        }
    );
}

#pragma mark - Status Bar Hook

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_SetOffset(
            (UIView *)self,
            SHAStatusOffset
        );
    }
}

%end

#pragma mark - _UIStatusBar Hook

%hook _UIStatusBar

- (layoutSubviews)
{
    %orig;

    SHA_LoadPreferences();

    if (SHAStatusOffset != 0.0)
    {
        SHA_SetOffset(
            (UIView *)self,
            SHAStatusOffset
        );
    }
}

%end

#pragma mark - Home Indicator Hook

%hook _UIHomeIndicatorView

- (layoutSubviews)
{
    %orig;

    SHA_LoadPreferences();

    if (SHAHomeOffset != 0.0)
    {
        SHA_SetOffset(
            (UIView *)self,
            SHAHomeOffset
        );
    }
}

%end

#pragma mark - Notification

static void SHA_SettingsChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SHA_Reapply();
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        SHAOriginalFrames =
            [NSMapTable
                weakToStrongObjectsMapTable];

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

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                1 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                SHA_Reapply();
            }
        );

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                3 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                SHA_Reapply();
            }
        );
    }
}
```
