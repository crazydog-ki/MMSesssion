// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSampleData.h"
#import "MMParseConfig.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MMSessionParseProtocol <NSObject>
@optional
- (instancetype)initWithConfig:(MMParseConfig *)config;
- (void)startParse;
- (void)finishParse;
- (MMSampleData *)pullSampleData:(MMSampleDataType)type;

typedef void(^MMFFParseCallback)(MMSampleData *data);
- (void)startParse:(MMFFParseCallback)callback;
@end

NS_ASSUME_NONNULL_END
