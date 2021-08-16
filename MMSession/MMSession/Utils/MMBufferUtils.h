// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMBufferUtils : NSObject
+ (AudioStreamBasicDescription)asbd;
+ (AudioBufferList *)produceAudioBufferList:(AudioStreamBasicDescription)audioFormat
                               numberFrames:(UInt32)frameCount;
+ (CMSampleBufferRef)produceAudioBuffer:(AudioBufferList *)bufferList
                             timingInfo:(CMSampleTimingInfo)timingInfo
                              frameNums:(UInt32)frameNums;
+ (void)resetAudioBufferList:(AudioBufferList *)bufferList;

+ (CMSampleBufferRef)produceVideoBuffer:(CVImageBufferRef)pixelBuffer
                             timingInfo:(CMSampleTimingInfo)timingInfo;
@end

NS_ASSUME_NONNULL_END
