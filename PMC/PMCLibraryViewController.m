#import "PMCLibraryViewController.h"
#import "PMCVideoTableViewCell.h"
#import "PMCSectionTableViewCell.h"

NSString * const PMCLanguageDidChangeNotification = @"PMCLanguageDidChangeNotification";

@interface PMCLibraryViewController ()

@property (nonatomic, strong) NSDictionary *currentRecord;
@property (nonatomic, strong) NSArray *records;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong, readonly) NSString *requestPath;
@property (nonatomic, strong) NSString *currentLanguage;

@end

@implementation PMCLibraryViewController

-(instancetype)initWithRequestPath:(NSString *)requestPath forRecord:(NSDictionary *)record {
    if (self = [self init]) {
        _requestPath = requestPath;

        self.currentLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
        self.currentRecord = record;

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        self.session = session;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageDidChange:) name:PMCLanguageDidChangeNotification object:nil];
    }
    return self;
}

-(NSString *)nextLanguage {
    if ([self.currentLanguage isEqualToString:@"en"]) {
        return @"ja";
    }
    else {
        return @"en";
    }
}

-(IBAction)selectNextLanguage {
    NSString *oldLanguage = self.currentLanguage;
    self.currentLanguage = [self nextLanguage];

    [[NSNotificationCenter defaultCenter] postNotificationName:PMCLanguageDidChangeNotification object:self userInfo:@{@"old":oldLanguage, @"new":self.currentLanguage}];
}

-(void)redrawForLanguageChange {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[self nextLanguage] style:UIBarButtonItemStylePlain target:self action:@selector(selectNextLanguage)];
    [self setTitleFromCurrentRecord];

    for (UITableViewCell *cell in self.tableView.visibleCells) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        NSDictionary *record = self.records[indexPath.row];
        if (record[@"requestPath"]) {
            PMCSectionTableViewCell *sectionCell = (PMCSectionTableViewCell *)cell;
            sectionCell.titleLabel.text = [self extractLabelFromRecord:record];
        }
        else {
            PMCVideoTableViewCell *videoCell = (PMCVideoTableViewCell *)cell;
            videoCell.titleLabel.text = [self extractLabelFromRecord:record];
        }
    }
}

-(void)languageDidChange:(NSNotification *)notification {
    self.currentLanguage = notification.userInfo[@"new"];
    [self redrawForLanguageChange];
}

-(void)setTitleFromCurrentRecord {
    if (self.currentRecord) {
        self.title = [self extractLabelFromRecord:self.currentRecord];
    }
    else {
        self.title = @"Library";
    }
}

-(void)loadView {
    [super loadView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshRecords:) forControlEvents:UIControlEventValueChanged];

    [self.tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCSectionTableViewCell" bundle:nil] forCellReuseIdentifier:@"Section"];

    [self.refreshControl beginRefreshing];
    [self refreshRecords:self.refreshControl];

    [self setTitleFromCurrentRecord];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[self nextLanguage] style:UIBarButtonItemStylePlain target:self action:@selector(selectNextLanguage)];
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

    cell.titleLabel.text = [self extractLabelFromRecord:video];

    id identifier = [video valueForKeyPath:@"identifier"];
    if (!identifier || identifier == [NSNull null]) {
        cell.identifierLabel.text = @"";
    }
    else {
        cell.identifierLabel.text = identifier;
    }

    return cell;
}

-(NSString *)extractLabelFromRecord:(NSDictionary *)record {
    for (NSString *lang in [@[self.currentLanguage] arrayByAddingObjectsFromArray:[NSLocale preferredLanguages]]) {
        NSString *keyPath = [@"label." stringByAppendingString:lang];
        id label = [record valueForKeyPath:keyPath];
        if (label && label != [NSNull null]) {
            return label;
        }
    }

    return nil;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForSection:(NSDictionary *)section atIndexPath:(NSIndexPath *)indexPath {
    PMCSectionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Section" forIndexPath:indexPath];

    cell.titleLabel.text = [self extractLabelFromRecord:section];

    return cell;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
        PMCLibraryViewController *next = [[PMCLibraryViewController alloc] initWithRequestPath:record[@"requestPath"] forRecord:record];
        next.currentLanguage = self.currentLanguage;

        [self.navigationController pushViewController:next animated:YES];
    }
    else {
        [self enqueueVideo:record];
    }
}

@end
