// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAudioRecorder.h"
#import "MMBufferUtils.h"

static const NSUInteger kAudioFrameNum = 1024;
static const NSUInteger kAudioQueueNum = 3;

@interface MMAudioRecorder ()
{
    AudioQueueRef _audioQueue;
    AudioQueueBufferRef _audioBuffers[kAudioQueueNum];
    AudioFileID _audioFileID;
    UInt32 _totalRecordNum;
}
@property (nonatomic, strong) MMAudioRecorderConfig *config;
@property (nonatomic, strong) dispatch_queue_t audioRecorderQueue;
@property (nonatomic, assign) AudioStreamBasicDescription audioDesc;
@end

@implementation MMAudioRecorder
#pragma mark - Public
- (instancetype)initWithConfig:(MMAudioRecorderConfig *)config {
    if (self = [super init]) {
        _config = config;
        _audioRecorderQueue = dispatch_queue_create("mmsession_audio_recorder_queue", DISPATCH_QUEUE_SERIAL);
        _totalRecordNum = 0;
        [self _generateAudioDesc];
        [self _createAudioHandle];
        [self _initAudioQueue];
    }
    return self;
}

- (void)startRecord {
    dispatch_sync(_audioRecorderQueue, ^{
        OSStatus status = AudioQueueStart(_audioQueue, NULL);
        if (status != noErr) {
            NSLog(@"[mm] audio queue start error: %d", status);
        }
    });
}

- (void)stopRecord {
    dispatch_sync(_audioRecorderQueue, ^{
        OSStatus status = AudioQueueStop(_audioQueue, YES);
        if (status != noErr) {
            NSLog(@"[mm] audio queue stop error: %d", status);
        }
        
        AudioFileClose(_audioFileID);
        _totalRecordNum = 0;
    });
}

#pragma mark - Private
- (void)_generateAudioDesc {
    _audioDesc = MMBufferUtils.asbd;
//    AudioStreamBasicDescription audioDesc = {0};
//    audioDesc.mSampleRate = _config.sampleRate;
//    audioDesc.mChannelsPerFrame = (UInt32)_config.channelsCount;
//    audioDesc.mFormatID = _config.audioFormat==MMAudioFormatPCM ? kAudioFormatLinearPCM : kAudioFormatMPEG4AAC;
//    if (audioDesc.mFormatID == kAudioFormatLinearPCM) {
//        audioDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
//        audioDesc.mFramesPerPacket = 1; /// 一个packet内部包含一个frame
//        audioDesc.mBitsPerChannel  = 16;
//        audioDesc.mBytesPerPacket = audioDesc.mBytesPerFrame = (audioDesc.mBitsPerChannel/8*audioDesc.mChannelsPerFrame);
//    } else if (audioDesc.mFormatID == kAudioFormatMPEG4AAC) {
//        audioDesc.mFormatFlags = kMPEG4Object_AAC_Main;
//    }
//    _audioDesc = audioDesc;
}

- (void)_createAudioHandle {
    CFURLRef audioUrl = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)_config.audioFilePath, NULL);
    AudioFileID audioFileID;
    OSStatus status = AudioFileCreateWithURL(audioUrl,
                                             kAudioFileCAFType,
                                             &_audioDesc,
                                             kAudioFileFlags_EraseFile,
                                             &audioFileID);
    if (status != noErr) {
        NSLog(@"[mm] audio file create error: %d", status);
    }
    CFRelease(audioUrl);
    _audioFileID = audioFileID;
}

- (void)_initAudioQueue {
    OSStatus status = AudioQueueNewInput(&_audioDesc,
                                         AudioRecordCallback,
                                         (__bridge void *)self,
                                         NULL,
                                         kCFRunLoopCommonModes,
                                         0,
                                         &_audioQueue);
    if (status != noErr) {
        NSLog(@"[mm] init audio recorder error: %d", (int)status);
    }

    int bufferSize = 1024 * sizeof(float) * 16;
//    if (_audioDesc.mFormatID == kAudioFormatLinearPCM) {
//        int frameNums = kAudioFrameNum;
//        int sizeOfFrame = _audioDesc.mBytesPerFrame;
//        bufferSize = frameNums*sizeOfFrame;
//    } else if (_audioDesc.mFormatID == kAudioFormatMPEG4AAC) {
//        /// TODO:AAC音频编码格式
//    }

    for (int i = 0; i < kAudioQueueNum; i++) {
        status = AudioQueueAllocateBuffer(_audioQueue,
                                          bufferSize,
                                          &_audioBuffers[i]);
        status = AudioQueueEnqueueBuffer(_audioQueue,
                                         _audioBuffers[i],
                                         0,
                                         NULL);
        if (status != noErr) {
            NSLog(@"[mm] audio recorder allocate / enqueue buffer error: %d", status);
        }
    }
}

void AudioRecordCallback(void *__nullable                   inUserData,
                         AudioQueueRef                      inAQ,
                         AudioQueueBufferRef                inBuffer,
                         const AudioTimeStamp               *inStartTime,
                         UInt32                             inNumberPacketDescriptions,
                         const AudioStreamPacketDescription *__nullable inPacketDescs) {
    NSLog(@"[mm] receive audio buffer");
    MMAudioRecorder *audioRecorder = (__bridge MMAudioRecorder *)inUserData;
    UInt32 packetNum = inBuffer->mAudioDataByteSize/audioRecorder->_audioDesc.mBytesPerPacket;
    OSStatus status = AudioFileWritePackets(audioRecorder->_audioFileID,
                                            false,
                                            inBuffer->mAudioDataByteSize,
                                            inPacketDescs,
                                            audioRecorder->_totalRecordNum,
                                            &packetNum,
                                            inBuffer);
    if (status != noErr) {
        NSLog(@"[mm] audio file write packet error: %d", status);
    }
    audioRecorder->_totalRecordNum += packetNum;
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}
@end
