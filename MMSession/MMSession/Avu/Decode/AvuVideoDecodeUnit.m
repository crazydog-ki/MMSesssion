#import "AvuVideoDecodeUnit.h"
#import "AvuFFmpegParser.h"
#import "AvuVTDecoder.h"
#import "AvuBufferQueue.h"
#import "AvuBuffer.h"

@interface AvuVideoDecodeUnit()
@property (nonatomic, strong) dispatch_queue_t decodeQueue;
@property (nonatomic, strong) dispatch_queue_t decodeQueue2;
@property (nonatomic, assign) AvuDecodeStatus decodeStatus;

@property (nonatomic, strong) AvuFFmpegParser *ffmpegParser;
@property (nonatomic, strong) AvuVTDecoder *vtDecoder;
@property (nonatomic, strong) AvuBufferQueue *videoQueue;

@property (nonatomic, assign) double seekTime;
@property (nonatomic, assign) double lastSeekTime;
@property (nonatomic, assign) BOOL needSeek;
@property (nonatomic, assign) double seekDelta;
@property (nonatomic, strong) AvuBuffer *lastBuffer;
@end

@implementation AvuVideoDecodeUnit
#pragma mark - AvuDecodeUnitProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _seekTime = -1;
        _lastSeekTime = -1;
        _needSeek = NO;
        _decodeQueue = dispatch_queue_create("avu_video_decode_queue", DISPATCH_QUEUE_SERIAL);
        _decodeQueue2 = dispatch_queue_create("avu_video_decode_queue2", DISPATCH_QUEUE_SERIAL);
        _decodeStatus = AvuDecodeStatus_Init;
        [self _startDecode];
    }
    return self;
}

- (void)seekToTime:(double)time isForce:(BOOL)isForce {
    dispatch_async(self.decodeQueue2, ^{
        AvuClipRange *clipRange = self.config.clipRange;
        double seekTime = time-clipRange.attachTime+clipRange.startTime;
        AvuSeekType seekType = [self.videoQueue getSeekTypeAt:seekTime];
        if (isForce || (0.1 < fabs(time-self.lastSeekTime) && seekType==AvuSeekType_Back)) {
            // 暂时处理仅逆向seek，100ms seek一次，防止太频繁
            self.seekTime = seekTime;
            self.needSeek = YES;
        }
    });
}

- (void)seekToTime:(double)time {
    [self seekToTime:time isForce:NO];
}

- (AvuBuffer *)requestBufferAtTime:(double)time {
    /// 主时间轴时间转换为视频时间轴时间
    AvuClipRange *clipRange = self.config.clipRange;
    double reqTime = time-clipRange.attachTime+clipRange.startTime;
    AvuBuffer *buffer = [self.videoQueue requestVideoBufferAtTime:reqTime];
    if (buffer && fabs(buffer.pts-reqTime)<0.2) {
        self.lastBuffer = buffer;
    } else {
        buffer = self.lastBuffer;
    }
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
            
            dispatch_sync(self.decodeQueue2, ^{
                if (self.needSeek && [self _needReallySeek] && ![self.videoQueue isHitCacheAt:self.seekTime]) {
                    [self.vtDecoder flush];
                    [self.videoQueue flush];
                    [self.ffmpegParser seekToTime:self.seekTime];
                    [self.videoQueue configSeekTime:self.seekTime];
                    NSLog(@"[yjx] video decode unit seek, seek time: %lf", self.seekTime);
                    self.needSeek = NO;
                    self.seekDelta = fabs(self.seekTime-self.lastSeekTime);
                    self.lastSeekTime = self.seekTime;
                }
            });
            
            AvuBuffer *videoBuffer = [[AvuBuffer alloc] init];
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
    
    self.ffmpegParser = [[AvuFFmpegParser alloc] initWithConfig:config];
    [self.ffmpegParser seekToTime:config.clipRange.startTime];
    
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

- (BOOL)_needReallySeek {
    return YES; /// 调试暂时返回YES
    AvuSeekType seekType = [self.videoQueue getSeekTypeAt:self.seekTime];
    /// 逆向肯定需要seek；正向根据是否在同一个gop进行判断
    if (seekType == AvuSeekType_Back) {
        return YES;
    }
    return NO;
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
