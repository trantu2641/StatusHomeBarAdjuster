#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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
    UIScreen *screen = [UIScreen mainScreen];

    CGSize size = screen.bounds.size;

    /*
     * Portrait trên iPhone:
     *
     * width < height
     */

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
#pragma mark Application content
#pragma mark -

/*
 * Không chạy trong SpringBoard.
 *
 * Phần này chạy trong application process.
 *
 * Mục tiêu:
 *
 * StatusBarHeight < 30
 *
 * -> giảm top safe-area mà UIKit cung cấp cho
 *    root view của application.
 *
 * Không scale layer.
 * Không thay đổi X.
 * Không thay đổi chiều rộng.
 */


%hook UIView


- (UIEdgeInsets)safeAreaInsets
{
    UIEdgeInsets original =
        %orig;


    /*
     * Chỉ xử lý Portrait.
     */
    if (!SHAIsPortrait()) {
        return original;
    }


    CGFloat statusHeight =
        SHAGetStatusBarHeight();


    /*
     * Chỉ can thiệp khi giá trị nhỏ hơn
     * minimum thông thường.
     *
     * >= 30 giữ nguyên hành vi hiện tại.
     */
    if (statusHeight < 30.0) {

        /*
         * Không được tạo safe area âm.
         */
        if (statusHeight < 0.0)
            statusHeight = 0.0;


        /*
         * Chỉ giảm TOP.
         *
         * Left / Bottom / Right giữ nguyên.
         */
        if (original.top > statusHeight) {

            original.top =
                statusHeight;
        }
    }


    return original;
}


%end


#pragma mark -
#pragma mark UIWindow
#pragma mark -

%hook UIWindow


- (void)safeAreaInsetsDidChange
{
    %orig;

    /*
     * UIKit sẽ tự layout lại các view phụ thuộc
     * safeAreaInsets.
     */
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
         * SpringBoard:
         *
         * giữ Status Bar hook.
         */
        if ([bundleID isEqualToString:
                @"com.apple.springboard"]) {

            %init;

            return;
        }


        /*
         * Application:
         *
         * load các hook UIView/UIApplication.
         *
         * Không đụng Home Bar.
         */
        %init;
    }
}
