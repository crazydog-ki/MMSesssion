// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMEncodeConfig.h"

@implementation MMEncodeConfig
- (instancetype)init {
    if (self = [super init]) {
        _pixelFormat = MMPixelFormatTypeFullRangeYUV;
        _videoSize = CGSizeMake(720, 1280);
        _keyframeInterval = 1.0f;
        _isRealtime = NO;
        _isBFrame = NO;
        _bitrate = 2560000;
    }
    return self;
}
@end
