#import "PMCControlsViewController.h"
#import "PMCHTTPClient.h"

@interface PMCControlsViewController ()

@property (weak, nonatomic) IBOutlet UIButton *locationSelector;

@end

@implementation PMCControlsViewController

-(id)init {
    if (self = [super initWithNibName:[[self class] description] bundle:nil]) {
        self.title = @"Controls";
    }
    return self;
}

-(void)viewWillAppear:(BOOL)animated {
    [self setLocationLabel:[PMCHTTPClient sharedClient].currentLocation[@"label"]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hostDidChange:) name:PMCHostDidChangeNotification object:nil];
}

-(void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)sendMethodToCurrent:(NSString *)method {
    [[PMCHTTPClient sharedClient] sendMethod:method toEndpoint:@"/current" completion:nil];
}

-(IBAction)nextVideo   { [self sendMethodToCurrent:@"DELETE"]; }
-(IBAction)nextAudio   { [self sendMethodToCurrent:@"NEXTAUDIO"]; }
-(IBAction)nextSubs    { [self sendMethodToCurrent:@"NEXTSUBS"]; }
-(IBAction)playPause   { [self sendMethodToCurrent:@"PLAYPAUSE"]; }
-(IBAction)stopPlaying { [self sendMethodToCurrent:@"STOP"]; }

-(IBAction)shutdownPi   {
    [[PMCHTTPClient sharedClient] sendMethod:@"SHUTDOWN" toEndpoint:@"/pi" completion:nil];
}

- (IBAction)selectLocation:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:@"Select a location"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSDictionary *location in [PMCHTTPClient locations]) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:location[@"label"]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  [PMCHTTPClient sharedClient].currentLocation = location;
                                                              }];
        [alert addAction:action];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

-(void)hostDidChange:(NSNotification *)notification {
    [self setLocationLabel:notification.userInfo[@"new"][@"label"]];
}

-(void)setLocationLabel:(NSString *)label {
    [UIView performWithoutAnimation:^{
        [self.locationSelector setTitle:label forState:UIControlStateNormal];
        [self.locationSelector layoutIfNeeded];
    }];
}

@end
