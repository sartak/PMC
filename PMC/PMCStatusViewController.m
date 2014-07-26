#import "PMCStatusViewController.h"

@interface PMCStatusViewController () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong, readonly) NSString *statusText;

@end

@implementation PMCStatusViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.title = @"Status";

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        self.session = session;

        NSURLSessionTask *task = [self.session dataTaskWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/status"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        }];
        [task resume];
    }
    return self;
}

-(void)loadView {
    [super loadView];

    UITextView *textView = [[UITextView alloc] init];
    textView.editable = NO;
    self.view = textView;
}

@end
