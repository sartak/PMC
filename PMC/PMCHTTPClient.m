#import "PMCHTTPClient.h"

NSString * const PMCHostDidChangeNotification = @"PMCHostDidChangeNotification";
NSString * const PMCConnectedStatusNotification = @"PMCConnectedStatusNotification";
NSString * const PMCPauseStatusNotification = @"PMCPauseStatusNotification";
NSString * const PMCVolumeStatusNotification = @"PMCVolumeStatusNotification";
NSString * const PMCInputStatusNotification = @"PMCInputStatusNotification";
NSString * const PMCTVPowerStatusNotification = @"PMCTVPowerStatusNotification";
NSString * const PMCMediaStartedNotification = @"PMCMediaStartedNotification";
NSString * const PMCMediaFinishedNotification = @"PMCMediaFinishedNotification";

@interface PMCHTTPClient () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLConnection *statusConnection;
@property (nonatomic, strong) NSData *statusBuffer;
@property (nonatomic) int statusBackoffExponent;
@property (nonatomic, strong) NSTimer *resubscribeTimer;

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
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        self.session = session;
    }
    return self;
}

+(NSArray *)locations {
    return @[
             @{@"label": @"Living Room", @"host": @"http://pmc.sartak.org" },
             @{@"label": @"Bedroom", @"host": @"http://pmc2.sartak.org" },
             @{@"label": @"BPS", @"host": @"http://bloc.local:5000" },
             ];
}

-(NSString *)username {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PMC_USERNAME"];
}

-(NSString *)password {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PMC_PASSWORD"];
}

-(NSDictionary *)currentLocation {
    if (!_currentLocation) {
        [self setCurrentLocation:[[self class] locations][0]];
    }
    return _currentLocation;
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

    _currentLocation = currentLocation;
    [[NSNotificationCenter defaultCenter] postNotificationName:PMCHostDidChangeNotification object:self userInfo:@{@"new":currentLocation}];
    [self resubscribeToStatus];
}

-(NSString *)host {
    return self.currentLocation[@"host"];
}

-(NSMutableURLRequest *)requestWithEndpoint:(NSString *)endpoint method:(NSString *)method {
    NSURL *url = [NSURL URLWithString:endpoint relativeToURL:[NSURL URLWithString:[self host]]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:[self username] forHTTPHeaderField:@"X-PMC-Username"];
    [request addValue:[self password] forHTTPHeaderField:@"X-PMC-Password"];
    request.HTTPMethod = method;
    return request;
}

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint completion:(void (^)(NSError *error))completion {
    [self sendMethod:method toEndpoint:endpoint withParams:nil completion:completion];
}

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(NSError *error))completion {
    NSMutableURLRequest *request = [self requestWithEndpoint:endpoint method:method];

    if (params) {
        NSMutableArray *parts = [NSMutableArray array];
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            [parts addObject:[NSString stringWithFormat:@"%@=%@",
                              [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                              [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        }];

        NSString *body = [parts componentsJoinedByString:@"&"];
        request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    }

    NSLog(@"%@ %@", request.HTTPMethod, request.URL);

    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    }];
    [task resume];
}

-(void)jsonFrom:(NSString *)endpoint completion:(void (^)(id json, NSError *error))completion {
    NSMutableURLRequest *request = [self requestWithEndpoint:endpoint method:@"GET"];

    NSLog(@"%@ %@", request.HTTPMethod, request.URL);

    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
        }

        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(json, error);
            });
        }
    }];
    [task resume];
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
    NSLog(@"didFail");
}

-(void)unsubscribeToStatus {
    [self.resubscribeTimer invalidate];
    self.resubscribeTimer = nil;

    [self.statusConnection cancel];
    self.statusConnection = nil;
}

-(void)resubscribeToStatus {
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
    if ([event[@"type"] isEqualToString:@"paused"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PMCPauseStatusNotification object:self userInfo:@{@"isPaused":event[@"paused"]}];
    }
    else {
        NSLog(@"%@", event);
    }
}

-(void)subscribeToStatus {
    if (self.statusConnection) {
        return;
    }

    self.statusBuffer = [NSData data];

    NSMutableURLRequest *request = [self requestWithEndpoint:@"/status" method:@"GET"];
    NSLog(@"%@ %@", request.HTTPMethod, request.URL);
    NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
    self.statusConnection = connection;
}

@end
