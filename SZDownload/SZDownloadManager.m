
#import "SZDownloadManager.h"
#import "NSString+SZDownload.h"
#import "SZDownloadConst.h"

#pragma mark - 默认设置
/** 存放所有的文件大小 */
static NSMutableDictionary *_totalFileSizes;
/** 存放所有的文件大小的文件路径 */
static NSString *_totalFileSizesFile;

/** 根文件夹 */
static NSString *const SZDownloadRootDir = @"SZDownload";

/** 默认manager的标识 */
static NSString *const SZDowndloadManagerDefaultIdentifier = @"com.star.stenpZ.downloadManager";


@interface SZDownloadInfo ()
{
    SZDownloadState _state;
}

/** 下载状态 */
@property(nonatomic) SZDownloadState state;
/** 这次写入的数量 */
@property(nonatomic) NSInteger bytesWritten;
/** 已下载的数量 */
@property(nonatomic) NSInteger totalBytesWritten;
/** 文件的总大小 */
@property(nonatomic) NSInteger totalBytesExpectedToWrite;
/** 文件名 */
@property(nonatomic, copy) NSString *fileName;
/** 文件路径 */
@property(nonatomic, copy) NSString *filePath;
/** 文件url */
@property(nonatomic, copy) NSString *fileURL;
/** 下载的错误信息 */
@property(nonatomic, strong) NSError *error;

/** 存放所有的进度回调 */
@property(nonatomic, copy) SZDownloadProgressChangeBlock progressChangeBlock;
/** 存放所有的完毕回调 */
@property(nonatomic, copy) SZDownloadStateChangeBlock stateChangeBlock;
/** 任务 */
@property(nonatomic, strong) NSURLSessionDataTask *task;
/** 文件流 */
@property(nonatomic, strong) NSOutputStream *stream;

@end


@implementation SZDownloadInfo

/**
 *  初始化任务
 */
- (void)setupTask:(NSURLSession *)session {
    if (self.task) return;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.fileURL]];
    NSString *range = [NSString stringWithFormat:@"bytes=%zd-", self.totalBytesWritten];
    [request setValue:range forHTTPHeaderField:@"Range"];
    
    self.task = [session dataTaskWithRequest:request];
    // 设置描述
    self.task.taskDescription = self.fileURL;
}

/**
 *  通知进度改变
 */
- (void)notifyProgressChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        !self.progressChangeBlock ? : self.progressChangeBlock(self.bytesWritten, self.totalBytesWritten, self.totalBytesExpectedToWrite);
        [[NSNotificationCenter defaultCenter] postNotificationName:SZDownloadProgressDidChangeNotification
                                                            object:self
                                                          userInfo:@{SZDownloadInfoKey : self}];
    });
}

/**
 *  通知下载完毕
 */
- (void)notifyStateChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        !self.stateChangeBlock ? : self.stateChangeBlock(self.state, self.filePath, self.error);
        [[NSNotificationCenter defaultCenter] postNotificationName:SZDownloadStateDidChangeNotification
                                            object:self
                                          userInfo:@{SZDownloadInfoKey : self}];
    });
}

#pragma mark - 状态控制
- (void)setState:(SZDownloadState)state {
    SZDownloadState oldState = self.state;
    if (state == oldState) return;
    
    _state = state;
    
    // 发通知
    [self notifyStateChange];
}

/**
 *  取消
 */
- (void)cancel {
    if (self.state == SZDownloadStateCompleted || self.state == SZDownloadStateNone) return;
    
    [self.task cancel];
    self.state = SZDownloadStateNone;
}

/**
 *  恢复
 */
- (void)resume {
    if (self.state == SZDownloadStateCompleted || self.state == SZDownloadStateResumed) return;
    
    [self.task resume];
    self.state = SZDownloadStateResumed;
}

/**
 * 等待下载
 */
- (void)willResume {
    if (self.state == SZDownloadStateCompleted || self.state == SZDownloadStateWillResume) return;
    
    self.state = SZDownloadStateWillResume;
}

/**
 *  暂停
 */
- (void)suspend {
    if (self.state == SZDownloadStateCompleted || self.state == SZDownloadStateSuspened) return;
    
    if (self.state == SZDownloadStateResumed) { // 如果是正在下载
        [self.task suspend];
        self.state = SZDownloadStateSuspened;
    } else { // 如果是等待下载
        self.state = SZDownloadStateNone;
    }
}

#pragma mark - 代理方法处理
- (void)didReceiveResponse:(NSHTTPURLResponse *)response {
    // 获得文件总长度
    if (!self.totalBytesExpectedToWrite) {
        self.totalBytesExpectedToWrite = [response.allHeaderFields[@"Content-Length"] integerValue] + self.totalBytesWritten;
        // 存储文件总长度
        _totalFileSizes[self.fileURL] = @(self.totalBytesExpectedToWrite);
        [_totalFileSizes writeToFile:_totalFileSizesFile atomically:YES];
    }
    
    // 打开流
    [self.stream open];
    
    // 清空错误
    self.error = nil;
}

