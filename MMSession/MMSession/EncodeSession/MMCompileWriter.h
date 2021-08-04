// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSessionProcessProtocol.h"
#import "MMCompileWriterConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMCompileWriter : NSObject<MMSessionProcessProtocol>

typedef void (^CompleteHandle)(NSURL *_Nullable fileUrl, NSError *_Nullable error);

- (instancetype)initWithConfig:(MMCompileWriterConfig *)config;

- (void)startEncode;

- (void)stopEncodeWithCompleteHandle:(CompleteHandle)handler;

@end

NS_ASSUME_NONNULL_END
