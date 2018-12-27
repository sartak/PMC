@interface PMCQueueViewController : UITableViewController

extern NSString * const PMCQueueDidChangeNotification;
extern NSString * const PMCQueueCurrentDidChangeNotification;

-(BOOL)isPlayingMedia:(NSDictionary *)media;
-(BOOL)hasQueuedMedia:(NSDictionary *)media;
-(NSDictionary *)currentMedia;

@end
