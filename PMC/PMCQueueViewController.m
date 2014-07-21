#import "PMCQueueViewController.h"
#import "PMCVideoTableViewCell.h"

@interface PMCQueueViewController ()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSArray *videos;

@end

@implementation PMCQueueViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.title = @"Queue";

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        self.session = session;

        [self.refreshControl beginRefreshing];
        [self refreshVideos:self.refreshControl];
    }
    return self;
}

-(void)loadView {
    [super loadView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshVideos:) forControlEvents:UIControlEventValueChanged];

    [self.tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];
}

-(void)setVideos:(NSArray *)videos {
    _videos = videos;
    [self.tableView reloadData];
}

-(void)refreshVideos:(UIRefreshControl *)sender {
    NSURLSessionTask *task = [self.session dataTaskWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/queue"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *videos = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.videos = videos;
            [sender endRefreshing];
        });
    }];
    [task resume];
}

#pragma mark - UITableViewDataSource

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.videos.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *video = self.videos[indexPath.row];
    PMCVideoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Video" forIndexPath:indexPath];

    id label = [video valueForKeyPath:@"label.ja"];
    if (!label || label == [NSNull null]) {
        label = [video valueForKeyPath:@"label.en"];
    }
    cell.titleLabel.text = label;

    id identifier = [video valueForKeyPath:@"identifier"];
    if (!identifier || identifier == [NSNull null]) {
        cell.identifierLabel.text = @"";
    }
    else {
        cell.identifierLabel.text = identifier;
    }

    return cell;
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
//    NSDictionary *video = self.videos[indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
//    [self enqueueVideo:video];
}

@end
