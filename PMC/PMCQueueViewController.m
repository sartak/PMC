#import "PMCQueueViewController.h"
#import "PMCVideoTableViewCell.h"
#import "PMCHTTPClient.h"

@interface PMCQueueViewController ()

@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) NSDictionary *currentVideo;

@end

@implementation PMCQueueViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.title = @"Queue";
    }
    return self;
}

-(void)loadView {
    [super loadView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshVideos:) forControlEvents:UIControlEventValueChanged];

    self.tableView.rowHeight = 44;

    [self.tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];

    [self.refreshControl beginRefreshing];
    [self refreshVideos:self.refreshControl];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(clearQueue)];
}

-(void)refreshVideos:(UIRefreshControl *)sender {
    __block BOOL refreshedCurrent = NO;
    __block BOOL refreshedVideos = NO;

    [[PMCHTTPClient sharedClient] jsonFrom:@"queue" completion:^(NSArray *videos, NSError *error) {
        self.videos = videos;
        refreshedVideos = YES;

        if (refreshedCurrent) {
            [self.tableView reloadData];
            [sender endRefreshing];
        }
    }];

    [[PMCHTTPClient sharedClient] jsonFrom:@"current" completion:^(NSArray *videos, NSError *error) {
        self.videos = videos;
        refreshedVideos = YES;

        if (refreshedCurrent) {
            [self.tableView reloadData];
            [sender endRefreshing];
        }
    }];
}

-(void)clearQueue {
    [self.refreshControl beginRefreshing];
    [[PMCHTTPClient sharedClient] sendMethod:@"DELETE" toEndpoint:@"queue" completion:^(NSError *error) {
        self.videos = @[];
        [self.tableView reloadData];
        [self.refreshControl endRefreshing];
    }];
}

-(void)dequeueVideo:(NSDictionary *)video {
    [[PMCHTTPClient sharedClient] sendMethod:@"REMOVE" toEndpoint:video[@"remotePath"] completion:nil];
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


    id duration = [video valueForKeyPath:@"duration_seconds"];
    if (!duration || duration == [NSNull null]) {
        cell.durationLabel.text = @"";
    }
    else {
        int seconds = [duration intValue];
        int minutes = seconds / 60;
        seconds %= 60;
        int hours = minutes / 60;
        minutes %= 60;

        if (hours) {
            cell.durationLabel.text = [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
        }
        else {
            cell.durationLabel.text = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
        }
    }

    cell.immersionIndicator.hidden = ![[video valueForKeyPath:@"immersible"] boolValue];
    cell.immersionIndicator.tintColor = [UIColor greenColor];

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
