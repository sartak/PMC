@interface PMCDownloadManager : NSObject

+(NSArray *)downloadedMedia;
+(NSURL *)URLForDownloadedMedia:(NSDictionary *)media mustExist:(BOOL)mustExist;
+(void)deleteDownloadedMedia:(NSDictionary *)media;

+(NSDictionary *)metadataForDownloadedMedia:(NSString *)mediaId;
+(void)saveMetadataForDownloadedMedia:(NSDictionary *)media;
+(void)updateMetadataForMedia:(NSDictionary *)media;
+(unsigned long long)appDiskSpace;
+(unsigned long long)freeDiskSpace;

+(NSArray *)downloadingMedia;

+(NSArray *)failedDownloadMedia;
+(void)clearFailedDownloadForMedia:(NSDictionary *)media;
+(void)downloadFailedForMedia:(NSDictionary *)media withReason:(NSString *)reason;
+(NSString *)reasonForFailedDownloadOfMedia:(NSDictionary *)media;

+(void)persistDownloadedMedia:(NSDictionary *)media;
+(BOOL)downloadedMediaIsPersisted:(NSDictionary *)media;

@end
