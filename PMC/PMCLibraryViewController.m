#import "PMCLibraryViewController.h"
#import "PMCVideoTableViewCell.h"
#import "PMCGameTableViewCell.h"
#import "PMCTreeTableViewCell.h"
#import "PMCSummaryTableViewCell.h"
#import "PMCFiveStarTableViewCell.h"
#import "PMCOneStarTableViewCell.h"
#import "PMCHTTPClient.h"
#import "PMCQueueViewController.h"
#import "PMCBackgroundDownloadManager.h"

@import AVFoundation;
@import AVKit;
@import MediaPlayer;

NSString * const PMCLanguageDidChangeNotification = @"PMCLanguageDidChangeNotification";

@interface PMCLibraryViewController () <AVPlayerViewControllerDelegate>

@property (nonatomic, strong) NSDictionary *currentRecord;
@property (nonatomic, strong) NSArray *records;
@property (nonatomic, strong, readonly) NSString *requestPath;
@property (nonatomic, strong) NSString *currentLanguage;
@property (nonatomic) int totalDuration;
@property (nonatomic) int totalVideos;
@property (nonatomic) int totalPlaytime;
@property (nonatomic) int totalGames;
@property (nonatomic, strong) PMCQueueViewController *queue;
@property (nonatomic, strong) NSMutableDictionary *currentlyWatching;
@property (nonatomic, strong) NSTimer *provisionalViewingTimer;

@end

@implementation PMCLibraryViewController

-(instancetype)init {
    if (self = [super init]) {
        self.currentLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageDidChange:) name:PMCLanguageDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queueDidChange:) name:PMCQueueDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didConnect) name:PMCConnectedStatusNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishMedia) name:PMCMediaFinishedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadDidBegin:) name:PMCBackgroundDownloadDidBegin object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadDidProgress:) name:PMCBackgroundDownloadDidProgress object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadDidComplete:) name:PMCBackgroundDownloadDidComplete object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadDidFail:) name:PMCBackgroundDownloadDidFail object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadErrorDidClear:) name:PMCBackgroundDownloadErrorDidClear object:nil];
    }
    return self;
}

-(instancetype)initWithRequestPath:(NSString *)requestPath forRecord:(NSDictionary *)record withQueue:(PMCQueueViewController *)queue {
    if (self = [self init]) {
        _requestPath = requestPath;
        _queue = queue;

        self.currentRecord = record;
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
                [cell setValue:[self extractLabelFromRecord:record] forKeyPath:@"titleLabel.text"];
            }
        }
        else if (indexPath.section == 1) {
            // localize...
        }
    }
}

-(void)redrawForQueueChange {
    for (UITableViewCell<PMCMediaCell> *cell in self.tableView.visibleCells) {
        if ([cell isKindOfClass:[PMCTreeTableViewCell class]]) {
            continue;
        }

        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        if (indexPath.section == 0) {
            NSDictionary *record = self.records[indexPath.row];

            if ([self.queue isPlayingMedia:record]) {
                cell.playingIndicator.hidden = NO;
                cell.enqueuedIndicator.hidden = YES;
                cell.uploadIndicator.hidden = YES;
            }
            else if ([self.queue hasQueuedMedia:record]) {
                cell.playingIndicator.hidden = YES;
                cell.enqueuedIndicator.hidden = NO;
                cell.uploadIndicator.hidden = YES;
            }
            else {
                cell.playingIndicator.hidden = YES;
                cell.enqueuedIndicator.hidden = YES;
                cell.uploadIndicator.hidden = ![[PMCHTTPClient sharedClient] hasSavedOrProvisionalViewingForMedia:record];
            }
        }
    }
}

-(void)queueDidChange:(NSNotification *)notification {
    [self redrawForQueueChange];
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
        self.title = [PMCHTTPClient sharedClient].currentLocation[@"label"];
    }
}

