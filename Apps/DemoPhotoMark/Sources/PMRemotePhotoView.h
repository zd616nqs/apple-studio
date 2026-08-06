#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 本 target ObjC 活范例:SDWebImage 加载远程图 + MBProgressHUD 转圈
@interface PMRemotePhotoView : UIView

- (void)loadPhotoWithURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
