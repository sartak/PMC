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
extern NSString * const PMCAudioDidChangeNotification;

@property (nonatomic, strong) NSDictionary *currentLocation;
@property (nonatomic, strong) NSMutableDictionary *currentlyDownloading;

+(instancetype)sharedClient;

-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion;
-(void)sendMethod:(NSString *)method toEndpoint:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion;
-(void)jsonFrom:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(id json, NSError *error))completion;
-(void)mediaFrom:(NSString *)endpoint withParams:(NSDictionary *)params completion:(void (^)(NSArray *records, NSError *error))completion;

-(NSURLSessionDownloadTask *)downloadMedia:(NSDictionary *)media withAction:(NSDictionary *)action progress:(void (^)(float progress))progress completion:(void (^)(NSURL *location, NSError *error))completion;

-(void)sendViewing:(NSDictionary *)viewing completion:(void (^)(NSError *))completion;
-(void)sendViewingWithRetries:(NSDictionary *)viewing completion:(void (^)(NSError *error))completion;
-(BOOL)hasSavedOrProvisionalViewingForMedia:(NSDictionary *)media;
-(NSDictionary *)latestSavedViewingForMedia:(NSDictionary *)media;

-(void)setProvisionalViewing:(NSDictionary *)viewing;

+(NSArray *)locations;
-(void)subscribeToStatus;

+(NSString *)username;
+(NSString *)password;
+(NSString *)device;
+(NSString *)networkSSID;
-(NSString *)host;

@end
