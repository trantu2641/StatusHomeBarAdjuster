#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

@class _UIStatusBar;
@class SBMainDisplaySceneLayoutStatusBarView;
@class SBStatusBarContainer;
@class SBHomeGrabberView;
@class SBHomeGrabberRotationView;

static NSString * const kSHAPath =
    @"/var/mobile/Media/SHA_LiveGeometry.txt";

#pragma mark - File

static void SHAWrite(NSString *text)
{
    if (!text)
        return;

    @try {
        NSFileHandle *file =
            [NSFileHandle fileHandleForWritingAtPath:kSHAPath];

        if (!file) {
            [text writeToFile:kSHAPath
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
    @catch (__unused NSException *e) {
    }
}

static NSString *SHAClass(id object)
{
    if (!object)
        return @"(nil)";

    return NSStringFromClass([object class]);
}

static NSString *SHAFrame(CGRect r)
{
    return [NSString stringWithFormat:
        @"x=%.2f y=%.2f w=%.2f h=%.2f",
        r.origin.x,
        r.origin.y,
        r.size.width,
        r.size.height];
}

#pragma mark - UIView geometry dump

static void SHADumpView(id object, NSString *title)
{
    if (!object)
        return;

    UIView *view = nil;

    if ([object isKindOfClass:[UIView class]])
        view = (UIView *)object;

    NSMutableString *out =
        [NSMutableString string];

    [out appendFormat:
        @"\n\n"
         "============================================================\n"
         "%@\n"
         "============================================================\n",
        title];

    if (!view) {
        [out appendFormat:
            @"Object = %@ <%p>\n"
             "NOT UIView\n",
            SHAClass(object),
            object];

        SHAWrite(out);
        return;
    }

    UIView *current = view;
    NSInteger level = 0;

    while (current && level < 30) {

        [out appendFormat:
            @"\n[%ld] %@ <%p>\n",
            (long)level,
            SHAClass(current),
            current];

        [out appendFormat:
            @"  frame   : %@\n",
            SHAFrame(current.frame)];

        [out appendFormat:
            @"  bounds  : %@\n",
            SHAFrame(current.bounds)];

        [out appendFormat:
            @"  center  : %.2f, %.2f\n",
            current.center.x,
            current.center.y];

        [out appendFormat:
            @"  hidden  : %@\n",
            current.hidden ? @"YES" : @"NO"];

        [out appendFormat:
            @"  alpha   : %.3f\n",
            current.alpha];

        if (@available(iOS 11.0, *)) {

            UIEdgeInsets insets =
                current.safeAreaInsets;

            [out appendFormat:
                @"  safeArea: top=%.2f left=%.2f "
                 @"bottom=%.2f right=%.2f\n",
                insets.top,
                insets.left,
                insets.bottom,
                insets.right];
        }

        UIView *superview =
            current.superview;

        [out appendFormat:
            @"  parent  : %@ <%p>\n",
            superview ? SHAClass(superview) : @"(nil)",
            superview];

        @try {

            NSArray *vertical =
                [current
                    constraintsAffectingLayoutForAxis:
                        UILayoutConstraintAxisVertical];

            [out appendFormat:
                @"  V constraints: %lu\n",
                (unsigned long)vertical.count];

            NSUInteger count =
                MIN((NSUInteger)30,
                    vertical.count);

            for (NSUInteger i = 0; i < count; i++) {

                [out appendFormat:
                    @"    V[%lu] %@\n",
                    (unsigned long)i,
                    vertical[i]];
            }
        }
        @catch (__unused NSException *e) {

            [out appendString:
                @"  V constraints: EXCEPTION\n"];
        }

        @try {

            NSArray *horizontal =
                [current
                    constraintsAffectingLayoutForAxis:
                        UILayoutConstraintAxisHorizontal];

            [out appendFormat:
                @"  H constraints: %lu\n",
                (unsigned long)horizontal.count];

            NSUInteger count =
                MIN((NSUInteger)15,
                    horizontal.count);

            for (NSUInteger i = 0; i < count; i++) {

                [out appendFormat:
                    @"    H[%lu] %@\n",
                    (unsigned long)i,
                    horizontal[i]];
            }
        }
        @catch (__unused NSException *e) {

            [out appendString:
                @"  H constraints: EXCEPTION\n"];
        }

        current = superview;
        level++;
    }

    SHAWrite(out);
}

#pragma mark - Class methods dump

static void SHADumpClass(Class cls, NSString *name)
{
    if (!cls)
        return;

    NSMutableString *out =
        [NSMutableString string];

    [out appendFormat:
        @"\n\n"
         "############################################################\n"
         "# CLASS %@\n"
         "############################################################\n",
        name];

    Class superClass =
        class_getSuperclass(cls);

    if (superClass) {
        [out appendFormat:
            @"Superclass: %@\n",
            NSStringFromClass(superClass)];
    }

    unsigned int count = 0;

    Method *methods =
        class_copyMethodList(cls, &count);

    [out appendFormat:
        @"Instance methods: %u\n",
        count];

    for (unsigned int i = 0; i < count; i++) {

        SEL selector =
            method_getName(methods[i]);

        [out appendFormat:
            @"  - %s\n",
            sel_getName(selector)];
    }

    if (methods)
        free(methods);

    unsigned int classCount = 0;

    Method *classMethods =
        class_copyMethodList(
            object_getClass(cls),
            &classCount);

    [out appendFormat:
        @"Class methods: %u\n",
        classCount];

    for (unsigned int i = 0;
         i < classCount;
         i++) {

        SEL selector =
            method_getName(classMethods[i]);

        [out appendFormat:
            @"  + %s\n",
            sel_getName(selector)];
    }

    if (classMethods)
        free(classMethods);

    SHAWrite(out);
}

#pragma mark - Home Grabber Rotation View

%hook SBHomeGrabberRotationView

- (void)layoutSubviews
{
    %orig;

    static BOOL dumped = NO;

    if (dumped)
        return;

    dumped = YES;

    id object = (id)self;

    SHADumpView(
        object,
        @"LIVE HOME BAR / SBHomeGrabberRotationView"
    );

    @try {

        SEL selector =
            NSSelectorFromString(@"grabberView");

        id receiver = object;

        BOOL responds =
            [receiver respondsToSelector:selector];

        SHAWrite(
            [NSString stringWithFormat:
                @"\n[HOME]\n"
                 "grabberView selector available = %@\n",
                responds ? @"YES" : @"NO"]
        );

        if (responds) {

            id grabber =
                ((id (*)(id, SEL))
                    objc_msgSend)(
                        receiver,
                        selector);

            if (grabber) {

                SHADumpView(
                    grabber,
                    @"LIVE HOME BAR / grabberView"
                );
            }
        }
    }
    @catch (NSException *exception) {

        SHAWrite(
            [NSString stringWithFormat:
                @"\n[HOME EXCEPTION] %@\n",
                exception]
        );
    }
}

%end

#pragma mark - Home Grabber View

%hook SBHomeGrabberView

- (void)layoutSubviews
{
    %orig;

    static BOOL dumped = NO;

    if (dumped)
        return;

    dumped = YES;

    SHADumpView(
        (id)self,
        @"LIVE HOME BAR / SBHomeGrabberView"
    );
}

%end

#pragma mark - Status Bar Main Display

%hook SBMainDisplaySceneLayoutStatusBarView

- (void)layoutSubviews
{
    %orig;

    static BOOL dumped = NO;

    if (dumped)
        return;

    dumped = YES;

    SHADumpView(
        (id)self,
        @"LIVE STATUS BAR / SBMainDisplaySceneLayoutStatusBarView"
    );
}

%end

#pragma mark - Status Bar Container

%hook SBStatusBarContainer

- (void)layoutSubviews
{
    %orig;

    static BOOL dumped = NO;

    if (dumped)
        return;

    dumped = YES;

    SHADumpView(
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

    SHADumpView(
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

        if (![bundleID
            isEqualToString:@"com.apple.springboard"]) {

            return;
        }

        /*
         * Xóa file diagnostic cũ.
         */
        [@"" writeToFile:kSHAPath
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];

        SHAWrite(
            @"############################################################\n"
             "# StatusHomeBarAdjuster\n"
             "# LIVE GEOMETRY DIAGNOSTIC\n"
             "#\n"
             "# NO FRAME / BOUNDS / TRANSFORM IS MODIFIED\n"
             "############################################################\n"
        );

        Class homeRotation =
            objc_getClass(
                "SBHomeGrabberRotationView");

        Class home =
            objc_getClass(
                "SBHomeGrabberView");

        Class statusMain =
            objc_getClass(
                "SBMainDisplaySceneLayoutStatusBarView");

        Class statusContainer =
            objc_getClass(
                "SBStatusBarContainer");

        Class status =
            objc_getClass(
                "_UIStatusBar");

        SHAWrite(
            [NSString stringWithFormat:
                @"\n[RUNTIME CLASS CHECK]\n"
                 "SBHomeGrabberRotationView : %@\n"
                 "SBHomeGrabberView : %@\n"
                 "SBMainDisplaySceneLayoutStatusBarView : %@\n"
                 "SBStatusBarContainer : %@\n"
                 "_UIStatusBar : %@\n",
                homeRotation ? @"FOUND" : @"NOT FOUND",
                home ? @"FOUND" : @"NOT FOUND",
                statusMain ? @"FOUND" : @"NOT FOUND",
                statusContainer ? @"FOUND" : @"NOT FOUND",
                status ? @"FOUND" : @"NOT FOUND"
            ]
        );

        /*
         * Dump method list để biết chính xác class
         * nào có API geometry/layout.
         */
        if (homeRotation) {
            SHADumpClass(
                homeRotation,
                @"SBHomeGrabberRotationView");
        }

        if (home) {
            SHADumpClass(
                home,
                @"SBHomeGrabberView");
        }

        if (statusMain) {
            SHADumpClass(
                statusMain,
                @"SBMainDisplaySceneLayoutStatusBarView");
        }

        if (statusContainer) {
            SHADumpClass(
                statusContainer,
                @"SBStatusBarContainer");
        }

        if (status) {
            SHADumpClass(
                status,
                @"_UIStatusBar");
        }

        SHAWrite(
            @"\n[+] Diagnostic loaded successfully.\n"
        );

        %init;
    }
}
