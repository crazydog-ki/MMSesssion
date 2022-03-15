#import <Foundation/Foundation.h>
#import "AvuConfig.h"
#import "AvuBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuMultiVideoUnit : NSObject
- (instancetype)initWithConfig:(AvuConfig *)config;
- (NSArray<NSDictionary<NSString *, AvuBuffer *> *> *)requestVideoBuffersAt:(double)time;
- (void)seekToTime:(double)time isForce:(BOOL)isForce;
- (void)seekToTime:(double)time;
@end

NS_ASSUME_NONNULL_END
