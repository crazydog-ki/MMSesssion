// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSessionProcessProtocol.h"
#import "MMDecodeConfig.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MMYUVType) {
    MMYUVType_Y = 0,
    MMYUVType_U = 1,
    MMYUVType_V = 2,
};

@interface MMFFDecoder : NSObject <MMSessionProcessProtocol>
- (instancetype)initWithConfig:(MMDecodeConfig *)config;
- (MMSampleData *)pullSampleData:(MMSampleDataType)type;

/// PCM Callback
typedef void(^PcmDataCallback)(NSData *data);
@property (nonatomic, copy) PcmDataCallback pcmCallback;

/// YUV Callback
typedef void(^YuvDataCallback)(void *data, int size, MMYUVType type);
@property (nonatomic, copy) YuvDataCallback yuvCallback;
@end

NS_ASSUME_NONNULL_END
