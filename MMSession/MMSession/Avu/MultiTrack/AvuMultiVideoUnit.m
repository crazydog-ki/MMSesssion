#import "AvuMultiVideoUnit.h"
#import "AvuVideoDecodeUnit.h"

@interface AvuMultiVideoUnit()
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) dispatch_queue_t multiVideoQueue;
@property (nonatomic, strong) NSMutableArray<NSString *> *videoClips;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AvuClipRange *> *clipRangeMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AvuVideoDecodeUnit *> *decoderMap;
@end

@implementation AvuMultiVideoUnit
#pragma mark - Public
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _multiVideoQueue = dispatch_queue_create("avu_multi_video_queue", DISPATCH_QUEUE_SERIAL);
        _videoClips = [NSMutableArray array];
        _clipRangeMap = [NSMutableDictionary dictionary];
        _decoderMap = [NSMutableDictionary dictionary];
        [self _initClips];
    }
    return self;
}

- (NSArray<NSDictionary<NSString *, AvuBuffer *> *> *)requestVideoBuffersAt:(double)time {
    __block NSMutableArray *videoBuffers = [NSMutableArray array];
    dispatch_sync(self.multiVideoQueue, ^{
        for (int i = 0; i < self.videoClips.count; i++) {
            NSString *videoClip = self.videoClips[i];
            AvuClipRange *clipRange = self.clipRangeMap[videoClip];
            if (![AvuClipRange isClipRange:clipRange containsTime:time]) continue;
            
            AvuVideoDecodeUnit *videoDecoder = self.decoderMap[videoClip];
            AvuBuffer *videoBuffer = [videoDecoder requestBufferAtTime:time];
            if (!videoBuffer) continue;
            [videoBuffers addObject:@{videoClip:videoBuffer}];
        }
    });
    return videoBuffers;
}

- (void)seekToTime:(double)time isForce:(BOOL)isForce {
    for (int i = 0; i < self.videoClips.count; i++) {
        NSString *videoClip = self.videoClips[i];
        AvuVideoDecodeUnit *videoDecode = self.decoderMap[videoClip];
        [videoDecode seekToTime:time isForce:isForce];
    }
}

- (void)seekToTime:(double)time {
    [self seekToTime:time isForce:NO];
}

- (void)updateClip:(AvuConfig *)config {
    dispatch_sync(self.multiVideoQueue, ^{
        AvuUpdateType type = config.updateType;
        NSArray *videoPaths = config.videoPaths;
        int clipCount = (int)videoPaths.count;
        if (type == AvuUpdateType_Add) {
            NSDictionary *videoClipRanges = config.clipRanges;
            for (int i = 0; i < clipCount; i++) {
                NSString *videoPath = videoPaths[i];
                AvuClipRange *videoClipRange = videoClipRanges[videoPath];
                /// 创建视频解码器
                AvuConfig *videoConfig = [[AvuConfig alloc] init];
                videoConfig.type = AvuType_Video;
                videoConfig.videoPath = videoPath;
                videoConfig.clipRange = videoClipRange;
                AvuVideoDecodeUnit *videoDecoder = [[AvuVideoDecodeUnit alloc] initWithConfig:videoConfig];
                
                /// 缓存
                [self.videoClips addObject:videoPath];
                self.clipRangeMap[videoPath] = videoClipRange;
                self.decoderMap[videoPath] = videoDecoder;
            }
        } else if (type == AvuUpdateType_Remove) {
            for (int i = 0; i < clipCount; i++) {
                NSString *videoPath = videoPaths[i];
                /// 清理数据
                [self.videoClips removeObject:videoPath];
                [self.clipRangeMap removeObjectForKey:videoPath];
                [self.decoderMap removeObjectForKey:videoPath];
            }
        }
    });
}

#pragma mark - Private
- (void)_initClips {
    NSArray *videoPaths = _config.videoPaths;
    NSDictionary *videoClipRanges = _config.clipRanges;
    int clipCount = (int)videoPaths.count;
    for (int i = 0; i < clipCount; i++) {
        NSString *videoPath = videoPaths[i];
        AvuClipRange *videoClipRange = videoClipRanges[videoPath];
        /// 创建视频解码器
        AvuConfig *videoConfig = [[AvuConfig alloc] init];
        videoConfig.type = AvuType_Video;
        videoConfig.videoPath = videoPath;
        videoConfig.clipRange = videoClipRange;
        AvuVideoDecodeUnit *videoDecoder = [[AvuVideoDecodeUnit alloc] initWithConfig:videoConfig];
        
        /// 缓存
        [self.videoClips addObject:videoPath];
        self.clipRangeMap[videoPath] = videoClipRange;
        self.decoderMap[videoPath] = videoDecoder;
    }
}
@end
