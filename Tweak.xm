#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

static CGFloat SHAStatusOffset = 0.0;
static CGFloat SHAHomeOffset = 0.0;

static BOOL SHAAdjustingStatus = NO;
static BOOL SHAAdjustingHome = NO;

static CGFloat SHAClamp(CGFloat value) {
    if (value < -120.0)
        return -120.0;

    if (value > 120.0)
        return 120.0;

    return value;
}

static void SHA_LoadPreferences(void) {
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
        CFGetTypeID(statusValue) == CFNumberGetTypeID()) {

        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)statusValue,
            kCFNumberDoubleType,
            &value
        );

        SHAStatusOffset = SHAClamp((CGFloat)value);
    }

    if (homeValue &&
        CFGetTypeID(homeValue) == CFNumberGetTypeID()) {

        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)homeValue,
            kCFNumberDoubleType,
            &value
        );

        SHAHomeOffset = SHAClamp((CGFloat)value);
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}


/*
 * Nhận thay đổi từ Settings.
 */
static void SHA_PreferencesChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
) {
    SHA_LoadPreferences();
}


/*
 * =========================
 * STATUS BAR
 * =========================
 */

%hook UIStatusBar

- (void)setFrame:(CGRect)frame {

    if (SHAAdjustingStatus || SHAStatusOffset == 0.0) {
        %orig(frame);
        return;
    }

    SHAAdjustingStatus = YES;

    frame.origin.y += SHAStatusOffset;

    %orig(frame);

    SHAAdjustingStatus = NO;
}

%end


/*
 * =========================
 * HOME INDICATOR
 * =========================
 */

%hook _UIHomeIndicatorView

- (void)setFrame:(CGRect)frame {

    if (SHAAdjustingHome || SHAHomeOffset == 0.0) {
        %orig(frame);
        return;
    }

    SHAAdjustingHome = YES;

    frame.origin.y += SHAHomeOffset;

    %orig(frame);

    SHAAdjustingHome = NO;
}

%end


%ctor {
    @autoreleasepool {

        SHA_LoadPreferences();

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            SHA_PreferencesChanged,
            CFSTR("com.congtu.statushomebaradjuster.settingsChanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }
}
