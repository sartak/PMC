#import "PMCBackgroundDownloadManager.h"
#import "PMCHTTPClient.h"

NSString * const PMCBackgroundDownloadDidBegin = @"PMCBackgroundDownloadDidBegin";
NSString * const PMCBackgroundDownloadDidProgress = @"PMCBackgroundDownloadDidProgress";
NSString * const PMCBackgroundDownloadDidComplete = @"PMCBackgroundDownloadDidComplete";
NSString * const PMCBackgroundDownloadDidFail = @"PMCBackgroundDownloadDidFail";
NSString * const PMCBackgroundDownloadErrorDidClear = @"PMCBackgroundDownloadErrorDidClear";

@interface PMCBackgroundDownloadManager () <NSURLSessionDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSData *> *resumeData;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *bytesForMedia;

@end

@implementation PMCBackgroundDownloadManager

+(instancetype)sharedClient {
    static dispatch_once_t onceToken;
    static PMCBackgroundDownloadManager *sharedClient;
    dispatch_once(&onceToken, ^{
        sharedClient = [[PMCBackgroundDownloadManager alloc] init];
    });
    return sharedClient;
}

-(instancetype)init {
    if (self = [super init]) {
        _resumeData = [NSMutableDictionary dictionary];
        _bytesForMedia = [NSMutableDictionary dictionary];
    }
    return self;
}

-(NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"PMC"];
        config.discretionary = NO;
        config.sessionSendsLaunchEvents = YES;
        config.HTTPMaximumConnectionsPerHost = 2;

        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }

    return _session;
}

-(NSDictionary<NSString *, NSDictionary *> *)downloadingMetadata {
    NSData *json = [[NSUserDefaults standardUserDefaults] dataForKey:@"downloadingMetadata"];
    if (!json) {
        return @{};
    }
    NSDictionary *metadata = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    if (!metadata) {
        return @{};
    }
    return metadata;
}

