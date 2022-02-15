#import "AvuUtils.h"

@implementation AvuUtils
#pragma mark - Audio
+ (AudioStreamBasicDescription)asbd {
    return *([[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:44100 channels:2 interleaved:YES].streamDescription);
}

+ (AudioBufferList *)produceAudioBufferList:(AudioStreamBasicDescription)audioFormat
                               numberFrames:(UInt32)frameCount {
    BOOL isInterleaved = !(audioFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
    int bufferNum = isInterleaved ? 1:audioFormat.mChannelsPerFrame;
    int channelsPerBuffer = isInterleaved ? audioFormat.mChannelsPerFrame:1;
    int bytesPerBuffer = audioFormat.mBytesPerFrame * frameCount;

    AudioBufferList *audioBuffer = (AudioBufferList *)calloc(1, sizeof(AudioBufferList)+(bufferNum-1)*sizeof(AudioBuffer));
    audioBuffer->mNumberBuffers = bufferNum;
    for (int i = 0; i < bufferNum; i++) {
        audioBuffer->mBuffers[i].mData = calloc(bytesPerBuffer, 1);
        audioBuffer->mBuffers[i].mDataByteSize = bytesPerBuffer;
        audioBuffer->mBuffers[i].mNumberChannels = channelsPerBuffer;
    }
    return audioBuffer;
}

+ (void)resetAudioBufferList:(AudioBufferList *)bufferList {
    if (!bufferList) return;
    for (int i = 0; i < bufferList->mNumberBuffers; i++) {
        AudioBuffer audioBuffer = bufferList->mBuffers[i];
        memset(audioBuffer.mData, 0, audioBuffer.mDataByteSize);
    }
}

+ (CMSampleBufferRef)produceAudioBuffer:(AudioBufferList *)bufferList
                             timingInfo:(CMSampleTimingInfo)timingInfo
                              frameNums:(UInt32)frameNums {
    CMFormatDescriptionRef format = NULL;
    AudioStreamBasicDescription asbd = AvuUtils.asbd;
    OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault,
                                                     &asbd,
                                                     0,
                                                     NULL,
                                                     0,
                                                     NULL,
                                                     NULL,
                                                     &format);

    CMSampleBufferRef audioBuffer = NULL;
    status = CMSampleBufferCreate(kCFAllocatorDefault,
                                  NULL,
                                  false,
                                  NULL,
                                  NULL,
                                  format,
                                  (CMItemCount)frameNums,
                                  1,
                                  &timingInfo,
                                  0,
                                  NULL,
                                  &audioBuffer);
    
    status = CMSampleBufferSetDataBufferFromAudioBufferList(audioBuffer,
                                                            kCFAllocatorDefault,
                                                            kCFAllocatorDefault,
                                                            0,
                                                            bufferList);
    if (format) {
        CFRelease(format);
        format = NULL;
    }
    return audioBuffer;
}

+ (void)freeAudioBufferList:(AudioBufferList *)bufferList {
    for (int i = 0; i < bufferList->mNumberBuffers; i++) {
        if (bufferList->mBuffers[i].mData) {
            free(bufferList->mBuffers[i].mData);
        }
    }
    free(bufferList);
}

#pragma mark - Video
+ (CMSampleBufferRef)produceVideoBuffer:(CVImageBufferRef)pixelBuffer
                             timingInfo:(CMSampleTimingInfo)timingInfo {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    OSStatus ret = -1;
    CMVideoFormatDescriptionRef videoInfo = NULL;
    ret = CMVideoFormatDescriptionCreateForImageBuffer(NULL,
                                                       pixelBuffer,
                                                       &videoInfo);
    
    CMSampleBufferRef sampleBuffer = NULL;
    ret = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                             pixelBuffer,
                                             true,
                                             NULL,
                                             NULL,
                                             videoInfo,
                                             &timingInfo,
                                             &sampleBuffer);
    CFRelease(videoInfo);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return sampleBuffer;
}
@end
