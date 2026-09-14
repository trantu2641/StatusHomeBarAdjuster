#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

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

#pragma mark - Settings Changed

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

#pragma mark - Status Bar

%hook UIStatusBar

- (void)layoutSubviews
{
    %orig;

    CGFloat offset = SHAStatusOffset;

    if (offset == 0.0)
    {
        self.transform = CGAffineTransformIdentity;
        return;
    }

    self.transform =
        CGAffineTransformMakeTranslation(
            0.0,
            offset
        );
}

%end

#pragma mark - Home Indicator

%hook _UIHomeIndicatorView

- (void)layoutSubviews
{
    %orig;

    CGFloat offset = SHAHomeOffset;

    if (offset == 0.0)
    {
        self.transform = CGAffineTransformIdentity;
        return;
    }

    self.transform =
        CGAffineTransformMakeTranslation(
            0.0,
            offset
        );
}

%end

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
    }
}
