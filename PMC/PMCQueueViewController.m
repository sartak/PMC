#import "PMCQueueViewController.h"
#import "PMCVideoTableViewCell.h"
#import "PMCGameTableViewCell.h"
#import "PMCHTTPClient.h"

@interface PMCQueueViewController ()

@property (nonatomic, strong) NSArray *media;
@property (nonatomic, strong) NSDictionary *currentMedia;
@property (nonatomic, strong) NSTimer *notificationRefreshTimer;

@end

@implementation PMCQueueViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.title = @"Queue";
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hostDidChange:) name:PMCHostDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaDidChange) name:PMCMediaStartedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaDidChange) name:PMCMediaFinishedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didConnect) name:PMCConnectedStatusNotification object:nil];
    }
    return self;
}

-(void)mediaDidChange {
    if (self.notificationRefreshTimer) {
        return;
    }

    self.notificationRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(notificationRefresh) userInfo:nil repeats:NO];
}

-(void)notificationRefresh {
    [self.notificationRefreshTimer invalidate];
    self.notificationRefreshTimer = nil;

    [self refreshMedia:self.refreshControl];
}

-(void)didConnect {
    [self notificationRefresh];
}

-(void)loadView {
    [super loadView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshMedia:) forControlEvents:UIControlEventValueChanged];

    self.tableView.rowHeight = 44;

    [self.tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCGameTableViewCell" bundle:nil] forCellReuseIdentifier:@"Game"];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(clearQueue)];
}

-(void)refreshMedia:(UIRefreshControl *)sender {
    __block BOOL refreshedCurrent = NO;
    __block BOOL refreshedMedia = NO;

    [[PMCHTTPClient sharedClient] jsonFrom:@"/queue" completion:^(NSArray *media, NSError *error) {
        self.media = media;
        refreshedMedia = YES;

        if (refreshedCurrent) {
            [self.tableView reloadData];
            [sender endRefreshing];
        }
    }];

    [[PMCHTTPClient sharedClient] jsonFrom:@"/current" completion:^(NSDictionary *currentMedia, NSError *error) {
        self.currentMedia = currentMedia;
        refreshedCurrent = YES;

        if (refreshedMedia) {
            [self.tableView reloadData];
            [sender endRefreshing];
        }
    }];
}

-(void)clearQueue {
    [self.refreshControl beginRefreshing];
    [[PMCHTTPClient sharedClient] sendMethod:@"DELETE" toEndpoint:@"/queue" completion:^(NSError *error) {
        self.media = @[];
        [self.tableView reloadData];
        [self.refreshControl endRefreshing];
    }];
}

-(void)dequeueMedia:(NSDictionary *)media {
    [[PMCHTTPClient sharedClient] sendMethod:@"REMOVE" toEndpoint:media[@"removePath"] completion:nil];
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
        return self.media.count;
    }
}

-(NSString *)currentLanguage { return @"xxx"; }

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

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *record;
    BOOL isCurrent = NO;
    if (indexPath.section == 0) {
        record = self.currentMedia;
        isCurrent = YES;
    }
    else {
        record = self.media[indexPath.row];
    }

    if (!record) {
        return [self tableView:tableView cellForVideo:record atIndexPath:indexPath isCurrent:isCurrent];
    }
    else if ([record[@"type"] isEqualToString:@"video"]) {
        return [self tableView:tableView cellForVideo:record atIndexPath:indexPath isCurrent:isCurrent];
    }
    else if ([record[@"type"] isEqualToString:@"game"]) {
        return [self tableView:tableView cellForGame:record atIndexPath:indexPath isCurrent:isCurrent];
    }
    else {
        NSLog(@"invalid type %@ for indexPath %@/%@", record[@"type"], @(indexPath.section), @(indexPath.row));
        NSLog(@"%@", record);
        return nil;
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForVideo:(NSDictionary *)video atIndexPath:(NSIndexPath *)indexPath isCurrent:(BOOL)isCurrent {
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

    if (isCurrent) {
        cell.backgroundColor = [UIColor colorWithWhite:0.95f alpha:1];
    }
    else if (![[video valueForKeyPath:@"streamable"] boolValue]) {
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

-(UITableViewCell *)tableView:(UITableView *)tableView cellForGame:(NSDictionary *)game atIndexPath:(NSIndexPath *)indexPath isCurrent:(BOOL)isCurrent {
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
            cell.playtimeLabel.text = [NSString stringWithFormat:@"%dh %dm %ds", hours, minutes, seconds];
        }
        else {
            cell.playtimeLabel.text = [NSString stringWithFormat:@"%dm %ds", minutes, seconds];
        }
    }

    if (isCurrent) {
        cell.backgroundColor = [UIColor colorWithWhite:0.95f alpha:1];
    }
    else if (![[game valueForKeyPath:@"streamable"] boolValue]) {
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

-(void)hostDidChange:(NSNotification *)notification {
    [self.refreshControl beginRefreshing];
    [self refreshMedia:self.refreshControl];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        return;
    }

    NSDictionary *media = self.media[indexPath.row];

    if (media[@"removePath"]) {
        [self dequeueMedia:media];

        NSMutableArray *newMedia = [NSMutableArray array];
        for (NSDictionary *m in self.media) {
            if (m != media) {
                [newMedia addObject:m];
            }
        }

        self.media = [newMedia copy];
        [tableView reloadData];
    }
}

@end