-(void)loadView {
    [super loadView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshRecords:) forControlEvents:UIControlEventValueChanged];

    self.tableView.estimatedRowHeight = 44;

    [self.tableView registerNib:[UINib nibWithNibName:@"PMCVideoTableViewCell" bundle:nil] forCellReuseIdentifier:@"Video"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCGameTableViewCell" bundle:nil] forCellReuseIdentifier:@"Game"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCTreeTableViewCell" bundle:nil] forCellReuseIdentifier:@"Tree"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCFiveStarTableViewCell" bundle:nil] forCellReuseIdentifier:@"★★★★★"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCOneStarTableViewCell" bundle:nil] forCellReuseIdentifier:@"★☆☆☆☆"];
    [self.tableView registerNib:[UINib nibWithNibName:@"PMCSummaryTableViewCell" bundle:nil] forCellReuseIdentifier:@"Summary"];

    if (self.currentRecord) {
        [self.refreshControl beginRefreshing];
        [self refreshRecords:self.refreshControl];
    }

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

-(void)didConnect {
    [self refreshRecordsAnimated:NO];
}

-(void)didFinishMedia {
    [self refreshRecordsAnimated:NO];
}

-(void)refreshRecordsAnimated:(BOOL)animated {
    if (animated) {
        [self.refreshControl beginRefreshing];
        [self refreshRecords:self.refreshControl];
    }
    else {
        [self refreshRecords:nil];
    }
}

-(void)refreshRecords:(UIRefreshControl *)sender {
    [[PMCHTTPClient sharedClient] mediaFrom:self.requestPath withParams:nil completion:^(NSArray *records, NSError *error) {
        self.records = records;
        [sender endRefreshing];
    }];
}

-(void)enqueueMedia:(NSDictionary *)media usingAction:(NSDictionary *)action {
    [[PMCHTTPClient sharedClient] sendMethod:@"POST"
                                  toEndpoint:action[@"url"]
                                  completion:nil];
}

