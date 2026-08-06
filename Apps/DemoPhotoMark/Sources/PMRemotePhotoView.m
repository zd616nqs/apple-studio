#import "PMRemotePhotoView.h"
@import MBProgressHUD;
@import SDWebImage;

@interface PMRemotePhotoView ()
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation PMRemotePhotoView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageView.frame = self.bounds;
}

- (void)loadPhotoWithURL:(NSURL *)url {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self animated:YES];
    [self.imageView sd_setImageWithURL:url
                             completed:^(UIImage *_Nullable image,
                                         NSError *_Nullable error,
                                         SDImageCacheType cacheType,
                                         NSURL *_Nullable imageURL) {
        [hud hideAnimated:YES];
    }];
}

@end
