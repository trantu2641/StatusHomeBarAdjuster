#import "RootListController.h"

#import <Preferences/Preferences.h>
#import <Foundation/Foundation.h>
#import <notify.h>


static NSString * const SHA_PREFS_SUITE =
    @"com.congtu.statushomebaradjuster";

static NSString * const SHA_STATUS_KEY =
    @"StatusBarHeight";

static NSString * const SHA_HOME_KEY =
    @"HomeBarHeight";

static const char *SHA_SETTINGS_CHANGED =
    "com.congtu.statushomebaradjuster.settingsChanged";


@implementation SHAStatusHomeBarAdjusterController


- (NSArray *)specifiers
{
    if (!_specifiers)
    {
        _specifiers =
            [self loadSpecifiersFromPlistName:@"Root"
                                       target:self];
    }

    return _specifiers;
}


- (void)applySettings
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:SHA_PREFS_SUITE];


    NSInteger status =
        [defaults integerForKey:SHA_STATUS_KEY];

    NSInteger home =
        [defaults integerForKey:SHA_HOME_KEY];


    /*
     * Chỉ cho phép:
     *
     * 0 → 120
     */

    status = MAX(0, MIN(120, status));
    home   = MAX(0, MIN(120, home));


    [defaults setInteger:status
                  forKey:SHA_STATUS_KEY];

    [defaults setInteger:home
                  forKey:SHA_HOME_KEY];


    [defaults synchronize];


    /*
     * Báo cho tweak refresh.
     */

    notify_post(SHA_SETTINGS_CHANGED);
}


@end
