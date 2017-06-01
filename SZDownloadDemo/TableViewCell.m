
#import "TableViewCell.h"
#import "SZDownload.h"
#import "WHC_AutoLayout.h"

#define kMargin 15.f

@implementation TableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.numberOfLines = 0;
        [self.contentView addSubview:self.titleLabel];
        self.titleLabel.whc_LeftSpace(kMargin).whc_RightSpace(kMargin).whc_TopSpace(kMargin);
        
        self.progressView = [[UIProgressView alloc] init];
        [self.contentView addSubview:self.progressView];
        self.progressView.whc_LeftSpace(kMargin).whc_RightSpace(120).whc_TopSpaceToView(kMargin, self.titleLabel).whc_Height(kMargin);
        
        self.progressLabel = [[UILabel alloc] init];
        [self.contentView addSubview:self.progressLabel];
        self.progressLabel.whc_LeftSpace(kMargin).whc_TopSpaceToView(kMargin, self.progressView);
        
        self.speedLabel = [[UILabel alloc] init];
        [self.contentView addSubview:self.speedLabel];
        self.speedLabel.whc_LeftSpaceToView(kMargin, self.progressLabel).whc_TopSpaceEqualView(self.progressLabel);
        
        self.operationButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.operationButton setTitle:@"download" forState:UIControlStateNormal];
        [self.operationButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [self.contentView addSubview:self.operationButton];
        self.operationButton.whc_LeftSpaceToView(kMargin, self.progressView).whc_RightSpace(-kMargin).whc_TopSpaceEqualView(self.progressView).whc_Height(30.f);
        [self.operationButton addTarget:self action:@selector(downloadAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)setUrl:(NSString *)url {
    self.titleLabel.text = url;
    _url = url;
    SZDownloadInfo *info = [[SZDownloadManager defaultManager] downloadInfoForURL:_url];
    switch (info.state) {
        case SZDownloadStateNone:
            if (info.totalBytesWritten) {
                self.progressView.hidden = self.progressLabel.hidden = self.speedLabel.hidden = false;
                [self.operationButton setTitle:@"restart" forState:UIControlStateNormal];
            } else {
                self.progressView.hidden = self.progressLabel.hidden = self.speedLabel.hidden = true;
                [self.operationButton setTitle:@"download" forState:UIControlStateNormal];
            }
            break;
        case SZDownloadStateResumed:
            self.progressView.hidden = self.progressLabel.hidden = self.speedLabel.hidden = false;
            [self.operationButton setTitle:@"pause" forState:UIControlStateNormal];
            break;
        case SZDownloadStateSuspened:
            self.progressView.hidden = self.progressLabel.hidden = self.speedLabel.hidden = false;
            [self.operationButton setTitle:@"restart" forState:UIControlStateNormal];
            break;
        case SZDownloadStateCompleted:
            self.progressView.hidden = self.progressLabel.hidden = self.speedLabel.hidden = true;
            [self.operationButton setTitle:@"open" forState:UIControlStateNormal];
            break;
        case SZDownloadStateWillResume:
            self.progressView.hidden = self.progressLabel.hidden = self.speedLabel.hidden = false;
            [self.operationButton setTitle:@"wait" forState:UIControlStateNormal];
            break;
        default:
            break;
    }
    float progress = info.totalBytesExpectedToWrite ? (float)info.totalBytesWritten/(float)info.totalBytesExpectedToWrite: 0.f;
    self.progressView.progress = progress;
    self.progressLabel.text = [NSString stringWithFormat:@"下载进度：%.2lf %%", progress * 100];
    self.speedLabel.text = [NSString stringWithFormat:@"%.2lf kb/s", (float)info.bytesWritten/1024];
}


- (void)downloadAction {
    SZDownloadManager *manager = [SZDownloadManager defaultManager];
    SZDownloadInfo *info = [manager downloadInfoForURL:self.url];
    switch (info.state) {
        case SZDownloadStateNone:
        {
            [manager download:self.url progress:^(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite) {
                self.url = self.url;
            } state:^(SZDownloadState state, NSString *filePath, NSError *error) {
                self.url = self.url;
            }];
        }break;
            
        case SZDownloadStateResumed:
        {
            [manager suspend:self.url];
        }break;
            
        case SZDownloadStateSuspened:
        {
            [manager resume:self.url];
        }break;
            
        case SZDownloadStateCompleted:
        {
            NSLog(@"打开文件！！！ %@", info.filePath);
        }break;
            
        case SZDownloadStateWillResume:
        {
            [manager cancel:self.url];
        }break;
            
        default:
            break;
    }
}

@end
