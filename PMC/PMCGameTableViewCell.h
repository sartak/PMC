#import "PMCMediaCell.h"

@interface PMCGameTableViewCell : UITableViewCell <PMCMediaCell>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *identifierLabel;
@property (weak, nonatomic) IBOutlet UILabel *playtimeLabel;
@property (weak, nonatomic) IBOutlet UIImageView *enqueuedIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *playingIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *uploadIndicator;

@end
