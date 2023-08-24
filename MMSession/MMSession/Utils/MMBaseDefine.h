// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#ifndef MMBaseDefine_h
#define MMBaseDefine_h

typedef NS_OPTIONS(NSUInteger, MMFFDecodeType) {
    MMFFDecodeType_Video = 1 << 0,
    MMFFDecodeType_Audio = 1 << 1
};

typedef NS_OPTIONS(NSInteger, MMPixelFormatType) {
    MMPixelFormatTypeFullRangeYUV  = 1 << 0,
    MMPixelFormatTypeVideoRangeYUV = 1 << 1,
    MMPixelFormatTypeBGRA          = 1 << 2,
};

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

typedef NS_OPTIONS(NSUInteger, MMFFParseType) {
    MMFFParseType_Video = 1 << 0,
    MMFFParseType_Audio = 1 << 1
};

#endif /* MMBaseDefine_h */
