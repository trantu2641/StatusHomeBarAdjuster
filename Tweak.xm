#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define PREF_DOMAIN @"com.tutu.statushomebaradjuster"

static CGFloat SHAStatusOffset = 0.0;
static CGFloat SHAHomeOffset = 0.0;

static void SHA_LoadPreferences(void) {
    CFPreferencesAppSynchronize(CFSTR("com.tutu.statushomebaradjuster"));

    CFPropertyListRef statusValue =
        CFPreferencesCopyAppValue(CFSTR("StatusBarOffset"),
                                   CFSTR("com.tutu.statushomebaradjuster"));

    CFPropertyListRef homeValue =
        CFPreferencesCopyAppValue(CFSTR("HomeBarOffset"),
                                   CFSTR("com.tutu.statushomebaradjuster"));

    SHAStatusOffset = 0.0;
    SHAHomeOffset = 0.0;

    if (statusValue && CFGetTypeID(statusValue) == CFNumberGetTypeID()) {
        double value = 0;
        CFNumberGetValue((CFNumberRef)statusValue,
                         kCFNumberDoubleType,
                         &value);

        if (value < -120) value = -120;
        if (value > 120) value = 120;

        SHAStatusOffset = value;
    }

    if (homeValue && CFGetTypeID(homeValue) == CFNumberGetTypeID()) {
        double value = 0;
        CFNumberGetValue((CFNumberRef)homeValue,
                         kCFNumberDoubleType,
                         &value);

        if (value < -120) value = -120;
        if (value > 120) value = 120;

        SHAHomeOffset = value;
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

static CGFloat SHA_ClampedOffset(CGFloat value) {
    if (value < -120.0)
        return -120.0;

    if (value > 120.0)
        return 120.0;

    return value;
}

%hook UIStatusBar

- (void)setFrame:(CGRect)frame {
    frame.origin.y += SHA_ClampedOffset(SHAStatusOffset);

    %orig(frame);
}

- (void)layoutSubviews {
    %orig;

    if (SHAStatusOffset == 0)
        return;

    CGRect frame = self.frame;

    CGFloat expectedY =
        frame.origin.y + SHA_ClampedOffset(SHAStatusOffset);

    if (fabs(frame.origin.y - expectedY) > 0.5) {
        frame.origin.y = expectedY;
        self.frame = frame;
    }
}

%end


/*
 * iOS 16 SpringBoard home indicator.
 *
 * _UIHomeIndicatorView is a private UIKit class.
 * We intentionally only modify its vertical position.
 */
%hook _UIHomeIndicatorView

- (void)setFrame:(CGRect)frame {
    frame.origin.y += SHA_ClampedOffset(SHAHomeOffset);

    %orig(frame);
}

- (void)layoutSubviews {
    %orig;

    if (SHAHomeOffset == 0)
        return;

    CGRect frame = self.frame;

    CGFloat expectedY =
        frame.origin.y + SHA_ClampedOffset(SHAHomeOffset);

    if (fabs(frame.origin.y - expectedY) > 0.5) {
        frame.origin.y = expectedY;
        self.frame = frame;
    }
}

%end


%ctor {
    @autoreleasepool {
        SHA_LoadPreferences();
    }
}
