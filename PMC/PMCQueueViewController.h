@interface PMCQueueViewController : UITableViewController

extern NSString * const PMCQueueDidChangeNotification;

-(BOOL)isPlayingMedia:(NSDictionary *)media;
-(BOOL)hasQueuedMedia:(NSDictionary *)media;

@end
