#import "PMCAppDelegate.h"
#import "PMCLibraryViewController.h"

@implementation PMCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    PMCLibraryViewController *library = [[PMCLibraryViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:library];
    self.window.rootViewController = nav;

    [self.window makeKeyAndVisible];
    return YES;
}

@end
