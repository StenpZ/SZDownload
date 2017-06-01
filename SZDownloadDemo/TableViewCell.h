
#import <UIKit/UIKit.h>

@interface TableViewCell : UITableViewCell

@property(nonatomic, strong) UIImageView *avatar;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIProgressView *progressView;
@property(nonatomic, strong) UILabel *progressLabel;
@property(nonatomic, strong) UILabel *speedLabel;
@property(nonatomic, strong) UIButton *operationButton;

@property(nonatomic, copy) NSString *url;

@end
