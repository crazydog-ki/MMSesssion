// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSessionProcessProtocol.h"
#import "CameraCompileWriterConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraCompileWriter : NSObject<MMSessionProcessProtocol>

typedef void (^CompleteHandle)(NSURL *_Nullable fileUrl, NSError *_Nullable error);

- (instancetype)initWithConfig:(CameraCompileWriterConfig *)config;

- (void)startRecord;

- (void)stopRecordWithCompleteHandle:(CompleteHandle)handler;

@end

NS_ASSUME_NONNULL_END
