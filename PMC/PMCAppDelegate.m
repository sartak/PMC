#import "PMCAppDelegate.h"
#import "PMCLibraryViewController.h"
#import "PMCControlsViewController.h"
#import "PMCQueueViewController.h"
#import "PMCStatusViewController.h"
#import "PMCHTTPClient.h"

@interface PMCAppDelegate ()

@property (nonatomic, strong) UINavigationController *libraryNav;
@property (nonatomic, strong) PMCLibraryViewController *libraryRoot;

@end

@implementation PMCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    PMCControlsViewController *controls = [[PMCControlsViewController alloc] init];
    controls.tabBarItem.image = [UIImage imageNamed:@"Play Circle"];
    UINavigationController *controlsNav = [[UINavigationController alloc] initWithRootViewController:controls];

    PMCLibraryViewController *library = [[PMCLibraryViewController alloc] initWithRequestPath:@"/library" forRecord:nil];
    library.tabBarItem.image = [UIImage imageNamed:@"Albums"];
    UINavigationController *libraryNav = [[UINavigationController alloc] initWithRootViewController:library];
    self.libraryNav = libraryNav;
    self.libraryRoot = library;

    PMCQueueViewController *queue = [[PMCQueueViewController alloc] init];
    queue.tabBarItem.image = [UIImage imageNamed:@"Playlist"];
    UINavigationController *queueNav = [[UINavigationController alloc] initWithRootViewController:queue];

    PMCStatusViewController *status = [[PMCStatusViewController alloc] init];
    status.tabBarItem.image = [UIImage imageNamed:@"Info"];
    UINavigationController *statusNav = [[UINavigationController alloc] initWithRootViewController:status];


    UITabBarController *tabVC = [[UITabBarController alloc] init];
    tabVC.viewControllers = @[controlsNav, libraryNav, queueNav, statusNav];
    tabVC.selectedIndex = 1;
    self.window.rootViewController = tabVC;

    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hostDidChange:) name:PMCHostDidChangeNotification object:nil];

    return YES;
}

-(void)hostDidChange:(NSNotification *)notification {
    [self.libraryNav popToRootViewControllerAnimated:NO];
    [self.libraryRoot refreshRecords];
    self.libraryRoot.title = [PMCHTTPClient sharedClient].currentLocation[@"label"];
}

@end
