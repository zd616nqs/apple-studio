#import "PMWatermarkRenderer.h"
@import LegacyCore;

@implementation PMWatermarkRenderer

+ (NSString *)normalizedCaption:(NSString *)raw {
    return [LGCStringSanitizer sanitize:raw];
}

+ (nullable UIImage *)imageWithText:(NSString *)text size:(CGSize)size {
    NSString *caption = [self normalizedCaption:text];
    if (caption.length == 0) {
        return nil;
    }

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [UIColor.blackColor setFill];
        [context fillRect:CGRectMake(0, 0, size.width, size.height)];
        NSDictionary *attributes = @{
            NSFontAttributeName : [UIFont boldSystemFontOfSize:20],
            NSForegroundColorAttributeName : UIColor.whiteColor,
        };
        [caption drawAtPoint:CGPointMake(12, 12) withAttributes:attributes];
    }];
}

@end
