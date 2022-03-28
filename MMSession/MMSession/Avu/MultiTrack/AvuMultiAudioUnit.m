#import "AvuMultiAudioUnit.h"
#import "AvuAudioDecodeUnit.h"
#import "AvuAudioQueue.h"
#import "AvuUtils.h"

static const NSUInteger kMaxSamplesCount = 8192;
static const NSUInteger kSamplesCount = 1024;
static const NSUInteger kAudioTimescale = 44100;

@interface AvuMultiAudioUnit()
{
    AudioBufferList *_bufferList;
    AudioBufferList *_mixBufferList;
}
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) dispatch_queue_t multiAudioQueue;
@property (nonatomic, strong) NSMutableArray<NSString *> *audioClips;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AvuClipRange *> *clipRangeMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *audioVolumes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AvuAudioDecodeUnit *> *decoderMap;

@property (nonatomic, strong) AvuAudioQueue *audioPlayer;

@property (nonatomic, assign) double audioPlayTime;
@end
@implementation AvuMultiAudioUnit
#pragma mark - Public
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _multiAudioQueue = dispatch_queue_create("avu_multi_audio_queue", DISPATCH_QUEUE_SERIAL);
        _audioClips = [NSMutableArray array];
        _clipRangeMap = [NSMutableDictionary dictionary];
        _audioVolumes = [NSMutableDictionary dictionary];
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

- (void)seekToTime:(double)time {
    [self.audioPlayer pause];
    self.audioPlayTime = time;
    for (int i = 0; i < self.audioClips.count; i++) {
        NSString *audioClip = self.audioClips[i];
        AvuAudioDecodeUnit *audioDecoder = self.decoderMap[audioClip];
        [audioDecoder seekToTime:time];
    }
    [self.audioPlayer play];
}

- (double)getAudioPts {
    return self.audioPlayTime;
}

- (void)setVolume:(double)volume {
    [self.audioPlayer setVolume:volume];
}

