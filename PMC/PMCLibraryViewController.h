#import "PMCQueueViewController.h"

@interface PMCLibraryViewController : UITableViewController

extern NSString * const PMCLanguageDidChangeNotification;

-(instancetype)initWithRequestPath:(NSString *)requestPath forRecord:(NSDictionary *)record withQueue:(PMCQueueViewController *)queue;

-(void)refreshRecordsAnimated:(BOOL)animated;

@end
