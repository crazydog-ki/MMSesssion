// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSessionProcessProtocol.h"
#import "MMDecodeConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMFFDecoder : NSObject <MMSessionProcessProtocol>
- (instancetype)initWithConfig:(MMDecodeConfig *)config;
- (MMSampleData *)pullSampleData:(MMSampleDataType)type;
typedef void(^PcmDataCallback)(NSData *data);
@property (nonatomic, copy) PcmDataCallback pcmCallback;
@end

NS_ASSUME_NONNULL_END
