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

static BOOL SHAIsPortrait(void)
{
    UIScreen *screen =
        [UIScreen mainScreen];

    CGSize size =
        screen.bounds.size;

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

    if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {

        original.height =
            SHAGetStatusBarHeight();
    }

    return original;
}


%end


#pragma mark -
#pragma mark Application root view
#pragma mark -

/*
 * Chỉ chỉnh root view của UIWindow.
 *
 * KHÔNG hook toàn bộ UIView.
 *
 * KHÔNG thay safeAreaInsets.
 *
 * KHÔNG scale layer.
 *
 * KHÔNG đụng Home Bar.
 */

%hook UIWindow


- (void)layoutSubviews
{
    %orig;

    /*
     * Không chạy trong SpringBoard.
     */
    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];

    if ([bundleID isEqualToString:@"com.apple.springboard"])
        return;


    /*
     * Chỉ Portrait.
     */
    if (!SHAIsPortrait())
        return;


    UIViewController *rootViewController =
        self.rootViewController;

    if (rootViewController == nil)
        return;


    UIView *rootView =
        rootViewController.view;

    if (rootView == nil)
        return;


    /*
     * Chỉ xử lý root view thật sự nằm trong
     * UIWindow này.
     */
    if (rootView.superview != self)
        return;


    CGFloat statusHeight =
        SHAGetStatusBarHeight();


    CGRect windowBounds =
        self.bounds;


    /*
     * Không thay đổi X / Width.
     */
    CGFloat width =
        windowBounds.size.width;


    /*
     * Toàn bộ phần app bắt đầu ngay sau
     * Status Bar.
     */
    CGFloat newY =
        statusHeight;


    /*
     * Phần còn lại của màn hình.
     */
    CGFloat newHeight =
        windowBounds.size.height - statusHeight;


    if (newHeight < 0.0)
        newHeight = 0.0;


    CGRect newFrame =
        CGRectMake(
            0.0,
            newY,
            width,
            newHeight
        );


    /*
     * Chỉ thay frame khi thực sự khác.
     */
    if (!CGRectEqualToRect(
            rootView.frame,
            newFrame)) {

        rootView.frame =
            newFrame;
    }
}


%end


#pragma mark -
#pragma mark Constructor
#pragma mark -

%ctor
{
    @autoreleasepool {

        NSString *bundleID =
            [[NSBundle mainBundle] bundleIdentifier];


        /*
         * Một %init duy nhất.
         *
         * SpringBoard:
         *   _UIStatusBar hoạt động.
         *
         * App:
         *   UIWindow root-view adjustment hoạt động.
         */
        (void)bundleID;

        %init;
    }
}
