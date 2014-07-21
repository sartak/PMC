#import "PMCLibraryViewController.h"
#import "PMCVideoTableViewCell.h"

@interface PMCLibraryViewController ()

@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation PMCLibraryViewController

-(void)loadView {
    [super loadView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshVideos:) forControlEvents:UIControlEventValueChanged];

    [self.tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];

    [self.navigationController setToolbarHidden:NO];
    [self setToolbarItems:@[
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(playPause)],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(nextSubs)],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(nextAudio)],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward target:self action:@selector(nextVideo)],
                            ]];
}

-(void)viewWillLayoutSubviews {
    self.tableView.frame = self.view.frame;
}

-(void)setVideos:(NSArray *)videos {
    _videos = videos;
    [self.tableView reloadData];
}

-(void)refreshVideos:(UIRefreshControl *)sender {
    NSURLSessionTask *task = [self.session dataTaskWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/library"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *videos = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.videos = videos;
            [sender endRefreshing];
        });
    }];
    [task resume];
}

-(void)viewWillAppear:(BOOL)animated {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    self.session = session;

    [self.refreshControl beginRefreshing];
    [self refreshVideos:self.refreshControl];
}

-(void)enqueueVideo:(NSDictionary *)video {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/queue"]];
    request.HTTPMethod = @"POST";
    NSString *params = [NSString stringWithFormat:@"video=%@", [video valueForKeyPath:@"id"]];
    request.HTTPBody = [params dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}

-(void)nextVideo {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/current"]];
    request.HTTPMethod = @"DELETE";
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}

-(void)nextAudio {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/current"]];
    request.HTTPMethod = @"NEXTAUDIO";
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}

-(void)nextSubs {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/current"]];
    request.HTTPMethod = @"NEXTSUBS";
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}

-(void)playPause {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/current"]];
    request.HTTPMethod = @"PLAYPAUSE";
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
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
    NSDictionary *video = self.videos[indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self enqueueVideo:video];
}

@end
