#import <Foundation/Foundation.h>
#import "AvuBufferProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuFFmpegDecoder : NSObject <AvuBufferProcessProtocol>
- (void)stopDecode;
@property (nonatomic, strong) AvuDecodeErrorCallback decodeErrorCallback;
@end

NS_ASSUME_NONNULL_END
