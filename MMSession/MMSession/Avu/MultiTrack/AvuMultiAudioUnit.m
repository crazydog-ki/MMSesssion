#import "AvuMultiAudioUnit.h"
#import "AvuAudioDecodeUnit.h"
#import "AvuAudioQueue.h"
#import "AvuUtils.h"

static const NSUInteger kMaxSamplesCount = 8192;

@interface AvuMultiAudioUnit()
{
    AudioBufferList *_bufferList;
    AudioBufferList *_mixBufferList;
}
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) NSMutableArray<NSString *> *audioClips;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AvuClipRange *> *clipRangeMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AvuAudioDecodeUnit *> *decoderMap;

@property (nonatomic, strong) AvuAudioQueue *audioPlayer;

@property (nonatomic, assign) double audioPlayTime;
@end
@implementation AvuMultiAudioUnit
#pragma mark - Public
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _audioClips = [NSMutableArray array];
        _clipRangeMap = [NSMutableDictionary dictionary];
        _decoderMap = [NSMutableDictionary dictionary];
        _audioPlayTime = 0.0f;
        [self _initClips];
        [self _setupAudioPlayer];
    }
    return self;
}

- (void)start {
    [self.audioPlayer play];
}

- (void)dealloc {
    if (_bufferList) {
        [AvuUtils freeAudioBufferList:_bufferList];
        _bufferList = nil;
    }
    
    if (_mixBufferList) {
        [AvuUtils freeAudioBufferList:_mixBufferList];
        _mixBufferList = nil;
    }
}

#pragma mark - Private
- (void)_initClips {
    NSArray *audioPaths = _config.audioPaths;
    NSDictionary *audioClipRanges = _config.clipRanges;
    int clipCount = (int)audioPaths.count;
    for (int i = 0; i < clipCount; i++) {
        NSString *audioPath = audioPaths[i];
        AvuClipRange *audioClipRange = audioClipRanges[audioPath];
        /// 创建音频解码器
        AvuConfig *audioConfig = [[AvuConfig alloc] init];
        audioConfig.type = AvuType_Audio;
        audioConfig.audioPath = audioPath;
        audioConfig.clipRange = audioClipRange;
        AvuAudioDecodeUnit *audioDecoder = [[AvuAudioDecodeUnit alloc] initWithConfig:audioConfig];
        
        /// 缓存
        [self.audioClips addObject:audioPath];
        self.clipRangeMap[audioPath] = audioClipRange;
        self.decoderMap[audioPath] = audioDecoder;
    }
}
 
- (void)_setupAudioPlayer {
    _bufferList = [AvuUtils produceAudioBufferList:AvuUtils.asbd
                                      numberFrames:kMaxSamplesCount];
    _mixBufferList = [AvuUtils produceAudioBufferList:AvuUtils.asbd
                                         numberFrames:kMaxSamplesCount];
    
    AvuConfig *playerConfig = [[AvuConfig alloc] init];
    playerConfig.needPullData = YES;
    AvuAudioQueue *audioPlayer = [[AvuAudioQueue alloc] initWithConfig:playerConfig];
    weakify(self);
    audioPlayer.pullDataBlk = ^(AudioBufferBlock  _Nonnull block) {
        strongify(self);
        NSLog(@"[avu] pull audio buffer");
        /// 1. 重置音频buffer
        [AvuUtils resetAudioBufferList:self->_bufferList];
        /// 2. 获取音频buffer
        UInt32 samples = 0;
        for (int i = 0; i < self.audioClips.count; i++) {
            NSString *audioClip = self.audioClips[i];
            AvuAudioDecodeUnit *audioDecoder = self.decoderMap[audioClip];
            AvuBuffer *buffer = [audioDecoder requestBufferAtTime:self.audioPlayTime];
            if (!buffer) continue;
            CMSampleBufferRef sampleBuffer = buffer.audioBuffer;
            if (sampleBuffer) {
                /// sampleBuffer -> bufferList
                samples = (UInt32)CMSampleBufferGetNumSamples(sampleBuffer);
                self->_bufferList->mBuffers[0].mDataByteSize = samples * AvuUtils.asbd.mBytesPerFrame;
                
                self->_mixBufferList->mBuffers[0].mDataByteSize = samples * AvuUtils.asbd.mBytesPerFrame;
                CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, 0, samples, self->_mixBufferList);
                CFRelease(sampleBuffer);
                sampleBuffer = nil;
                /// 3. Mix音频
                [self _mixAudioBufferList:self->_mixBufferList to:self->_bufferList];
                [AvuUtils resetAudioBufferList:self->_mixBufferList]; /// 重置
            }
        }
        /// 4. block回调
        block(self->_bufferList);
        /// 5. 更改playTime
        self.audioPlayTime += CMTimeGetSeconds(CMTimeMake(samples, 44100));
    };
    self.audioPlayer = audioPlayer;
}

- (void)_mixAudioBufferList:(AudioBufferList *)bufferList
                         to:(AudioBufferList *)dstBufferList {
    NSInteger sampleCount = bufferList->mBuffers[0].mDataByteSize / sizeof(float);
    float *data = (float *)bufferList->mBuffers[0].mData;
    float *dstData = (float *)dstBufferList->mBuffers[0].mData;
    for (int i = 0; i < sampleCount; i++) {
        float mix = dstData[i]+data[i];
        mix = (1.0f < mix) ? 1.0f : (mix < -1.0f ? -1.0f : mix);
        dstData[i] = mix;
    }
}
@end
