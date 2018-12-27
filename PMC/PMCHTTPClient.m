#import "PMCHTTPClient.h"
#import "PMCDownloadManager.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
@import SystemConfiguration.CaptiveNetwork;

NSString * const PMCHostDidChangeNotification = @"PMCHostDidChangeNotification";
NSString * const PMCConnectedStatusNotification = @"PMCConnectedStatusNotification";
NSString * const PMCPauseStatusNotification = @"PMCPauseStatusNotification";
NSString * const PMCFastForwardStatusNotification = @"PMCFastForwardStatusNotification";
NSString * const PMCVolumeStatusNotification = @"PMCVolumeStatusNotification";
NSString * const PMCInputStatusNotification = @"PMCInputStatusNotification";
NSString * const PMCTVPowerStatusNotification = @"PMCTVPowerStatusNotification";
NSString * const PMCMediaStartedNotification = @"PMCMediaStartedNotification";
NSString * const PMCMediaFinishedNotification = @"PMCMediaFinishedNotification";
NSString * const PMCQueueChangeNotification = @"PMCQueueChangeNotification";
NSString * const PMCAudioDidChangeNotification = @"PMCAudioDidChangeNotification";

@interface PMCHTTPClient () <NSURLConnectionDataDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLConnection *statusConnection;
@property (nonatomic, strong) NSData *statusBuffer;
@property (nonatomic) int statusBackoffExponent;
@property (nonatomic, strong) NSTimer *resubscribeTimer;
@property (nonatomic, strong) NSMapTable *taskInfo;

@end

@implementation PMCHTTPClient

@synthesize currentLocation = _currentLocation;

+(instancetype)sharedClient {
    static dispatch_once_t onceToken;
    static PMCHTTPClient *sharedClient;
    dispatch_once(&onceToken, ^{
        sharedClient = [[PMCHTTPClient alloc] init];
    });
    return sharedClient;
}

-(instancetype)init {
    if (self = [super init]) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        self.session = session;

        self.currentlyDownloading = [NSMutableDictionary dictionary];

        self.taskInfo = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory valueOptions:NSMapTableStrongMemory];

        [NSNotificationCenter.defaultCenter addObserverForName:CTRadioAccessTechnologyDidChangeNotification
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:^(NSNotification *note) {
                                                        NSLog(@"radio changed: %@", note.userInfo);
                                                        self.statusBackoffExponent = 0;
                                                        [self resubscribeToStatus];
                                                    }];

        [self convertProvisionalViewing];

        [self subscribeToStatus];
    }
    return self;
}

+(NSArray *)locations {
#if 0
        return @[@{@"label": @"Library", @"host": @"http://atwood.local:5000", @"id":@"atwood" }];
#elif 0
        return @[@{@"label": @"Library", @"host": @"http://hampshire.local:5000", @"id":@"hampshire" }];
#else
    NSArray *locations;

    NSString *network = [self networkSSID];


    if ([network isEqualToString:@"Dexter"]) {
        locations = @[
                 @{@"label": @"Office", @"host": @"http://junction.local:5000", @"id":@"junction" },
                 //@{@"label": @"Bedroom", @"host": @"http://tleilax.local:5000", @"id":@"tleilax" },
                 ];
    }
    else {
        locations = @[
                 @{@"label": @"Office", @"host": @"https://pmc.sartak.org", @"id":@"junction" },
              //   @{@"label": @"Bedroom", @"host": @"https://pmc2.sartak.org", @"id":@"tleilax" },
                 ];
    }

    return locations;
#endif
}

+(NSString *)username {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PMC_USERNAME"];
}

+(NSString *)password {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PMC_PASSWORD"];
}

+(NSString *)device {
    return [[UIDevice currentDevice] name];
}

+(NSString *)networkSSID {
    NSArray *interfaceNames = CFBridgingRelease(CNCopySupportedInterfaces());

    NSDictionary *SSIDInfo;
    for (NSString *interfaceName in interfaceNames) {
        SSIDInfo = CFBridgingRelease(
                                     CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName));

        BOOL isNotEmpty = (SSIDInfo.count > 0);
        if (isNotEmpty) {
            break;
        }
    }

    return SSIDInfo[@"SSID"];
}

