#import <Foundation/Foundation.h>
#import "AvuConfig.h"

NS_ASSUME_NONNULL_BEGIN
@interface AvuMultiAudioUnit : NSObject
- (instancetype)initWithConfig:(AvuConfig *)config;
- (void)start;
- (void)seekToTime:(double)time; /// 针对主时间线
- (double)getAudioPts;

// 音量调节 0-1
- (void)setVolume:(double)volume;

// 增删
- (void)updateClip:(AvuConfig *)config;
@end

NS_ASSUME_NONNULL_END
