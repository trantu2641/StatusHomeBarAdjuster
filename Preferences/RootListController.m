#import "SHAStatusHomeBarAdjusterController.h"

#import <Preferences/Preferences.h>
#import <Foundation/Foundation.h>
#import <notify.h>


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
    /*
     * DOMAIN RIÊNG HOÀN TOÀN
     */
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:@"com.congtu.statushomebaradjuster"];


    /*
     * Status Bar
     */
    NSInteger status =
        [defaults integerForKey:@"StatusBarOffset"];


    /*
     * Home Bar
     */
    NSInteger home =
        [defaults integerForKey:@"HomeBarOffset"];


    /*
     * Giới hạn -120 → +120
     */

    if (status < -120)
        status = -120;

    if (status > 120)
        status = 120;


    if (home < -120)
        home = -120;

    if (home > 120)
        home = 120;


    /*
     * Ghi lại giá trị đã clamp
     */

    [defaults setInteger:status
                  forKey:@"StatusBarOffset"];


    [defaults setInteger:home
                  forKey:@"HomeBarOffset"];


    [defaults synchronize];


    /*
     * Báo cho SpringBoard reload
     */

    notify_post(
        "com.congtu.statushomebaradjuster.settingsChanged"
    );
}


@end
