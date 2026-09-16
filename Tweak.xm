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

    if (height < 0.0) {
        height = 0.0;
    }

    if (height > 120.0) {
        height = 120.0;
    }

    return height;
}

#pragma mark - Portrait check

static BOOL SHAPortrait(void)
{
    CGRect bounds = [UIScreen mainScreen].bounds;

    return bounds.size.height >= bounds.size.width;
}

#pragma mark -
#pragma mark UIApplicationSceneSettings
#pragma mark -

%hook UIApplicationSceneSettings

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

- (CGRect)_statusBarAvoidanceFrame
{
    CGRect original = %orig;

    if (!SHAPortrait()) {
        return original;
    }

    CGRect adjusted = original;

    adjusted.origin.y = 0.0;
    adjusted.size.height = SHAStatusBarHeight();

    return adjusted;
}


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

%end
