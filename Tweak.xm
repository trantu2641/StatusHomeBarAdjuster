#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define PREF_DOMAIN @"com.tutu.statushomebaradjuster"

static CGFloat SHAStatusOffset = 0.0;
static CGFloat SHAHomeOffset = 0.0;
static BOOL SHAAdjustingStatus = NO;
static BOOL SHAAdjustingHome = NO;

static CGFloat SHA_Clamp(CGFloat value) {
    if (value < -120.0)
        return -120.0;

    if (value > 120.0)
        return 120.0;

    return value;
}

static void SHA_LoadPreferences(void) {
    CFPreferencesAppSynchronize(CFSTR(PREF_DOMAIN));

    CFPropertyListRef statusValue =
        CFPreferencesCopyAppValue(
            CFSTR("StatusBarOffset"),
            CFSTR(PREF_DOMAIN)
        );

    CFPropertyListRef homeValue =
        CFPreferencesCopyAppValue(
            CFSTR("HomeBarOffset"),
            CFSTR(PREF_DOMAIN)
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

        SHAStatusOffset = SHA_Clamp((CGFloat)value);
    }

    if (homeValue &&
        CFGetTypeID(homeValue) == CFNumberGetTypeID()) {

        double value = 0.0;

        CFNumberGetValue(
            (CFNumberRef)homeValue,
            kCFNumberDoubleType,
            &value
        );

        SHAHomeOffset = SHA_Clamp((CGFloat)value);
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}


/*
 * Status Bar
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

- (void)layoutSubviews {

    %orig;

    if (SHAAdjustingStatus || SHAStatusOffset == 0.0)
        return;

    UIView *view = (UIView *)self;

    CGRect frame = view.frame;

    frame.origin.y += SHAStatusOffset;

    SHAAdjustingStatus = YES;
    view.frame = frame;
    SHAAdjustingStatus = NO;
}

%end


/*
 * Home Indicator
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

- (void)layoutSubviews {

    %orig;

    if (SHAAdjustingHome || SHAHomeOffset == 0.0)
        return;

    UIView *view = (UIView *)self;

    CGRect frame = view.frame;

    frame.origin.y += SHAHomeOffset;

    SHAAdjustingHome = YES;
    view.frame = frame;
    SHAAdjustingHome = NO;
}

%end


%ctor {
    @autoreleasepool {
        SHA_LoadPreferences();
    }
}
