#import "PMCAppDelegate.h"
#import "PMCLibraryViewController.h"
#import "PMCControlsViewController.h"
#import "PMCQueueViewController.h"
#import "PMCDownloadsViewController.h"
#import "PMCHTTPClient.h"

@interface PMCAppDelegate ()

@property (nonatomic, strong) UINavigationController *libraryNav;
@property (nonatomic, strong) PMCLibraryViewController *libraryRoot;

@end

@implementation PMCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    PMCQueueViewController *queue = [[PMCQueueViewController alloc] init];
    queue.tabBarItem.image = [UIImage imageNamed:@"Playlist"];
    UINavigationController *queueNav = [[UINavigationController alloc] initWithRootViewController:queue];

    PMCControlsViewController *controls = [[PMCControlsViewController alloc] init];
    controls.tabBarItem.image = [UIImage imageNamed:@"Play Circle"];
    UINavigationController *controlsNav = [[UINavigationController alloc] initWithRootViewController:controls];
    controls.queueController = queue;

    PMCDownloadsViewController *downloads = [[PMCDownloadsViewController alloc] init];
    downloads.tabBarItem.image = [UIImage imageNamed:@"Download"];
    UINavigationController *downloadsNav = [[UINavigationController alloc] initWithRootViewController:downloads];

    PMCLibraryViewController *library = [[PMCLibraryViewController alloc] initWithRequestPath:@"/library" forRecord:nil withQueue:queue];
    library.tabBarItem.image = [UIImage imageNamed:@"Albums"];
    UINavigationController *libraryNav = [[UINavigationController alloc] initWithRootViewController:library];
    self.libraryNav = libraryNav;
    self.libraryRoot = library;

    UITabBarController *tabVC = [[UITabBarController alloc] init];
    tabVC.viewControllers = @[controlsNav, libraryNav, queueNav, downloadsNav];
    tabVC.selectedIndex = 1;
    self.window.rootViewController = tabVC;

    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hostDidChange:) name:PMCHostDidChangeNotification object:nil];

    return YES;
}

-(void)hostDidChange:(NSNotification *)notification {
    self.libraryRoot.title = [PMCHTTPClient sharedClient].currentLocation[@"label"];

    // not a real host change, just a radio change
    if ([notification.userInfo[@"new"][@"id"] isEqualToString:notification.userInfo[@"old"][@"id"]]) {
        return;
    }

    [self.libraryNav popToRootViewControllerAnimated:NO];
    [self.libraryRoot refreshRecordsAnimated:NO];
}

-(void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    if ([shortcutItem.type isEqualToString:@"playpause"]) {
        [[PMCHTTPClient sharedClient] sendMethod:@"PLAYPAUSE" toEndpoint:@"/current" completion:^(NSData *data, NSURLResponse *response, NSError *error) {
            completionHandler(error ? NO : YES);
        }];
    }
    else if ([shortcutItem.type isEqualToString:@"immerse"]) {
        [[PMCHTTPClient sharedClient] sendMethod:@"PUT" toEndpoint:@"/queue/source" withParams:@{@"tree":@"245"} completion:^(NSData *data, NSURLResponse *response, NSError *error) {
            completionHandler(error ? NO : YES);
        }];
    }
}

@end