-(NSString *)preferredSpokenLanguages:(NSDictionary *)video {
    NSMutableArray *langs = [NSMutableArray array];
    for (NSDictionary *spec in video[@"spoken_langs"]) {
        if (![langs containsObject:spec[@"type"]]) {
            [langs addObject:spec[@"type"]];
        }
    }
    
    langs = [[langs sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    NSMutableArray *existingPreferred = [NSMutableArray array];
    
    for (NSString *preferredFull in [NSLocale preferredLanguages]) {
        NSString *preferred = [preferredFull componentsSeparatedByString:@"-"][0];
        
        if ([langs containsObject:preferred]) {
            [existingPreferred addObject:preferred];
            [langs removeObject:preferred];
        }
    }
    [existingPreferred addObjectsFromArray:langs];
    
    return [existingPreferred componentsJoinedByString:@", "];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForVideo:(NSDictionary *)video atIndexPath:(NSIndexPath *)indexPath {
    PMCVideoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Video" forIndexPath:indexPath];
    [self updateCell:cell forVideo:video atIndexPath:indexPath];
    return cell;
}

-(void)updateCell:(PMCVideoTableViewCell *)cell forVideo:(NSDictionary *)video atIndexPath:(NSIndexPath *)indexPath {
    PMCBackgroundDownloadManager *downloadManager = [PMCBackgroundDownloadManager sharedClient];

    cell.titleLabel.text = [self extractLabelFromRecord:video];

    id identifier = [video valueForKeyPath:@"identifier"];
    if (!identifier || identifier == [NSNull null]) {
        cell.identifierLabel.text = @"";
    }
    else {
        cell.identifierLabel.text = identifier;
    }

    cell.durationLabel.textColor = [UIColor lightGrayColor];
    id duration = [video valueForKeyPath:@"duration_seconds"];
    if (!duration || duration == [NSNull null] || [duration intValue] == 0) {
        cell.durationLabel.text = @"";
    }
    else {
        int seconds = [duration intValue];

        int resume = 0;
        
        NSDictionary *savedViewing = [[PMCHTTPClient sharedClient] latestSavedViewingForMedia:video];
        if (savedViewing) {
            resume = [savedViewing[@"endSeconds"] intValue];
        }
        else {
            resume = [[video valueForKeyPath:@"resume.seconds"] intValue];
        }

        if (resume) {
            seconds -= resume;
            cell.durationLabel.textColor = [UIColor blueColor];
        }

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

        if (resume) {
            cell.durationLabel.text = [cell.durationLabel.text stringByAppendingString:@" left"];
        }
    }

    cell.immersionIndicator.hidden = ![[video valueForKeyPath:@"immersible"] boolValue];
    cell.immersionIndicator.tintColor = [UIColor greenColor];

    cell.downloadedIndicator.hidden = ![downloadManager mediaIsDownloaded:video];

    if ([downloadManager mediaIsDownloading:video]) {
        cell.downloadingIndicator.hidden = NO;
        [cell.downloadingIndicator startAnimating];
    }
    else {
        cell.downloadingIndicator.hidden = YES;
    }

    // force 12x12, see http://stackoverflow.com/questions/2638120/can-i-change-the-size-of-uiactivityindicator
    cell.downloadingIndicator.transform = CGAffineTransformMakeScale(0.6, 0.6);

    NSNumber *downloadProgress = [downloadManager downloadProgressForMedia:video];
    if (downloadProgress) {
        float percent = [downloadProgress floatValue];

        cell.downloadProgress.hidden = NO;
        cell.downloadProgress.frame = CGRectMake(cell.downloadProgress.superview.bounds.origin.x,
                                                 cell.downloadProgress.superview.bounds.origin.y,
                                                 cell.downloadProgress.superview.bounds.size.width * percent,
                                                 cell.downloadProgress.superview.bounds.size.height
                                                 );

        if ([downloadManager downloadIsLocalForMedia:video]) {
            cell.downloadProgress.backgroundColor = [UIColor colorWithRed:232/255. green:140/255. blue:255/255. alpha:1];
        }
        else {
            cell.downloadProgress.backgroundColor = [UIColor colorWithRed:140/255. green:191/255. blue:255/255. alpha:1];
        }
    }
    else {
        cell.downloadProgress.hidden = YES;
    }

    if ([downloadManager downloadErrorForMedia:video]) {
        cell.titleLabel.textColor = [UIColor redColor];
    }
    else {
        cell.titleLabel.textColor = [UIColor blackColor];
    }

    cell.accessoryType = UITableViewCellAccessoryNone;

    if ([self.queue isPlayingMedia:video]) {
        cell.playingIndicator.hidden = NO;
        cell.enqueuedIndicator.hidden = YES;
        cell.uploadIndicator.hidden = YES;
    }
    else if ([self.queue hasQueuedMedia:video]) {
        cell.playingIndicator.hidden = YES;
        cell.enqueuedIndicator.hidden = NO;
        cell.uploadIndicator.hidden = YES;
    }
    else {
        cell.playingIndicator.hidden = YES;
        cell.enqueuedIndicator.hidden = YES;
        cell.uploadIndicator.hidden = ![[PMCHTTPClient sharedClient] hasSavedOrProvisionalViewingForMedia:video];
    }

    if (![[video valueForKeyPath:@"streamable"] boolValue]) {
        cell.backgroundColor = [UIColor colorWithHue:0 saturation:.11f brightness:1 alpha:1];
    }
    else if ([[video valueForKeyPath:@"completed"] isEqual:[NSNull null]]) {
        cell.backgroundColor = [UIColor whiteColor];
    }
    else {
        int lastPlayedEpoch = 0;
        if (![[video valueForKeyPath:@"last_played"] isEqual:[NSNull null]]) {
            lastPlayedEpoch = [[video valueForKeyPath:@"last_played"] intValue];
        }

        NSDate *lastPlayed = [NSDate dateWithTimeIntervalSince1970:lastPlayedEpoch];
        NSTimeInterval since = [[NSDate date] timeIntervalSinceDate:lastPlayed];
        double percent = since / (5*365*24*60*60.);
        double saturation = MAX(.10, .4 * (1-percent));

        cell.backgroundColor = [UIColor colorWithHue:117/360. saturation:saturation brightness:1 alpha:1];
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForGame:(NSDictionary *)game atIndexPath:(NSIndexPath *)indexPath {
    PMCGameTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Game" forIndexPath:indexPath];

    cell.titleLabel.text = [self extractLabelFromRecord:game];

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

    if ([self.queue isPlayingMedia:game]) {
        cell.playingIndicator.hidden = NO;
        cell.enqueuedIndicator.hidden = YES;
    }
    else if ([self.queue hasQueuedMedia:game]) {
        cell.playingIndicator.hidden = YES;
        cell.enqueuedIndicator.hidden = NO;
    }
    else {
        cell.playingIndicator.hidden = YES;
        cell.enqueuedIndicator.hidden = YES;
    }

    if (![[game valueForKeyPath:@"streamable"] boolValue]) {
        cell.backgroundColor = [UIColor colorWithHue:0 saturation:.11f brightness:1 alpha:1];
    }
    else if ([[game valueForKeyPath:@"completed"] isEqual:[NSNull null]]) {
        cell.backgroundColor = [UIColor whiteColor];
    }
    else {
        cell.backgroundColor = [UIColor colorWithHue:117/360. saturation:.22f brightness:1 alpha:1];
    }
    
    return cell;
}

-(NSString *)extractLabelFromRecord:(NSDictionary *)record {
    for (NSString *lang in [@[self.currentLanguage] arrayByAddingObjectsFromArray:[NSLocale preferredLanguages]]) {
        NSArray *components = [lang componentsSeparatedByString:@"-"];
        NSString *keyPath = [@"label." stringByAppendingString:components[0]];
        id label = [record valueForKeyPath:keyPath];
        if (label && label != [NSNull null]) {
            return label;
        }
    }

    return [record valueForKeyPath:@"label.en"];
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

    cell.titleLabel.text = [self extractLabelFromRecord:tree];

    return cell;
}

-(void)shareDownloadedMedia:(NSDictionary *)media fromCell:(UITableViewCell *)cell {
    NSURL *url = [[PMCBackgroundDownloadManager sharedClient] URLForDownloadedMedia:media mustExist:YES];
    if (url) {
        UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];

        activity.popoverPresentationController.sourceView = self.view;
        activity.popoverPresentationController.sourceRect = cell.frame;
        [activity.popoverPresentationController setPermittedArrowDirections:UIPopoverArrowDirectionDown|UIPopoverArrowDirectionUp];
        
        [self presentViewController:activity animated:YES completion:nil];
    }
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
    PMCBackgroundDownloadManager *downloadManager = [PMCBackgroundDownloadManager sharedClient];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSDictionary *record = self.records[indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section != 0) {
        return;
    }
    
    PMCVideoTableViewCell *videoCell;
    if ([cell isKindOfClass:[PMCVideoTableViewCell class]]) {
        videoCell = (PMCVideoTableViewCell *)cell;
    }

    NSString *message = [self extractLabelFromRecord:record];
    if ([record[@"tags"] count]) {
        message = [NSString stringWithFormat:@"%@\n[%@]", message, [record[@"tags"] componentsJoinedByString:@", "]];
    }
    if ([record[@"path"] hasPrefix:@"/media/paul/Go/American Yunguseng Dojang/"]) {
        message = [NSString stringWithFormat:@"%@\n(%d)", message, -1*[record[@"sort_order"] intValue]];
    }
    else if ([record[@"type"] isEqualToString:@"video"]) {
        message = [NSString stringWithFormat:@"%@\n(%@)", message, [self preferredSpokenLanguages:record]];
    }

    NSString *downloadError = [downloadManager downloadErrorForMedia:record];
    if (downloadError) {
        message = downloadError;
    }
    
    if (downloadError || (record[@"actions"] && [record[@"actions"] count] > 1)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        for (NSDictionary *action in record[@"actions"]) {
            if ([action[@"type"] isEqualToString:@"download"]) {
                if ([downloadManager mediaIsDownloaded:record]) {
                    NSURL *url = [downloadManager URLForDownloadedMedia:record mustExist:YES];
                    if ([[record valueForKeyPath:@"resume.seconds"] intValue]) {
                        UIAlertAction *playAction = [UIAlertAction actionWithTitle:@"Play Downloaded from Beginning"
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^(UIAlertAction *alertAction) {
                                                                               [self beginPlayingURL:url forRecord:record withAction:action];
                                                                           }];
                        [alert addAction:playAction];

                        NSMutableDictionary *actionForPlay = [action mutableCopy];
                        actionForPlay[@"seek"] = [record valueForKeyPath:@"resume.seconds"];
                        UIAlertAction *resumeAction = [UIAlertAction actionWithTitle:@"Resume Downloaded"
                                                                               style:UIAlertActionStyleDefault
                                                                             handler:^(UIAlertAction *alertAction) {
                                                                                 [self beginPlayingURL:url forRecord:record withAction:actionForPlay];
                                                                             }];
                        [alert addAction:resumeAction];
                    }
                    else {
                        UIAlertAction *playAction = [UIAlertAction actionWithTitle:@"Play Downloaded"
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^(UIAlertAction *alertAction) {
                                                                               [self beginPlayingURL:url forRecord:record withAction:action];
                                                                           }];
                        [alert addAction:playAction];
                    }

                    UIAlertAction *shareAction = [UIAlertAction actionWithTitle:@"Share Downloaded"
                                                                          style:UIAlertActionStyleDefault
                                                                        handler:^(UIAlertAction *alertAction) {
                                                                            [self shareDownloadedMedia:record fromCell:cell];
                                                                        }];
                    [alert addAction:shareAction];

                    if (![downloadManager downloadedMediaIsPersisted:record]) {
                        UIAlertAction *persistAction = [UIAlertAction actionWithTitle:@"Disable Autodelete"
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction *alertAction) {
                                                                                  [downloadManager persistDownloadedMedia:record];
                                                                              }];

                        [alert addAction:persistAction];
                    }

                    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Delete Downloaded"
                                                                           style:UIAlertActionStyleDestructive
                                                                         handler:^(UIAlertAction *alertAction) {
                                                                             [downloadManager deleteDownloadedMedia:record];

                                                                             [UIView animateWithDuration:0.5 animations:^{
                                                                                 videoCell.downloadedIndicator.alpha = 0;
                                                                             } completion:^(BOOL finished) {
                                                                                 videoCell.downloadedIndicator.hidden = YES;
                                                                                 videoCell.downloadedIndicator.alpha = 1;
                                                                                 [self refreshRecordsAnimated:NO];
                                                                             }];
                                                                         }];

                    [alert addAction:deleteAction];
                } else if ([downloadManager mediaIsDownloading:record]) {
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel Download"
                                                                           style:UIAlertActionStyleDestructive
                                                                         handler:^(UIAlertAction *alertAction) {
                                                                             [downloadManager cancelMediaDownload:record];
                                                                         }];
                    [alert addAction:cancelAction];
                } else { // to download
                    if ([downloadManager downloadErrorForMedia:record]) {
                        UIAlertAction *clearErrorAction = [UIAlertAction actionWithTitle:@"Clear Error"
                                                                                    style:UIAlertActionStyleDestructive
                                                                                  handler:^(UIAlertAction *alertAction) {
                                                                                      [downloadManager clearDownloadErrorForMedia:record];
                                                                                  }];
                        [alert addAction:clearErrorAction];
                    }

                    NSString *title = [downloadManager downloadResumeDataForMedia:record] ? @"Resume Download" : [downloadManager downloadErrorForMedia:record] ? @"Retry Download" : @"Download";

                    UIAlertAction *downloadAction = [UIAlertAction actionWithTitle:title
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^(UIAlertAction *alertAction) {
                                                                               [downloadManager downloadMedia:record usingAction:action];
                                                                           }];
                    [alert addAction:downloadAction];
                }

                continue;
            }

            UIAlertAction *alertAction = [UIAlertAction actionWithTitle:action[@"label"]
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *alertAction) {
                                                                    [self selectedAction:action forRecord:record fromCell:cell];
                                                                }];
            [alert addAction:alertAction];
        }

        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = cell.frame;
        [alert.popoverPresentationController setPermittedArrowDirections:UIPopoverArrowDirectionDown|UIPopoverArrowDirectionUp];

        [self presentViewController:alert animated:YES completion:nil];
    }
    else if (record[@"actions"] && [record[@"actions"] count] == 1) {
        [self selectedAction:record[@"actions"][0] forRecord:record fromCell:cell];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No actions"
                                                        message:[NSString stringWithFormat:@"No actions for media type '%@'", record[@"type"]]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

-(void)selectedAction:(NSDictionary *)action forRecord:(NSDictionary *)record fromCell:(UITableViewCell *)cell {
    if ([action[@"type"] isEqualToString:@"stream"]) {
        [self beginStreaming:record usingAction:action];
    }
    else if ([action[@"type"] isEqualToString:@"download"]) {
        [[PMCBackgroundDownloadManager sharedClient] downloadMedia:record usingAction:action];
    }
    else if ([action[@"type"] isEqualToString:@"navigate"]) {
        PMCLibraryViewController *next = [[PMCLibraryViewController alloc] initWithRequestPath:action[@"url"] forRecord:record withQueue:self.queue];
        next.currentLanguage = self.currentLanguage;

        [self.navigationController pushViewController:next animated:YES];
    }
    else {
        NSString *method = @"POST";
        if (action[@"method"]) {
            method = action[@"method"];
        }
        [[PMCHTTPClient sharedClient] sendMethod:method
                                      toEndpoint:action[@"url"]
                                      completion:^(NSData *data, NSURLResponse *response, NSError *error) {
                                          [self refreshRecordsAnimated:NO];
                                      }];
    }
}

-(void)beginStreaming:(NSDictionary *)record usingAction:(NSDictionary *)action {
    NSString *endpoint = [NSString stringWithFormat:@"%@%@&user=%@&pass=%@", [[PMCHTTPClient sharedClient] host], action[@"url"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PMC_USERNAME"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PMC_PASSWORD"]];
    NSURL *url = [NSURL URLWithString:endpoint];
    [self beginPlayingURL:url forRecord:record withAction:action];
}

-(void)beginPlayingURL:(NSURL *)url forRecord:(NSDictionary *)record withAction:(NSDictionary *)action {
    self.currentlyWatching = [NSMutableDictionary dictionary];
    self.currentlyWatching[@"media"] = record;
    self.currentlyWatching[@"action"] = action;
    self.currentlyWatching[@"startTime"] = [NSDate date];

    if (action[@"audioTrack"]) {
        self.currentlyWatching[@"audioTrack"] = action[@"audioTrack"];
    }
    else {
        self.currentlyWatching[@"audioTrack"] = @(0);
    }

    if (action[@"initialSeconds"]) {
        self.currentlyWatching[@"initialSeconds"] = action[@"initialSeconds"];
    }
    else {
        self.currentlyWatching[@"initialSeconds"] = @(0);
    }

    if (action[@"seek"]) {
        self.currentlyWatching[@"seek"] = action[@"seek"];
    }

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    item.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];

    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    self.currentlyWatching[@"player"] = player;

    item = [player currentItem];
    self.currentlyWatching[@"playerItem"] = item;

    [player addObserver:self forKeyPath:@"status" options:0 context:nil];
    [item addObserver:self forKeyPath:@"playbackBufferEmpty" options:0 context:nil];
    [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:0 context:nil];

    AVPlayerViewController *vc = [[AVPlayerViewController alloc] init];
    vc.player = player;
    vc.allowsPictureInPicturePlayback = YES;
    vc.delegate = self;

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    NSDictionary *info = @{
                           MPMediaItemPropertyTitle:[self extractLabelFromRecord:record],
                           MPNowPlayingInfoPropertyPlaybackRate:@(1.0),
                           MPMediaItemPropertyPlaybackDuration:record[@"duration_seconds"]
                           };
    infoCenter.nowPlayingInfo = info;

    MPRemoteCommandCenter *rcc = [MPRemoteCommandCenter sharedCommandCenter];
    MPSkipIntervalCommand *skipBackwardIntervalCommand = [rcc skipBackwardCommand];
    [skipBackwardIntervalCommand setEnabled:YES];
    [skipBackwardIntervalCommand addTarget:self action:@selector(skipBackwardEvent:)];
    skipBackwardIntervalCommand.preferredIntervals = @[@(15)];

    MPSkipIntervalCommand *skipForwardIntervalCommand = [rcc skipForwardCommand];
    skipForwardIntervalCommand.preferredIntervals = @[@(15)];
    [skipForwardIntervalCommand setEnabled:YES];
    [skipForwardIntervalCommand addTarget:self action:@selector(skipForwardEvent:)];

    MPRemoteCommand *pauseCommand = [rcc pauseCommand];
    [pauseCommand setEnabled:YES];
    [pauseCommand addTarget:self action:@selector(playOrPauseEvent:)];

    MPRemoteCommand *playCommand = [rcc playCommand];
    [playCommand setEnabled:YES];
    [playCommand addTarget:self action:@selector(playOrPauseEvent:)];

    vc.updatesNowPlayingInfoCenter = NO;

    [self presentViewController:vc animated:YES completion:^{
        self.provisionalViewingTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(saveProvisionalViewing) userInfo:nil repeats:YES];
        [player play];
        [self updateNowPlaying];
    }];
}

