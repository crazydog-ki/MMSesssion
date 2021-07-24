// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAudioQueuePlayer.h"

static const NSInteger kMaxByteSize = 1024 * sizeof(float) * 16;
static const NSInteger kBufferCount = 3;

@interface MMAudioQueuePlayer () {
    AudioQueueBufferRef *_audioBufferArr; // 音频流缓冲区
}

@property (nonatomic, strong) dispatch_queue_t audioPlayerQueue;
@property (nonatomic, strong) MMAudioQueuePlayerConfig *config;
@property (nonatomic, assign) AudioQueueRef audioQueue;

@end

@implementation MMAudioQueuePlayer

- (instancetype)initWithConfig:(MMAudioQueuePlayerConfig *)config {
    if (self = [super init]) {
        _audioPlayerQueue = dispatch_queue_create("mmsession_audio_palyer_queue", DISPATCH_QUEUE_SERIAL);
        _config = config;
        [self _initAudioQueue];
    }
    return self;
}

- (AudioStreamBasicDescription)asbd {
    return *([[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:44100 channels:2 interleaved:YES].streamDescription);
}

- (void)play {
    dispatch_sync(_audioPlayerQueue, ^{
        AudioQueueReset(self.audioQueue);
        
        _audioBufferArr = calloc(kBufferCount, sizeof(AudioQueueBufferRef));
        for (int i = 0; i < kBufferCount; i++) {
            if (!_audioBufferArr[i] || !_audioBufferArr[i]->mAudioData) {
                AudioQueueAllocateBuffer(self.audioQueue, kMaxByteSize, &_audioBufferArr[i]);
            }
            MMAudioQueuePullData((__bridge void *)self, self.audioQueue, _audioBufferArr[i]);
        }
        
        if (self.audioQueue) {
            OSStatus ret = AudioQueueStart(self.audioQueue, NULL);
            if (ret != noErr) {
                NSLog(@"[yjx] audio queue start error: %d", ret);
            }
        }
    });
}

- (void)pause {
    dispatch_sync(_audioPlayerQueue, ^{
        if (self.audioQueue) {
            OSStatus ret = AudioQueuePause(self.audioQueue);
            if (ret != noErr) {
                NSLog(@"[yjx] audio queue pause error: %d", ret);
            }
        }
    });
}

- (void)stop {
    dispatch_sync(_audioPlayerQueue, ^{
        if (self.audioQueue) {
            OSStatus ret = AudioQueueStop(self.audioQueue, YES);
            if (ret != noErr) {
                NSLog(@"[yjx] audio queue stop error: %d", ret);
            }
        }
    });
}

- (void)flush {
    dispatch_sync(_audioPlayerQueue, ^{
        if (self.audioQueue) {
            OSStatus ret = AudioQueueFlush(self.audioQueue);
            if (ret != noErr) {
                NSLog(@"[yjx] audio queue flush error: %d", ret);
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

#pragma mark - Private
- (void)_initAudioQueue {
    AudioStreamBasicDescription asbd = self.asbd;
    OSStatus ret = AudioQueueNewOutput(&asbd, MMAudioQueuePullData, (__bridge void *)self, NULL, NULL, 0, &_audioQueue);
    if (ret != noErr) {
        NSLog(@"[yjx] create audio queue error: %d", ret);
        AudioQueueDispose(self.audioQueue, YES);
        self.audioQueue = nil;
        return;
    }
    
    ret = AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, MMAudioQueuePropertyCallback, (__bridge void *)(self));
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
    MMAudioQueuePlayer *self = (__bridge  MMAudioQueuePlayer *)inUserData;
    if (!self) {
        NSLog(@"[yjx] audio queue callback self is nil");
        return;
    }
    
    __block OSStatus ret = noErr;
    if (inBuffer == NULL) {
        ret = AudioQueueAllocateBuffer(self.audioQueue,
                                       kMaxByteSize,
                                       &inBuffer);
        if (!inBuffer || ret != noErr) {
            NSLog(@"[yjx] allocate audio buffer error: %d", ret);
            return;
        }
    }
    
    // 向外拉数据
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
}

@end
