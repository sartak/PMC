#import "PMCHTTPClient.h"

NSString * const PMCHostDidChangeNotification = @"PMCHostDidChangeNotification";

@interface PMCHTTPClient ()

@property (nonatomic, strong) NSURLSession *session;

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
    if ([_currentLocation[@"host"] isEqualToString:currentLocation[@"host"]]) {
        return;
    }

    _currentLocation = currentLocation;
    [[NSNotificationCenter defaultCenter] postNotificationName:PMCHostDidChangeNotification object:self userInfo:@{@"new":currentLocation}];
}

-(NSString *)host {
    return self.currentLocation[@"host"];
}

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint completion:(void (^)(NSError *error))completion {
    [self sendMethod:method toEndpoint:endpoint withParams:nil completion:completion];
}

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(NSError *error))completion {
    NSURL *url = [NSURL URLWithString:endpoint relativeToURL:[NSURL URLWithString:[self host]]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:[self username] forHTTPHeaderField:@"X-PMC-Username"];
    [request addValue:[self password] forHTTPHeaderField:@"X-PMC-Password"];
    request.HTTPMethod = method;

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
    NSURL *url = [NSURL URLWithString:endpoint relativeToURL:[NSURL URLWithString:[self host]]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:[self username] forHTTPHeaderField:@"X-PMC-Username"];
    [request addValue:[self password] forHTTPHeaderField:@"X-PMC-Password"];
    request.HTTPMethod = @"GET";

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

-(NSURLSessionDataTask *)streamJsonFrom:(NSString *)endpoint chunk:(void (^)(id json, NSError *error))chunk completion:(void (^)(NSError *error))completion {
    NSURL *url = [NSURL URLWithString:endpoint relativeToURL:[NSURL URLWithString:[self host]]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:[self username] forHTTPHeaderField:@"X-PMC-Username"];
    [request addValue:[self password] forHTTPHeaderField:@"X-PMC-Password"];
    request.HTTPMethod = @"GET";

    NSLog(@"%@ %@", request.HTTPMethod, request.URL);

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
        }

//        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    }];

    [task resume];

    NSLog(@"%@", task);

    return task;
}

@end
