#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#pragma mark - SBMainDisplaySceneLayoutStatusBarView

%group SHAStatusBarLayoutGroup

%hook SBMainDisplaySceneLayoutStatusBarView

/*
 * iOS 16.4 diagnostic đã xác nhận method này tồn tại:
 *
 * - statusBar:willAnimateFromHeight:toHeight:duration:animation:
 *
 * Bản test này KHÔNG thay đổi geometry.
 *
 * Không:
 * - sửa frame
 * - sửa bounds
 * - sửa center
 * - sửa transform
 * - gọi layoutSubviews
 * - sửa safeAreaInsets
 * - hook UIStatusBar_Modern
 *
 * Mục đích duy nhất:
 * xác nhận hook này có an toàn trên SpringBoard iOS 16.4 hay không.
 */

- (void)statusBar:(id)statusBar
willAnimateFromHeight:(CGFloat)fromHeight
      toHeight:(CGFloat)toHeight
      duration:(NSTimeInterval)duration
     animation:(id)animation
{
    %orig(statusBar,
          fromHeight,
          toHeight,
          duration,
          animation);
}

%end

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool {

        Class cls =
            NSClassFromString(
                @"SBMainDisplaySceneLayoutStatusBarView"
            );

        SEL selector =
            @selector(
                statusBar:
                willAnimateFromHeight:
                toHeight:
                duration:
                animation:
            );

        if (cls &&
            [cls instancesRespondToSelector:selector]) {

            %init(SHAStatusBarLayoutGroup);
        }
    }
}
