// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMAudioCapture : NSObject
- (void)start;
- (void)stop;
typedef void(^AudioOutputCallback)(CMSampleBufferRef sampleBuffer);
@property (nonatomic, copy) AudioOutputCallback audioOutput;
@end

NS_ASSUME_NONNULL_END
