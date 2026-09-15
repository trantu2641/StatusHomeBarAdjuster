#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

@class _UIStatusBar;
@class SBMainDisplaySceneLayoutStatusBarView;
@class SBStatusBarContainer;
@class SBHomeGrabberView;
@class SBHomeGrabberRotationView;

static NSString * const kSHADiagnosticPath =
    @"/var/mobile/Media/SHA_LiveGeometry.txt";

#pragma mark - File output

static void SHAAppend(NSString *text)
{
    if (!text)
        return;

    @try {
        NSFileHandle *file =
            [NSFileHandle fileHandleForWritingAtPath:kSHADiagnosticPath];

        if (!file) {
            [text writeToFile:kSHADiagnosticPath
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:nil];
            return;
        }

        [file seekToEndOfFile];

        NSData *data =
            [text dataUsingEncoding:NSUTF8StringEncoding];

        if (data)
            [file writeData:data];

        [file closeFile];
    }
    @catch (__unused NSException *exception) {
    }
}

static NSString *SHAClassName(id object)
{
    if (!object)
        return @"(nil)";

    return NSStringFromClass([object class]);
}

static NSString *SHAFrameString(CGRect frame)
{
    return [NSString stringWithFormat:
        @"x=%.2f y=%.2f w=%.2f h=%.2f",
        frame.origin.x,
        frame.origin.y,
        frame.size.width,
        frame.size.height
    ];
}

static NSString *SHABoundsString(CGRect bounds)
{
    return [NSString stringWithFormat:
        @"x=%.2f y=%.2f w=%.2f h=%.2f",
        bounds.origin.x,
        bounds.origin.y,
        bounds.size.width,
        bounds.size.height
    ];
}

#pragma mark - View diagnostic

static void SHADumpViewChain(id object, NSString *title)
{
    if (!object)
        return;

    UIView *view = nil;

    /*
     * Private SpringBoard classes are only forward-declared above.
     * Therefore we intentionally convert them through id.
     */
    if ([object isKindOfClass:[UIView class]]) {
        view = (UIView *)object;
    }

    NSMutableString *output = [NSMutableString string];

    [output appendFormat:
        @"\n"
         "============================================================\n"
         "%@\n"
         "============================================================\n",
        title
    ];

    if (!view) {
        [output appendFormat:
            @"Object: %@ <%p>\n"
             "NOT a UIView instance\n",
            SHAClassName(object),
            object
        ];

        SHAAppend(output);
        return;
    }

    UIView *current = view;
    NSInteger level = 0;

    while (current && level < 25) {

        [output appendFormat:
            @"\n[%ld] %@ <%p>\n",
            (long)level,
            SHAClassName(current),
            current
        ];

        [output appendFormat:
            @"  frame       = %@\n",
            SHAFrameString(current.frame)
        ];

        [output appendFormat:
            @"  bounds      = %@\n",
            SHABoundsString(current.bounds)
        ];

        [output appendFormat:
            @"  center      = (%.2f, %.2f)\n",
            current.center.x,
            current.center.y
        ];

        [output appendFormat:
            @"  hidden      = %@\n",
            current.hidden ? @"YES" : @"NO"
        ];

        [output appendFormat:
            @"  alpha       = %.3f\n",
            current.alpha
        ];

        [output appendFormat:
            @"  userInteraction = %@\n",
            current.userInteractionEnabled ? @"YES" : @"NO"
        ];

        if (@available(iOS 11.0, *)) {

            UIEdgeInsets safeArea =
                current.safeAreaInsets;

            [output appendFormat:
                @"  safeAreaInsets = "
                 @"top %.2f / left %.2f / "
                 @"bottom %.2f / right %.2f\n",
                safeArea.top,
                safeArea.left,
                safeArea.bottom,
                safeArea.right
            ];
        }

        UIView *superview =
            current.superview;

        if (superview) {

            [output appendFormat:
                @"  superview   = %@ <%p>\n",
                SHAClassName(superview),
                superview
            ];

        } else {

            [output appendString:
                @"  superview   = (nil)\n"
            ];
        }

        /*
         * Vertical constraints affecting this view.
         */
        @try {

            NSArray *verticalConstraints =
                [current
                    constraintsAffectingLayoutForAxis:
                        UILayoutConstraintAxisVertical];

            [output appendFormat:
                @"  V constraints = %lu\n",
                (unsigned long)verticalConstraints.count
            ];

            NSUInteger count =
                MIN((NSUInteger)20,
                    verticalConstraints.count);

            for (NSUInteger i = 0; i < count; i++) {

                NSLayoutConstraint *constraint =
                    verticalConstraints[i];

                [output appendFormat:
                    @"    V[%lu] = %@\n",
                    (unsigned long)i,
                    constraint
                ];
            }
        }
        @catch (__unused NSException *exception) {

            [output appendString:
                @"  V constraints = <exception>\n"
            ];
        }

        /*
         * Horizontal constraints.
         */
        @try {

            NSArray *horizontalConstraints =
                [current
                    constraintsAffectingLayoutForAxis:
                        UILayoutConstraintAxisHorizontal];

            [output appendFormat:
                @"  H constraints = %lu\n",
                (unsigned long)horizontalConstraints.count
            ];

            NSUInteger count =
                MIN((NSUInteger)10,
                    horizontalConstraints.count);

            for (NSUInteger i = 0; i < count; i++) {

                NSLayoutConstraint *constraint =
                    horizontalConstraints[i];

                [output appendFormat:
                    @"    H[%lu] = %@\n",
                    (unsigned long)i,
                    constraint
                ];
            }
        }
        @catch (__unused NSException *exception) {

            [output appendString:
                @"  H constraints = <exception>\n"
            ];
        }

        current = current.superview;
        level++;
    }

    SHAAppend(output);
}

