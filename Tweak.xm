#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *SHAFile = @"/var/mobile/Media/SHA_LiveGeometry.txt";

static void SHAWrite(NSString *text) {
    @synchronized (SHAFile) {
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:SHAFile];

        if (!handle) {
            [[text dataUsingEncoding:NSUTF8StringEncoding] writeToFile:SHAFile atomically:YES];
        } else {
            [handle seekToEndOfFile];
            [handle writeData:[text dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }
    }
}

static NSString *SHAClassName(id obj) {
    if (!obj) return @"(nil)";
    return NSStringFromClass([obj class]);
}

static NSString *SHAFrame(CGRect r) {
    return [NSString stringWithFormat:
        @"x=%.2f y=%.2f w=%.2f h=%.2f",
        r.origin.x,
        r.origin.y,
        r.size.width,
        r.size.height
    ];
}

static void SHADumpViewChain(UIView *view, NSString *title) {
    if (!view) return;

    NSMutableString *out = [NSMutableString string];

    [out appendFormat:
        @"\n==================================================\n"
         @"%@\n"
         @"==================================================\n",
        title];

    UIView *current = view;
    NSInteger level = 0;

    while (current && level < 15) {

        UIWindow *window = nil;

        if ([current isKindOfClass:[UIWindow class]]) {
            window = (UIWindow *)current;
        } else {
            window = current.window;
        }

        [out appendFormat:
            @"\n[%ld] %@ <%p>\n"
             @" frame: %@\n"
             @" bounds: %@\n"
             @" center: (%.2f, %.2f)\n"
             @" hidden: %@ alpha: %.3f\n"
             @" window: %@ <%p>\n",
            (long)level,
            SHAClassName(current),
            current,
            SHAFrame(current.frame),
            SHAFrame(current.bounds),
            current.center.x,
            current.center.y,
            current.hidden ? @"YES" : @"NO",
            current.alpha,
            window ? SHAClassName(window) : @"(nil)",
            window
        ];

        if (@available(iOS 11.0, *)) {
            [out appendFormat:
                @" safeAreaInsets: top=%.2f left=%.2f bottom=%.2f right=%.2f\n",
                current.safeAreaInsets.top,
                current.safeAreaInsets.left,
                current.safeAreaInsets.bottom,
                current.safeAreaInsets.right
            ];
        }

        if (current.superview) {
            [out appendFormat:
                @" superview: %@ <%p>\n",
                SHAClassName(current.superview),
                current.superview
            ];
        } else {
            [out appendString:@" superview: (nil)\n"];
        }

        NSArray *constraintsV =
            [current constraintsAffectingLayoutForAxis:UILayoutConstraintAxisVertical];

        if (constraintsV.count > 0) {
            [out appendFormat:@" vertical constraints: %lu\n",
                (unsigned long)constraintsV.count];

            NSUInteger max = MIN(constraintsV.count, 12);

            for (NSUInteger i = 0; i < max; i++) {
                [out appendFormat:
                    @"   V[%lu] %@\n",
                    (unsigned long)i,
                    constraintsV[i]
                ];
            }
        }

        current = current.superview;
        level++;
    }

    SHAWrite(out);
}

static void SHAHeader(void) {
    SHAWrite(
        @"\n\n"
         "##################################################\n"
         "# SHA LIVE GEOMETRY DIAGNOSTIC\n"
         "##################################################\n"
         "# NO GEOMETRY IS MODIFIED BY THIS BUILD\n"
         "##################################################\n"
    );
}


// ==================================================
// HOME BAR
// ==================================================

%hook SBHomeGrabberRotationView

- (void)layoutSubviews {
    %orig;

    static BOOL dumped = NO;

    if (!dumped) {
        dumped = YES;

        SHADumpViewChain(
            self,
            @"LIVE HOME BAR - SBHomeGrabberRotationView"
        );

        @try {
            UIView *grabber = [self performSelector:@selector(grabberView)];

            if (grabber) {
                SHADumpViewChain(
                    grabber,
                    @"LIVE HOME BAR - grabberView"
                );
            }
        }
        @catch (...) {
            SHAWrite(@"\n[HOME] grabberView exception\n");
        }
    }
}

%end


// ==================================================
// HOME BAR CONTAINER
// ==================================================

%hook SBHomeGrabberView

- (void)layoutSubviews {
    %orig;

    static BOOL dumped = NO;

    if (!dumped) {
        dumped = YES;

        SHADumpViewChain(
            self,
            @"LIVE HOME BAR - SBHomeGrabberView"
        );
    }
}

%end


// ==================================================
// STATUS BAR ROOT VIEW
// ==================================================

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews {
    %orig;

    static BOOL dumped = NO;

    if (!dumped) {
        dumped = YES;

        SHADumpViewChain(
            self,
            @"LIVE STATUS BAR - SBMainDisplaySceneLayoutStatusBarView"
        );
    }
}

%end


// ==================================================
// STATUS BAR CONTAINER
// ==================================================

%hook SBStatusBarContainer

- (void)layoutSubviews {
    %orig;

    static BOOL dumped = NO;

    if (!dumped) {
        dumped = YES;

        SHADumpViewChain(
            self,
            @"LIVE STATUS BAR - SBStatusBarContainer"
        );
    }
}

%end


// ==================================================
// UIKit STATUS BAR
// ==================================================

%hook _UIStatusBar

- (void)layoutSubviews {
    %orig;

    static BOOL dumped = NO;

    if (!dumped) {
        dumped = YES;

        SHADumpViewChain(
            self,
            @"LIVE STATUS BAR - _UIStatusBar"
        );
    }
}

%end


// ==================================================
// CONSTRUCTOR
// ==================================================

%ctor {

    @autoreleasepool {

        if (![[NSBundle mainBundle].bundleIdentifier
              isEqualToString:@"com.apple.springboard"]) {
            return;
        }

        SHAHeader();

        %init;

        SHAWrite(
            @"\n[+] StatusHomeBarAdjuster diagnostic loaded successfully.\n"
        );
    }
}
