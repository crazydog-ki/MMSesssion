// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#ifndef MMBaseDefine_h
#define MMBaseDefine_h

#define CREATE_SERIAL_QUEUE dispatch_queue_create(typeid(*this).name(), DISPATCH_QUEUE_SERIAL)
#define CREATE_SERIAL_QUEUE2(name) dispatch_queue_create(name, DISPATCH_QUEUE_SERIAL)

typedef NS_OPTIONS(NSUInteger, MMDecodeType) {
    MMDecodeType_Video = 1 << 0,
    MMDecodeType_Audio = 1 << 1
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

typedef NS_OPTIONS(NSUInteger, MMYUVType) {
    MMYUVType_Y = 1 << 0,
    MMYUVType_U = 1 << 1,
    MMYUVType_V = 1 << 2,
};

#endif /* MMBaseDefine_h */
