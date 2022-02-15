#import "AvuConfig.h"

@implementation AvuClipRange
+ (instancetype)clipRangeStart:(double)start end:(double)end {
    AvuClipRange *clipRange = [[AvuClipRange alloc] init];
    clipRange.startTime = start;
    clipRange.endTime = end;
    return clipRange;
}

+ (instancetype)clipRangeAttach:(double)attach start:(double)start end:(double)end {
    AvuClipRange *clipRange = [[AvuClipRange alloc] init];
    clipRange.attachTime = attach;
    clipRange.startTime = start;
    clipRange.endTime = end;
    return clipRange;
}
@end

@implementation AvuConfig
@end
