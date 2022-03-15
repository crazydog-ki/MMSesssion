#import <Foundation/Foundation.h>
#import "AvuBufferProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, AvuSeekType) {
    AvuSeekType_No      = 1 << 0,
    AvuSeekType_Back    = 1 << 1,
    AvuSeekType_Forward = 1 << 2,
};

@interface AvuBufferQueue : NSObject <AvuBufferProcessProtocol>
- (int)size;
- (BOOL)exceedMax;
- (void)configSeekTime:(double)seekTime;
- (void)flush;
- (BOOL)isHitCacheAt:(double)time;
- (AvuSeekType)getSeekTypeAt:(double)time;

- (AvuBuffer *)requestAudioBufferAtTime:(double)time;
- (AvuBuffer *)requestVideoBufferAtTime:(double)time;

/// 音频pcm数据存储
- (void)push:(UInt8 *)data size:(UInt32)size;
- (void)pop:(UInt8 *)data offset:(UInt32)offset size:(UInt32)size;

typedef void(^AvuBufferEndCallback)(void);
@property (nonatomic, strong) AvuBufferEndCallback bufferEndCallback;
@end

NS_ASSUME_NONNULL_END
