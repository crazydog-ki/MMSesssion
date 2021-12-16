// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MMSampleDataType) {
    MMSampleDataType_None_Video    = 1 << 0,
    MMSampleDataType_None_Audio    = 1 << 1,
    MMSampleDataType_Parsed_Video  = 1 << 2,
    MMSampleDataType_Parsed_Audio  = 1 << 3,
    MMSampleDataType_Decoded_Video = 1 << 4,
    MMSampleDataType_Decoded_Audio = 1 << 5,
};

typedef NS_OPTIONS(NSUInteger, MMSampleDataFlag) {
    MMSampleDataFlagNone     = 1 << 0,
    MMSampleDataFlagBegin    = 1 << 1,
    MMSampleDataFlagProcess  = 1 << 2,
    MMSampleDataFlagEnd      = 1 << 3,
    MMSampleDataFlagCancel   = 1 << 4,
};

typedef NS_OPTIONS(NSUInteger, MMVideoFormat) {
    MMVideoFormatH264 = 1 << 0,
    MMVideoFormatH265 = 1 << 1
};

@interface MMParsedVideoInfo : NSObject
@property (nonatomic, assign) MMVideoFormat format;
@property (nonatomic, assign) uint8_t       *data;
@property (nonatomic, assign) int           dataSize;
@property (nonatomic, assign) uint8_t       *extraData;
@property (nonatomic, assign) int           extradataSize;
@property (nonatomic, assign) double        pts;
@property (nonatomic, assign) double        dts;
@property (nonatomic, assign) double        duration;
@property (nonatomic, assign) double        rotate;
@property (nonatomic, assign) int           videoIdx;
@property (nonatomic, assign) void          *parsedData;
@end

@interface MMParsedAudioInfo : NSObject
@property (nonatomic, assign) uint8_t *data;
@property (nonatomic, assign) int     dataSize;
@property (nonatomic, assign) int     channel;
@property (nonatomic, assign) int     sampleRate;
@property (nonatomic, assign) double  pts;
@property (nonatomic, assign) double  dts;
@property (nonatomic, assign) double  duration;
@property (nonatomic, assign) int     audioIdx;
@property (nonatomic, assign) void    *parsedData;
@end

@interface MMSampleData : NSObject
@property (nonatomic, assign) MMSampleDataType dataType;
@property (nonatomic, assign) MMSampleDataFlag statusFlag;

@property (nonatomic, assign) CMSampleBufferRef sampleBuffer;
@property (nonatomic, assign) CVPixelBufferRef  pixelBuffer;

@property (nonatomic, assign) CMTime pts;

@property (nonatomic, strong) MMParsedVideoInfo *videoInfo;
@property (nonatomic, strong) MMParsedAudioInfo *audioInfo;
@end

NS_ASSUME_NONNULL_END
