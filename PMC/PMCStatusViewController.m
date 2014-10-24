#import "PMCStatusViewController.h"

@interface PMCStatusViewController () <NSURLSessionDataDelegate>

@property (nonatomic, strong, readonly) NSString *statusText;

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
}

@end
