#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

static CGFloat SHAStatusOffset = 0.0;
static CGFloat SHAHomeOffset = 0.0;


/*
 * Đọc settings từ domain RIÊNG.
 *
 * Không liên quan:
 * xyz.cypwn.systemcorner
 */
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


/*
 * Khi bấm Apply trong Settings,
 * reload lại giá trị.
 */
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


/*
 * STATUS BAR
 */

%hook UIStatusBar

- (void)setFrame:(CGRect)frame
{
    static BOOL busy = NO;


    if (busy || SHAStatusOffset == 0.0)
    {
        %orig(frame);
        return;
    }


    busy = YES;


    frame.origin.y += SHAStatusOffset;


    %orig(frame);


    busy = NO;
}

%end



/*
 * HOME BAR
 */

%hook _UIHomeIndicatorView

- (void)setFrame:(CGRect)frame
{
    static BOOL busy = NO;


    if (busy || SHAHomeOffset == 0.0)
    {
        %orig(frame);
        return;
    }


    busy = YES;


    frame.origin.y += SHAHomeOffset;


    %orig(frame);


    busy = NO;
}

%end



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
    }
}
