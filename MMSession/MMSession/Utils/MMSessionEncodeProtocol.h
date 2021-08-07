// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMEncodeConfig.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MMSessionEncodeProtocol <NSObject>
typedef void (^CompleteHandle)(NSURL *_Nullable fileUrl, NSError *_Nullable error);
- (instancetype)initWithConfig:(MMEncodeConfig *)config;
- (void)startEncode;
- (void)stopEncodeWithCompleteHandle:(CompleteHandle)handler;
@end

NS_ASSUME_NONNULL_END
