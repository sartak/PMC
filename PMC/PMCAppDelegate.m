#import "PMCAppDelegate.h"
#import "PMCLibraryViewController.h"
#import "PMCControlsViewController.h"
#import "PMCQueueViewController.h"
#import "PMCStatusViewController.h"

@implementation PMCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    PMCControlsViewController *controls = [[PMCControlsViewController alloc] init];
    UINavigationController *controlsNav = [[UINavigationController alloc] initWithRootViewController:controls];

    PMCLibraryViewController *library = [[PMCLibraryViewController alloc] initWithRequestPath:@"/library" forRecord:nil];
    UINavigationController *libraryNav = [[UINavigationController alloc] initWithRootViewController:library];

    PMCQueueViewController *queue = [[PMCQueueViewController alloc] init];
    UINavigationController *queueNav = [[UINavigationController alloc] initWithRootViewController:queue];

    PMCStatusViewController *status = [[PMCStatusViewController alloc] init];
    UINavigationController *statusNav = [[UINavigationController alloc] initWithRootViewController:status];


    UITabBarController *tabVC = [[UITabBarController alloc] init];
    tabVC.viewControllers = @[controlsNav, libraryNav, queueNav, statusNav];
    tabVC.selectedIndex = 1;
    self.window.rootViewController = tabVC;

    [self.window makeKeyAndVisible];
    return YES;
}

@end