- (void)didReceiveData:(NSData *)data {
    // 写数据
    NSInteger result = [self.stream write:data.bytes maxLength:data.length];
    
    if (result == -1) {
        self.error = self.stream.streamError;
        [self.task cancel]; // 取消请求
    } else {
        self.bytesWritten = data.length;
        [self notifyProgressChange]; // 通知进度改变
    }
}

- (void)didCompleteWithError:(NSError *)error {
    // 关闭流
    [self.stream close];
    self.bytesWritten = 0;
    self.stream = nil;
    self.task = nil;
    
    // 错误(避免nil的error覆盖掉之前设置的self.error)
    self.error = error ? error : self.error;
    
    // 通知(如果下载完毕 或者 下载出错了)
    if (self.state == SZDownloadStateCompleted || error) {
        // 设置状态
        self.state = error ? SZDownloadStateNone : SZDownloadStateCompleted;
    }
}

#pragma mark - getters/setters
- (NSString *)filePath {
    if (!_filePath) {
        _filePath = [NSString stringWithFormat:@"%@/%@", SZDownloadRootDir, self.fileName].cachePath;
    }
    
    if (_filePath && ![[NSFileManager defaultManager] fileExistsAtPath:_filePath]) {
        NSString *dir = [_filePath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return _filePath;
}

- (NSString *)fileName {
    if (!_fileName) {
        NSString *pathExtension = self.fileURL.pathExtension;
        if (!pathExtension.length) {
            pathExtension = @"zip";
        }
        _fileName = [NSString stringWithFormat:@"%@.%@", self.fileURL.md5String, pathExtension];
    }
    return _fileName;
}

- (NSOutputStream *)stream {
    if (!_stream) {
        _stream = [NSOutputStream outputStreamToFileAtPath:self.filePath append:YES];
    }
    return _stream;
}

- (NSInteger)totalBytesWritten {
    return self.filePath.fileSize;
}

- (NSInteger)totalBytesExpectedToWrite {
    if (!_totalBytesExpectedToWrite) {
        _totalBytesExpectedToWrite = [_totalFileSizes[self.fileURL] integerValue];
    }
    return _totalBytesExpectedToWrite;
}

- (SZDownloadState)state {
    // 如果是下载完毕
    if (self.totalBytesExpectedToWrite && self.totalBytesWritten == self.totalBytesExpectedToWrite) {
        return SZDownloadStateCompleted;
    }
    
    // 如果下载失败
    if (self.task.error) return SZDownloadStateNone;
    
    return _state;
}

@end

@interface SZDownloadManager ()<NSURLSessionDelegate>

/** session */
@property(nonatomic, strong) NSURLSession *session;
/** 存放所有文件的下载信息 */
@property(nonatomic, strong) NSMutableArray *downloadInfoArray;
/** 是否正在批量处理 */
@property(nonatomic, getter=isBatching) BOOL batching;

@end

@implementation SZDownloadManager

/** 存放所有的manager */
static NSMutableDictionary *_managers;
/** 锁 */
static NSRecursiveLock *_lock;

+ (void)initialize {
    _totalFileSizesFile = [NSString stringWithFormat:@"%@/%@", SZDownloadRootDir, @"SZDownloadFileSizes.plist".md5String].cachePath;
    
    _totalFileSizes = [NSMutableDictionary dictionaryWithContentsOfFile:_totalFileSizesFile];
    if (!_totalFileSizes) {
        _totalFileSizes = [NSMutableDictionary dictionary];
    }
    
    _managers = [NSMutableDictionary dictionary];
    
    _lock = [[NSRecursiveLock alloc] init];
}

+ (instancetype)defaultManager {
    return [self managerWithIdentifier:SZDowndloadManagerDefaultIdentifier];
}

+ (instancetype)manager {
    return [[self alloc] init];
}

+ (instancetype)managerWithIdentifier:(NSString *)identifier {
    if (!identifier) return [self manager];
    
    SZDownloadManager *mgr = _managers[identifier];
    if (!mgr) {
        mgr = [self manager];
        _managers[identifier] = mgr;
    }
    return mgr;
}

#pragma mark - 懒加载
- (NSURLSession *)session {
    if (!_session) {
        // 配置
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        // session
        self.session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:self.queue];
    }
    return _session;
}

- (NSOperationQueue *)queue {
    if (!_queue) {
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return _queue;
}

- (NSMutableArray *)downloadInfoArray {
    if (!_downloadInfoArray) {
        _downloadInfoArray = [NSMutableArray array];
    }
    return _downloadInfoArray;
}

- (int)maxDownloadingCount {
    if (!_maxDownloadingCount) {
        _maxDownloadingCount = 1;
    }
    return _maxDownloadingCount;
}

#pragma mark - 私有方法

#pragma mark - 公共方法
- (SZDownloadInfo *)download:(NSString *)url toDestinationPath:(NSString *)destinationPath progress:(SZDownloadProgressChangeBlock)progress state:(SZDownloadStateChangeBlock)state {
    if (!url) return nil;
    
    // 下载信息
    SZDownloadInfo *info = [self downloadInfoForURL:url];
    
    // 设置block
    info.progressChangeBlock = progress;
    info.stateChangeBlock = state;
    
    // 设置文件路径
    if (destinationPath) {
        info.filePath = destinationPath;
        info.fileName = [destinationPath lastPathComponent];
    }
    
    // 如果已经下载完毕
    if (info.state == SZDownloadStateCompleted) {
        // 完毕
        [info notifyStateChange];
        return info;
    } else if (info.state == SZDownloadStateResumed) {
        return info;
    }
    
    // 创建任务
    [info setupTask:self.session];
    
    // 开始任务
    [self resume:url];
    
    return info;
}

- (SZDownloadInfo *)download:(NSString *)url progress:(SZDownloadProgressChangeBlock)progress state:(SZDownloadStateChangeBlock)state {
    return [self download:url toDestinationPath:nil progress:progress state:state];
}

- (SZDownloadInfo *)download:(NSString *)url state:(SZDownloadStateChangeBlock)state {
    return [self download:url toDestinationPath:nil progress:nil state:state];
}

- (SZDownloadInfo *)download:(NSString *)url {
    return [self download:url toDestinationPath:nil progress:nil state:nil];
}

#pragma mark - 文件操作
/**
 * 让第一个等待下载的文件开始下载
 */
- (void)resumeFirstWillResume {
    if (self.isBatching) return;
    
    SZDownloadInfo *willInfo = [self.downloadInfoArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"state==%d", SZDownloadStateWillResume]].firstObject;
    [self resume:willInfo.fileURL];
}

- (void)cancelAll {
    [self.downloadInfoArray enumerateObjectsUsingBlock:^(SZDownloadInfo *info, NSUInteger idx, BOOL *stop) {
        [self cancel:info.fileURL];
    }];
}

+ (void)cancelAll {
    [_managers.allValues makeObjectsPerformSelector:@selector(cancelAll)];
}

- (void)suspendAll {
    self.batching = YES;
    [self.downloadInfoArray enumerateObjectsUsingBlock:^(SZDownloadInfo *info, NSUInteger idx, BOOL *stop) {
        [self suspend:info.fileURL];
    }];
    self.batching = NO;
}

+ (void)suspendAll {
    [_managers.allValues makeObjectsPerformSelector:@selector(suspendAll)];
}

- (void)resumeAll {
    [self.downloadInfoArray enumerateObjectsUsingBlock:^(SZDownloadInfo *info, NSUInteger idx, BOOL *stop) {
        [self resume:info.fileURL];
    }];
}

+ (void)resumeAll {
    [_managers.allValues makeObjectsPerformSelector:@selector(resumeAll)];
}

- (void)cancel:(NSString *)url {
    if (url == nil) return;
    
    // 取消
    [[self downloadInfoForURL:url] cancel];
    
    // 这里不需要取出第一个等待下载的，因为调用cancel会触发-URLSession:task:didCompleteWithError:
    //    [self resumeFirstWillResume];
}

- (void)suspend:(NSString *)url {
    if (url == nil) return;
    
    // 暂停
    [[self downloadInfoForURL:url] suspend];
    
    // 取出第一个等待下载的
    [self resumeFirstWillResume];
}

- (void)resume:(NSString *)url {
    if (!url) return;
    
    // 获得下载信息
    SZDownloadInfo *info = [self downloadInfoForURL:url];
    
    // 正在下载的
    NSArray *downloadingDownloadInfoArray = [self.downloadInfoArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"state==%d", SZDownloadStateResumed]];
    if (self.maxDownloadingCount && downloadingDownloadInfoArray.count == self.maxDownloadingCount) {
        // 等待下载
        [info willResume];
    } else {
        // 继续
        [info resume];
    }
}

#pragma mark - 获得下载信息
- (SZDownloadInfo *)downloadInfoForURL:(NSString *)url {
    if (!url) return nil;
    
    SZDownloadInfo *info = [self.downloadInfoArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"fileURL==%@", url]].firstObject;
    if (!info) {
        info = [[SZDownloadInfo alloc] init];
        info.fileURL = url; // 设置url
        [self.downloadInfoArray addObject:info];
    }
    return info;
}

#pragma mark - <NSURLSessionDataDelegate>
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    // 获得下载信息
    SZDownloadInfo *info = [self downloadInfoForURL:dataTask.taskDescription];
    
    // 处理响应
    [info didReceiveResponse:response];
    
    // 继续
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    // 获得下载信息
    SZDownloadInfo *info = [self downloadInfoForURL:dataTask.taskDescription];
    
    // 处理数据
    [info didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    // 获得下载信息
    SZDownloadInfo *info = [self downloadInfoForURL:task.taskDescription];
    
    // 处理结束
    [info didCompleteWithError:error];
    
    // 恢复等待下载的
    [self resumeFirstWillResume];
}

@end
