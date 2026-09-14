#import "RootListController.h"
#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <notify.h>

@implementation RootListController

- (NSArray *)specifiers
{
    if (!_specifiers) {
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
            initWithSuiteName:@"com.congtu.statushomebaradjuster"];

    NSInteger status =
        [defaults integerForKey:@"StatusBarOffset"];

    NSInteger home =
        [defaults integerForKey:@"HomeBarOffset"];

    status = MAX(-120, MIN(120, status));
    home = MAX(-120, MIN(120, home));

    [defaults setInteger:status
                  forKey:@"StatusBarOffset"];

    [defaults setInteger:home
                  forKey:@"HomeBarOffset"];

    [defaults synchronize];

    notify_post(
        "com.congtu.statushomebaradjuster.settingsChanged"
    );
}

@end
