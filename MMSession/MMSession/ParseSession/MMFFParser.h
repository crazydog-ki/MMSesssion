// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSessionProcessProtocol.h"
#import "MMParseConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMFFParser : NSObject <MMSessionProcessProtocol>
- (instancetype)initWithConfig:(MMParseConfig *)config;
- (void *)getFmtCtx;
@end

NS_ASSUME_NONNULL_END
