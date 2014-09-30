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

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(clearQueue)];
}

-(void)refreshVideos:(UIRefreshControl *)sender {
    __block BOOL refreshedCurrent = NO;
    __block BOOL refreshedVideos = NO;

    NSURLSessionTask *queueTask = [self.session dataTaskWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/queue"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *videos = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.videos = videos;
            refreshedVideos = YES;

            if (refreshedCurrent) {
                [self.tableView reloadData];
                [sender endRefreshing];
            }
        });
    }];

    NSURLSessionTask *currentTask = [self.session dataTaskWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/current"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *currentVideo = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentVideo = currentVideo;
            refreshedCurrent = YES;

            if (refreshedVideos) {
                [self.tableView reloadData];
                [sender endRefreshing];
            }
        });
    }];

    [queueTask resume];
    [currentTask resume];
}

-(void)clearQueue {
    NSURL *url = [NSURL URLWithString:@"http://10.0.1.13:5000/queue"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"DELETE";
    [self.refreshControl beginRefreshing];
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.videos = @[];
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
        });
    }];
    [task resume];
}

-(void)dequeueVideo:(NSDictionary *)video {
    NSURL *url = [NSURL URLWithString:video[@"removePath"] relativeToURL:[NSURL URLWithString:@"http://10.0.1.13:5000/"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"REMOVE";
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
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

    id identifier = [video valueForKeyPath:@"identifier"];
    if (!identifier || identifier == [NSNull null]) {
        cell.identifierLabel.text = @"";
    }
    else {
        cell.identifierLabel.text = identifier;
    }

    if (isCurrent) {
        cell.backgroundColor = [UIColor colorWithWhite:0.95f alpha:1];
    }
    else if ([[video valueForKeyPath:@"watched"] isEqual:[NSNull null]]) {
        cell.backgroundColor = [UIColor whiteColor];
    }
    else {
        cell.backgroundColor = [UIColor colorWithHue:117/360. saturation:.22f brightness:1 alpha:1];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *video = self.videos[indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (video[@"removePath"]) {
        [self dequeueVideo:video];

        NSMutableArray *newVideos = [NSMutableArray array];
        for (NSDictionary *v in self.videos) {
            if (v != video) {
                [newVideos addObject:v];
            }
        }

        self.videos = [newVideos copy];
        [tableView reloadData];
    }
}

@end
