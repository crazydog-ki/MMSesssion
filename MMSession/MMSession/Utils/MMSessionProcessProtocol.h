// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSampleData.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MMSessionProcessProtocol <NSObject>
@optional
- (void)addNextVideoNode:(id<MMSessionProcessProtocol>)node;
- (void)addNextAudioNode:(id<MMSessionProcessProtocol>)node;
- (void)processSampleData:(MMSampleData *)sampleData;
- (double)getPts;
@end

NS_ASSUME_NONNULL_END
