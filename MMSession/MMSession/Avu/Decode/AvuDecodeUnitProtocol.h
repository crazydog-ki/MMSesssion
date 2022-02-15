#import <Foundation/Foundation.h>
#import "AvuConfig.h"
#import "AvuBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@protocol AvuDecodeUnitProtocol <NSObject>
- (instancetype)initWithConfig:(AvuConfig *)config;
- (BOOL)isValid;
- (void)seekToTime:(double)time;
- (AvuBuffer *)dequeue;
- (AvuBuffer *)requestBufferAtTime:(double)time;
- (void)pause;
- (void)start;
- (void)stop;

- (void)updateConfig:(AvuConfig *)config;
@end

NS_ASSUME_NONNULL_END