-(void)saveDownloadingMetadata:(NSDictionary<NSString *, NSDictionary *> *)metadata {
    NSData *json = [NSJSONSerialization dataWithJSONObject:metadata options:0 error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:json forKey:@"downloadingMetadata"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSDictionary *)downloadingMetadataForMediaId:(NSString *)mediaId {
    return self.downloadingMetadata[mediaId];
}

-(void)saveDownloadingMetadataForMedia:(NSDictionary *)media {
    NSMutableDictionary<NSString *, NSDictionary *> *metadata = [[self downloadingMetadata] mutableCopy];
    metadata[media[@"id"]] = media;
    [self saveDownloadingMetadata:metadata];
}

-(void)clearDownloadingMetadataForMedia:(NSDictionary *)media {
    NSMutableDictionary<NSString *, NSDictionary *> *metadata = [[self downloadingMetadata] mutableCopy];
    [metadata removeObjectForKey:media[@"id"]];
    [self saveDownloadingMetadata:metadata];
}

-(NSDictionary<NSString *, NSArray *> *)downloadErrors {
    NSData *json = [[NSUserDefaults standardUserDefaults] dataForKey:@"downloadErrors"];
    if (!json) {
        return @{};
    }
    NSDictionary *errors = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    if (!errors) {
        return @{};
    }
    return errors;
}

-(void)saveDownloadErrors:(NSDictionary<NSString *, NSArray *> *)errors {
    NSData *json = [NSJSONSerialization dataWithJSONObject:errors options:0 error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:json forKey:@"downloadErrors"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSString *)downloadErrorForMedia:(NSDictionary *)media {
    return self.downloadErrors[media[@"id"]][1];
}

-(void)saveDownloadErrorForMedia:(NSDictionary *)media error:(NSError *)error {
    NSMutableDictionary<NSString *, NSArray *> *errors = [[self downloadErrors] mutableCopy];
    errors[media[@"id"]] = @[media, [error localizedDescription]];
    [self saveDownloadErrors:errors];
}

-(void)clearDownloadErrorForMedia:(NSDictionary *)media {
    NSMutableDictionary<NSString *, NSArray *> *errors = [[self downloadErrors] mutableCopy];
    [errors removeObjectForKey:media[@"id"]];
    [self saveDownloadErrors:errors];
    [self.resumeData removeObjectForKey:media[@"id"]];
    [self clearDownloadIsLocalForMedia:media];

    [[NSNotificationCenter defaultCenter] postNotificationName:PMCBackgroundDownloadErrorDidClear object:self userInfo:@{@"media":media}];
}

-(NSDictionary<NSString *, NSNumber *> *)downloadProgress {
    NSDictionary *progress = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"downloadProgress"];
    if (!progress) {
        return @{};
    }
    return progress;
}

-(void)saveDownloadProgress:(NSDictionary<NSString *, NSNumber *> *)progress {
    [[NSUserDefaults standardUserDefaults] setObject:progress forKey:@"downloadProgress"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSNumber *)downloadProgressForMedia:(NSDictionary *)media {
    return self.downloadProgress[media[@"id"]];
}

-(void)saveDownloadProgressForMedia:(NSDictionary *)media percent:(float)percent {
    NSMutableDictionary<NSString *, NSNumber *> *progress = [[self downloadProgress] mutableCopy];
    progress[media[@"id"]] = @(percent);
    [self saveDownloadProgress:progress];
}

-(void)clearDownloadProgressForMedia:(NSDictionary *)media {
    NSMutableDictionary<NSString *, NSNumber *> *progress = [[self downloadProgress] mutableCopy];
    [progress removeObjectForKey:media[@"id"]];
    [self saveDownloadProgress:progress];
}

-(NSDictionary<NSString *, NSNumber *> *)downloadIsLocal {
    NSDictionary *isLocal = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"downloadIsLocal"];
    if (!isLocal) {
        return @{};
    }
    return isLocal;
}

-(void)saveDownloadIsLocal:(NSDictionary<NSString *, NSNumber *> *)isLocal {
    [[NSUserDefaults standardUserDefaults] setObject:isLocal forKey:@"downloadIsLocal"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(BOOL)downloadIsLocalForMedia:(NSDictionary *)media {
    return [self.downloadIsLocal[media[@"id"]] boolValue];
}

-(void)saveDownloadIsLocalForMedia:(NSDictionary *)media isLocal:(BOOL)local {
    NSMutableDictionary<NSString *, NSNumber *> *isLocal = [[self downloadIsLocal] mutableCopy];
    isLocal[media[@"id"]] = @(local);
    [self saveDownloadIsLocal:isLocal];
}

-(void)clearDownloadIsLocalForMedia:(NSDictionary *)media {
    NSMutableDictionary<NSString *, NSNumber *> *isLocal = [[self downloadIsLocal] mutableCopy];
    [isLocal removeObjectForKey:media[@"id"]];
    [self saveDownloadIsLocal:isLocal];
}

-(void)downloadMedia:(NSDictionary *)media usingAction:(NSDictionary *)action {
    [self saveDownloadingMetadataForMedia:media];
    [self clearDownloadErrorForMedia:media];

    NSString *endpoint = action[@"url"];
    NSMutableURLRequest *request = [[PMCHTTPClient sharedClient] requestWithEndpoint:endpoint method:@"GET"];

    NSLog(@"%@ %@", request.HTTPMethod, request.URL);
    NSURLSessionDownloadTask *download;

    if (self.resumeData[media[@"id"]]) {
        download = [self.session downloadTaskWithResumeData:self.resumeData[media[@"id"]]];
        [self.resumeData removeObjectForKey:media[@"id"]];
    }
    else {
        download = [self.session downloadTaskWithRequest:request];
        BOOL isLocal = [[request.URL host] containsString:@".local"];
        [self saveDownloadIsLocalForMedia:media isLocal:isLocal];
    }

    download.taskDescription = media[@"id"];

    [download resume];

    [[NSNotificationCenter defaultCenter] postNotificationName:PMCBackgroundDownloadDidBegin object:self userInfo:@{@"media":media}];
}

-(void)cancelMediaDownload:(NSDictionary *)media {
    [self.session getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> *tasks) {
        for (NSURLSessionTask *task in tasks) {
            if ([task.taskDescription isEqualToString:media[@"id"]]) {
                if ([task isKindOfClass:[NSURLSessionDownloadTask class]]) {
                    [(NSURLSessionDownloadTask *)task cancelByProducingResumeData:^(NSData *resumeData) {
                        self.resumeData[media[@"id"]] = resumeData;
                    }];
                }
                else {
                    [task cancel];
                }
            }
        }
    }];
}

-(BOOL)mediaIsDownloaded:(NSDictionary *)media {
    return [self URLForDownloadedMedia:media mustExist:YES] ? YES : NO;
}

-(BOOL)mediaIsDownloading:(NSDictionary *)media {
    return [self downloadingMetadataForMediaId:media[@"id"]] ? YES : NO;
}

-(void)moveDownload:(NSURL *)location forMedia:(NSDictionary *)media {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    NSURL *subdirURL = [documentsURL URLByAppendingPathComponent:@"downloaded"];

    NSURL *fileURL = [self URLForDownloadedMedia:media mustExist:NO];

    if (![fileManager fileExistsAtPath:subdirURL.path]) {
        NSError *error;
        [fileManager createDirectoryAtPath:subdirURL.path
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
        if (error) {
            [self saveDownloadErrorForMedia:media error:error];
            [[NSNotificationCenter defaultCenter] postNotificationName:PMCBackgroundDownloadDidFail object:self userInfo:@{@"media":media, @"error":error}];
            return;
        }
    }

    NSError *moveError;
    if (![fileManager moveItemAtURL:location toURL:fileURL error:&moveError]) {
        [self saveDownloadErrorForMedia:media error:moveError];
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCBackgroundDownloadDidFail object:self userInfo:@{@"media":media, @"error":moveError}];
        return;
    }

    NSError *attrError;
    BOOL success = [fileURL setResourceValue:[NSNumber numberWithBool: YES]
                                      forKey:NSURLIsExcludedFromBackupKey error:&attrError];
    if (!success) {
        [self saveDownloadErrorForMedia:media error:attrError];
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCBackgroundDownloadDidFail object:self userInfo:@{@"media":media, @"error":attrError}];
        return;
    }

    [self saveMetadataForDownloadedMedia:media];

    [[NSNotificationCenter defaultCenter] postNotificationName:PMCBackgroundDownloadDidComplete object:self userInfo:@{@"media":media}];
}

-(NSURL *)URLForDownloadedMedia:(NSDictionary *)media mustExist:(BOOL)mustExist withExtension:(NSString *)extension {
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", media[@"id"], extension];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    NSURL *subdirURL = [documentsURL URLByAppendingPathComponent:@"downloaded"];
    NSURL *fileURL = [subdirURL URLByAppendingPathComponent:fileName];

    if (mustExist && ![fileManager fileExistsAtPath:fileURL.path]) {
        return nil;
    }

    return fileURL;
}

-(NSURL *)URLForDownloadedMedia:(NSDictionary *)media mustExist:(BOOL)mustExist {
    return [self URLForDownloadedMedia:media mustExist:mustExist withExtension:media[@"extension"]];
}

-(NSURL *)URLForPersistedMedia:(NSDictionary *)media mustExist:(BOOL)mustExist {
    return [self URLForDownloadedMedia:media mustExist:mustExist withExtension:@"persist"];
}

-(NSURL *)URLForDownloadedMediaMetadata:(NSString *)mediaId mustExist:(BOOL)mustExist {
    NSString *fileName = [NSString stringWithFormat:@"%@.json", mediaId];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    NSURL *subdirURL = [documentsURL URLByAppendingPathComponent:@"downloaded"];
    NSURL *fileURL = [subdirURL URLByAppendingPathComponent:fileName];

    if (mustExist && ![fileManager fileExistsAtPath:fileURL.path]) {
        return nil;
    }

    return fileURL;
}

-(NSDictionary *)metadataForMetadataURL:(NSURL *)url {
    NSError *error = nil;

    if (!url) {
        return nil;
    }

    NSData *contents = [NSData dataWithContentsOfFile:url.path options:0 error:&error];

    if (error) {
        NSLog(@"Error reading file %@: %@", url.path, error);
        return nil;
    }

    id json = [NSJSONSerialization JSONObjectWithData:contents options:0 error:&error];
    if (error) {
        NSLog(@"Error loading file %@: %@", url.path, error);
        return nil;
    }

    return json;
}

-(NSDictionary *)metadataForDownloadedMedia:(NSString *)mediaId {
    return [self metadataForMetadataURL:[self URLForDownloadedMediaMetadata:mediaId mustExist:YES]];
}

-(void)saveMetadataForDownloadedMedia:(NSDictionary *)media {
    NSURL *url = [self URLForDownloadedMediaMetadata:media[@"id"] mustExist:NO];
    NSError *error = nil;

    NSData *json = [NSJSONSerialization dataWithJSONObject:media options:0 error:&error];
    if (error) {
        NSLog(@"Error serializing JSON %@: %@", url.path, error);
        return;
    }

    [json writeToFile:url.path atomically:YES];
}

-(void)takeUpdatesToMetadataForMedia:(NSDictionary *)media {
    NSURL *url = [self URLForDownloadedMediaMetadata:media[@"id"] mustExist:YES];
    if (url) {
        [self saveMetadataForDownloadedMedia:media];
    }

    if ([self downloadingMetadataForMediaId:media[@"id"]]) {
        [self saveDownloadingMetadataForMedia:media];
    }
}

-(NSDirectoryEnumerator *)mediaEnumerator {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    NSURL *subdirURL = [documentsURL URLByAppendingPathComponent:@"downloaded"];

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:subdirURL includingPropertiesForKeys:@[NSURLNameKey] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];

    return enumerator;
}

