#import "LGCStringSanitizer.h"

@implementation LGCStringSanitizer

+ (NSString *)sanitize:(NSString *)input {
    NSString *trimmed = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\s+"
                                                                           options:0
                                                                             error:nil];
    return [regex stringByReplacingMatchesInString:trimmed
                                           options:0
                                             range:NSMakeRange(0, trimmed.length)
                                      withTemplate:@" "];
}

@end
