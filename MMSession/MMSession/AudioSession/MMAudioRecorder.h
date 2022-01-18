// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <AVFoundation/AVFoundation.h>
#import "MMAudioRecorderConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMAudioRecorder : NSObject
- (instancetype)initWithConfig:(MMAudioRecorderConfig *)config;
- (void)startRecord;
//- (void)pauseRecord;
- (void)stopRecord;
@end

NS_ASSUME_NONNULL_END
