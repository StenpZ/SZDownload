
#import <Foundation/Foundation.h>

@interface NSString (SZDownload)

@property(nonatomic, copy, readonly) NSString *md5String;
@property(nonatomic, copy, readonly) NSString *cachePath;
@property(nonatomic, readonly) NSInteger fileSize;

@end
