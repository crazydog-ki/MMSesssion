#import <Foundation/Foundation.h>
#import "AvuConfig.h"
#import "AvuBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@protocol AvuDecodeUnitProtocol <NSObject>
- (instancetype)initWithConfig:(AvuConfig *)config;
- (BOOL)isValid;
- (void)start;
- (void)pause;
- (void)stop;
- (void)seekToTime:(double)time isForce:(BOOL)isForce;
- (void)seekToTime:(double)time;

- (AvuBuffer *)requestBufferAtTime:(double)time;
- (void)updateConfig:(AvuConfig *)config;
@end

NS_ASSUME_NONNULL_END
