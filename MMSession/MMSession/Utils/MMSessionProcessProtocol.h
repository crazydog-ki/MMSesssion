// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSampleData.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MMSessionProcessProtocol <NSObject>
@optional
- (void)processVideoBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)processAudioBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)processSampleData:(MMSampleData *)sampleData;
@property (nonatomic, strong) id<MMSessionProcessProtocol> nextNodes;
@end

NS_ASSUME_NONNULL_END
