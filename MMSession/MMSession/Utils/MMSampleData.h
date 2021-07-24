// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MMSampleDataTypeVideo,
    MMSampleDataTypeAudio,
} MMSampleDataType;

typedef enum : NSUInteger {
    MMSampleDataFlagNone,
    MMSampleDataFlagBegin,
    MMSampleDataFlagProcess,
    MMSampleDataFlagEnd,
    MMSampleDataFlagCancel,
} MMSampleDataFlag;

@interface MMSampleData : NSObject

@property (nonatomic, assign) MMSampleDataType bufferType;
@property (nonatomic, assign) MMSampleDataFlag flag;
@property (nonatomic, assign) CMSampleBufferRef sampleBuffer;
@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;

@end

NS_ASSUME_NONNULL_END
