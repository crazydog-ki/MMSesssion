#import <AVFoundation/AVFoundation.h>
#import "AvuConfig.h"
#import "AvuBuffer.h"

NS_ASSUME_NONNULL_BEGIN
@interface AvuAudioQueue : NSObject
- (instancetype)initWithConfig:(AvuConfig *)config;
- (void)play;
- (void)pause;
- (void)stop;
- (void)flush;

- (double)getPts;

typedef void(^AudioBufferBlock)(AudioBufferList *bufferList);
typedef void(^PullAudioDataBlock)(AudioBufferBlock block);
@property (nonatomic, strong) PullAudioDataBlock pullDataBlk;

typedef void(^AudioPlayEndBlock)(void);
@property (nonatomic, strong) AudioPlayEndBlock playEndBlk;

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END
