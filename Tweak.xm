#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define SHA_PREFS @"/var/mobile/Library/Preferences/com.congtu.statushomebaradjuster.plist"

#pragma mark - Preferences

static CGFloat SHAStatusBarHeight(void)
{
    NSDictionary *prefs =
        [NSDictionary dictionaryWithContentsOfFile:SHA_PREFS];

    id value = prefs[@"StatusBarHeight"];

    CGFloat height = 30.0;

    if ([value isKindOfClass:[NSNumber class]]) {
        height = [value doubleValue];
    }
    else if ([value isKindOfClass:[NSString class]]) {
        height = [value doubleValue];
    }

    // 0...120 px
    if (height < 0.0) {
        height = 0.0;
    }

    if (height > 120.0) {
        height = 120.0;
    }

    return height;
}

#pragma mark - Orientation

static BOOL SHAPortrait(void)
{
    UIScreen *screen = [UIScreen mainScreen];

    CGRect bounds = screen.bounds;

    /*
     * iPhone portrait:
     * width < height
     *
     * Landscape:
     * width > height
     */
    return bounds.size.height >= bounds.size.width;
}

#pragma mark -
#pragma mark UIApplicationSceneSettings
#pragma mark -

%hook UIApplicationSceneSettings

/*
 * Đây là hook đã được xác nhận có tác dụng trên máy:
 *
 * Spotlight + một số app đã thay đổi Status Bar.
 *
 * Giữ lại làm nguồn chiều cao Status Bar.
 */
- (CGFloat)defaultStatusBarHeightForOrientation:(NSInteger)orientation
{
    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) {
        return %orig;
    }

    return SHAStatusBarHeight();
}

%end


#pragma mark -
#pragma mark SBMainDisplaySceneLayoutStatusBarView
#pragma mark -

%hook SBMainDisplaySceneLayoutStatusBarView

/*
 * SpringBoard dùng avoidance frame để báo cho scene:
 *
 * "Phần phía trên này đang bị Status Bar chiếm."
 *
 * Ta chỉ thay đổi chiều cao.
 *
 * TOP vẫn luôn ở 0.
 */
- (CGRect)_statusBarAvoidanceFrame
{
    CGRect original = %orig;

    /*
     * Tuyệt đối không thay đổi landscape.
     */
    if (!SHAPortrait()) {
        return original;
    }

    CGFloat height = SHAStatusBarHeight();

    CGRect adjusted = original;

    adjusted.origin.y = 0.0;
    adjusted.size.height = height;

    return adjusted;
}

@end


#pragma mark -
#pragma mark Apply avoidance frame
#pragma mark -

%hook SBMainDisplaySceneLayoutStatusBarView

/*
 * Đây là đường SpringBoard áp dụng avoidance frame
 * vào scene.
 *
 * Portrait:
 *
 *   y = 0
 *   height = StatusBarHeight
 *
 * Landscape:
 *   giữ nguyên hoàn toàn.
 */
- (void)_applyStatusBarAvoidanceFrame:(CGRect)frame
                 toSceneWithIdentifier:(NSString *)sceneIdentifier
{
    if (!SHAPortrait()) {
        %orig(frame, sceneIdentifier);
        return;
    }

    CGRect adjusted = frame;

    adjusted.origin.y = 0.0;
    adjusted.size.height = SHAStatusBarHeight();

    %orig(adjusted, sceneIdentifier);
}

@end


#pragma mark -
#pragma mark Scene avoidance-frame propagation
#pragma mark -

%hook SBMainDisplaySceneLayoutStatusBarView

/*
 * SpringBoard gọi callback này khi avoidance frame
 * thay đổi.
 *
 * Ta thay chiều cao trước khi chuyển tiếp xuống scene.
 */
- (void)sceneWithIdentifier:(NSString *)sceneIdentifier
 didChangeStatusBarAvoidanceFrameTo:(CGRect)frame
{
    if (!SHAPortrait()) {
        %orig(sceneIdentifier, frame);
        return;
    }

    CGRect adjusted = frame;

    adjusted.origin.y = 0.0;
    adjusted.size.height = SHAStatusBarHeight();

    %orig(sceneIdentifier, adjusted);
}

@end


#pragma mark -
#pragma mark Constructor
#pragma mark -

%ctor
{
    /*
     * Không cần %init().
     *
     * Logos tự đăng ký các %hook ở trên.
     *
     * Chưa có bất kỳ Home Bar hook nào.
     */
}
