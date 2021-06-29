// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "VideoPreview.h"
#import <AVFoundation/AVFoundation.h>

@implementation VideoPreview

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat width = self.bounds.size.width;
        CGFloat height = width * 16 / 9;
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        _imageView.backgroundColor = UIColor.yellowColor;
        [self addSubview:_imageView];
    }
    return self;
}

@end
