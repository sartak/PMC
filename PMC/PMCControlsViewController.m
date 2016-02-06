#import "PMCControlsViewController.h"
#import "PMCHTTPClient.h"

@interface PMCControlsViewController ()

@property (weak, nonatomic) IBOutlet UIView *tvOnView;
@property (weak, nonatomic) IBOutlet UIView *tvOffView;

@property (nonatomic) BOOL tvOn;

@property (nonatomic) NSString *pauseStatus;
@property (nonatomic) NSString *fastForwardStatus;
@property (nonatomic) BOOL isMuted;
@property (nonatomic) int volume;
@property (nonatomic) BOOL hideVolume;
@property (nonatomic) BOOL hideInput;
@property (nonatomic) int targetVolume;
@property (nonatomic, strong) NSString *input;
@property (nonatomic, strong) NSArray *availableAudio;
@property (nonatomic, strong) NSDictionary *selectedAudio;

@property (weak, nonatomic) IBOutlet UIButton *locationSelector;
@property (weak, nonatomic) IBOutlet UIButton *playpauseButton;
@property (weak, nonatomic) IBOutlet UIButton *fastForwardButton;
@property (weak, nonatomic) IBOutlet UILabel *volumeLabel;
@property (weak, nonatomic) IBOutlet UIButton *volume50Button;
@property (weak, nonatomic) IBOutlet UIButton *volume100Button;
@property (weak, nonatomic) IBOutlet UIButton *volume75Button;
@property (weak, nonatomic) IBOutlet UIButton *volume25Button;
@property (weak, nonatomic) IBOutlet UIButton *muteButton;
@property (weak, nonatomic) IBOutlet UIButton *audioButton;

@property (weak, nonatomic) IBOutlet UILabel *rcaLabel;
@property (weak, nonatomic) IBOutlet UILabel *piLabel;
@property (weak, nonatomic) IBOutlet UILabel *appleTvLabel;
@property (weak, nonatomic) IBOutlet UIButton *rcaButton;
@property (weak, nonatomic) IBOutlet UIButton *piButton;
@property (weak, nonatomic) IBOutlet UIButton *appleTvButton;

@end

@implementation PMCControlsViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.title = @"Controls";
        [self setTvOn:NO animated:NO];
        [self setPauseStatus:@"play"];
        [self setFastForwardStatus:@"show"];
        self.input = @"Pi";
        self.volume = self.targetVolume = 50;
        self.isMuted = NO;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hostDidChange:) name:PMCHostDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseStatusDidChange:) name:PMCPauseStatusNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fastForwardStatusDidChange:) name:PMCFastForwardStatusNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeStatusDidChange:) name:PMCVolumeStatusNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputStatusDidChange:) name:PMCInputStatusNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(televisionPowerDidChange:) name:PMCTVPowerStatusNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioDidChange:) name:PMCAudioDidChangeNotification object:nil];

    }
    return self;
}

