#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString * const kSHADiagnosticPath =
    @"/var/mobile/Media/SHA_Diagnostic.txt";

#pragma mark - File Logger

static void SHALog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);

    NSString *message =
        [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    NSString *line =
        [NSString stringWithFormat:@"%@\n", message];

    NSData *data =
        [line dataUsingEncoding:NSUTF8StringEncoding];

    NSFileHandle *handle =
        [NSFileHandle fileHandleForWritingAtPath:kSHADiagnosticPath];

    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } else {
        [data writeToFile:kSHADiagnosticPath atomically:YES];
    }
}

static NSString *SHAFrameString(CGRect frame)
{
    return [NSString stringWithFormat:
            @"{x=%.2f y=%.2f w=%.2f h=%.2f}",
            frame.origin.x,
            frame.origin.y,
            frame.size.width,
            frame.size.height];
}

static NSString *SHAInsetsString(UIEdgeInsets insets)
{
    return [NSString stringWithFormat:
            @"{top=%.2f left=%.2f bottom=%.2f right=%.2f}",
            insets.top,
            insets.left,
            insets.bottom,
            insets.right];
}

#pragma mark - View Dump

static void SHADumpView(UIView *view, NSInteger depth)
{
    if (!view || depth > 5)
        return;

    NSMutableString *prefix = [NSMutableString string];

    for (NSInteger i = 0; i < depth; i++)
        [prefix appendString:@"  "];

    NSString *name = NSStringFromClass(view.class);

    SHALog(@"%@CLASS %@", prefix, name);
    SHALog(@"%@FRAME %@", prefix, SHAFrameString(view.frame));
    SHALog(@"%@BOUNDS %@", prefix, SHAFrameString(view.bounds));
    SHALog(@"%@SAFE %@", prefix, SHAInsetsString(view.safeAreaInsets));
    SHALog(@"%@SUBVIEWS %lu",
           prefix,
           (unsigned long)view.subviews.count);

    for (UIView *subview in view.subviews)
        SHADumpView(subview, depth + 1);
}

#pragma mark - Class Methods

static void SHADumpClass(NSString *className)
{
    Class cls = NSClassFromString(className);

    SHALog(@"");
    SHALog(@"========================================");
    SHALog(@"CLASS: %@", className);
    SHALog(@"========================================");

    if (!cls) {
        SHALog(@"CLASS NOT FOUND");
        return;
    }

    SHALog(@"Class pointer: %p", cls);
    SHALog(@"Superclass: %@", NSStringFromClass(class_getSuperclass(cls)));

    unsigned int count = 0;

    Method *methods =
        class_copyMethodList(object_getClass(cls), &count);

    SHALog(@"--- CLASS METHODS (%u) ---", count);

    for (unsigned int i = 0; i < count; i++) {

        SEL selector =
            method_getName(methods[i]);

        const char *types =
            method_getTypeEncoding(methods[i]);

        SHALog(@"+ %@   [%s]",
               NSStringFromSelector(selector),
               types ?: "");
    }

    free(methods);

    count = 0;

    methods =
        class_copyMethodList(cls, &count);

    SHALog(@"--- INSTANCE METHODS (%u) ---", count);

    for (unsigned int i = 0; i < count; i++) {

        SEL selector =
            method_getName(methods[i]);

        const char *types =
            method_getTypeEncoding(methods[i]);

        SHALog(@"- %@   [%s]",
               NSStringFromSelector(selector),
               types ?: "");
    }

    free(methods);
}

#pragma mark - Runtime Geometry

