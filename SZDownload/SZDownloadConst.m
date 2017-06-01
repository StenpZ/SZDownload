
#import "SZDownloadConst.h"

/** 下载进度发生改变的通知 */
NSString *const SZDownloadProgressDidChangeNotification = @"SZDownloadProgressDidChangeNotification";
/** 下载状态发生改变的通知 */
NSString *const SZDownloadStateDidChangeNotification = @"SZDownloadStateDidChangeNotification";
/** 利用这个key从通知中取出对应的SZDownloadInfo对象 */
NSString *const SZDownloadInfoKey = @"SZDownloadInfoKey";
