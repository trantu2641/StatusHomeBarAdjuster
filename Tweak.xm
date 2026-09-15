#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <notify.h>

#pragma mark - Constants

static NSString * const SHASettingsDomain =
    @"com.congtu.statushomebaradjuster";

static const CGFloat SHA_MIN_DELTA = -120.0;
static const CGFloat SHA_MAX_DELTA =  120.0;

#pragma mark - Preferences

static CGFloat SHAStatusDelta = 0.0;
static CGFloat SHAHomeDelta = 0.0;

static void SHA_LoadPreferences(void)
{
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

    SHAStatusDelta = 0.0;
    SHAHomeDelta = 0.0;

    if (statusValue &&
        CFGetTypeID(statusValue) == CFNumberGetTypeID())
    {
        double value = 0.0;

        if (CFNumberGetValue(
                (CFNumberRef)statusValue,
                kCFNumberDoubleType,
                &value))
        {
            SHAStatusDelta =
                (CGFloat)MAX(
                    SHA_MIN_DELTA,
                    MIN(SHA_MAX_DELTA, value)
                );
        }
    }

    if (homeValue &&
        CFGetTypeID(homeValue) == CFNumberGetTypeID())
    {
        double value = 0.0;

        if (CFNumberGetValue(
                (CFNumberRef)homeValue,
                kCFNumberDoubleType,
                &value))
        {
            SHAHomeDelta =
                (CGFloat)MAX(
                    SHA_MIN_DELTA,
                    MIN(SHA_MAX_DELTA, value)
                );
        }
    }

    if (statusValue)
        CFRelease(statusValue);

    if (homeValue)
        CFRelease(homeValue);
}

#pragma mark - Orientation

static BOOL SHA_IsPortrait(UIView *view)
{
    if (!view)
        return NO;

    UIWindow *window = view.window;

    if (!window)
        return NO;

    if (@available(iOS 13.0, *))
    {
        UIWindowScene *scene =
            window.windowScene;

        if (!scene)
            return NO;

        UIInterfaceOrientation orientation =
            scene.interfaceOrientation;

        return
            orientation == UIInterfaceOrientationPortrait ||
            orientation == UIInterfaceOrientationPortraitUpsideDown;
    }

    return NO;
}

#pragma mark - Home Bar Visual

/*
 * Không thay đổi frame/bounds của Home Bar container.
 *
 * Không thay đổi:
 * - safe area
 * - gesture region
 * - gesture recognizers
 * - superview geometry
 *
 * Chỉ áp dụng visual transform cho chính visual layer.
 *
 * Nếu delta = 0 thì loại bỏ transform.
 */

static void SHA_ApplyHomeVisual(UIView *view)
{
    if (!view)
        return;

    if (!view.window)
        return;

    if (!SHA_IsPortrait(view))
        return;

    CGFloat delta = SHAHomeDelta;

    CALayer *layer = view.layer;

    if (!layer)
        return;

    /*
     * delta = 0:
     * khôi phục visual nguyên bản.
     */
    if (fabs(delta) < 0.001)
    {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];

        layer.transform =
            CATransform3DIdentity;

        [CATransaction commit];

        return;
    }

    CGFloat originalHeight =
        CGRectGetHeight(layer.bounds);

    if (originalHeight <= 0.0)
        return;

    /*
     * Tính scale từ chiều cao gốc.
     *
     * Không thay bounds.
     * Không thay frame.
     */
    CGFloat targetHeight =
        originalHeight + delta;

    if (targetHeight < 1.0)
        targetHeight = 1.0;

    CGFloat scaleY =
        targetHeight / originalHeight;

    /*
     * Giới hạn để tránh giá trị bất thường.
     */
    if (scaleY < 0.05)
        scaleY = 0.05;

    if (scaleY > 20.0)
        scaleY = 20.0;

    /*
     * Chỉ thay rendering transform.
     *
     * Không gọi setNeedsLayout.
     * Không sửa bounds.
     */
    CATransform3D transform =
        CATransform3DMakeScale(
            1.0,
            scaleY,
            1.0
        );

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    layer.transform = transform;

    [CATransaction commit];
}

#pragma mark - Home Bar Classes

@interface MTLumaDodgePillView : UIView
@end

@interface MTStaticColorPillView : UIView
@end

#pragma mark - Luma Home Bar

%hook MTLumaDodgePillView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    /*
     * Chỉ chạy sau khi view thực sự
     * được đưa vào window.
     */
    if (self.window)
    {
        SHA_ApplyHomeVisual(
            (UIView *)self
        );
    }
}

%end

#pragma mark - Static Home Bar

%hook MTStaticColorPillView

- (void)didMoveToWindow
{
    %orig;

    SHA_LoadPreferences();

    if (self.window)
    {
        SHA_ApplyHomeVisual(
            (UIView *)self
        );
    }
}

%end

#pragma mark - Settings Notification

static void SHA_SettingsChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SHA_LoadPreferences();

    /*
     * Không ép toàn bộ UIKit layout lại.
     *
     * Điều này rất quan trọng:
     * tránh tạo cascade layout trong SpringBoard.
     */

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            /*
             * Không chạm private system views ở đây.
             *
             * Các Home Bar visual objects sẽ nhận
             * preference mới khi UIKit đưa chúng
             * vào window lần tiếp theo.
             */
        }
    );
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        SHA_LoadPreferences();

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            SHA_SettingsChanged,
            CFSTR(
                "com.congtu.statushomebaradjuster.settingsChanged"
            ),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }
}
