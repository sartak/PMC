#import "PMCLibraryViewController.h"
#import "PMCVideoTableViewCell.h"
#import "PMCGameTableViewCell.h"
#import "PMCTreeTableViewCell.h"
#import "PMCTagTableViewCell.h"
#import "PMCSummaryTableViewCell.h"
#import "PMCFiveStarTableViewCell.h"
#import "PMCOneStarTableViewCell.h"
#import "PMCHTTPClient.h"

@import MediaPlayer;

NSString * const PMCLanguageDidChangeNotification = @"PMCLanguageDidChangeNotification";

@interface PMCLibraryViewController ()

@property (nonatomic, strong) NSDictionary *currentRecord;
@property (nonatomic, strong) NSArray *records;
@property (nonatomic, strong, readonly) NSString *requestPath;
@property (nonatomic, strong) NSString *currentLanguage;
@property (nonatomic) int totalDuration;
@property (nonatomic) int totalVideos;
@property (nonatomic) int totalPlaytime;
@property (nonatomic) int totalGames;

@end

@implementation PMCLibraryViewController

-(instancetype)initWithRequestPath:(NSString *)requestPath forRecord:(NSDictionary *)record {
    if (self = [self init]) {
        _requestPath = requestPath;

        self.currentLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
        self.currentRecord = record;

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
        if (indexPath.section == 0) {
            NSDictionary *record = self.records[indexPath.row];
            if ([cell respondsToSelector:@selector(titleLabel)]) {
                [cell setValue:[self extractLabelFromRecord:record includeSpaceForTag:YES] forKeyPath:@"titleLabel.text"];
            }
        }
        else if (indexPath.section == 1) {
            // localize...
        }
    }
}

-(void)languageDidChange:(NSNotification *)notification {
    self.currentLanguage = notification.userInfo[@"new"];
    [self redrawForLanguageChange];
}

-(void)setTitleFromCurrentRecord {
    if (self.currentRecord) {
        self.title = [self extractLabelFromRecord:self.currentRecord includeSpaceForTag:NO];
    }
    else {
        self.title = [PMCHTTPClient sharedClient].currentLocation[@"label"];
    }
}

-(void)loadView {
    [super loadView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshRecords:) forControlEvents:UIControlEventValueChanged];

    self.tableView.rowHeight = 44;

    [self.tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCGameTableViewCell" bundle:nil] forCellReuseIdentifier:@"Game"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCTreeTableViewCell" bundle:nil] forCellReuseIdentifier:@"Tree"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCTagTableViewCell" bundle:nil] forCellReuseIdentifier:@"Tag"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCFiveStarTableViewCell" bundle:nil] forCellReuseIdentifier:@"★★★★★"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCOneStarTableViewCell" bundle:nil] forCellReuseIdentifier:@"★☆☆☆☆"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCSummaryTableViewCell" bundle:nil] forCellReuseIdentifier:@"Summary"];

    [self.refreshControl beginRefreshing];
    [self refreshRecords:self.refreshControl];

    [self setTitleFromCurrentRecord];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[self nextLanguage] style:UIBarButtonItemStylePlain target:self action:@selector(selectNextLanguage)];
}

-(void)setRecords:(NSArray *)records {
    _records = records;

    self.totalDuration = 0;
    self.totalVideos = 0;
    self.totalPlaytime = 0;
    self.totalGames = 0;

    for (NSDictionary *record in records) {
        if ([record[@"type"] isEqualToString:@"video"]) {
            self.totalVideos++;

            id duration = [record valueForKeyPath:@"duration_seconds"];
            if (duration && duration != [NSNull null]) {
                self.totalDuration += [duration intValue];
            }
        }
        else if ([record[@"type"] isEqualToString:@"game"]) {
            self.totalGames++;

            id duration = [record valueForKeyPath:@"playtime"];
            if (duration && duration != [NSNull null]) {
                self.totalPlaytime += [duration intValue];
            }
        }

    }

    [self.tableView reloadData];
}

-(void)refreshRecords {
    [self.refreshControl beginRefreshing];
    [self refreshRecords:self.refreshControl];
}