static void SHADumpRuntime(void)
{
    SHALog(@"");
    SHALog(@"########################################");
    SHALog(@"STATUSHOMEBARADJUSTER DIAGNOSTIC");
    SHALog(@"########################################");

    SHALog(@"Process: %@", NSProcessInfo.processInfo.processName);
    SHALog(@"Bundle: %@", NSBundle.mainBundle.bundleIdentifier);
    SHALog(@"iOS: %@", UIDevice.currentDevice.systemVersion);

    UIApplication *app = UIApplication.sharedApplication;

    SHALog(@"Connected scenes: %lu",
           (unsigned long)app.connectedScenes.count);

    for (UIScene *scene in app.connectedScenes) {

        SHALog(@"");
        SHALog(@"SCENE %@", NSStringFromClass(scene.class));
        SHALog(@"Scene state: %ld",
               (long)scene.activationState);

        if ([scene isKindOfClass:[UIWindowScene class]]) {

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            SHALog(@"Orientation: %ld",
                   (long)windowScene.interfaceOrientation);

            SHALog(@"Windows: %lu",
                   (unsigned long)windowScene.windows.count);

            for (UIWindow *window in windowScene.windows) {

                SHALog(@"");
                SHALog(@"WINDOW %@", NSStringFromClass(window.class));
                SHALog(@"Frame %@", SHAFrameString(window.frame));
                SHALog(@"Bounds %@", SHAFrameString(window.bounds));
                SHALog(@"Safe %@", SHAInsetsString(window.safeAreaInsets));
                SHALog(@"Hidden %d", window.hidden);
                SHALog(@"Level %.2f", window.windowLevel);

                if (window.rootViewController) {

                    SHALog(@"ROOT VC %@",
                           NSStringFromClass(window.rootViewController.class));

                    SHALog(@"ROOT VIEW %@",
                           NSStringFromClass(window.rootViewController.view.class));

                    SHADumpView(window.rootViewController.view, 0);
                }
            }
        }
    }

    /*
     * Các class quan trọng.
     */
    SHADumpClass(@"UIStatusBar_Modern");
    SHADumpClass(@"UIStatusBarWindow");
    SHADumpClass(@"_UIStatusBar");
    SHADumpClass(@"SBMainDisplaySceneLayoutStatusBarView");
    SHADumpClass(@"SBDeviceApplicationSceneView");
    SHADumpClass(@"SBHomeGrabberView");
    SHADumpClass(@"SBHomeGrabberRotationView");
    SHADumpClass(@"UIApplicationSceneSettings");

    SHALog(@"");
    SHALog(@"########################################");
    SHALog(@"END DIAGNOSTIC");
    SHALog(@"########################################");
}

#pragma mark - Visual Marker

static void SHAShowMarker(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{

        UIWindow *targetWindow = nil;

        for (UIScene *scene in
             UIApplication.sharedApplication.connectedScenes) {

            if (![scene isKindOfClass:[UIWindowScene class]])
                continue;

            UIWindowScene *ws = (UIWindowScene *)scene;

            for (UIWindow *window in ws.windows) {

                if (!window.hidden &&
                    window.bounds.size.width > 0 &&
                    window.bounds.size.height > 0) {

                    targetWindow = window;
                    break;
                }
            }

            if (targetWindow)
                break;
        }

        if (!targetWindow)
            return;

        UILabel *label =
            [[UILabel alloc] initWithFrame:CGRectMake(10, 80, 250, 45)];

        label.text = @"SHA DIAGNOSTIC: LOADED";
        label.textAlignment = NSTextAlignmentCenter;
        label.font =
            [UIFont boldSystemFontOfSize:13.0];
        label.textColor = UIColor.whiteColor;
        label.backgroundColor =
            [UIColor colorWithWhite:0.0 alpha:0.85];
        label.layer.cornerRadius = 8.0;
        label.clipsToBounds = YES;

        label.tag = 5316001;

        [targetWindow addSubview:label];

        /*
         * Tự biến mất sau 10 giây.
         */
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(10 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{

                UIView *marker =
                    [targetWindow viewWithTag:5316001];

                [marker removeFromSuperview];
            });
    });
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        NSString *bundleID =
            NSBundle.mainBundle.bundleIdentifier;

        /*
         * Chỉ chạy trong SpringBoard.
         */
        if (![bundleID isEqualToString:@"com.apple.springboard"])
            return;

        SHALog(@"");
        SHALog(@"[SHA] CONSTRUCTOR EXECUTED");
        SHALog(@"[SHA] SpringBoard detected");

        SHAShowMarker();

        /*
         * Đợi SpringBoard dựng xong hierarchy.
         */
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(3 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{

                SHALog(@"[SHA] Starting runtime dump");

                SHADumpRuntime();

                SHALog(@"[SHA] Runtime dump completed");
            });
    }
}
