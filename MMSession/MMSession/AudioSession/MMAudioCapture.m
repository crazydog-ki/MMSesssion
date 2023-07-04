// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAudioCapture.h"
#import <AVFoundation/AVFoundation.h>
#include <mach/mach_time.h>

@interface MMAudioCapture ()
@property (strong, nonatomic) AVAudioEngine *audioEngine;
@property (strong, nonatomic) AVAudioInputNode *inputNode;
@end

@implementation MMAudioCapture

- (instancetype)init {
    if (self = [super init]) {
        [self _initEngine];
    }
    return self;
}

- (void)start {
    NSError *error;
    [self.audioEngine startAndReturnError:&error];
    if (error) {
        NSLog(@"[yjx] startAndReturnError: %@", [error localizedDescription]);
    }
}

- (void)stop {
    [self.audioEngine stop];
}
#pragma mark - Private
- (void)_initEngine {
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.inputNode = [self.audioEngine inputNode];

    AVAudioFormat *format = [self.inputNode outputFormatForBus:0];
    //AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:44100 channels:2 interleaved:YES];
    [self.audioEngine connect:self.inputNode to:self.audioEngine.mainMixerNode format:format];
    
    [self.inputNode installTapOnBus:0 bufferSize:1024 format:format block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        AudioBufferList audioBufferList = *(buffer.audioBufferList);
        AudioBuffer audioBuffer = audioBufferList.mBuffers[0];

        CMFormatDescriptionRef formatDescription;
        AudioStreamBasicDescription audioFormat = *(format.streamDescription);
        OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &audioFormat, 0, NULL, 0, NULL, NULL, &formatDescription);
        if (status != noErr) {
            NSLog(@"[yjx] CMAudioFormatDescriptionCreate: %d", status);
            return;
        }

        CMBlockBufferRef blockBuffer;
        status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, audioBuffer.mData, audioBuffer.mDataByteSize, kCFAllocatorNull, NULL, 0, audioBuffer.mDataByteSize, 0, &blockBuffer);
        if (status != noErr) {
            NSLog(@"[yjx] CMBlockBufferCreateWithMemoryBlock: %d", status);
            CFRelease(formatDescription);
            return;
        }
        
        // set pts
        uint64_t time = when.hostTime;
        mach_timebase_info_data_t info;
        mach_timebase_info(&info);
        time *= info.numer;
        time /= info.denom;
        CMTime pts = CMTimeMake(time, NSEC_PER_SEC);
        CMSampleTimingInfo timingInfo = {kCMTimeInvalid, pts, kCMTimeInvalid};

        CMSampleBufferRef sampleBuffer;
        status = CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer, true, NULL, NULL, formatDescription, buffer.frameLength, 1, &timingInfo, 0, NULL, &sampleBuffer);
        if (status != noErr) {
            NSLog(@"[yjx] CMSampleBufferCreate: %d", status);
            CFRelease(formatDescription);
            CFRelease(blockBuffer);
            return;
        }

        if (self.audioOutput) {
            self.audioOutput(sampleBuffer);
        }

        CFRelease(formatDescription);
        CFRelease(blockBuffer);
        CFRelease(sampleBuffer);
    }];
}
@end
