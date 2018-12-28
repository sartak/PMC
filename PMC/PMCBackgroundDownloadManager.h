@interface PMCBackgroundDownloadManager : NSObject

extern NSString * const PMCBackgroundDownloadDidBegin;
extern NSString * const PMCBackgroundDownloadDidProgress;
extern NSString * const PMCBackgroundDownloadDidComplete;
extern NSString * const PMCBackgroundDownloadDidFail;
extern NSString * const PMCBackgroundDownloadErrorDidClear;

@property (nonatomic, strong) void (^backgroundCompletionHandler)(void);

+(instancetype)sharedClient;

-(void)downloadMedia:(NSDictionary *)media usingAction:(NSDictionary *)action;
-(void)cancelMediaDownload:(NSDictionary *)media;
-(void)deleteDownloadedMedia:(NSDictionary *)media;

-(BOOL)mediaIsDownloaded:(NSDictionary *)media;
-(BOOL)mediaIsDownloading:(NSDictionary *)media;
-(NSNumber *)downloadProgressForMedia:(NSDictionary *)media;

-(NSString *)downloadErrorForMedia:(NSDictionary *)media;
-(void)clearDownloadErrorForMedia:(NSDictionary *)media;
-(NSData *)downloadResumeDataForMedia:(NSDictionary *)media;

-(NSURL *)URLForDownloadedMedia:(NSDictionary *)media mustExist:(BOOL)mustExist;
-(void)takeUpdatesToMetadataForMedia:(NSDictionary *)media;
-(void)didSendCompletedViewingForMediaId:(NSString *)mediaId;

-(void)persistDownloadedMedia:(NSDictionary *)media;
-(BOOL)downloadedMediaIsPersisted:(NSDictionary *)media;

-(unsigned long long)appDiskSpace;
-(unsigned long long)freeDiskSpace;

-(NSArray<NSDictionary *> *)downloadedMedia;
-(NSArray<NSDictionary *> *)downloadingMedia;
-(NSArray<NSDictionary *> *)failedDownloadMedia;

@end
