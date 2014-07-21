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

-(void)sendMethod:(NSString *)method {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/current"]];
    request.HTTPMethod = method;
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}

-(IBAction)nextVideo   { [self sendMethod:@"DELETE"]; }
-(IBAction)nextAudio   { [self sendMethod:@"NEXTAUDIO"]; }
-(IBAction)nextSubs    { [self sendMethod:@"NEXTSUBS"]; }
-(IBAction)playPause   { [self sendMethod:@"PLAYPAUSE"]; }
-(IBAction)stopPlaying { [self sendMethod:@"STOP"]; }

@end
