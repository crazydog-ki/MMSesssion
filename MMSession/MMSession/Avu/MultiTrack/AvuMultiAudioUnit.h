#import <Foundation/Foundation.h>
#import "AvuConfig.h"

NS_ASSUME_NONNULL_BEGIN
@interface AvuMultiAudioUnit : NSObject
- (instancetype)initWithConfig:(AvuConfig *)config;
- (void)start;
- (void)seekToTime:(double)time; /// 针对主时间线
@end

NS_ASSUME_NONNULL_END
