// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "SceneDelegate.h"
#import "MMMainViewController.h"

@interface SceneDelegate ()
@end

@implementation SceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.backgroundColor = UIColor.whiteColor;
    UINavigationController *mainNavController = [[UINavigationController alloc] initWithRootViewController:[[MMMainViewController alloc] init]];
    mainNavController.navigationBar.opaque = YES;
    mainNavController.navigationBar.tintColor = kMMColor;
    mainNavController.navigationBar.barTintColor = kMMColor;
    mainNavController.navigationBar.backgroundColor = kMMColor;
    mainNavController.navigationBar.alpha = 1.0f;
    self.window.rootViewController = mainNavController;
    [self.window makeKeyAndVisible];
}
@end
