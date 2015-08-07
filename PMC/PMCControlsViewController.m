#import "PMCControlsViewController.h"
#import "PMCHTTPClient.h"

@interface PMCControlsViewController ()

@property (weak, nonatomic) IBOutlet UIButton *locationSelector;
@property (weak, nonatomic) IBOutlet UIButton *playpauseButton;
@property (nonatomic) BOOL isPaused;

@end

@implementation PMCControlsViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.title = @"Controls";
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hostDidChange:) name:PMCHostDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseStatusDidChange:) name:PMCPauseStatusNotification object:nil];
    }
    return self;
}

-(void)viewWillAppear:(BOOL)animated {
    [self setLocationLabel:[PMCHTTPClient sharedClient].currentLocation[@"label"]];
}

-(void)sendMethodToCurrent:(NSString *)method {
    [[PMCHTTPClient sharedClient] sendMethod:method toEndpoint:@"/current" completion:nil];
}

-(IBAction)nextVideo   { [self sendMethodToCurrent:@"DELETE"]; }
-(IBAction)nextAudio   { [self sendMethodToCurrent:@"NEXTAUDIO"]; }
-(IBAction)nextSubs    { [self sendMethodToCurrent:@"NEXTSUBS"]; }
-(IBAction)stopPlaying { [self sendMethodToCurrent:@"STOP"]; }

-(IBAction)playPause {
    [self setIsPaused:!self.isPaused];
    [self sendMethodToCurrent:@"PLAYPAUSE"];
}

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

-(void)setIsPaused:(BOOL)isPaused {
    _isPaused = isPaused;

    if (isPaused) {
        [self.playpauseButton setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
    }
    else {
        [self.playpauseButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    }
}

-(void)pauseStatusDidChange:(NSNotification *)notification {
    if ([notification.userInfo[@"isPaused"] boolValue]) {
        [self setIsPaused:YES];
    }
    else {
        [self setIsPaused:NO];
    }
}

@end
