// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMDecodeReaderConfig.h"
#import "MMSampleData.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMDecodeReader : NSObject

- (instancetype)initWithConfig:(MMDecodeReaderConfig *)config;
- (BOOL)startDecode;
- (void)stopDecode;
- (MMSampleData *)pullSampleBuffer:(MMSampleDataType)type;

@end

NS_ASSUME_NONNULL_END
