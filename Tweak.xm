#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#pragma mark -
#pragma mark Preferences
#pragma mark -

static CGFloat SHAStatusBarHeight(void)
{
    CFStringRef domain =
        CFSTR("com.congtu.statushomebaradjuster");

    /*
     * Đồng bộ Preferences trước khi đọc.
     */
    CFPreferencesAppSynchronize(domain);

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            CFSTR("StatusBarHeight"),
            domain
        );

    CGFloat height = 30.0;

    if (value)
    {
        /*
         * PSEditTextCell có thể lưu NSString,
         * còn RootListController có thể lưu NSNumber.
         *
         * Hỗ trợ cả hai.
         */
        if (CFGetTypeID(value) == CFNumberGetTypeID())
        {
            double number = 30.0;

            if (CFNumberGetValue(
                    (CFNumberRef)value,
                    kCFNumberDoubleType,
                    &number))
            {
                height = (CGFloat)number;
            }
        }
        else if (CFGetTypeID(value) == CFStringGetTypeID())
        {
            height =
                (CGFloat)CFStringGetDoubleValue(
                    (CFStringRef)value
                );
        }

        CFRelease(value);
    }

    /*
     * Giới hạn đúng yêu cầu:
     *
     * 0   = ẩn
     * 30  = mặc định
     * 120 = tối đa
     */
    if (height < 0.0)
        height = 0.0;

    if (height > 120.0)
        height = 120.0;

    return height;
}

#pragma mark -
#pragma mark UIApplicationSceneSettings
#pragma mark -

%hook UIApplicationSceneSettings

- (CGFloat)defaultStatusBarHeightForOrientation:(NSInteger)orientation
{
    /*
     * Chỉ Portrait.
     */
    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown)
    {
        return %orig;
    }

    return SHAStatusBarHeight();
}

- (CGFloat)statusBarHeight
{
    /*
     * Giữ cùng một giá trị cho API statusBarHeight.
     *
     * Một số thành phần SpringBoard lấy chiều cao
     * qua method này thay vì defaultStatusBarHeightForOrientation:.
     */
    return SHAStatusBarHeight();
}

%end