-(unsigned long long)appDiskSpace {
    unsigned long long used = 0;
    NSDirectoryEnumerator *enumerator = [self mediaEnumerator];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    for (NSURL *url in enumerator) {
        used += [[fileManager attributesOfItemAtPath:[url path] error:nil] fileSize];
    }
    return used;
}

-(unsigned long long)freeDiskSpace {
    unsigned long long totalSpace = 0;
    unsigned long long totalFreeSpace = 0;
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];

    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
    } else {
        NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %ld", [error domain], (long)[error code]);
    }

    return totalFreeSpace;
}

-(NSArray<NSDictionary *> *)downloadedMedia {
    NSMutableArray *media = [NSMutableArray array];
    NSDirectoryEnumerator *enumerator = [self mediaEnumerator];

    for (NSURL *url in enumerator) {
        if ([[url pathExtension] isEqualToString:@"json"]) {
            NSDictionary *metadata = [self metadataForMetadataURL:url];

            // make sure the sibling media file does exist
            NSURL *mediaFile = [self URLForDownloadedMedia:metadata mustExist:YES];
            if (!mediaFile) {
                [self deleteDownloadedMedia:metadata];
                continue;
            }

            [media addObject:metadata];
        }
    }

    return [media copy];

}

-(NSArray<NSDictionary *> *)downloadingMedia {
    NSMutableArray *media = [NSMutableArray array];
    [self.downloadingMetadata enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *record, BOOL *stop) {
        [media addObject:record];
    }];
    return [media copy];
}

