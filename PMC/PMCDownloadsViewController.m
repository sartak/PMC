#import "PMCDownloadsViewController.h"
#import "PMCDownloadManager.h"
#import "PMCHTTPClient.h"

@interface PMCDownloadsViewController ()

@property (nonatomic, strong) NSArray *records;

@end

@implementation PMCDownloadsViewController

@dynamic records; // use superclass's smarter implementation

-(id)init {
    if (self = [super init]) {
        self.title = @"Downloads";
    }
    
    return self;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshRecordsAnimated:NO];
}

-(NSString *)sizeDescription:(unsigned long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lluB", size];
    }
    size /= 1024;
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lluK", size];
    }
    size /= 1024;
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lluM", size];
    }
    size /= 1024;
    return [NSString stringWithFormat:@"%lluG", size];
}

-(NSString *)diskDescription {
    return [NSString stringWithFormat:@"%@ + %@", [self sizeDescription:[PMCDownloadManager appDiskSpace]], [self sizeDescription:[PMCDownloadManager freeDiskSpace]]];
}

-(void)refreshRecordsFromDisk {
    [NSDictionary dictionaryWithObjectsAndKeys:@"test", @"blah", @"other", @"other", nil];
    
    NSMutableArray *refreshed = [NSMutableArray array];
    [refreshed addObjectsFromArray:[PMCDownloadManager failedDownloadMedia]];
    [refreshed addObjectsFromArray:[PMCDownloadManager downloadingMedia]];
    [refreshed addObjectsFromArray:[PMCDownloadManager downloadedMedia]];
    
    [refreshed sortUsingDescriptors:@[
                                      [NSSortDescriptor sortDescriptorWithKey:@"treeId" ascending:YES],
                                      [NSSortDescriptor sortDescriptorWithKey:@"sort_order" ascending:YES],
                                      [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES],
                                      ]];
    self.records = [refreshed copy];
}

-(void)refreshRecords:(UIRefreshControl *)sender {
    [self refreshRecordsFromDisk];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[self diskDescription] style:UIBarButtonItemStylePlain target:nil action:nil];

    // filter records through server to update viewing, metadata, etc
    NSMutableArray *ids = [NSMutableArray array];
    for (NSDictionary *record in [PMCDownloadManager downloadedMedia]) {
        [ids addObject:record[@"id"]];
    }
    NSString *idString = [ids componentsJoinedByString:@","];

    [[PMCHTTPClient sharedClient] mediaFrom:@"/library" withParams:@{@"id":idString} completion:^(NSArray *records, NSError *error) {
        [self refreshRecordsFromDisk];
        [sender endRefreshing];
    }];
}

-(void)setTitleFromCurrentRecord {
    // no-op
}

@end
