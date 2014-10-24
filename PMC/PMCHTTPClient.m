#import "PMCHTTPClient.h"

@interface PMCHTTPClient ()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation PMCHTTPClient

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

-(NSString *)username {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PMC_USERNAME"];
}

-(NSString *)password {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PMC_PASSWORD"];
}

-(NSString *)host {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PMC_HOST"];
}

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint completion:(void (^)(NSError *error))completion {
    [self sendMethod:method toEndpoint:endpoint withParams:nil completion:completion];
}

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(NSError *error))completion {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [self host], endpoint]];

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

    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    }];
    [task resume];
}

-(void)jsonFrom:(NSString *)endpoint completion:(void (^)(id json, NSError *error))completion {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [self host], endpoint]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:[self username] forHTTPHeaderField:@"X-PMC-Username"];
    [request addValue:[self password] forHTTPHeaderField:@"X-PMC-Password"];
    request.HTTPMethod = @"GET";

    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(json, error);
            });
        }
    }];
    [task resume];
}

@end
