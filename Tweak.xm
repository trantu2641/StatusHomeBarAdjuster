#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@class _UIStatusBar;
@class SBMainDisplaySceneLayoutStatusBarView;
@class SBStatusBarContainer;
@class SBHomeGrabberView;
@class SBHomeGrabberRotationView;

static NSString *SHAFile = @"/var/mobile/Media/SHA_LiveGeometry.txt";

static void SHAWrite(NSString *text) {
    @synchronized (SHAFile) {
        NSFileHandle *handle =
            [NSFileHandle fileHandleForWritingAtPath:SHAFile];

        if (!handle) {
            [[text dataUsingEncoding:NSUTF8StringEncoding]
                writeToFile:SHAFile
                atomically:YES];
        } else {
            [handle seekToEndOfFile];
            [handle writeData:
                [text dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }
    }
}

static NSString *SHAClassName(id obj) {
    if (!obj) {
        return @"(nil)";
    }

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


/*
 * Quan trọng:
 *
 * Dùng id thay vì UIView * ở argument đầu tiên.
 * Các class private của SpringBoard chỉ được forward-declare,
 * nên compiler không biết chúng kế thừa UIView.
 */
static void SHADumpViewChain(id object, NSString *title) {

    if (!object) {
        return;
    }

    UIView *view = nil;

    if ([object isKindOfClass:[UIView class]]) {
        view = (UIView *)object;
    }

    if (!view) {
        SHAWrite(
            [NSString stringWithFormat:
                @"\n[%@]\n"
                 "Object %@ <%p> is NOT UIView\n",
                title,
                SHAClassName(object),
                object
            ]
        );

        return;
    }

    NSMutableString *out = [NSMutableString string];

    [out appendFormat:
        @"\n==================================================\n"
         @"%@\n"
         @"==================================================\n",
        title
    ];

    UIView *current = view;
    NSInteger level = 0;

    while (current && level < 20) {

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
             @" hidden: %@\n"
             @" alpha: %.3f\n"
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

            UIEdgeInsets safe = current.safeAreaInsets;

            [out appendFormat:
                @" safeAreaInsets: "
                 @"top=%.2f "
                 @"left=%.2f "
                 @"bottom=%.2f "
                 @"right=%.2f\n",
                safe.top,
                safe.left,
                safe.bottom,
                safe.right
            ];
        }

        UIView *superview = current.superview;

        if (superview) {
            [out appendFormat:
                @" superview: %@ <%p>\n",
                SHAClassName(superview),
                superview
            ];
        } else {
            [out appendString:
                @" superview: (nil)\n"
            ];
        }

        NSArray *verticalConstraints =
            [current constraintsAffectingLayoutForAxis:
                UILayoutConstraintAxisVertical];

        if (verticalConstraints.count > 0) {

            [out appendFormat:
                @" vertical constraints: %lu\n",
                (unsigned long)verticalConstraints.count
            ];

            NSUInteger max =
                MIN(verticalConstraints.count, 20);

            for (NSUInteger i = 0; i < max; i++) {

                [out appendFormat:
                    @"   V[%lu] %@\n",
                    (unsigned long)i,
                    verticalConstraints[i]
                ];
            }
        }

        current = superview;
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
         "# THIS BUILD DOES NOT MODIFY GEOMETRY\n"
         "##################################################\n"
    );
}


// ==================================================
// HOME BAR — ROTATION VIEW
// ==================================================

%hook SBHomeGrabberRotationView

- (void)layoutSubviews {

    %orig;

    static BOOL dumped = NO;

    if (!dumped) {

        dumped = YES;

        SHADumpViewChain(
            (id)self,
            @"LIVE HOME BAR - SBHomeGrabberRotationView"
        );

        @try {

            SEL selector =
                NSSelectorFromString(@"grabberView");

            if ([self respondsToSelector:selector]) {

                id grabber =
                    ((id (*)(id, SEL))
                        objc_msgSend)(
                            (id)self,
                            selector
                        );

                if (grabber) {

                    SHADumpViewChain(
                        grabber,
                        @"LIVE HOME BAR - grabberView"
                    );
                }
            }
        }
        @catch (...) {

            SHAWrite(
                @"\n[HOME] grabberView exception\n"
            );
        }
    }
}

%end


// ==================================================
// HOME BAR — MAIN VIEW
// ==================================================

%hook SBHomeGrabberView

- (void)layoutSubviews {

    %orig;

    static BOOL dumped = NO;

    if (!dumped) {

        dumped = YES;

        SHADumpViewChain(
            (id)self,
            @"LIVE HOME BAR - SBHomeGrabberView"
        );
    }
}

%end


// ==================================================
// STATUS BAR — MAIN DISPLAY VIEW
// ==================================================

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews {

    %orig;

    static BOOL dumped = NO;

    if (!dumped) {

        dumped = YES;

        SHADumpViewChain(
            (id)self,
            @"LIVE STATUS BAR - SBMainDisplaySceneLayoutStatusBarView"
        );
    }
}

%end


// ==================================================
// STATUS BAR — CONTAINER
// ==================================================

%hook SBStatusBarContainer

- (void)layoutSubviews {

    %orig;

    static BOOL dumped = NO;

    if (!dumped) {

        dumped = YES;

        SHADumpViewChain(
            (id)self,
            @"LIVE STATUS BAR - SBStatusBarContainer"
        );
    }
}

%end


// ==================================================
// STATUS BAR — UIKIT
// ==================================================

%hook _UIStatusBar

- (void)layoutSubviews {

    %orig;

    static BOOL dumped = NO;

    if (!dumped) {

        dumped = YES;

        SHADumpViewChain(
            (id)self,
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

        NSString *bundleID =
            [[NSBundle mainBundle] bundleIdentifier];

        if (![bundleID
            isEqualToString:@"com.apple.springboard"]) {

            return;
        }

        SHAHeader();

        %init;

        SHAWrite(
            @"\n"
             "[+] SHA diagnostic loaded successfully.\n"
        );
    }
}