-(void)seekToTime:(CMTime)time {
    NSDictionary *stream = self.currentlyWatching;
    if (!stream) {
        return;
    }
    AVPlayer *player = stream[@"player"];
    [player seekToTime:time];
    [self updateNowPlaying:CMTimeGetSeconds(time)];
}

-(void)updateNowPlaying:(NSTimeInterval)time {
    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary *playingInfo = [NSMutableDictionary dictionaryWithDictionary:center.nowPlayingInfo];
    [playingInfo setObject:@(time) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    center.nowPlayingInfo = playingInfo;
}

-(void)updateNowPlaying {
    NSDictionary *stream = self.currentlyWatching;
    if (!stream) {
        return;
    }
    AVPlayer *player = stream[@"player"];
    [self updateNowPlaying:CMTimeGetSeconds(player.currentTime)];
}

-(void)skipByInterval:(NSTimeInterval)interval {
    NSDictionary *stream = self.currentlyWatching;
    if (!stream) {
        return;
    }
    AVPlayer *player = stream[@"player"];
    
    CMTime newTime = CMTimeMakeWithSeconds(CMTimeGetSeconds(player.currentTime) + interval, player.currentTime.timescale);
    [self seekToTime:newTime];
}

-(void)skipBackwardEvent:(MPSkipIntervalCommandEvent *)event {
    [self skipByInterval:-event.interval];
}

-(void)skipForwardEvent:(MPSkipIntervalCommandEvent *)event {
    [self skipByInterval:event.interval];
}

-(void)playOrPauseEvent:(MPRemoteCommandEvent *)event {
    NSDictionary *stream = self.currentlyWatching;
    if (!stream) {
        return;
    }
    AVPlayer *player = stream[@"player"];
    
    if (player.currentItem && player.rate != 0) {
        [player pause];
    }
    else {
        [player play];
        [self updateNowPlaying];
    }
}

-(void)saveProvisionalViewing {
    [[PMCHTTPClient sharedClient] setProvisionalViewing:[self currentlyWatchingViewing]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (!self.currentlyWatching) {
        return;
    }

    NSDictionary *stream = self.currentlyWatching;
    AVPlayer *player = stream[@"player"];
    AVPlayerItem *item = stream[@"playerItem"];

    if (object == player && [keyPath isEqualToString:@"status"]) {
        if (player.status == AVPlayerStatusReadyToPlay) {
            if (self.currentlyWatching[@"seek"]) {
                CMTimeScale scale = player.currentTime.timescale;
                CMTime time = CMTimeMake([self.currentlyWatching[@"seek"] intValue], scale);
                [self seekToTime:time];
            }
        }
        else if (player.status == AVPlayerStatusFailed) {

        }
    }
    else if (object == item && [keyPath isEqualToString:@"playbackBufferEmpty"]) {
        /*
        if (item.playbackBufferEmpty) {
            NSLog(@"pausing because playbackBufferEmpty");
            [player pause];
        }
         */
    }
    else if (object == item && [keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        /*
        if (item.playbackLikelyToKeepUp) {
            NSLog(@"unpausing because playbackLikelyToKeepUp");
            [player play];
            [self updateNowPlaying];

        }
         */
    }
}

-(void)appDidEnterBackground {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *stream = self.currentlyWatching;
        if (stream && ![stream[@"pip"] boolValue]) {
            AVPlayer *player = stream[@"player"];
            [player pause];
        }
    });
}

-(NSDictionary *)currentlyWatchingViewing {
    if (!self.currentlyWatching) {
        return nil;
    }

    NSDictionary *stream = self.currentlyWatching;
    AVPlayer *player = stream[@"player"];

    NSDictionary *media = self.currentlyWatching[@"media"];

    // didn't really stream anything, not even worth adding a viewing
    if (CMTimeGetSeconds(player.currentTime) < 2) {
        return nil;
    }

    return @{
             @"mediaId": media[@"id"],
             @"startTime": [@([stream[@"startTime"] timeIntervalSince1970]) stringValue],
             @"endTime": [@([[NSDate date] timeIntervalSince1970]) stringValue],
             @"initialSeconds": [stream[@"initialSeconds"] stringValue],
             @"endSeconds": [@([stream[@"initialSeconds"] intValue] + CMTimeGetSeconds(player.currentTime)) stringValue],
             @"audioTrack": [stream[@"audioTrack"] stringValue],
             @"location": [PMCHTTPClient device],
             };
}

-(void)didFinishWatching {
    if (!self.currentlyWatching) {
        return;
    }

    NSDictionary *params = [self currentlyWatchingViewing];

    [self.provisionalViewingTimer invalidate];
    self.provisionalViewingTimer = nil;

    NSDictionary *stream = self.currentlyWatching;
    self.currentlyWatching = nil;

    AVPlayer *player = stream[@"player"];
    [player removeObserver:self forKeyPath:@"status"];

    AVPlayerItem *item = stream[@"playerItem"];
    [item removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [item removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];

    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    infoCenter.nowPlayingInfo = nil;

   // [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
  //  [self resignFirstResponder];

    if (params) {
        [[PMCHTTPClient sharedClient] setProvisionalViewing:nil];
        [[PMCHTTPClient sharedClient] sendViewingWithRetries:params completion:^(NSError *error) {
            [self didFinishMedia];
        }];
    }
    else {
        [self didFinishMedia];
    }
}

-(void)itemDidFinishPlaying:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self didFinishWatching];
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

-(void)viewDidAppear:(BOOL)animated {
    if (self.currentlyWatching) {
        [self didFinishWatching];
    }
}

#pragma mark - AVPlayerViewControllerDelegate

-(void)playerViewControllerWillStartPictureInPicture:(AVPlayerViewController *)playerViewController {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"setting pip to YES");
        self.currentlyWatching[@"pip"] = @(YES);
    });
}

