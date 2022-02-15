#import "AvuAudioQueue.h"
#import "AvuUtils.h"

#define weakify(var) __weak typeof(var) weak_##var = var;
#define strongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = weak_##var; \
_Pragma("clang diagnostic pop")

static const NSInteger kMaxByteSize    = 1024 * sizeof(float) * 16;
static const NSInteger kBufferListSize = 8192;
static const NSInteger kBufferCount    = 3;
static const NSInteger kBufferCaches   = 3;

@interface AvuAudioQueue () {
    AudioQueueBufferRef *_audioBufferArr; // 音频流缓冲区
    AudioBufferList *_bufferList;
}
@property (nonatomic, strong) dispatch_queue_t audioPlayerQueue;
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, assign) AudioQueueRef audioQueue;
@property (nonatomic, strong) NSMutableArray<NSValue *> *bufferCaches;
@property (nonatomic, strong) NSCondition *condition;
@property (nonatomic, assign) double audioPts;
@end

@implementation AvuAudioQueue
#pragma mark - Public
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _audioPlayerQueue = dispatch_queue_create("mmsession_audio_palyer_queue", DISPATCH_QUEUE_SERIAL);
        _bufferCaches = [NSMutableArray arrayWithCapacity:kBufferCaches];
        _condition = [[NSCondition alloc] init];
        _audioPts = 0.0f;
        _bufferList = [AvuUtils produceAudioBufferList:AvuUtils.asbd
                                          numberFrames:kBufferListSize];
        [self _initAudioQueue];
    }
    return self;
}

- (void)play {
    NSString *currentCategory = AVAudioSession.sharedInstance.category;
    if (![currentCategory isEqualToString:AVAudioSessionCategoryPlayback] &&
        ![currentCategory isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback
                                       withOptions:kNilOptions
                                             error:nil];
    }
        
    dispatch_sync(_audioPlayerQueue, ^{
        AudioQueueReset(self.audioQueue);
        
        if (!_audioBufferArr) {
            _audioBufferArr = calloc(kBufferCount, sizeof(AudioQueueBufferRef));
        }
        
        for (int i = 0; i < kBufferCount; i++) {
            if (!_audioBufferArr[i] || !_audioBufferArr[i]->mAudioData) {
                AudioQueueAllocateBuffer(self.audioQueue, kMaxByteSize, &_audioBufferArr[i]);
            }
            MMAudioQueuePullData((__bridge void *)self, self.audioQueue, _audioBufferArr[i]);
        }
        
        if (self.audioQueue) {
            OSStatus ret = AudioQueueStart(self.audioQueue, NULL);
            if (ret != noErr) {
                NSLog(@"[avu] audio queue start error: %d", ret);
            }
        }
    });
}

- (void)pause {
    dispatch_sync(_audioPlayerQueue, ^{
        if (self.audioQueue) {
            OSStatus ret = AudioQueuePause(self.audioQueue);
            if (ret != noErr) {
                NSLog(@"[avu] audio queue pause error: %d", ret);
            }
        }
    });
}

- (void)stop {
    dispatch_sync(_audioPlayerQueue, ^{
        if (self.audioQueue) {
            OSStatus ret = AudioQueueStop(self.audioQueue, YES);
            if (ret != noErr) {
                NSLog(@"[avu] audio queue stop error: %d", ret);
            }
        }
    });
}

- (void)flush {
    dispatch_sync(_audioPlayerQueue, ^{
        if (self.audioQueue) {
            OSStatus ret = AudioQueueFlush(self.audioQueue);
            if (ret != noErr) {
                NSLog(@"[avu] audio queue flush error: %d", ret);
            }
        }
    });
}

- (void)dealloc {
    if (self.audioQueue) {
        AudioQueueStop(self.audioQueue, YES);
        AudioQueueDispose(self.audioQueue, YES);
        self.audioQueue = nil;
    }
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [_condition lock];
    self.audioPts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer));
    // NSLog(@"[avu] render audio pts: %lf", self.audioPts);
    while (kBufferCaches == self.bufferCaches.count) {
        [self.condition wait];
    }
    
    CFRetain(sampleBuffer);
    NSValue *audioBuffer = [NSValue valueWithPointer:sampleBuffer];
    [self.bufferCaches insertObject:audioBuffer atIndex:0];
    [_condition unlock];
}

