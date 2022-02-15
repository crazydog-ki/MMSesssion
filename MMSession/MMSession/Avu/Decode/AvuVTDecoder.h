#import <Foundation/Foundation.h>
#import "AvuBufferProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuVideoFrameInfo : NSObject
@property (nonatomic, assign) double pts;
@property (nonatomic, assign) double dts;
@property (nonatomic, assign) double duration;
@end

@interface AvuVTDecoder : NSObject <AvuBufferProcessProtocol>
- (void)stopDecode;
- (void)flush;

@property (nonatomic, strong) AvuDecodeErrorCallback decodeErrorCallback;
@end

NS_ASSUME_NONNULL_END