-(NSDictionary *)currentLocation {
    // radio change means we might go from internet -> LAN
    NSDictionary *match;
    for (NSDictionary *location in [[self class] locations]) {
        // got the same host, we're still connected to the same network
        if ([_currentLocation[@"host"] isEqualToString:location[@"host"]]) {
            return _currentLocation;
        }
        // different host but same id means we should switch to this one
        else if ([_currentLocation[@"id"] isEqualToString:location[@"id"]]) {
            match = location;
        }
    }

    if (match) {
        // we didn't match on host but we matched on id so update _currentLocation
        [self setCurrentLocation:match];
        return match;
    }
    else {
        // no match, perhaps _currentLocation is empty, so just grab the first location
        [self setCurrentLocation:[[self class] locations][0]];
        return _currentLocation;
    }
}

-(void)setCurrentLocation:(NSDictionary *)currentLocation {
    // init
    if (!_currentLocation) {
        _currentLocation = currentLocation;
        return;
    }

    if ([_currentLocation[@"host"] isEqualToString:currentLocation[@"host"]]) {
        return;
    }

    [self unsubscribeToStatus];

    NSDictionary *old = _currentLocation;
    _currentLocation = currentLocation;
    [[NSNotificationCenter defaultCenter] postNotificationName:PMCHostDidChangeNotification object:self userInfo:@{@"new":currentLocation, @"old":old}];
    [self resubscribeToStatus];
}

-(NSString *)host {
    return self.currentLocation[@"host"];
}

-(NSMutableURLRequest *)requestWithEndpoint:(NSString *)endpoint method:(NSString *)method {
    NSURL *url = [NSURL URLWithString:[[self host] stringByAppendingString:endpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setAllowsCellularAccess:YES];
    [request addValue:[[self class] username] forHTTPHeaderField:@"X-PMC-Username"];
    [request addValue:[[self class] password] forHTTPHeaderField:@"X-PMC-Password"];
    request.HTTPMethod = method;
    return request;
}

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion {
    [self sendMethod:method toEndpoint:endpoint withParams:nil completion:completion];
}

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion {
    NSMutableURLRequest *request = [self requestWithEndpoint:endpoint method:method];

    if (params) {
        NSMutableArray *parts = [NSMutableArray array];
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            [parts addObject:[NSString stringWithFormat:@"%@=%@",
                              [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                              [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        }];

        NSString *query = [parts componentsJoinedByString:@"&"];
        NSString *joiner = @"?";
        if ([[request.URL description] containsString:@"?"]) {
            joiner = @"&";
        }
        request.URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", request.URL, joiner, query]];
    }

    NSLog(@"%@ %@", request.HTTPMethod, request.URL);

    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(data, response, error);
            });
        }
    }];
    [task resume];
}

-(void)jsonFrom:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(id json, NSError *error))completion {
    [self sendMethod:@"GET" toEndpoint:endpoint withParams:params completion:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(json, error);
            });
        }

    }];
}

-(void)mediaFrom:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(NSArray *records, NSError *error))completion {
    [self jsonFrom:endpoint withParams:params completion:^(NSArray *records, NSError *error) {
        for (NSDictionary *record in records) {
            if ([record[@"type"] isEqualToString:@"tree"]) {
                continue;
            }
            [PMCDownloadManager updateMetadataForMedia:record];
        }
        completion(records, error);
    }];
}

-(NSURLSessionDownloadTask *)beginDownload:(NSString *)endpoint forMedia:(NSDictionary *)media progress:(void (^)(float progress))progress completion:(void (^)(NSURL *location, NSError *error))completion {
    NSMutableURLRequest *request = [self requestWithEndpoint:endpoint method:@"GET"];
    NSLog(@"%@ %@", request.HTTPMethod, request.URL);

    NSDictionary *taskInfo = @{
                               @"completion":completion,
                               @"progress":progress,
                               @"media":media,
                               };
    NSURLSessionDownloadTask *download = [self.session downloadTaskWithRequest:request];
    [self.taskInfo setObject:taskInfo forKey:download];
    [download resume];
    return download;
}