#pragma mark - Runtime information

static void SHADumpClassMethods(Class cls,
                                 NSString *name)
{
    if (!cls)
        return;

    NSMutableString *output = [NSMutableString string];

    [output appendFormat:
        @"\n\n"
         "############################################################\n"
         "# CLASS: %@\n"
         "############################################################\n",
        name
    ];

    Class superClass = class_getSuperclass(cls);

    if (superClass) {

        [output appendFormat:
            @"Superclass: %@\n",
            NSStringFromClass(superClass)
        ];
    }

    unsigned int count = 0;

    Method *methods =
        class_copyMethodList(cls, &count);

    [output appendFormat:
        @"Instance methods: %u\n",
        count
    ];

    for (unsigned int i = 0; i < count; i++) {

        SEL selector =
            method_getName(methods[i]);

        [output appendFormat:
            @"  - %s\n",
            sel_getName(selector)
        ];
    }

    if (methods)
        free(methods);

    unsigned int classCount = 0;

    Method *classMethods =
        class_copyMethodList(
            object_getClass(cls),
            &classCount
        );

    [output appendFormat:
        @"Class methods: %u\n",
        classCount
    ];

    for (unsigned int i = 0; i < classCount; i++) {

        SEL selector =
            method_getName(classMethods[i]);

        [output appendFormat:
            @"  + %s\n",
            sel_getName(selector)
        ];
    }

    if (classMethods)
        free(classMethods);

    SHAAppend(output);
}

#pragma mark - Home Bar

%hook SBHomeGrabberRotationView

- (void)layoutSubviews
{
    %orig;

    static BOOL dumped = NO;

    if (dumped)
        return;

    dumped = YES;

    SHADumpViewChain(
        (id)self,
        @"LIVE HOME BAR / SBHomeGrabberRotationView"
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
                    @"LIVE HOME BAR / grabberView"
                );
            }
        }

    }
    @catch (NSException *exception) {

        SHAAppend(
            [NSString stringWithFormat:
                @"\n[HOME ERROR] %@\n",
                exception
            ]
        );
    }
}

%end

#pragma mark - Home Bar main container

%hook SBHomeGrabberView

