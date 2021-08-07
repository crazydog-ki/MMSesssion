// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSessionProcessProtocol.h"
#import "MMEncodeConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMVTEncoder : NSObject<MMSessionProcessProtocol>
- (instancetype)initWithConfig:(MMEncodeConfig *)config;
@end

NS_ASSUME_NONNULL_END