-(NSURLSessionDownloadTask *)downloadMedia:(NSDictionary *)media withAction:(NSDictionary *)action progress:(void (^)(float progress))progress completion:(void (^)(NSURL *location, NSError *error))completion {
    return [self beginDownload:action[@"url"] forMedia:media progress:progress completion:^(NSURL *location, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
            [PMCDownloadManager downloadFailedForMedia:media withReason:error.localizedDescription];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }
            return;
        }

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
        NSURL *subdirURL = [documentsURL URLByAppendingPathComponent:@"downloaded"];

        NSURL *fileURL = [PMCDownloadManager URLForDownloadedMedia:media mustExist:NO];

        if (![fileManager fileExistsAtPath:subdirURL.path]) {
            NSError *error;
            [fileManager createDirectoryAtPath:subdirURL.path
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&error];
            if (error) {
                NSLog(@"error creating %@: %@", subdirURL.path, error);
                [PMCDownloadManager downloadFailedForMedia:media withReason:error.localizedDescription];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil, error);
                    });
                }
                return;
            }
        }

        NSError *moveError;
        if (![fileManager moveItemAtURL:location toURL:fileURL error:&moveError]) {
            NSLog(@"%@", moveError);
            [PMCDownloadManager downloadFailedForMedia:media withReason:moveError.localizedDescription];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, moveError);
                });
            }
            return;
        }
        
        NSError *attrError;
        BOOL success = [fileURL setResourceValue:[NSNumber numberWithBool: YES]
                                          forKey:NSURLIsExcludedFromBackupKey error:&attrError];
        if (!success) {
            NSLog(@"%@", attrError);
            [PMCDownloadManager downloadFailedForMedia:media withReason:attrError.localizedDescription];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, attrError);
                });
            }
            return;
        }

        [PMCDownloadManager clearFailedDownloadForMedia:media];

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(fileURL, nil);
            });
        }
    }];
}

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    float percent = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;

    NSDictionary *taskInfo = [self.taskInfo objectForKey:downloadTask];
    if (taskInfo && taskInfo[@"progress"]) {
        void (^progress)(float progress) = taskInfo[@"progress"];
        progress(percent);
    }
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!error) {
        return;
    }
    
    NSLog(@"didCompleteWithError");
    NSDictionary *taskInfo = [self.taskInfo objectForKey:task];
    if (taskInfo) {
        if (taskInfo[@"completion"]) {
            void (^completion)(NSURL *location, NSError *error) = taskInfo[@"completion"];
            completion(nil, error);
        }
        if (taskInfo[@"media"]) {
            [PMCDownloadManager downloadFailedForMedia:taskInfo[@"media"] withReason:error.localizedDescription];
        }
    }
}

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSLog(@"done downloading to %@", location);

    NSDictionary *taskInfo = [self.taskInfo objectForKey:downloadTask];
    if (taskInfo && taskInfo[@"completion"]) {
        void (^completion)(NSURL *location, NSError *error) = taskInfo[@"completion"];
        completion(location, nil);
    }
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    // we've bailed out
    if (!self.statusConnection) {
        return;
    }

    NSMutableData *buffer = [self.statusBuffer mutableCopy];
    [buffer appendData:data];

    while (1) {
        NSRange range = [buffer rangeOfData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0, buffer.length)];

        // no newline yet. bail
        if (range.location == NSNotFound) {
            self.statusBuffer = [buffer copy];
            return;
        }

        // pull off the first line of json
        NSData *chunk = [buffer subdataWithRange:NSMakeRange(0, range.location)];
        self.statusBuffer = [buffer subdataWithRange:NSMakeRange(range.location+1, buffer.length - range.location - 1)];
        buffer = [self.statusBuffer mutableCopy];

        id json = [NSJSONSerialization JSONObjectWithData:chunk options:0 error:nil];

        if (json) {
            self.statusBackoffExponent = 0;
            [self handleStatusJson:json];
        }
        else {
            NSLog(@"got invalid json chunk: <%@>", [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding]);
        }

        // there was a newline. so repeat, since we might have gotten multiple lines of complete json
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"didFail: %@", error);
    [self resubscribeToStatus];
}

-(void)unsubscribeToStatus {
    NSLog(@"unsubscribe");

    [self.resubscribeTimer invalidate];
    self.resubscribeTimer = nil;

    [self.statusConnection cancel];
    self.statusConnection = nil;
}

-(void)resubscribeToStatus {
    NSLog(@"resubscribe");

    [self.statusConnection cancel];
    self.statusConnection = nil;

    if (self.statusBackoffExponent == 0) {
        self.statusBackoffExponent++;
        [self subscribeToStatus];
        return;
    }

    if (self.statusBackoffExponent < 10) {
        self.statusBackoffExponent++;
    }

    self.resubscribeTimer = [NSTimer scheduledTimerWithTimeInterval:pow(1.5, self.statusBackoffExponent) target:self selector:@selector(subscribeToStatus) userInfo:nil repeats:NO];
}

// this happens before the didReceiveData callback, which means we don't try to parse the proxy's 502
// html page as JSON
-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
    if (response.statusCode != 200) {
        [self resubscribeToStatus];
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self resubscribeToStatus];
}