- (void)layoutSubviews
{
    %orig;

    static BOOL dumped = NO;

    if (dumped)
        return;

    dumped = YES;

    SHADumpViewChain(
        (id)self,
        @"LIVE HOME BAR / SBHomeGrabberView"
    );
}

%end

#pragma mark - Status Bar main display

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    static BOOL dumped = NO;

    if (dumped)
        return;

    dumped = YES;

    SHADumpViewChain(
        (id)self,
        @"LIVE STATUS BAR / SBMainDisplaySceneLayoutStatusBarView"
    );
}

%end

#pragma mark - Status Bar container

%hook SBStatusBarContainer

- (void)layoutSubviews
{
    %orig;

    static BOOL dumped = NO;

    if (dumped)
        return;

    dumped = YES;

    SHADumpViewChain(
        (id)self,
        @"LIVE STATUS BAR / SBStatusBarContainer"
    );
}

%end

#pragma mark - UIKit Status Bar

%hook _UIStatusBar

- (void)layoutSubviews
{
    %orig;

    static BOOL dumped = NO;

    if (dumped)
        return;

    dumped = YES;

    SHADumpViewChain(
        (id)self,
        @"LIVE STATUS BAR / _UIStatusBar"
    );
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        NSString *bundleID =
            [[NSBundle mainBundle] bundleIdentifier];

        /*
         * Diagnostic only runs inside SpringBoard.
         */
        if (![bundleID
            isEqualToString:@"com.apple.springboard"]) {

            return;
        }

        /*
         * Start a fresh diagnostic file.
         */
        [@"" writeToFile:kSHADiagnosticPath
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];

        SHAAppend(
            @"############################################################\n"
             "# StatusHomeBarAdjuster\n"
             "# LIVE GEOMETRY DIAGNOSTIC\n"
             "#\n"
             "# THIS BUILD DOES NOT MODIFY ANY UI GEOMETRY.\n"
             "############################################################\n"
        );

        /*
         * Confirm classes really exist at runtime.
         */
        Class homeRotation =
            objc_getClass("SBHomeGrabberRotationView");

        Class home =
            objc_getClass("SBHomeGrabberView");

        Class statusMain =
            objc_getClass(
                "SBMainDisplaySceneLayoutStatusBarView"
            );

        Class statusContainer =
            objc_getClass("SBStatusBarContainer");

        Class uiStatus =
            objc_getClass("_UIStatusBar");

        SHAAppend(
            [NSString stringWithFormat:
                @"\n"
                 "[RUNTIME CLASSES]\n"
                 "SBHomeGrabberRotationView = %@\n"
                 "SBHomeGrabberView = %@\n"
                 "SBMainDisplaySceneLayoutStatusBarView = %@\n"
                 "SBStatusBarContainer = %@\n"
                 "_UIStatusBar = %@\n",
                homeRotation ? @"FOUND" : @"NOT FOUND",
                home ? @"FOUND" : @"NOT FOUND",
                statusMain ? @"FOUND" : @"NOT FOUND",
                statusContainer ? @"FOUND" : @"NOT FOUND",
                uiStatus ? @"FOUND" : @"NOT FOUND"
            ]
        );

        /*
         * Dump the important classes' method lists.
         */
        if (homeRotation) {
            SHADumpClassMethods(
                homeRotation,
                @"SBHomeGrabberRotationView"
            );
        }

        if (home) {
            SHADumpClassMethods(
                home,
                @"SBHomeGrabberView"
            );
        }

        if (statusMain) {
            SHADumpClassMethods(
                statusMain,
                @"SBMainDisplaySceneLayoutStatusBarView"
            );
        }

        if (statusContainer) {
            SHADumpClassMethods(
                statusContainer,
                @"SBStatusBarContainer"
            );
        }

        if (uiStatus) {
            SHADumpClassMethods(
                uiStatus,
                @"_UIStatusBar"
            );
        }

        SHAAppend(
            @"\n[+] Diagnostic tweak loaded.\n"
        );

        %init;
    }
}
