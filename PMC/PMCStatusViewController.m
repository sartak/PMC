#import "PMCStatusViewController.h"
#import "PMCHTTPClient.h"

@interface PMCStatusViewController ()

@property (nonatomic, strong, readonly) NSString *statusText;
@property (nonatomic, strong) NSURLSessionDataTask *streamingRequest;

@end

@implementation PMCStatusViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.title = @"Status";
    }
    return self;
}

-(void)loadView {
    [super loadView];

    UITextView *textView = [[UITextView alloc] init];
    textView.editable = NO;
    self.view = textView;

    [self reconnectStream];
}

-(void)reconnectStream {
    [self.streamingRequest cancel];
    self.streamingRequest = [[PMCHTTPClient sharedClient] streamJsonFrom:@"/status" chunk:^(id json, NSError *error) {
        UITextView *textView = (UITextView *)self.view;
        textView.text = [textView.text stringByAppendingString:json];
    } completion:^(NSError *error){
        [self reconnectStream];
    }];
}

@end
