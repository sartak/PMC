#import "PMCLibraryViewController.h"
#import "PMCVideoTableViewCell.h"

@interface PMCLibraryViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) UITableView *tableView;

@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation PMCLibraryViewController

-(void)loadView {
    self.view = [[UIView alloc] init];

    UITableView *tableView = [[UITableView alloc] init];
    self.tableView = tableView;
    [self.view addSubview:tableView];
    tableView.dataSource = self;
    tableView.delegate = self;
    [tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];

    [self.navigationController setToolbarHidden:NO];
    [self setToolbarItems:@[
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(playPause)],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward target:self action:@selector(nextVideo)],
                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            ]];
}

-(void)viewWillLayoutSubviews {
    self.tableView.frame = self.view.frame;
}

-(void)setVideos:(NSArray *)videos {
    _videos = videos;
    [self.tableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    self.session = session;

    NSURLSessionTask *task = [session dataTaskWithURL:[NSURL URLWithString:@"http://10.0.1.13:5000/library"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *videos = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.videos = videos;
        });
    }];
    [task resume];
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
    cell.titleLabel.text = [video valueForKeyPath:@"label.ja"];
    cell.identifierLabel.text = [video valueForKeyPath:@"identifier"];
    return cell;
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *video = self.videos[indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self enqueueVideo:video];
}

@end
