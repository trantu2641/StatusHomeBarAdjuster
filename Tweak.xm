#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define SHA_PREFS_DOMAIN "com.congtu.statushomebaradjuster"
#define SHA_STATUS_BAR_HEIGHT "StatusBarHeight"


#pragma mark -
#pragma mark Preferences
#pragma mark -

static CGFloat SHAGetStatusBarHeight(void)
{
    CFPreferencesAppSynchronize(
        CFSTR(SHA_PREFS_DOMAIN)
    );

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            CFSTR(SHA_STATUS_BAR_HEIGHT),
            CFSTR(SHA_PREFS_DOMAIN)
        );

    CGFloat height = 30.0;

    if (value != NULL) {

        if (CFGetTypeID(value) == CFNumberGetTypeID()) {

            double number = 30.0;

            if (CFNumberGetValue(
                    (CFNumberRef)value,
                    kCFNumberDoubleType,
                    &number)) {

                height = (CGFloat)number;
            }
        }
        else if (CFGetTypeID(value) == CFStringGetTypeID()) {

            height =
                (CGFloat)CFStringGetDoubleValue(
                    (CFStringRef)value
                );
        }

        CFRelease(value);
    }

    if (height < 0.0)
        height = 0.0;

    if (height > 120.0)
        height = 120.0;

    return height;
}


#pragma mark -
#pragma mark Orientation
#pragma mark -

static BOOL SHAIsPortraitWindow(UIWindow *window)
{
    UIWindowScene *scene =
        window.windowScene;

    if (scene != nil) {

        UIInterfaceOrientation orientation =
            scene.interfaceOrientation;

        if (orientation == UIInterfaceOrientationPortrait ||
            orientation == UIInterfaceOrientationPortraitUpsideDown) {

            return YES;
        }

        if (orientation == UIInterfaceOrientationLandscapeLeft ||
            orientation == UIInterfaceOrientationLandscapeRight) {

            return NO;
        }
    }

    /*
     * Fallback.
     */
    CGSize size =
        window.bounds.size;

    return size.width < size.height;
}


#pragma mark -
#pragma mark Application Window
#pragma mark -

%hook UIWindow


- (UIEdgeInsets)safeAreaInsets
{
    UIEdgeInsets original =
        %orig;


    /*
     * Không thay đổi SpringBoard.
     */
    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];

    if ([bundleID isEqualToString:
            @"com.apple.springboard"]) {

        return original;
    }


    /*
     * Chỉ Portrait.
     */
    if (!SHAIsPortraitWindow(self)) {

        return original;
    }


    /*
     * Chỉ xử lý cửa sổ ứng dụng thực sự.
     *
     * Không đụng các UIWindow không có
     * root view controller.
     */
    if (self.rootViewController == nil) {

        return original;
    }


    /*
     * Status Bar height người dùng đặt:
     *
     * 0...120
     */
    CGFloat targetHeight =
        SHAGetStatusBarHeight();


    /*
     * Đây là điểm quan trọng nhất:
     *
     * KHÔNG thay frame của rootView.
     * KHÔNG scale layer.
     *
     * Chỉ thay TOP SAFE AREA của WINDOW.
     */
    if (targetHeight < 30.0) {

        original.top =
            targetHeight;
    }


    return original;
}


%end


#pragma mark -
#pragma mark _UIStatusBar
#pragma mark -

/*
 * Giữ nguyên cơ chế Status Bar hiện tại.
 *
 * Phần này chịu trách nhiệm thay intrinsic height
 * của Status Bar.
 */

%hook _UIStatusBar


+ (CGSize)intrinsicContentSizeForTargetScreen:(id)targetScreen
                                   orientation:(long long)orientation
                                  onLockScreen:(BOOL)onLockScreen
{
    CGSize original =
        %orig(
            targetScreen,
            orientation,
            onLockScreen
        );


    /*
     * Chỉ Portrait.
     */
    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        original.height =
            SHAGetStatusBarHeight();
    }


    return original;
}


+ (CGSize)intrinsicContentSizeForTargetScreen:(id)targetScreen
                                   orientation:(long long)orientation
                                  onLockScreen:(BOOL)onLockScreen
                                isAzulBLinked:(BOOL)isAzulBLinked
{
    CGSize original =
        %orig(
            targetScreen,
            orientation,
            onLockScreen,
            isAzulBLinked
        );


    /*
     * Chỉ Portrait.
     */
    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        original.height =
            SHAGetStatusBarHeight();
    }


    return original;
}


%end


#pragma mark -
#pragma mark Constructor
#pragma mark -

%ctor
{
    @autoreleasepool {

        /*
         * Một %init duy nhất.
         */
        %init;
    }
}
