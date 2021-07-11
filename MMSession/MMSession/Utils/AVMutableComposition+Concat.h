// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVMutableComposition (Concat)

- (void)concatVideo:(AVAsset *)videoAsset
          timeRange:(CMTimeRange)timeRange;

- (AVVideoComposition *)videoComposition;

@end

NS_ASSUME_NONNULL_END
