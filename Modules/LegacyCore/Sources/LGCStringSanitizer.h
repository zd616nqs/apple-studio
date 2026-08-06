#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 共享层 ObjC 活范例:字符串清洗(ticket 03 起由混编 app 经 module import 消费)
@interface LGCStringSanitizer : NSObject

/// 去首尾空白,并把连续空白折叠为单个空格
+ (NSString *)sanitize:(NSString *)input;

@end

NS_ASSUME_NONNULL_END
