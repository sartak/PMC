@interface PMCHTTPClient : NSObject

extern NSString * const PMCHostDidChangeNotification;
extern NSString * const PMCPauseStatusNotification;

@property (nonatomic, strong) NSDictionary *currentLocation;

+(instancetype)sharedClient;

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint completion:(void (^)(NSError *error))completion;
-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(NSError *error))completion;
-(void)jsonFrom:(NSString *)endpoint completion:(void (^)(id json, NSError *error))completion;

+(NSArray *)locations;
-(void)subscribeToStatus;

@end
