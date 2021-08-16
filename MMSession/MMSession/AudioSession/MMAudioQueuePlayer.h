// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAudioQueuePlayerConfig.h"
#import "MMSessionProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMAudioQueuePlayer : NSObject <MMSessionProcessProtocol>
- (instancetype)initWithConfig:(MMAudioQueuePlayerConfig *)config;
- (void)play;
- (void)pause;
- (void)stop;
- (void)flush;

typedef void(^AudioBufferBlock)(AudioBufferList *bufferList);
typedef void(^PullAudioDataBlock)(AudioBufferBlock block);
@property (nonatomic, strong) PullAudioDataBlock pullDataBlk;
@end

NS_ASSUME_NONNULL_END
