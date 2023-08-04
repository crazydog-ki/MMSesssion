// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMProcessBase.h"

@interface MMProcessBase ()
@property (nonatomic, strong) NSMutableArray *nextVideoNodes;
@property (nonatomic, strong) NSMutableArray *nextAudioNodes;
@property (nonatomic, strong) dispatch_queue_t processQueue;
@end

@implementation MMProcessBase
- (instancetype)init {
    if (self = [super init]) {
       const char *name = [NSString stringWithFormat:@"mmsession_%@_queue", NSStringFromClass(self.class)].UTF8String;
        _processQueue = dispatch_queue_create(name, DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)doTaskSync:(dispatch_block_t)task {
    dispatch_sync(_processQueue, ^{
        task();
    });
}

- (void)doTaskAsync:(dispatch_block_t)task {
    dispatch_async(_processQueue, ^{
        task();
    });
}

- (void)addNextVideoNode:(id<MMSessionProcessProtocol>)node {
    [self.nextVideoNodes addObject:node];
}

- (void)addNextAudioNode:(id<MMSessionProcessProtocol>)node {
    [self.nextAudioNodes addObject:node];
}
@end