-(void)handleStatusJson:(NSDictionary *)event {
    NSString *type = event[@"type"];
    NSLog(@"event:%@", type);

    if ([type isEqualToString:@"playpause"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCPauseStatusNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"fastforward"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCFastForwardStatusNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"finished"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCMediaFinishedNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"started"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCMediaStartedNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"television/volume"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCVolumeStatusNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"television/input"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCInputStatusNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"television/power"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCTVPowerStatusNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"queue"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCQueueChangeNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"connected"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCConnectedStatusNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"audio"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCAudioDidChangeNotification object:self userInfo:event];
    }
    else if ([type isEqualToString:@"subscriber"]) {
        // ignore. I'm self-centered
    }
    else {
        NSLog(@"unhandled event: %@", event);
    }
}

-(void)subscribeToStatus {
    NSLog(@"subscribe");
    if (self.statusConnection) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusBuffer = [NSData data];

        NSMutableURLRequest *request = [self requestWithEndpoint:@"/status" method:@"GET"];
        NSLog(@"%@ %@", request.HTTPMethod, request.URL);
        NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
        self.statusConnection = connection;

        [self flushSavedViewings];
    });
}

-(void)setProvisionalViewing:(NSDictionary *)viewing {
    [[NSUserDefaults standardUserDefaults] setObject:viewing forKey:@"provisionalViewing"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSDictionary *)provisionalViewing {
    return [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"provisionalViewing"];
}

-(void)convertProvisionalViewing {
    NSDictionary *viewing = [self provisionalViewing];
    if (viewing) {
        NSLog(@"converting provisional viewing");
        [self saveViewingForRetry:viewing];
        [self setProvisionalViewing:nil];
    }
}

-(NSArray *)savedViewings {
    NSArray *viewings = [[NSUserDefaults standardUserDefaults] arrayForKey:@"viewing"];
    if (!viewings) {
        return [NSArray array];
    }
    return viewings;
}

-(BOOL)hasSavedOrProvisionalViewingForMedia:(NSDictionary *)media {
    if ([[self provisionalViewing][@"mediaId"] intValue] == [media[@"id"] intValue]) {
        return YES;
    }
    return [self latestSavedViewingForMedia:media] ? YES : NO;
}

-(void)setSavedViewings:(NSArray *)viewings {
    [[NSUserDefaults standardUserDefaults] setObject:viewings forKey:@"viewing"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSDictionary *)latestSavedViewingForMedia:(NSDictionary *)media {
    NSArray *viewings = [self savedViewings];
    NSDictionary *latest = nil;
    for (NSDictionary *viewing in viewings) {
        if ([viewing[@"mediaId"] intValue] == [media[@"id"] intValue]) {
            latest = viewing;
        }
    }
    return latest;
}

-(void)saveViewingForRetry:(NSDictionary *)viewing {
    NSMutableArray *viewings = [[self savedViewings] mutableCopy];
    [viewings addObject:viewing];
    [self setSavedViewings:viewings];
}

-(void)flushSavedViewings {
    NSArray *viewings = [self savedViewings];
    if (viewings.count) {
        NSDictionary *viewing = viewings[0];
        [self sendViewing:viewing completion:^(NSError *error) {
            if (!error) {
                NSMutableArray *newViewings = [[self savedViewings] mutableCopy];
                [newViewings removeObjectIdenticalTo:viewing];
                [self setSavedViewings:newViewings];
                [self flushSavedViewings];
            }
        }];
    }
}

-(void)sendViewing:(NSDictionary *)viewing completion:(void (^)(NSError *))completion {
    [self sendMethod:@"PUT" toEndpoint:@"/library/viewed" withParams:viewing completion:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (completion) {
            completion(error);
        }

        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
            if (headers[@"X-PMC-Completed"] && [headers[@"X-PMC-Completed"] boolValue]) {
                NSDictionary *media = [PMCDownloadManager metadataForDownloadedMedia:viewing[@"mediaId"]];
                if (media && ![PMCDownloadManager downloadedMediaIsPersisted:media]) {
                    [PMCDownloadManager deleteDownloadedMedia:media];
                }
            }
        }
    }];
}

-(void)sendViewingWithRetries:(NSDictionary *)viewing completion:(void (^)(NSError *error))completion {
    [self sendViewing:viewing completion:^(NSError *error) {
        if (error) {
            [self saveViewingForRetry:viewing];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    }];
}

@end
