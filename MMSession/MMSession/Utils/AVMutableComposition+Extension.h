// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

NS_ASSUME_NONNULL_BEGIN

@interface AVMutableComposition (Extension)

- (void)concatVideo:(AVAsset *)videoAsset
          timeRange:(CMTimeRange)timeRange;

@end

NS_ASSUME_NONNULL_END
