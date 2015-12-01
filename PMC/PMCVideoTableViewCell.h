#import "PMCMediaCell.h"

@interface PMCVideoTableViewCell : UITableViewCell <PMCMediaCell>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *identifierLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UIImageView *immersionIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *enqueuedIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *playingIndicator;

@end