-(void)viewWillAppear:(BOOL)animated {
    [self setTvOn:self.tvOn animated:NO];
    [self refreshPauseStatus];
    [self refreshFastForwardStatus];
    [self refreshVolumeLabel];
    [self refreshInputButtons];
    [self refreshAudioButton];

    self.locationSelector.hidden = [[PMCHTTPClient locations] count] == 1;
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

-(void)refreshPauseStatus {
    NSString *pauseStatus = self.pauseStatus;
    if ([pauseStatus isEqualToString:@"play"]) {
        self.playpauseButton.hidden = NO;
        [self.playpauseButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    }
    else if ([pauseStatus isEqualToString:@"pause"]) {
        self.playpauseButton.hidden = NO;
        [self.playpauseButton setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
    }
    else if ([pauseStatus isEqualToString:@"nothing"]) {
        self.playpauseButton.hidden = YES;
    }
}

-(void)refreshFastForwardStatus {
    NSString *fastForwardStatus = self.fastForwardStatus;
    if ([fastForwardStatus isEqualToString:@"show"]) {
        self.fastForwardButton.hidden = NO;
    }
    else if ([fastForwardStatus isEqualToString:@"hide"]) {
        self.fastForwardButton.hidden = YES;
    }
}

-(void)setPauseStatus:(NSString *)pauseStatus {
    _pauseStatus = pauseStatus;
    [self refreshPauseStatus];
}

-(void)pauseStatusDidChange:(NSNotification *)notification {
    [self setPauseStatus:notification.userInfo[@"status"]];
}

-(void)setFastForwardStatus:(NSString *)fastForwardStatus {
    _fastForwardStatus = fastForwardStatus;
    [self refreshFastForwardStatus];
}

-(void)fastForwardStatusDidChange:(NSNotification *)notification {
    [self setFastForwardStatus:notification.userInfo[@"status"]];
}

-(void)refreshVolumeLabel {
    if (self.hideVolume) {
        self.volumeLabel.hidden = YES;
        self.muteButton.hidden = YES;
        self.volume25Button.hidden = YES;
        self.volume50Button.hidden = YES;
        self.volume75Button.hidden = YES;
        self.volume100Button.hidden = YES;
    }
    else {
        NSString *vol = self.volume == self.targetVolume ? [@(self.volume) stringValue] : [NSString stringWithFormat:@"%d → %d", self.volume, self.targetVolume];
        self.volumeLabel.text = [NSString stringWithFormat:@"Volume: %@", self.isMuted ? @"Mute" : vol];
    }
}

-(void)setVolume:(int)volume {
    _volume = volume;
    [self refreshVolumeLabel];
}

-(void)setTargetVolume:(int)targetVolume {
    _targetVolume = targetVolume;
    [self refreshVolumeLabel];
}

-(void)setIsMuted:(BOOL)isMuted {
    _isMuted = isMuted;
    [self refreshVolumeLabel];
}

-(void)volumeStatusDidChange:(NSNotification *)notification {
    if ([notification.userInfo[@"hide"] boolValue]) {
        self.hideVolume = YES;
        [self refreshVolumeLabel];
    }
    else {
        [self setVolume:[notification.userInfo[@"volume"] intValue]];
        [self setIsMuted:[notification.userInfo[@"mute"] boolValue]];

        if (notification.userInfo[@"target"]) {
            [self setTargetVolume:[notification.userInfo[@"target"] intValue]];
        }
        else {
            [self setTargetVolume:self.volume];
        }
    }
}

-(void)refreshInputButtons {
    if (self.hideInput) {
        self.rcaButton.hidden     = YES;
        self.piButton.hidden      = YES;
        self.appleTvButton.hidden = YES;
        self.rcaLabel.hidden      = YES;
        self.piLabel.hidden       = YES;
        self.appleTvLabel.hidden  = YES;
    }
    else {
        NSString *input = self.input;

        self.rcaButton.hidden     = [input isEqualToString:@"RCA"];
        self.piButton.hidden      = [input isEqualToString:@"Pi"];
        self.appleTvButton.hidden = [input isEqualToString:@"AppleTV"];

        self.rcaLabel.hidden      = !self.rcaButton.hidden;
        self.piLabel.hidden       = !self.piButton.hidden;
        self.appleTvLabel.hidden  = !self.appleTvButton.hidden;
    }
}

-(void)setInput:(NSString *)input {
    _input = input;
    [self refreshInputButtons];
}

-(void)inputStatusDidChange:(NSNotification *)notification {
    if ([notification.userInfo[@"hide"] boolValue]) {
        self.hideInput = YES;
        [self refreshInputButtons];
    }
    else {
        NSString *input = notification.userInfo[@"input"];
        [self setInput:input];
    }
}

-(void)audioDidChange:(NSNotification *)notification {
    self.selectedAudio = notification.userInfo[@"selected"];
    self.availableAudio = notification.userInfo[@"available"];

    [self refreshAudioButton];
}

-(void)refreshAudioButton {
    if (self.availableAudio && self.availableAudio.count > 0) {
        NSString *label = self.selectedAudio[@"label"];
        NSLog(@"%@", label);

        [self.audioButton setTitle:label forState:UIControlStateNormal];
        self.audioButton.hidden = NO;
        if (self.availableAudio.count == 1) {
            [self.audioButton setEnabled:NO];
        }
        else {
            [self.audioButton setEnabled:YES];
        }
    }
    else {
        self.audioButton.hidden = YES;
        [self.audioButton setTitle:@"" forState:UIControlStateNormal];
    }
}

-(void)sendInput:(NSString *)input {
    [[PMCHTTPClient sharedClient] sendMethod:@"PUT" toEndpoint:@"/television/input" withParams:@{@"input": input} completion:nil];
    [self setInput:input];
}

- (IBAction)setRCA:(id)sender {
    [self sendInput:@"RCA"];
}

- (IBAction)setPi:(id)sender {
    [self sendInput:@"Pi"];
}

- (IBAction)setAppleTv:(id)sender {
    [self sendInput:@"AppleTV"];
}

-(void)sendVolume:(int)volume {
    [[PMCHTTPClient sharedClient] sendMethod:@"PUT" toEndpoint:@"/television/volume" withParams:@{@"volume": [@(volume) stringValue]} completion:nil];
    [self setTargetVolume:volume];
}

- (IBAction)sendMute:(id)sender {
    [[PMCHTTPClient sharedClient] sendMethod:@"MUTE" toEndpoint:@"/television/volume" completion:nil];
    [self setIsMuted:true];
}

- (IBAction)setVolume25:(id)sender {
    [self sendVolume:25];
}

- (IBAction)setVolume50:(id)sender {
    [self sendVolume:50];
}

- (IBAction)setVolume75:(id)sender {
    [self sendVolume:75];
}

- (IBAction)setVolume100:(id)sender {
    [self sendVolume:100];
}

- (IBAction)changeAudio:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:@"Select a track"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSDictionary *audio in self.availableAudio) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:audio[@"label"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           self.selectedAudio = audio;
                                                           [self refreshAudioButton];
                                                           [[PMCHTTPClient sharedClient] sendMethod:@"PUT" toEndpoint:@"/current/audio" withParams:@{@"track": [audio[@"id"] stringValue]} completion:nil];
                                                       }];
        [alert addAction:action];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

-(void)setTvOn:(BOOL)tvOn animated:(BOOL)animated {
    if (animated && _tvOn != tvOn) {
        self.tvOnView.transform = tvOn ? CGAffineTransformMakeTranslation(0, -30) : CGAffineTransformIdentity;
        self.tvOffView.transform = tvOn ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, -30);

        [UIView animateWithDuration:.3
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.tvOnView.alpha = tvOn ? 1 : 0;
                             self.tvOffView.alpha = tvOn ? 0 : 1;
                             self.tvOnView.transform = tvOn ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, -30);
                             self.tvOffView.transform = tvOn ? CGAffineTransformMakeTranslation(0, -30) : CGAffineTransformIdentity;
                         } completion:nil];
    }
    else {
        self.tvOnView.alpha = tvOn ? 1 : 0;
        self.tvOffView.alpha = tvOn ? 0 : 1;
    }

    _tvOn = tvOn;
}

-(void) flip {
    [self setTvOn:!self.tvOn animated:YES];
}

-(void)televisionPowerDidChange:(NSNotification *)notification {
    if ([notification.userInfo[@"is_on"] boolValue]) {
        [self setTvOn:YES animated:YES];
    }
    else {
        [self setTvOn:NO animated:YES];
    }
}

- (IBAction)turnTVOn:(id)sender {
    [[PMCHTTPClient sharedClient] sendMethod:@"ON" toEndpoint:@"/television/power" completion:nil];
    [self setTvOn:YES animated:YES];
}

- (IBAction)turnTVOff:(id)sender {
    [[PMCHTTPClient sharedClient] sendMethod:@"OFF" toEndpoint:@"/television/power" completion:nil];
    [self setTvOn:NO animated:YES];
}

@end