-(NSArray<NSDictionary *> *)failedDownloadMedia {
    NSMutableArray *media = [NSMutableArray array];
    [self.downloadErrors enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSArray *entry, BOOL *stop) {
        [media addObject:entry[0]];
    }];
    return [media copy];
}

-(void)deleteDownloadedMedia:(NSDictionary *)media {
    NSURL *fileURL = [self URLForDownloadedMedia:media mustExist:YES];
    NSURL *metadataURL = [self URLForDownloadedMediaMetadata:media[@"id"] mustExist:YES];
    NSURL *persistedURL = [self URLForPersistedMedia:media mustExist:YES];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;

    if (fileURL) {
        [fileManager removeItemAtURL:fileURL error:&error];
    }

    if (metadataURL) {
        [fileManager removeItemAtURL:metadataURL error:&error];
    }

    if (persistedURL) {
        [fileManager removeItemAtURL:persistedURL error:&error];
    }
}

-(void)didSendCompletedViewingForMediaId:(NSString *)mediaId {
    NSDictionary *media = [self metadataForDownloadedMedia:mediaId];
    if (media && ![self downloadedMediaIsPersisted:media]) {
        [self deleteDownloadedMedia:media];
    }
}

-(void)persistDownloadedMedia:(NSDictionary *)media {
    if ([self downloadedMediaIsPersisted:media]) {
        return;
    }

    NSURL *url = [self URLForPersistedMedia:media mustExist:NO];
    NSData *empty = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    [empty writeToFile:url.path atomically:YES];
}

