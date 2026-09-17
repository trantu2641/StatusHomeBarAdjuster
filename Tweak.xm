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

static BOOL SHAIsPortraitViewController(
    UIViewController *viewController
)
{
    if (viewController == nil)
        return NO;

    UIWindow *window =
        viewController.view.window;

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
#pragma mark Root View Controller
#pragma mark -

%hook UIViewController


- (void)viewDidLayoutSubviews
{
    %orig;


    /*
     * Không xử lý SpringBoard.
     */
    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];

    if ([bundleID isEqualToString:
            @"com.apple.springboard"]) {

        return;
    }


    /*
     * Chỉ Portrait.
     */
    if (!SHAIsPortraitViewController(self)) {

        return;
    }


    /*
     * Chỉ xử lý giá trị dưới 30.
     *
     * 30...120 giữ nguyên.
     */
    CGFloat targetHeight =
        SHAGetStatusBarHeight();

    if (targetHeight >= 30.0) {

        return;
    }


    UIWindow *window =
        self.view.window;

    if (window == nil)
        return;


    UIViewController *rootVC =
        window.rootViewController;

    if (rootVC == nil)
        return;


    /*
     * Chỉ root controller.
     *
     * Không sửa navigation controller con,
     * table controller con, player controller...
     */
    if (self != rootVC)
        return;


    /*
     * Tránh recursion/layout loop.
     */
    static BOOL adjusting = NO;

    if (adjusting)
        return;

    adjusting = YES;


    @try {

        UIEdgeInsets safe =
            self.view.safeAreaInsets;


        /*
         * Chiều cao Status Bar mà UIKit hiện đang
         * dành cho root controller.
         */
        CGFloat currentTop =
            safe.top;


        /*
         * Nếu đã đúng thì không làm gì.
         */
        if (fabs(currentTop - targetHeight) > 0.5) {

            /*
             * additionalSafeAreaInsets được cộng
             * vào safe area hiện tại.
             *
             * Ví dụ:
             *
             * current = 49
             * target  = 10
             *
             * additional = -39
             *
             * kết quả ≈ 10.
             */
            UIEdgeInsets additional =
                self.additionalSafeAreaInsets;


            CGFloat correction =
                targetHeight - currentTop;


            additional.top =
                correction;


            /*
             * Không cho các cạnh khác bị thay đổi.
             */
            additional.left = 0.0;
            additional.right = 0.0;
            additional.bottom = 0.0;


            self.additionalSafeAreaInsets =
                additional;
        }

    }
    @catch (__unused id exception) {

        /*
         * Không để lỗi layout của app làm
         * process bị crash.
         */
    }


    adjusting = NO;
}


%end


#pragma mark -
#pragma mark UIApplicationSceneSettings
#pragma mark -

@interface UIApplicationSceneSettings : NSObject

- (double)statusBarHeight;

- (double)defaultStatusBarHeightForOrientation:
    (long long)orientation;

- (UIEdgeInsets)safeAreaInsetsPortrait;

- (CGRect)statusBarAvoidanceFrame;

@end


%hook UIApplicationSceneSettings


- (UIEdgeInsets)safeAreaInsetsPortrait
{
    UIEdgeInsets original =
        %orig;

    CGFloat height =
        SHAGetStatusBarHeight();

    if (height < 30.0) {

        original.top =
            height;

        if (original.top < 0.0)
            original.top = 0.0;
    }

    return original;
}


- (CGRect)statusBarAvoidanceFrame
{
    CGRect original =
        %orig;

    CGFloat height =
        SHAGetStatusBarHeight();

    if (height < 30.0) {

        original.origin.y =
            0.0;

        original.size.height =
            height;
    }

    return original;
}


- (double)statusBarHeight
{
    double original =
        %orig;

    CGFloat height =
        SHAGetStatusBarHeight();

    if (height < 30.0) {

        return (double)height;
    }

    return original;
}


- (double)defaultStatusBarHeightForOrientation:
    (long long)orientation
{
    double original =
        %orig(orientation);

    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {

        return original;
    }

    CGFloat height =
        SHAGetStatusBarHeight();

    if (height < 30.0) {

        return (double)height;
    }

    return original;
}


%end


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
#pragma mark Constructor
#pragma mark -

%ctor
{
    @autoreleasepool {
        %init;
    }
}
