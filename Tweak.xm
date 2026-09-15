#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void SHADumpClass(Class cls, NSMutableString *output)
{
    if (!cls)
        return;

    const char *className = class_getName(cls);

    [output appendFormat:
        @"\n==================================================\n"
         @"CLASS: %s\n"
         @"==================================================\n",
         className];


    /*
     * Instance methods
     */
    unsigned int count = 0;

    Method *methods =
        class_copyMethodList(cls, &count);

    [output appendFormat:
        @"\n-- INSTANCE METHODS (%u) --\n",
        count];

    for (unsigned int i = 0; i < count; i++)
    {
        Method method = methods[i];

        SEL selector =
            method_getName(method);

        const char *types =
            method_getTypeEncoding(method);

        [output appendFormat:
            @"- %s    [%s]\n",
            sel_getName(selector),
            types ? types : ""];
    }

    if (methods)
        free(methods);


    /*
     * Class methods
     */
    Class metaClass =
        object_getClass(cls);

    count = 0;

    Method *classMethods =
        class_copyMethodList(metaClass, &count);

    [output appendFormat:
        @"\n-- CLASS METHODS (%u) --\n",
        count];

    for (unsigned int i = 0; i < count; i++)
    {
        Method method = classMethods[i];

        SEL selector =
            method_getName(method);

        const char *types =
            method_getTypeEncoding(method);

        [output appendFormat:
            @"+ %s    [%s]\n",
            sel_getName(selector),
            types ? types : ""];
    }

    if (classMethods)
        free(classMethods);


    /*
     * Superclass chain
     */
    [output appendString:@"\n-- SUPERCLASS CHAIN --\n"];

    Class superClass =
        class_getSuperclass(cls);

    while (superClass)
    {
        [output appendFormat:
            @"  -> %s\n",
            class_getName(superClass)];

        superClass =
            class_getSuperclass(superClass);
    }
}


static void SHADumpRuntime(void)
{
    NSMutableString *output =
        [NSMutableString string];


    [output appendString:
        @"STATUS HOME BAR ADJUSTER\n"
         @"iOS Objective-C Runtime Diagnostic\n\n"];


    [output appendString:
        @"This file was generated directly inside SpringBoard.\n\n"];


    /*
     * Find every loaded class containing:
     *
     * HomeGrabber
     * HomeBar
     * Grabber
     * StatusBar
     */
    unsigned int classCount = 0;

    Class *classes =
        objc_copyClassList(&classCount);


    [output appendFormat:
        @"TOTAL LOADED CLASSES: %u\n\n",
        classCount];


    [output appendString:
        @"==================================================\n"
         @"MATCHING CLASSES\n"
         @"==================================================\n\n"];


    for (unsigned int i = 0; i < classCount; i++)
    {
        Class cls = classes[i];

        const char *name =
            class_getName(cls);

        if (!name)
            continue;


        NSString *className =
            [NSString stringWithUTF8String:name];

        if ([className rangeOfString:
                @"HomeGrabber"
                options:NSCaseInsensitiveSearch].location != NSNotFound ||

            [className rangeOfString:
                @"HomeBar"
                options:NSCaseInsensitiveSearch].location != NSNotFound ||

            [className rangeOfString:
                @"Grabber"
                options:NSCaseInsensitiveSearch].location != NSNotFound ||

            [className rangeOfString:
                @"StatusBar"
                options:NSCaseInsensitiveSearch].location != NSNotFound)
        {
            [output appendFormat:
                @"FOUND: %s\n",
                name];
        }
    }


    /*
     * Explicit important classes.
     */
    const char *importantClasses[] =
    {
        "SBHomeGrabberView",
        "SBHomeGrabberRotationView",
        "SBHomeGrabberRevealGesturesManager",
        "SBHomeGrabberSettings",
        "_UIStatusBar",
        "_UIStatusBarVisualProvider_iOS",
        "_UIStatusBarVisualProvider_Split",
        "UIApplicationSceneSettings"
    };


    [output appendString:
        @"\n\n==================================================\n"
         @"IMPORTANT CLASSES\n"
         @"==================================================\n"];


    for (NSUInteger i = 0;
         i < sizeof(importantClasses) / sizeof(importantClasses[0]);
         i++)
    {
        const char *name =
            importantClasses[i];

        Class cls =
            objc_getClass(name);

        if (cls)
        {
            SHADumpClass(cls, output);
        }
        else
        {
            [output appendFormat:
                @"\nCLASS NOT LOADED: %s\n",
                name];
        }
    }


    if (classes)
        free(classes);


    /*
     * Save result.
     */
    NSString *path =
        @"/var/mobile/Media/SHA_RuntimeDump.txt";


    NSError *error = nil;

    BOOL success =
        [output writeToFile:path
                 atomically:YES
                   encoding:NSUTF8StringEncoding
                      error:&error];


    if (!success)
    {
        NSString *fallback =
            [NSString stringWithFormat:
                @"ERROR WRITING FILE:\n%@\n\n%@",
                error,
                output];

        [fallback writeToFile:
            @"/tmp/SHA_RuntimeDump.txt"
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:nil];
    }
}


%ctor
{
    NSString *bundleIdentifier =
        [[NSBundle mainBundle] bundleIdentifier];

    if (![bundleIdentifier
            isEqualToString:@"com.apple.springboard"])
    {
        return;
    }


    /*
     * Chờ SpringBoard khởi tạo Objective-C classes.
     */
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(5.0 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{
            SHADumpRuntime();
        }
    );
}
