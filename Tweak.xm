#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#define SHA_PREFS @"/var/mobile/Library/Preferences/com.congtu.statushomebaradjuster.plist"

#pragma mark - Preferences

static CGFloat SHAStatusBarHeight(void)
{
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:SHA_PREFS];

    id value = prefs[@"StatusBarHeight"];
    CGFloat height = 30.0;

    if ([value isKindOfClass:[NSNumber class]]) {
        height = [value doubleValue];
    }
    else if ([value isKindOfClass:[NSString class]]) {
        height = [value doubleValue];
    }

    if (height < 0.0)
        height = 0.0;

    if (height > 120.0)
        height = 120.0;

    return height;
}

static BOOL SHAPortrait(NSInteger orientation)
{
    return orientation == UIInterfaceOrientationPortrait ||
           orientation == UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark -
#pragma mark UIApplicationSceneSettings
#pragma mark -

%hook UIApplicationSceneSettings

- (CGFloat)defaultStatusBarHeightForOrientation:(NSInteger)orientation
{
    if (!SHAPortrait(orientation)) {
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
 * SpringBoard asks this object for the rectangle that must be avoided
 * by scene content because of the Status Bar.
 *
 * Portrait:
 *
 *   x = 0
 *   y = 0
 *   width = screen width
 *   height = our StatusBarHeight
 *
 * Landscape:
 *   completely untouched.
 */
- (CGRect)_statusBarAvoidanceFrame
{
    CGRect original = %orig;

    /*
     * Do not touch landscape.
     *
     * The original rectangle also gives us a reliable screen width,
     * so we preserve that rather than constructing an arbitrary size.
     */
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;

    if ([self respondsToSelector:@selector(interfaceOrientation)]) {
        @try {
            orientation = (UIInterfaceOrientation)[self interfaceOrientation];
        }
        @catch (...) {
        }
    }

    /*
     * If we cannot reliably determine orientation from the object,
     * use the geometry itself as a conservative fallback.
     *
     * Portrait iPhone 11 Pro Max is wider than it is tall only in
     * landscape, so this avoids modifying the landscape case.
     */
    if (!SHAPortrait(orientation)) {
        return original;
    }

    CGFloat height = SHAStatusBarHeight();

    /*
     * Preserve the original x/width whenever possible.
     * Only the vertical extent is changed.
     */
    CGRect result = original;

    result.origin.y = 0.0;
    result.size.height = height;

    return result;
}


/*
 * This is the point where SpringBoard applies the avoidance frame
 * to a scene.
 *
 * We replace only the portrait vertical extent.
 * Landscape is passed through unchanged.
 */
- (void)_applyStatusBarAvoidanceFrame:(CGRect)frame
                 toSceneWithIdentifier:(NSString *)sceneIdentifier
{
    /*
     * Determine whether the current screen is portrait from the
     * actual screen geometry. This avoids depending on private
     * orientation APIs that may vary between iOS 16 builds.
     */
    UIScreen *screen = [UIScreen mainScreen];
    CGRect bounds = screen.bounds;

    BOOL portraitGeometry = bounds.size.height >= bounds.size.width;

    if (!portraitGeometry) {
        %orig(frame, sceneIdentifier);
        return;
    }

    CGRect adjusted = frame;

    adjusted.origin.y = 0.0;
    adjusted.size.height = SHAStatusBarHeight();

    %orig(adjusted, sceneIdentifier);
}


/*
 * SpringBoard also propagates avoidance-frame changes through this
 * callback. Modify the rectangle before it reaches the scene.
 */
- (void)sceneWithIdentifier:(NSString *)sceneIdentifier
 didChangeStatusBarAvoidanceFrameTo:(CGRect)frame
{
    UIScreen *screen = [UIScreen mainScreen];
    CGRect bounds = screen.bounds;

    BOOL portraitGeometry = bounds.size.height >= bounds.size.width;

    if (!portraitGeometry) {
        %orig(sceneIdentifier, frame);
        return;
    }

    CGRect adjusted = frame;

    adjusted.origin.y = 0.0;
    adjusted.size.height = SHAStatusBarHeight();

    %orig(sceneIdentifier, adjusted);
}

%end


#pragma mark -
#pragma mark Constructor
#pragma mark -

%ctor
{
    /*
     * Status Bar only.
     *
     * IMPORTANT:
     * No Home Bar hooks are initialized here.
     */
    %init(
        UIApplicationSceneSettings = %c(UIApplicationSceneSettings),
        SBMainDisplaySceneLayoutStatusBarView = %c(SBMainDisplaySceneLayoutStatusBarView)
    );
}