-(void)refreshRecords:(UIRefreshControl *)sender {
    [[PMCHTTPClient sharedClient] jsonFrom:self.requestPath completion:^(NSArray *records, NSError *error) {
        self.records = records;
        [sender endRefreshing];
    }];
}

-(void)enqueueMedia:(NSDictionary *)media {
    [[PMCHTTPClient sharedClient] sendMethod:@"POST"
                                  toEndpoint:@"/queue"
                                  withParams:@{@"media":[[media valueForKeyPath:@"id"] description]}
                                  completion:nil];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForVideo:(NSDictionary *)video atIndexPath:(NSIndexPath *)indexPath {
    PMCVideoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Video" forIndexPath:indexPath];

    cell.titleLabel.text = [self extractLabelFromRecord:video includeSpaceForTag:YES];

    id identifier = [video valueForKeyPath:@"identifier"];
    if (!identifier || identifier == [NSNull null]) {
        cell.identifierLabel.text = @"";
    }
    else {
        cell.identifierLabel.text = identifier;
    }

    id duration = [video valueForKeyPath:@"duration_seconds"];
    if (!duration || duration == [NSNull null] || [duration intValue] == 0) {
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

    if (![[video valueForKeyPath:@"streamable"] boolValue]) {
        cell.backgroundColor = [UIColor colorWithHue:0 saturation:.22f brightness:1 alpha:1];
    }
    else if ([[video valueForKeyPath:@"completed"] isEqual:[NSNull null]]) {
        cell.backgroundColor = [UIColor whiteColor];
    }
    else {
        NSDate *lastPlayed = [NSDate dateWithTimeIntervalSince1970:[[video valueForKeyPath:@"last_played"] intValue]];
        NSTimeInterval since = [[NSDate date] timeIntervalSinceDate:lastPlayed];
        double percent = since / (365*24*60*60.);
        double saturation = .33 * (1-percent);

        cell.backgroundColor = [UIColor colorWithHue:117/360. saturation:saturation brightness:1 alpha:1];
    }

    return cell;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForGame:(NSDictionary *)game atIndexPath:(NSIndexPath *)indexPath {
    PMCGameTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Game" forIndexPath:indexPath];

    cell.titleLabel.text = [self extractLabelFromRecord:game includeSpaceForTag:YES];

    id identifier = [game valueForKeyPath:@"identifier"];
    if (!identifier || identifier == [NSNull null]) {
        cell.identifierLabel.text = @"";
    }
    else {
        cell.identifierLabel.text = identifier;
    }

    id duration = [game valueForKeyPath:@"playtime"];
    if (!duration || duration == [NSNull null] || [duration intValue] == 0) {
        cell.playtimeLabel.text = @"";
    }
    else {
        int seconds = [duration intValue];
        int minutes = seconds / 60;
        seconds %= 60;
        int hours = minutes / 60;
        minutes %= 60;

        if (hours) {
            cell.playtimeLabel.text = [NSString stringWithFormat:@"%dh %2dm %ds", hours, minutes, seconds];
        }
        else {
            cell.playtimeLabel.text = [NSString stringWithFormat:@"%dm %ds", minutes, seconds];
        }
    }

    if (![[game valueForKeyPath:@"streamable"] boolValue]) {
        cell.backgroundColor = [UIColor colorWithHue:0 saturation:.22f brightness:1 alpha:1];
    }
    else if ([[game valueForKeyPath:@"completed"] isEqual:[NSNull null]]) {
        cell.backgroundColor = [UIColor whiteColor];
    }
    else {
        cell.backgroundColor = [UIColor colorWithHue:117/360. saturation:.22f brightness:1 alpha:1];
    }
    
    return cell;
}

-(NSString *)extractLabelFromRecord:(NSDictionary *)record includeSpaceForTag:(BOOL)extraSpace {
    for (NSString *lang in [@[self.currentLanguage] arrayByAddingObjectsFromArray:[NSLocale preferredLanguages]]) {
        NSString *keyPath = [@"label." stringByAppendingString:lang];
        id label = [record valueForKeyPath:keyPath];
        if (label && label != [NSNull null]) {
            if (extraSpace && [record[@"type"] isEqualToString:@"tag"]) {
                return [NSString stringWithFormat:@"  %@  ", label];
            }
            else {
                return label;
            }
        }
    }

    return nil;
}

-(UITableViewCell *)tableView:(UITableView *)tableView summaryCellAtIndexPath:(NSIndexPath *)indexPath withCount:(int)count andDuration:(int)duration singular:(NSString *)singular plural:(NSString *)plural serial:(BOOL)serial {
    PMCSummaryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Summary" forIndexPath:indexPath];

    if (count == 1) {
        cell.titleLabel.text = [NSString stringWithFormat:@"1 %@", singular];
    }
    else {
        cell.titleLabel.text = [NSString stringWithFormat:@"%d %@", count, plural];
    }

    int seconds = duration;
    int minutes = seconds / 60;
    seconds %= 60;
    int hours = minutes / 60;
    minutes %= 60;

    if (serial) {
        if (hours) {
            cell.durationLabel.text = [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
        }
        else {
            cell.durationLabel.text = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
        }
    }
    else {
        if (hours) {
            cell.durationLabel.text = [NSString stringWithFormat:@"%dh %dm %ds", hours, minutes, seconds];
        }
        else {
            cell.durationLabel.text = [NSString stringWithFormat:@"%dm %ds", minutes, seconds];
        }
    }

    return cell;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForTree:(NSDictionary *)tree atIndexPath:(NSIndexPath *)indexPath {
    PMCTreeTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Tree" forIndexPath:indexPath];

    cell.titleLabel.text = [self extractLabelFromRecord:tree includeSpaceForTag:YES];

    return cell;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForTag:(NSDictionary *)tag atIndexPath:(NSIndexPath *)indexPath {
    PMCTagTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Tag" forIndexPath:indexPath];

    cell.titleLabel.text = [self extractLabelFromRecord:tag includeSpaceForTag:YES];
    cell.titleLabel.layer.cornerRadius = 8;

    return cell;
}


-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UITableViewDataSource

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.totalVideos > 1 || self.totalGames > 1) {
        return 2;
    }
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.records.count;
    }
    else {
        int rows = 0;
        if (self.totalVideos > 1) rows++;
        if (self.totalGames > 1) rows++;
        return rows;
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *record = self.records[indexPath.row];

    if (indexPath.section == 0) {
        if ([record[@"type"] isEqualToString:@"tree"]) {
            return [self tableView:tableView cellForTree:record atIndexPath:indexPath];
        }
        else if ([record[@"type"] isEqualToString:@"tag"]) {
            if ([record[@"id"] isEqualToString:@"★★★★★"] || [record[@"id"] isEqualToString:@"★☆☆☆☆"]) {
                return [tableView dequeueReusableCellWithIdentifier:record[@"id"] forIndexPath:indexPath];
            }
            else {
                return [self tableView:tableView cellForTag:record atIndexPath:indexPath];
            }
        }
        else if ([record[@"type"] isEqualToString:@"video"]) {
            return [self tableView:tableView cellForVideo:record atIndexPath:indexPath];
        }
        else if ([record[@"type"] isEqualToString:@"game"]) {
            return [self tableView:tableView cellForGame:record atIndexPath:indexPath];
        }
        else {
            NSLog(@"invalid type %@", record[@"type"]);
            // die
            return nil;
        }
    }
    else {
        if (indexPath.row == 0 && self.totalVideos > 1) {
            // video
            return [self tableView:tableView summaryCellAtIndexPath:indexPath withCount:self.totalVideos andDuration:self.totalDuration singular:@"video" plural:@"videos" serial:YES];
        }
        else {
            return [self tableView:tableView summaryCellAtIndexPath:indexPath withCount:self.totalGames andDuration:self.totalPlaytime singular:@"game" plural:@"games" serial:NO];
        }
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
        [self enqueueMedia:record];
    }
}

@end
