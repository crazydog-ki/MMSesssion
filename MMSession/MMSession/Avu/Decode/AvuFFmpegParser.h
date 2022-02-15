#import <Foundation/Foundation.h>
#import "AvuBufferProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuFFmpegParser : NSObject <AvuBufferProcessProtocol>
- (void)seekToTime:(double)time;
- (void)stopParse;

- (CGSize)videoSize;
- (void *)getFmtCtx;
- (CMVideoFormatDescriptionRef)videoDesc;

@property (nonatomic, strong) AvuParseErrorCallback parseErrorCallback;
@end

NS_ASSUME_NONNULL_END
