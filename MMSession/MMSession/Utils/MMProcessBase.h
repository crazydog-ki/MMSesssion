// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSessionProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMProcessBase : NSObject <MMSessionProcessProtocol>
- (void)doTaskSync:(dispatch_block_t)task;
- (void)doTaskAsync:(dispatch_block_t)task;
@end

NS_ASSUME_NONNULL_END
