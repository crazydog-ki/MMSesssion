// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MMSampleDataType) {
    MMSampleDataType_None_Video    = 1,
    MMSampleDataType_None_Audio    = 2,
    MMSampleDataType_Parsed_Video  = 3,
    MMSampleDataType_Parsed_Audio  = 4,
    MMSampleDataType_Decoded_Video = 5,
    MMSampleDataType_Decoded_Audio = 6,
};

typedef NS_OPTIONS(NSUInteger, MMSampleDataFlag) {
    MMSampleDataFlagNone     = 1,
    MMSampleDataFlagBegin    = 2,
    MMSampleDataFlagProcess  = 3,
    MMSampleDataFlagEnd      = 4,
    MMSampleDataFlagCancel   = 5,
};

typedef NS_OPTIONS(NSUInteger, MMVideoFormat) {
    MMVideoFormatH264 = 1,
    MMVideoFormatH265 = 2
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
