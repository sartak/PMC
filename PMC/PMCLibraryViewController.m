#import "PMCLibraryViewController.h"
#import "PMCVideoTableViewCell.h"
#import "PMCSectionTableViewCell.h"

@interface PMCLibraryViewController ()

@property (nonatomic, strong) NSArray *records;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong, readonly) NSString *requestPath;

@end

@implementation PMCLibraryViewController

-(instancetype)initWithRequestPath:(NSString *)requestPath {
    if (self = [self init]) {
        _requestPath = requestPath;

        self.title = @"Library";

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        self.session = session;
    }
    return self;
}

-(void)loadView {
    [super loadView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshRecords:) forControlEvents:UIControlEventValueChanged];

    [self.tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCSectionTableViewCell" bundle:nil] forCellReuseIdentifier:@"Section"];

    [self.refreshControl beginRefreshing];
    [self refreshRecords:self.refreshControl];
}

-(void)setRecords:(NSArray *)records {
    _records = records;
    [self.tableView reloadData];
}

-(void)refreshRecords:(UIRefreshControl *)sender {
    NSURL *url = [NSURL URLWithString:self.requestPath relativeToURL:[NSURL URLWithString:@"http://10.0.1.13:5000/"]];
    NSURLSessionTask *task = [self.session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *records = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.records = records;
            [sender endRefreshing];
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

-(UITableViewCell *)tableView:(UITableView *)tableView cellForVideo:(NSDictionary *)video atIndexPath:(NSIndexPath *)indexPath {
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

-(UITableViewCell *)tableView:(UITableView *)tableView cellForSection:(NSDictionary *)section atIndexPath:(NSIndexPath *)indexPath {
    PMCSectionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Section" forIndexPath:indexPath];

    id label = [section valueForKeyPath:@"label.ja"];
    if (!label || label == [NSNull null]) {
        label = [section valueForKeyPath:@"label.en"];
    }
    cell.titleLabel.text = label;

    return cell;
}

#pragma mark - UITableViewDataSource

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.records.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *record = self.records[indexPath.row];

    if (record[@"requestPath"]) {
        return [self tableView:tableView cellForSection:record atIndexPath:indexPath];
    }
    else {
        return [self tableView:tableView cellForVideo:record atIndexPath:indexPath];
    }
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *record = self.records[indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (record[@"requestPath"]) {
        PMCLibraryViewController *next = [[PMCLibraryViewController alloc] initWithRequestPath:record[@"requestPath"]];
        [self.navigationController pushViewController:next animated:YES];
    }
    else {
        [self enqueueVideo:record];
    }
}

@end