- (void)updateClip:(AvuConfig *)config {
    dispatch_sync(self.multiAudioQueue, ^{
        AvuUpdateType type = config.updateType;
        NSArray *audioPaths = config.audioPaths;
        int clipCount = (int)audioPaths.count;
        if (type == AvuUpdateType_Add) {
            NSDictionary *audioClipRanges = config.clipRanges;
            for (int i = 0; i < clipCount; i++) {
                NSString *audioPath = audioPaths[i];
                AvuClipRange *audioClipRange = audioClipRanges[audioPath];
                NSNumber *volume = config.audioVolumes[audioPath];
                /// 创建音频解码器
                AvuConfig *audioConfig = [[AvuConfig alloc] init];
                audioConfig.type = AvuType_Audio;
                audioConfig.audioPath = audioPath;
                audioConfig.clipRange = audioClipRange;
                AvuAudioDecodeUnit *audioDecoder = [[AvuAudioDecodeUnit alloc] initWithConfig:audioConfig];
                
                /// 缓存
                [self.audioClips addObject:audioPath];
                self.clipRangeMap[audioPath] = audioClipRange;
                self.audioVolumes[audioPath] = volume;
                self.decoderMap[audioPath] = audioDecoder;
            }
        } else if (type == AvuUpdateType_Remove) {
            for (int i = 0; i < clipCount; i++) {
                NSString *audioPath = audioPaths[i];
                [self.audioClips removeObject:audioPath];
                [self.clipRangeMap removeObjectForKey:audioPath];
                [self.audioVolumes removeObjectForKey:audioPath];
                [self.decoderMap removeObjectForKey:audioPath];
            }
        } else if (type == AvuUpdateType_Volume) {
            for (int i = 0; i < clipCount; i++) {
                NSString *audioPath = audioPaths[i];
                self.audioVolumes[audioPath] = config.audioVolumes[audioPath] ;
            }
        }
    });
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
        NSNumber *volume = _config.audioVolumes[audioPath];
        /// 创建音频解码器
        AvuConfig *audioConfig = [[AvuConfig alloc] init];
        audioConfig.type = AvuType_Audio;
        audioConfig.audioPath = audioPath;
        audioConfig.clipRange = audioClipRange;
        AvuAudioDecodeUnit *audioDecoder = [[AvuAudioDecodeUnit alloc] initWithConfig:audioConfig];
        
        /// 缓存
        [self.audioClips addObject:audioPath];
        self.clipRangeMap[audioPath] = audioClipRange;
        self.audioVolumes[audioPath] = volume;
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
        dispatch_sync(self.multiAudioQueue, ^{
            /// 1. 重置音频buffer
            [AvuUtils resetAudioBufferList:self->_bufferList];
            /// 2. 获取音频buffer
            UInt32 getSize = kSamplesCount * AvuUtils.asbd.mBytesPerFrame;
            for (int i = 0; i < self.audioClips.count; i++) {
                NSString *audioClip = self.audioClips[i];
                double volume = [self.audioVolumes[audioClip] doubleValue];
                AvuClipRange *clipRange = self.clipRangeMap[audioClip];
                if (![AvuClipRange isClipRange:clipRange containsTime:self.audioPlayTime]) continue;
                AvuAudioDecodeUnit *audioDecoder = self.decoderMap[audioClip];
    //            AvuBuffer *buffer = [audioDecoder requestBufferAtTime:self.audioPlayTime];
    //            if (!buffer) continue;
    //            CMSampleBufferRef sampleBuffer = buffer.audioBuffer;
    //            if (sampleBuffer) {
    //                /// sampleBuffer -> bufferList
    //                int samples = (int)CMSampleBufferGetNumSamples(sampleBuffer);
    //                self->_bufferList->mBuffers[0].mDataByteSize = samples * AvuUtils.asbd.mBytesPerFrame;
    //
    //                self->_mixBufferList->mBuffers[0].mDataByteSize = samples * AvuUtils.asbd.mBytesPerFrame;
    //                CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, 0, samples, self->_mixBufferList);
    //                CFRelease(sampleBuffer);
    //                sampleBuffer = nil;
    //                /// 3. Mix音频
    //                [self _mixAudioBufferList:self->_mixBufferList to:self->_bufferList];
    //                [AvuUtils resetAudioBufferList:self->_mixBufferList]; /// 重置
    //            }
                [AvuUtils resetAudioBufferList:self->_mixBufferList]; /// 重置
                self->_mixBufferList->mBuffers[0].mDataByteSize = getSize;
                UInt8 *data = self->_mixBufferList->mBuffers[0].mData;
                // 取固定1024个
                [audioDecoder getAudioData:data offset:0 size:getSize];
                [self _mixAudioBufferList:self->_mixBufferList to:self->_bufferList gain:volume];
            }
            /// 4. block回调
            self->_bufferList->mBuffers[0].mDataByteSize = getSize;
            block(self->_bufferList);
            /// 5. 更改playTime
            self.audioPlayTime += CMTimeGetSeconds(CMTimeMake(kSamplesCount, kAudioTimescale));
        });
    };
    self.audioPlayer = audioPlayer;
}

- (void)_mixAudioBufferList:(AudioBufferList *)bufferList
                         to:(AudioBufferList *)dstBufferList
                       gain:(double)gain {
    NSInteger sampleCount = bufferList->mBuffers[0].mDataByteSize / sizeof(float);
    float *data = (float *)bufferList->mBuffers[0].mData;
    float *dstData = (float *)dstBufferList->mBuffers[0].mData;
    for (int i = 0; i < sampleCount; i++) {
        float mix = dstData[i]+data[i];
        mix = (1.0f < mix) ? 1.0f : (mix < -1.0f ? -1.0f : mix);
        dstData[i] = gain*mix;
    }
}
@end
