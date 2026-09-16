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
