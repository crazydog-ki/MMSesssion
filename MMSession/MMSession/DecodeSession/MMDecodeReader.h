// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSampleData.h"
#import "MMDecodeConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMDecodeReader : NSObject
- (instancetype)initWithConfig:(MMDecodeConfig *)config;
- (BOOL)startDecode;
- (void)stopDecode;

- (MMSampleData *)pullSampleData:(MMSampleDataType)type;
@end

NS_ASSUME_NONNULL_END
