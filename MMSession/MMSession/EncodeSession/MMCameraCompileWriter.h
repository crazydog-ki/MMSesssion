// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSessionProcessProtocol.h"
#import "MMCameraCompileWriterConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMCameraCompileWriter : NSObject<MMSessionProcessProtocol>

typedef void (^CompleteHandle)(NSURL *_Nullable fileUrl, NSError *_Nullable error);

- (instancetype)initWithConfig:(MMCameraCompileWriterConfig *)config;

- (void)startRecord;

- (void)stopRecordWithCompleteHandle:(CompleteHandle)handler;

@end

NS_ASSUME_NONNULL_END