-(BOOL)downloadedMediaIsPersisted:(NSDictionary *)media {
    return [self URLForPersistedMedia:media mustExist:YES] ? YES : NO;
}

-(NSData *)downloadResumeDataForMedia:(NSDictionary *)media {
    return self.resumeData[media[@"id"]];
}

#pragma mark - NSURLSessionDelegate

-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"URLSessionDidFinishEventsForBackgroundURLSession entry");
    if (self.backgroundCompletionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"URLSessionDidFinishEventsForBackgroundURLSession calling backgroundCompletionHandler");
            self.backgroundCompletionHandler();
        });
    }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSDictionary *media = [self downloadingMetadataForMediaId:downloadTask.taskDescription];

    [self clearDownloadingMetadataForMedia:media];
    [self clearDownloadProgressForMedia:media];
    [self clearDownloadIsLocalForMedia:media];
    [self.resumeData removeObjectForKey:media[@"id"]];
    [self.bytesForMedia removeObjectForKey:media[@"id"]];

    [self moveDownload:location forMedia:media];
}

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSDictionary *media = [self downloadingMetadataForMediaId:downloadTask.taskDescription];
    if (totalBytesExpectedToWrite == -1 && self.bytesForMedia[media[@"id"]]) {
        totalBytesExpectedToWrite = [self.bytesForMedia[media[@"id"]] longLongValue];
    }
    else {
        self.bytesForMedia[media[@"id"]] = @(totalBytesExpectedToWrite);
    }

    float percent = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    [self saveDownloadProgressForMedia:media percent:percent];
    [[NSNotificationCenter defaultCenter] postNotificationName:PMCBackgroundDownloadDidProgress object:self userInfo:@{@"media":media, @"percent":@(percent)}];
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!error) {
        return;
    }

    NSDictionary *media = [self downloadingMetadataForMediaId:task.taskDescription];

    NSData *resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
    if (resumeData) {
        self.resumeData[media[@"id"]] = resumeData;
    }
    else {
        [self clearDownloadIsLocalForMedia:media];
    }

    [self clearDownloadingMetadataForMedia:media];
    [self clearDownloadProgressForMedia:media];
    [self saveDownloadErrorForMedia:media error:error];

    [[NSNotificationCenter defaultCenter] postNotificationName:PMCBackgroundDownloadDidFail object:self userInfo:@{@"media":media, @"error":error}];
}

@end
