#import "AvuVideoDecodeUnit.h"
#import "AvuFFmpegParser.h"
#import "AvuVTDecoder.h"
#import "AvuBufferQueue.h"
#import "AvuBuffer.h"

@interface AvuVideoDecodeUnit()
@property (nonatomic, strong) dispatch_queue_t decodeQueue;
@property (nonatomic, assign) AvuDecodeStatus decodeStatus;

@property (nonatomic, strong) AvuFFmpegParser *ffmpegParser;
@property (nonatomic, strong) AvuVTDecoder *vtDecoder;
@property (nonatomic, strong) AvuBufferQueue *videoQueue;

@property (nonatomic, assign) double seekTime;
@end

@implementation AvuVideoDecodeUnit
#pragma mark - AvuDecodeUnitProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _seekTime = -1;
        _decodeQueue = dispatch_queue_create("avu_video_decode_queue", DISPATCH_QUEUE_SERIAL);
        _decodeStatus = AvuDecodeStatus_Init;
        [self _startDecode];
    }
    return self;
}

- (void)seekToTime:(double)time {
    self.seekTime = time;
}

- (AvuBuffer *)dequeue {
    AvuBuffer *buffer = self.videoQueue.dequeue;
    return buffer;
}

- (AvuBuffer *)requestBufferAtTime:(double)time {
    AvuBuffer *buffer = [self.videoQueue requestBufferAtTime:time];
    return buffer;
}

- (void)start {
    self.decodeStatus = AvuDecodeStatus_Start;
}

- (void)pause {
    self.decodeStatus = AvuDecodeStatus_Pause;
}

- (void)stop {
    self.decodeStatus = AvuDecodeStatus_Stop;
}

- (BOOL)isValid {
    return 0 < self.videoQueue.size;
}

- (void)updateConfig:(nonnull AvuConfig *)config {
    [self seekToTime:config.clipRange.startTime];
    
    [self.videoQueue updateConfig:config];
    _config = config;
}

#pragma mark - Private
- (void)_startDecode {
    dispatch_async(self.decodeQueue, ^{
        while (self.decodeStatus != AvuDecodeStatus_Stop) {
            if (self.decodeStatus == AvuDecodeStatus_Init) {
                [self _initDecodeChain];
                self.decodeStatus = AvuDecodeStatus_Start;
            }
            
            AvuBuffer *videoBuffer = [[AvuBuffer alloc] init];
            if (0 <= self.seekTime) {
                [self.vtDecoder flush];
                [self.videoQueue flush];
                [self.ffmpegParser seekToTime:self.seekTime];
                [self.videoQueue configSeekTime:self.seekTime];
                NSLog(@"[avu] video decode unit seek, seek time: %lf", self.seekTime);
                self.seekTime = -1;
            }
            
            if ([self.videoQueue exceedMax] || self.decodeStatus != AvuDecodeStatus_Start) {
                // NSLog(@"[avu] video sleep, buffer count: %d", self.videoQueue.size);
                [NSThread sleepForTimeInterval:0.001];
            } else {
                // NSLog(@"[avu] push a buffer");
                videoBuffer.type = AvuBufferType_Video;
                // NSLog(@"[avu] video decode unit push a buffer");
                [self.ffmpegParser processBuffer:videoBuffer];
            }
        }
        [self _clean];
    });
}

- (void)_initDecodeChain {
    AvuConfig *config = _config;
    /// 处理裁剪
    AvuClipRange *clipRange = config.clipRange;
    if (!clipRange) {
        AVAsset *videoAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:config.videoPath]];
        config.clipRange = [AvuClipRange clipRangeStart:0.0f end:CMTimeGetSeconds(videoAsset.duration)];
    }
    
    [self seekToTime:clipRange.startTime];
    self.ffmpegParser = [[AvuFFmpegParser alloc] initWithConfig:config];
    
    config.vtDesc = self.ffmpegParser.videoDesc;
    config.videoSize = self.ffmpegParser.videoSize;
    self.vtDecoder = [[AvuVTDecoder alloc] initWithConfig:config];
    
    self.videoQueue = [[AvuBufferQueue alloc] initWithConfig:config];
    
    [self.ffmpegParser addNextNode:self.vtDecoder];
    [self.vtDecoder addNextNode:self.videoQueue];
    
    if (self.decodeEndCallback) {
        self.videoQueue.bufferEndCallback = self.decodeEndCallback;
    }
    
    if (self.decodeErrorCallback) {
        self.ffmpegParser.parseErrorCallback = self.decodeErrorCallback;
        self.vtDecoder.decodeErrorCallback = self.decodeErrorCallback;
    }
}

- (void)_clean {
    if (self.ffmpegParser) {
        [self.ffmpegParser stopParse];
        self.ffmpegParser = nil;
    }
    
    if (self.vtDecoder) {
        [self.vtDecoder stopDecode];
        self.vtDecoder = nil;
    }
    
    if (self.videoQueue) {
        [self.videoQueue flush];
        self.videoQueue = nil;
    }
}
@end
