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
- (instancetype)init {
    if (self = [super init]) {
        _audioPaths = [NSMutableArray array];
        _videoPaths = [NSMutableArray array];
        _clipRanges = [NSMutableDictionary dictionary];
    }
    return self;
}
@end
