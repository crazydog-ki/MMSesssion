#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, AvuBufferType) {
    AvuBufferType_Video = 1 << 0,
    AvuBufferType_Audio = 1 << 1,
};

@interface AvuBuffer : NSObject
/// 数据帧类型
@property (nonatomic, assign) AvuBufferType type;

/// 数据帧相关信息
@property (nonatomic, assign) double pts;
@property (nonatomic, assign) double dts;
@property (nonatomic, assign) double duration;

@property (nonatomic, assign) int   channel;
@property (nonatomic, assign) int   sampleRate;
@property (nonatomic, assign) void *parsedData; // 不管理生命周期

/// 视频帧
@property (nonatomic, assign) CMSampleBufferRef sampleBuffer; // 压缩帧
@property (nonatomic, assign) CVPixelBufferRef  pixelBuffer;  // 未压缩帧

/// 音频帧
@property (nonatomic, assign) CMSampleBufferRef audioBuffer;  // 未压缩帧
@property (nonatomic, assign) AudioBufferList *bufferList;
@end

NS_ASSUME_NONNULL_END
