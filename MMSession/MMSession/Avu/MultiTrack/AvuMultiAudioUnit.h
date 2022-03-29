#import <Foundation/Foundation.h>
#import "AvuConfig.h"

NS_ASSUME_NONNULL_BEGIN
@interface AvuMultiAudioUnit : NSObject
- (instancetype)initWithConfig:(AvuConfig *)config;

- (void)start;
- (void)pause;
- (void)stop;

- (void)seekToTime:(double)time; /// 针对主时间线
- (double)getAudioPts;

// 音量调节 0-1
- (void)setVolume:(double)volume;

// 增删、音量调节
- (void)updateConfig:(AvuConfig *)config;
@end

NS_ASSUME_NONNULL_END
