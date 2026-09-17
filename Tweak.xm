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
#pragma mark Helpers
#pragma mark -

static BOOL SHAIsPortraitForWindow(UIWindow *window)
{
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


static BOOL SHAIsApplicationWindow(UIWindow *window)
{
    if (window == nil)
        return NO;

    NSString *bundleID =
        [[NSBundle mainBundle] bundleIdentifier];

    if ([bundleID isEqualToString:@"com.apple.springboard"])
        return NO;

    if (window.hidden)
        return NO;

    if (window.alpha <= 0.0)
        return NO;

    if (window.rootViewController == nil)
        return NO;

    return YES;
}


static BOOL SHAFrameIsUsable(CGRect frame)
{
    if (frame.size.width <= 1.0)
        return NO;

    if (frame.size.height <= 1.0)
        return NO;

    return YES;
}


static BOOL SHAViewLooksLikeRootContainer(
    UIView *view,
    UIView *rootView
)
{
    if (view == nil || rootView == nil)
        return NO;

    if (view == rootView)
        return NO;

    if (view.hidden)
        return NO;

    if (view.alpha <= 0.0)
        return NO;

    CGRect bounds =
        rootView.bounds;

    CGRect frame =
        view.frame;

    if (!SHAFrameIsUsable(frame))
        return NO;

    CGFloat rootWidth =
        bounds.size.width;

    CGFloat rootHeight =
        bounds.size.height;

    if (rootWidth <= 1.0 ||
        rootHeight <= 1.0) {

        return NO;
    }

    /*
     * Container phải gần như phủ toàn bộ
     * chiều ngang của root view.
     */
    CGFloat widthRatio =
        frame.size.width / rootWidth;

    if (widthRatio < 0.90)
        return NO;

    /*
     * Container phải đủ lớn theo chiều dọc.
     */
    CGFloat heightRatio =
        frame.size.height / rootHeight;

    if (heightRatio < 0.70)
        return NO;

    return YES;
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
#pragma mark Application root container
#pragma mark -

%hook UIView


- (void)layoutSubviews
{
    %orig;

    UIWindow *window =
        self.window;

    /*
     * Chỉ application process.
     */
    if (!SHAIsApplicationWindow(window))
        return;

    /*
     * Chỉ Portrait.
     */
    if (!SHAIsPortraitForWindow(window))
        return;

    /*
     * Chỉ hoạt động dưới 30.
     *
     * 30...120 giữ nguyên cơ chế cũ.
     */
    CGFloat targetHeight =
        SHAGetStatusBarHeight();

    if (targetHeight >= 30.0)
        return;


    UIViewController *rootController =
        window.rootViewController;

    if (rootController == nil)
        return;


    UIView *rootView =
        rootController.view;

    if (rootView == nil)
        return;


    /*
     * Chỉ xử lý chính root view của UIWindow.
     */
    if (self != rootView)
        return;


    /*
     * Tránh chạy lại trong cùng một chu kỳ layout.
     */
    static BOOL isAdjusting = NO;

    if (isAdjusting)
        return;


    isAdjusting = YES;


    @try {

        CGRect rootBounds =
            rootView.bounds;

        CGFloat rootWidth =
            rootBounds.size.width;

        CGFloat rootHeight =
            rootBounds.size.height;


        if (rootWidth <= 1.0 ||
            rootHeight <= 1.0) {

            isAdjusting = NO;
            return;
        }


        /*
         * ====================================================
         * TÌM CONTAINER ỨNG DỤNG
         * ====================================================
         *
         * Không sửa tất cả UIView.
         *
         * Chỉ xét các subview trực tiếp của root view
         * có kích thước gần bằng toàn màn hình.
         */
        UIView *bestContainer = nil;

        CGFloat bestScore = 0.0;


        for (UIView *candidate in rootView.subviews) {

            if (!SHAViewLooksLikeRootContainer(
                    candidate,
                    rootView)) {

                continue;
            }


            CGRect frame =
                candidate.frame;


            CGFloat widthRatio =
                frame.size.width / rootWidth;

            CGFloat heightRatio =
                frame.size.height / rootHeight;


            /*
             * Ưu tiên container lớn nhất.
             */
            CGFloat score =
                widthRatio * 0.6 +
                heightRatio * 0.4;


            if (score > bestScore) {

                bestScore =
                    score;

                bestContainer =
                    candidate;
            }
        }


        if (bestContainer != nil) {

            CGRect oldFrame =
                bestContainer.frame;


            /*
             * Chỉ chấp nhận container đang bắt đầu
             * gần vùng trên của root view.
             */
            if (oldFrame.origin.y < 60.0) {

                /*
                 * Mép trên mới.
                 */
                CGFloat newY =
                    targetHeight;


                /*
                 * Giữ nguyên mép dưới.
                 *
                 * bottom = oldY + oldHeight
                 */
                CGFloat bottom =
                    CGRectGetMaxY(oldFrame);


                /*
                 * Chiều cao mới.
                 */
                CGFloat newHeight =
                    bottom - newY;


                if (newHeight < 0.0)
                    newHeight = 0.0;


                CGRect newFrame =
                    CGRectMake(
                        oldFrame.origin.x,
                        newY,
                        oldFrame.size.width,
                        newHeight
                    );


                /*
                 * Chỉ thay khi thực sự khác.
                 */
                if (!CGRectEqualToRect(
                        oldFrame,
                        newFrame)) {

                    bestContainer.frame =
                        newFrame;
                }
            }
        }

    }
    @catch (__unused id exception) {

        /*
         * Tuyệt đối không để lỗi của một app
         * làm chết process.
         */
    }


    isAdjusting = NO;
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
