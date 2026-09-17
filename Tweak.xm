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
#pragma mark Root view detection
#pragma mark -

static BOOL SHAIsRootView(UIView *view)
{
    if (view == nil)
        return NO;

    UIWindow *window =
        view.window;

    if (window == nil)
        return NO;

    UIViewController *rootVC =
        window.rootViewController;

    if (rootVC == nil)
        return NO;

    UIView *rootView =
        rootVC.view;

    if (rootView == nil)
        return NO;

    return view == rootView;
}


#pragma mark -
#pragma mark Portrait detection
#pragma mark -

static BOOL SHAIsPortrait(UIView *view)
{
    UIWindow *window =
        view.window;

    if (window == nil)
        return NO;


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


    CGSize size =
        window.bounds.size;

    return size.width < size.height;
}


#pragma mark -
#pragma mark _UIStatusBar
#pragma mark -

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
#pragma mark Root application safe area
#pragma mark -

%hook UIView


- (UIEdgeInsets)safeAreaInsets
{
    UIEdgeInsets original =
        %orig;


    /*
     * Không bao giờ can thiệp SpringBoard.
     */
    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];

    if ([bundleID isEqualToString:
            @"com.apple.springboard"]) {

        return original;
    }


    /*
     * Chỉ root view của application.
     *
     * Đây là điểm khác biệt quan trọng:
     *
     * KHÔNG sửa UILabel
     * KHÔNG sửa UIImageView
     * KHÔNG sửa UITableView
     * KHÔNG sửa UISearchBar
     * KHÔNG sửa UIVisualEffectView
     * ...
     */
    if (!SHAIsRootView(self)) {

        return original;
    }


    /*
     * Chỉ Portrait.
     */
    if (!SHAIsPortrait(self)) {

        return original;
    }


    CGFloat targetHeight =
        SHAGetStatusBarHeight();


    /*
     * Từ 30 trở lên:
     *
     * giữ nguyên hoàn toàn cơ chế hiện tại.
     */
    if (targetHeight >= 30.0) {

        return original;
    }


    /*
     * ========================================================
     * 0...29
     * ========================================================
     *
     * Chỉ thay TOP.
     *
     * Bottom / Left / Right giữ nguyên.
     */
    original.top =
        targetHeight;


    /*
     * Không bao giờ trả về giá trị âm.
     */
    if (original.top < 0.0)
        original.top = 0.0;


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
         * Chỉ một %init.
         */
        %init;
    }
}
