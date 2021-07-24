// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMAssetReaderConfig.h"
#import "MMSampleData.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMAssetReader : NSObject

- (instancetype)initWithConfig:(MMAssetReaderConfig *)config;
- (BOOL)startReading;
- (void)stopReading;
- (MMSampleData *)pullSampleBuffer:(MMSampleDataType)type;

@end

NS_ASSUME_NONNULL_END
