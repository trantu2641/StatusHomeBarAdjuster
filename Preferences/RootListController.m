#import "SHAStatusHomeBarAdjusterController.h"
#import <Preferences/Preferences.h>
#import <Foundation/Foundation.h>
#import <notify.h>

@implementation SHAStatusHomeBarAdjusterController

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
        MAX(-120, MIN(120,
        [defaults integerForKey:@"StatusBarOffset"]));

    NSInteger home =
        MAX(-120, MIN(120,
        [defaults integerForKey:@"HomeBarOffset"]));

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
