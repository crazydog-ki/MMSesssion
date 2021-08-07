// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMDecodeConfig.h"
#import "MMSampleData.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MMSessionDecodeProtocol <NSObject>
@optional
- (instancetype)initWithConfig:(MMDecodeConfig *)config;
- (BOOL)startDecode;
- (void)stopDecode;
- (MMSampleData *)pullSampleData:(MMSampleDataType)type;
- (MMSampleData *)decodeParsedData:(MMSampleData *)sampleData;
@end

NS_ASSUME_NONNULL_END
