#import "AvuMultiDecoder.h"
#import "AvuVideoDecodeUnit.h"
#import "AvuAudioDecodeUnit.h"

@interface AvuMultiDecoder ()
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) NSMutableArray<AVAsset *> *clipArray;
@property (nonatomic, strong) NSMutableDictionary<AVAsset *, AvuVideoDecodeUnit *> *videoDecoderMap;
@property (nonatomic, strong) NSMutableDictionary<AVAsset *, AvuAudioDecodeUnit *> *audioDecoderMap;
@property (nonatomic, strong) NSMutableDictionary<AVAsset *, AvuClipRange *> *clipRangeMap;
@end

@implementation AvuMultiDecoder
#pragma mark - Public
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _clipArray = [NSMutableArray array];
        _videoDecoderMap = [NSMutableDictionary dictionary];
        _audioDecoderMap = [NSMutableDictionary dictionary];
        _clipRangeMap = [NSMutableDictionary dictionary];
        [self _initClipArrays];
    }
    return self;
}

- (NSArray<AvuBuffer *> *)requestVideoBufferAt:(double)time {
    NSUInteger clipCount = self.clipArray.count;
    NSMutableArray *videoBuffers = [NSMutableArray array];
    for (int i = 0; i < clipCount; i++) {
        AVAsset *asset = self.clipArray[i];
        AvuVideoDecodeUnit *videoDecoder = self.videoDecoderMap[asset];
        AvuClipRange *clipRange = self.clipRangeMap[asset];
        BOOL isValidClip = [self _isTime:time inClipRange:clipRange];
        
        if (isValidClip) {
            double requestTime = time-clipRange.attachTime+clipRange.startTime;
            AvuBuffer *videoBuffer = [videoDecoder requestBufferAtTime:requestTime];
            [videoBuffers addObject:videoBuffer];
        }
    }
    return videoBuffers;
}

- (NSArray<AvuBuffer *> *)requestAudioBufferAt:(double)time {
    return nil;
}

#pragma mark - Private
- (void)_initClipArrays {
    NSUInteger clipCount = self.config.videoAssets.count;
    NSArray *clipArray = self.config.videoAssets;
    NSDictionary *clipRanges = self.config.clipRanges;
    for (int i = 0; i < clipCount; i++) {
        AVAsset *asset = clipArray[i];
        NSString *assetPath = ((AVURLAsset *)asset).URL.path;
        AvuClipRange *clipRange = clipRanges[asset];
        self.clipRangeMap[asset] = clipRange;
        [self.clipArray addObject:asset];
        /// 视频
        AvuConfig *videoConfig = [[AvuConfig alloc] init];
        videoConfig.type = AvuType_Video;
        videoConfig.videoPath = assetPath;
        videoConfig.clipRange = clipRange;
        AvuVideoDecodeUnit *videoDecoder = [[AvuVideoDecodeUnit alloc] initWithConfig:videoConfig];
        self.videoDecoderMap[asset] = videoDecoder;
        /// 音频
        AvuConfig *audioConfig = [[AvuConfig alloc] init];
        audioConfig.type = AvuType_Audio;
        audioConfig.audioPath = assetPath;
        audioConfig.clipRange = clipRange;
        AvuAudioDecodeUnit *audioDecoder = [[AvuAudioDecodeUnit alloc] initWithConfig:audioConfig];
        self.audioDecoderMap[asset] = audioDecoder;
    }
}

- (BOOL)_isTime:(double)time inClipRange:(AvuClipRange *)clipRange {
    double begin = clipRange.attachTime;
    double end = clipRange.attachTime + clipRange.endTime - clipRange.startTime;
    return (begin<=time) && (time<=end);
}
@end
