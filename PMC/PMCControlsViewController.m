#import "PMCControlsViewController.h"
#import "PMCHTTPClient.h"

@implementation PMCControlsViewController

-(id)init {
    if (self = [super initWithNibName:[[self class] description] bundle:nil]) {
        self.title = @"Controls";
    }
    return self;
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

@end
