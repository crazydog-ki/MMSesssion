#import "AvuAudioDecodeUnit.h"
#import "AvuFFmpegParser.h"
#import "AvuFFmpegDecoder.h"
#import "AvuBufferQueue.h"

@interface AvuAudioDecodeUnit()
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) dispatch_queue_t decodeQueue;
@property (nonatomic, assign) AvuDecodeStatus decodeStatus;

@property (nonatomic, strong) AvuFFmpegParser *ffmpegParser;
@property (nonatomic, strong) AvuFFmpegDecoder *ffmpegDecoder;
@property (nonatomic, strong) AvuBufferQueue *audioQueue;

@property (nonatomic, assign) double seekTime;
@end

@implementation AvuAudioDecodeUnit
#pragma mark - AvuDecodeUnitProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _seekTime = -1;
        _decodeQueue = dispatch_queue_create("avu_audio_decode_queue", DISPATCH_QUEUE_SERIAL);
        _decodeStatus = AvuDecodeStatus_Init;
        [self _startDecode];
    }
    return self;
}

- (void)seekToTime:(double)time {
    AvuClipRange *clipRange = self.config.clipRange;
    self.seekTime = time-clipRange.attachTime+clipRange.startTime;
}

- (AvuBuffer *)requestBufferAtTime:(double)time {
    AvuClipRange *clipRange = self.config.clipRange;
    double reqTime = time-clipRange.attachTime+clipRange.startTime;
    AvuBuffer *buffer = [self.audioQueue requestAudioBufferAtTime:reqTime];
    return buffer;
}

- (void)getAudioData:(UInt8 *)data offset:(UInt32)offset size:(UInt32)size {
    [self.audioQueue pop:data offset:offset size:size];
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
    return 0 < self.audioQueue.size;
}

- (void)dealloc {
    // 音频解码资源清理
    self.decodeStatus = AvuDecodeStatus_Stop;
    [self _clean];
}
#pragma mark - Private
- (void)_startDecode {
    dispatch_async(self.decodeQueue, ^{
        while (self.decodeStatus != AvuDecodeStatus_Stop) {
            if (self.decodeStatus == AvuDecodeStatus_Init) {
                [self _initDecodeChain];
                self.decodeStatus = AvuDecodeStatus_Start;
            }
            
            if (0 <= self.seekTime) {
                [self.audioQueue flush];
                [self.ffmpegParser seekToTime:self.seekTime];
                [self.audioQueue configSeekTime:self.seekTime];
                NSLog(@"[avu] audio decode unit seek, seek time: %lf", self.seekTime);
                self.seekTime = -1;
            }
            
            if ([self.audioQueue exceedMax] || self.decodeStatus != AvuDecodeStatus_Start) {
                [NSThread sleepForTimeInterval:0.001];
            } else {
                AvuBuffer *audioBuffer = [[AvuBuffer alloc] init];
                audioBuffer.type = AvuBufferType_Audio;
                [self.ffmpegParser processBuffer:audioBuffer];
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
        AVAsset *audioAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:config.audioPath]];
        config.clipRange = [AvuClipRange clipRangeStart:0.0f end:CMTimeGetSeconds(audioAsset.duration)];
    }
    
    self.ffmpegParser = [[AvuFFmpegParser alloc] initWithConfig:config];
    [self.ffmpegParser seekToTime:clipRange.startTime];
    
    config.fmtCtx = self.ffmpegParser.getFmtCtx;
    self.ffmpegDecoder = [[AvuFFmpegDecoder alloc] initWithConfig:config];
    self.audioQueue = [[AvuBufferQueue alloc] initWithConfig:config];
    
    [self.ffmpegParser addNextNode:self.ffmpegDecoder];
    [self.ffmpegDecoder addNextNode:self.audioQueue];
    
    if (self.decodeEndCallback) {
        self.audioQueue.bufferEndCallback = self.decodeEndCallback;
    }
    
    if (self.decodeErrorCallback) {
        self.ffmpegParser.parseErrorCallback = self.decodeErrorCallback;
        self.ffmpegDecoder.decodeErrorCallback = self.decodeErrorCallback;
    }
}

- (void)_clean {
    if (self.ffmpegParser) {
        [self.ffmpegParser stopParse];
        self.ffmpegParser = nil;
    }
    
    if (self.ffmpegDecoder) {
        if (self.ffmpegDecoder) {
            [self.ffmpegDecoder stopDecode];
            self.ffmpegDecoder = nil;
        }
    }
    
    if (self.audioQueue) {
        [self.audioQueue flush];
        self.audioQueue = nil;
    }
}
@end
