#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 本 target ObjC 活范例:文字水印渲染(经 LegacyCore 清洗文本)
@interface PMWatermarkRenderer : NSObject

/// 经共享层 LGCStringSanitizer 清洗后的水印文本
+ (NSString *)normalizedCaption:(NSString *)raw;

/// 生成指定尺寸的文字水印图;text 清洗后为空则返回 nil
+ (nullable UIImage *)imageWithText:(NSString *)text size:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
