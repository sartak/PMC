@interface PMCLibraryViewController : UITableViewController

extern NSString * const PMCLanguageDidChangeNotification;

-(instancetype)initWithRequestPath:(NSString *)requestPath forRecord:(NSDictionary *)record;

@end
