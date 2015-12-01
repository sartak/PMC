@interface PMCHTTPClient : NSObject

extern NSString * const PMCHostDidChangeNotification;
extern NSString * const PMCConnectedStatusNotification;
extern NSString * const PMCPauseStatusNotification;
extern NSString * const PMCFastForwardStatusNotification;
extern NSString * const PMCVolumeStatusNotification;
extern NSString * const PMCTVPowerStatusNotification;
extern NSString * const PMCInputStatusNotification;
extern NSString * const PMCMediaStartedNotification;
extern NSString * const PMCMediaFinishedNotification;
extern NSString * const PMCQueueChangeNotification;

@property (nonatomic, strong) NSDictionary *currentLocation;

+(instancetype)sharedClient;

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint completion:(void (^)(NSError *error))completion;
-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(NSError *error))completion;
-(void)jsonFrom:(NSString *)endpoint completion:(void (^)(id json, NSError *error))completion;

+(NSArray *)locations;
-(void)subscribeToStatus;

-(NSString *)username;
-(NSString *)password;
-(NSString *)host;

@end
