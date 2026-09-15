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


static NSInteger SHAReadValue(NSUserDefaults *defaults,
                              NSString *key)
{
    id value = [defaults objectForKey:key];

    if ([value isKindOfClass:[NSNumber class]])
    {
        return [value integerValue];
    }

    if ([value isKindOfClass:[NSString class]])
    {
        return [(NSString *)value integerValue];
    }

    return 30;
}


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
        SHAReadValue(defaults, SHA_STATUS_KEY);

    NSInteger home =
        SHAReadValue(defaults, SHA_HOME_KEY);


    status =
        MAX(0, MIN(120, status));

    home =
        MAX(0, MIN(120, home));


    /*
     * Lưu dưới dạng NSNumber.
     * Từ đây Tweak đọc integerForKey:
     * sẽ luôn nhận đúng giá trị.
     */
    [defaults setObject:@(status)
                 forKey:SHA_STATUS_KEY];

    [defaults setObject:@(home)
                 forKey:SHA_HOME_KEY];

    [defaults synchronize];


    notify_post(SHA_SETTINGS_CHANGED);
}

@end
