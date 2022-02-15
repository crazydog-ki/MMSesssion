#import <Foundation/Foundation.h>
#import "AvuBufferProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuBufferQueue : NSObject <AvuBufferProcessProtocol>
- (BOOL)exceedMax;
- (int)size;
- (void)flush;
- (AvuBuffer *)dequeue;
- (AvuBuffer *)requestBufferAtTime:(double)time;

- (void)configSeekTime:(double)seekTime;

typedef void(^AvuBufferEndCallback)(void);
@property (nonatomic, strong) AvuBufferEndCallback bufferEndCallback;
@end

NS_ASSUME_NONNULL_END
