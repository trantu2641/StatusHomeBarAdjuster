#import <Foundation/Foundation.h>

%ctor
{
    @autoreleasepool
    {
        NSLog(
            @"[StatusHomeBarAdjuster] ======================================="
        );

        NSLog(
            @"[StatusHomeBarAdjuster] TWEAK LOADED"
        );

        NSLog(
            @"[StatusHomeBarAdjuster] Bundle: com.congtu.statushomebaradjuster"
        );

        NSLog(
            @"[StatusHomeBarAdjuster] Process: %@",
            [[NSProcessInfo processInfo] processName]
        );

        NSLog(
            @"[StatusHomeBarAdjuster] PID: %d",
            [[NSProcessInfo processInfo] processIdentifier]
        );

        NSLog(
            @"[StatusHomeBarAdjuster] ======================================="
        );
    }
}
