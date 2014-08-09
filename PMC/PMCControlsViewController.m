#import "PMCControlsViewController.h"

@interface PMCControlsViewController ()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation PMCControlsViewController

-(id)init {
    if (self = [super initWithNibName:[[self class] description] bundle:nil]) {
        self.title = @"Controls";

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        self.session = session;
    }
    return self;
}

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://10.0.1.13:5000/%@", endpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}

-(void)sendMethodToCurrent:(NSString *)method {
    [self sendMethod:method toEndpoint:@"current"];
}

-(IBAction)nextVideo   { [self sendMethodToCurrent:@"DELETE"]; }
-(IBAction)nextAudio   { [self sendMethodToCurrent:@"NEXTAUDIO"]; }
-(IBAction)nextSubs    { [self sendMethodToCurrent:@"NEXTSUBS"]; }
-(IBAction)playPause   { [self sendMethodToCurrent:@"PLAYPAUSE"]; }
-(IBAction)stopPlaying { [self sendMethodToCurrent:@"STOP"]; }

-(IBAction)shutdownPi   { [self sendMethod:@"SHUTDOWN" toEndpoint:@"pi"]; }

@end
