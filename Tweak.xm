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
#pragma mark Application safe area
#pragma mark -

%hook UIView


- (UIEdgeInsets)safeAreaInsets
{
    UIEdgeInsets original =
        %orig;


    /*
     * Chỉ thay đổi trong Portrait.
     */
    if (!SHAIsPortrait()) {
        return original;
    }


    CGFloat statusHeight =
        SHAGetStatusBarHeight();


    /*
     * Chỉ xử lý vùng 0...30.
     *
     * Từ 30 trở lên giữ nguyên cơ chế
     * Status Bar hiện tại.
     */
    if (statusHeight < 30.0) {

        /*
         * Chỉ giảm TOP.
         *
         * Không thay:
         *
         * left
         * bottom
         * right
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
}


%end


#pragma mark -
#pragma mark Constructor
#pragma mark -

%ctor
{
    @autoreleasepool {

        /*
         * Chỉ một %init duy nhất.
         *
         * Đây là nguyên nhân lỗi:
         *
         * re-%init of %group _ungrouped
         *
         * ở bản trước.
         */
        %init;
    }
}