- (double)getPts {
    return self.audioPts;
}

#pragma mark - Private
- (void)_initAudioQueue {
    AudioStreamBasicDescription asbd = AvuUtils.asbd;
    OSStatus ret = AudioQueueNewOutput(&asbd,
                                       MMAudioQueuePullData,
                                       (__bridge void *)self,
                                       NULL,
                                       NULL,
                                       0,
                                       &_audioQueue);
    if (ret != noErr) {
        NSLog(@"[avu] create audio queue error: %d", ret);
        AudioQueueDispose(self.audioQueue, YES);
        self.audioQueue = nil;
        return;
    }
    
    ret = AudioQueueAddPropertyListener(_audioQueue,
                                        kAudioQueueProperty_IsRunning,
                                        MMAudioQueuePropertyCallback,
                                        (__bridge void *)(self));
}

static void MMAudioQueuePropertyCallback(void *inUserData,
                                         AudioQueueRef inAQ,
                                         AudioQueuePropertyID inID) {

    if (inID == kAudioQueueProperty_IsRunning) {
        UInt32 flag = 0;
        UInt32 size = sizeof(flag);
        AudioQueueGetProperty(inAQ, inID, &flag, &size);
    }
}

static void MMAudioQueuePullData(void* __nullable inUserData,
                            AudioQueueRef inAQ,
                            AudioQueueBufferRef inBuffer) {
    AvuAudioQueue *self = (__bridge AvuAudioQueue *)inUserData;
    if (!self) {
        NSLog(@"[avu] audio queue callback self is nil");
        return;
    }
    
    __block OSStatus ret = noErr;
    if (inBuffer == NULL) {
        ret = AudioQueueAllocateBuffer(self.audioQueue,
                                       kMaxByteSize,
                                       &inBuffer);
        if (!inBuffer || ret != noErr) {
            NSLog(@"[avu] allocate audio buffer error: %d", ret);
            return;
        }
    }
    
    if (self.config.needPullData) { /// 向外拉数据
        weakify(self);
        self.pullDataBlk(^(AudioBufferList * _Nonnull bufferList) {
            strongify(self);
            if (bufferList) {
                UInt32 dataSize = bufferList->mBuffers[0].mDataByteSize;
                memcpy(inBuffer->mAudioData, bufferList->mBuffers[0].mData, dataSize);
                inBuffer->mAudioDataByteSize = dataSize;
                ret = AudioQueueEnqueueBuffer(self.audioQueue, inBuffer, 0, NULL);
            } else {
                memset(inBuffer->mAudioData, 0, kMaxByteSize);
                inBuffer->mAudioDataByteSize = kMaxByteSize;
                ret = AudioQueueEnqueueBuffer(self.audioQueue, inBuffer, 0, NULL);
            }
        });
    } else { /// 使用内部缓存
        AudioBufferList *bufferList = self->_bufferList;
        [AvuUtils resetAudioBufferList:bufferList];
        if (self.bufferCaches.count) {
            [self.condition lock];
            CMSampleBufferRef sampleBuffer = (CMSampleBufferRef)[self.bufferCaches.lastObject pointerValue];
            UInt32 samples = (UInt32)CMSampleBufferGetNumSamples(sampleBuffer);
            bufferList->mBuffers[0].mDataByteSize = samples * AvuUtils.asbd.mBytesPerFrame;
            CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, 0, samples, self->_bufferList);
            
            [self.bufferCaches removeLastObject];
            CFRelease(sampleBuffer);
            [self.condition signal];
            [self.condition unlock];
        }
        
        if (bufferList) {
            UInt32 dataSize = bufferList->mBuffers[0].mDataByteSize;
            memcpy(inBuffer->mAudioData, bufferList->mBuffers[0].mData, dataSize);
            inBuffer->mAudioDataByteSize = dataSize;
            ret = AudioQueueEnqueueBuffer(self.audioQueue, inBuffer, 0, NULL);
        }
    }
}
@end