-(void)playerViewControllerWillStopPictureInPicture:(AVPlayerViewController *)playerViewController {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"clearing pip");
        [self.currentlyWatching removeObjectForKey:@"pip"];
    });
}

-(void)playerViewControllerDidStopPictureInPicture:(AVPlayerViewController *)playerViewController {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
            // the user hit the X button while in picture in picture
            [self didFinishWatching];
        }
    });
}

-(BOOL)playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart:(AVPlayerViewController *)playerViewController {
    // if we're currently watching, don't restore the UI.
    // if we are not watching, then we already sent the viewing entry, so dismiss the video
    return self.currentlyWatching ? NO : YES;
}

-(void)refreshVisibleCells {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UITableViewCell *cell in self.tableView.visibleCells) {
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            if ([cell isKindOfClass:[PMCVideoTableViewCell class]]) {
                NSDictionary *record = self.records[indexPath.row];
                [self updateCell:(PMCVideoTableViewCell *)cell forVideo:record atIndexPath:indexPath];
            }
        }
    });
}

-(void)downloadDidBegin:(NSNotification *)event {
    [self refreshVisibleCells];
}

-(void)downloadDidProgress:(NSNotification *)event {
    dispatch_async(dispatch_get_main_queue(), ^{
        PMCBackgroundDownloadManager *downloadManager = [PMCBackgroundDownloadManager sharedClient];
        NSDictionary *media = event.userInfo[@"media"];
        for (UITableViewCell *cell in self.tableView.visibleCells) {
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            if ([cell isKindOfClass:[PMCVideoTableViewCell class]]) {
                NSDictionary *record = self.records[indexPath.row];
                if ([record[@"id"] isEqualToString:media[@"id"]]) {
                    PMCVideoTableViewCell *videoCell = (PMCVideoTableViewCell *)cell;
                    float percent = [event.userInfo[@"percent"] floatValue];
                    videoCell.downloadProgress.hidden = NO;
                    videoCell.downloadProgress.frame = CGRectMake(videoCell.downloadProgress.superview.bounds.origin.x,
                                                                  videoCell.downloadProgress.superview.bounds.origin.y,
                                                                  videoCell.downloadProgress.superview.bounds.size.width * percent,
                                                                  videoCell.downloadProgress.superview.bounds.size.height
                                                                  );
                    if ([downloadManager downloadIsLocalForMedia:record]) {
                        videoCell.downloadProgress.backgroundColor = [UIColor colorWithRed:232/255. green:140/255. blue:255/255. alpha:1];
                    }
                    else {
                        videoCell.downloadProgress.backgroundColor = [UIColor colorWithRed:140/255. green:191/255. blue:255/255. alpha:1];
                    }
                }
            }
        }
    });
}

-(void)downloadDidComplete:(NSNotification *)event {
    [self refreshVisibleCells];
}

-(void)downloadDidFail:(NSNotification *)event {
    [self refreshVisibleCells];
}

-(void)downloadErrorDidClear:(NSNotification *)event {
    [self refreshVisibleCells];
}

@end
