#import <Foundation/Foundation.h>
#import "AvuConfig.h"
#import "AvuBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuMultiDecoder : NSObject
- (instancetype)initWithConfig:(AvuConfig *)config;
- (NSArray<AvuBuffer *> *)requestVideoBufferAt:(double)time;
- (NSArray<AvuBuffer *> *)requestAudioBufferAt:(double)time;
@end

NS_ASSUME_NONNULL_END
