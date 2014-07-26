#import "PMCQueueViewController.h"
#import "PMCVideoTableViewCell.h"

@interface PMCQueueViewController ()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) NSDictionary *currentVideo;

@end

@implementation PMCQueueViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.title = @"Queue";

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        self.session = session;
    }
    return self;
}

-(void)loadView {
    [super loadView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshVideos:) forControlEvents:UIControlEventValueChanged];

    [self.tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];

    [self.refreshControl beginRefreshing];
    [self refreshVideos:self.refreshControl];
}

-(void)refreshVideos:(UIRefreshControl *)sender {
    NSURLSessionTask *queueTask = [self.session dataTaskWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/queue"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *videos = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.videos = videos;

            if (self.currentVideo) {
                [self.tableView reloadData];
                [sender endRefreshing];
            }
        });
    }];

    NSURLSessionTask *currentTask = [self.session dataTaskWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/current"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *currentVideo = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentVideo = currentVideo;

            if (self.videos) {
                [self.tableView reloadData];
                [sender endRefreshing];
            }
        });
    }];

    [queueTask resume];
    [currentTask resume];
}

#pragma mark - UITableViewDataSource

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    }
    else {
        return self.videos.count;
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PMCVideoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Video" forIndexPath:indexPath];
    NSDictionary *video;
    BOOL isCurrent = NO;

    if (indexPath.section == 0) {
        video = self.currentVideo;
        isCurrent = YES;
    }
    else {
        video = self.videos[indexPath.row];
    }

    id label = [video valueForKeyPath:@"label.ja"];
    if (!label || label == [NSNull null]) {
        label = [video valueForKeyPath:@"label.en"];
    }

    cell.titleLabel.text = label;
    cell.backgroundColor = isCurrent ? [UIColor colorWithWhite:0.95f alpha:1] : [UIColor whiteColor];

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
