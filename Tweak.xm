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

        SHAStatusOffset =
            (CGFloat)MAX(-120.0, MIN(120.0, value));
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

        SHAHomeOffset =
            (CGFloat)MAX(-120.0, MIN(120.0, value));
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Notification

static void SHA_PreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SHA_LoadPreferences();
}

#pragma mark - Apply Status Bar

static void SHA_ApplyStatusBarToObject(id object)
{
    if (!object)
        return;

    UIView *view = nil;

    if ([object isKindOfClass:[UIView class]])
        view = (UIView *)object;

    if (!view)
        return;

    /*
     * Không sửa frame gốc.
     * Translation giúp iOS tiếp tục quản lý
     * kích thước/layout của status bar.
     */
    CGAffineTransform transform =
        CGAffineTransformMakeTranslation(
            0.0,
            SHAStatusOffset
        );

    view.transform = transform;
}

#pragma mark - Status Bar Container

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    SHA_LoadPreferences();

    /*
     * iOS 13+ SpringBoard giữ status bar
     * trong ivar _statusBar.
     */
    id statusBar = nil;

    @try
    {
        statusBar = [self valueForKey:@"_statusBar"];
    }
    @catch (__unused NSException *exception)
    {
        statusBar = nil;
    }

    if (statusBar)
    {
        SHA_ApplyStatusBarToObject(statusBar);
    }

    /*
     * Một số layout version đặt trực tiếp
     * content trong container.
     */
    if (SHAStatusOffset != 0.0)
    {
        UIView *view = (UIView *)self;

        /*
         * Chỉ dịch container nếu không lấy được
         * status bar riêng.
         */
        if (!statusBar)
        {
            view.transform =
                CGAffineTransformMakeTranslation(
                    0.0,
                    SHAStatusOffset
                );
        }
    }
}

%end

#pragma mark - UIStatusBar Fallback

%hook UIStatusBar

- (void)setFrame:(CGRect)frame
{
    if (SHAStatusOffset != 0.0)
    {
        frame.origin.y += SHAStatusOffset;
    }

    %orig(frame);
}

%end

#pragma mark - Home Indicator

%hook _UIHomeIndicatorView

- (void)setFrame:(CGRect)frame
{
    if (SHAHomeOffset != 0.0)
    {
        frame.origin.y += SHAHomeOffset;
    }

    %orig(frame);
}

- (void)layoutSubviews
{
    %orig;

    if (SHAHomeOffset == 0.0)
    {
        return;
    }

    UIView *view = (UIView *)self;

    /*
     * Home Indicator thường được layout lại
     * nhiều lần. Translation được áp dụng sau
     * khi UIKit hoàn thành layout.
     */
    view.transform =
        CGAffineTransformMakeTranslation(
            0.0,
            SHAHomeOffset
        );
}

%end

#pragma mark - Runtime Fallback For Home Indicator

static void SHA_ApplyHomeIndicatorToWindows(void)
{
    if (SHAHomeOffset == 0.0)
        return;

    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application)
        return;

    NSArray *windows = application.windows;

    for (UIWindow *window in windows)
    {
        if (!window)
            continue;

        NSArray *subviews = window.subviews;

        for (UIView *view in subviews)
        {
            NSString *className =
                NSStringFromClass([view class]);

            if ([className rangeOfString:@"HomeIndicator"
                                  options:NSCaseInsensitiveSearch].location
                != NSNotFound)
            {
                view.transform =
                    CGAffineTransformMakeTranslation(
                        0.0,
                        SHAHomeOffset
                    );
            }
        }
    }
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
            SHA_PreferencesChanged,
            CFSTR(
                "com.congtu.statushomebaradjuster.settingsChanged"
            ),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        /*
         * Delay lần đầu để SpringBoard tạo đầy đủ
         * status bar/home indicator hierarchy.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                1 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                SHA_LoadPreferences();
                SHA_ApplyHomeIndicatorToWindows();
            }
        );
    }
}
