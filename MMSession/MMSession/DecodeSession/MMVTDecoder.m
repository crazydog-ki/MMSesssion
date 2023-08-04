// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMVTDecoder.h"
#import <VideoToolbox/VideoToolbox.h>
#ifdef __cplusplus
extern "C" {
#endif
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/samplefmt.h"
#include "libswresample/swresample.h"
#include "libavutil/pixdesc.h"
#ifdef __cplusplus
};
#endif

@interface MMVTDecoder () {
    VTDecompressionSessionRef _decompressionSession;
}
@property (nonatomic, strong) MMDecodeConfig *config;
@end

@implementation MMVTDecoder
- (instancetype)initWithConfig:(MMDecodeConfig *)config {
    if (self = [super init]) {
        _config = config;
        [self _initVt];
    }
    return self;
}

#pragma mark - Private
void vt_decode_callback(void *decompressionOutputRefCon,
                        void *sourceFrameRefCon,
                        OSStatus status,
                        VTDecodeInfoFlags infoFlags,
                        CVImageBufferRef imageBuffer,
                        CMTime presentationTimeStamp,
                        CMTime presentationDuration) {
    if (status != noErr) {
        NSLog(@"[yjx] vt_decode_callback - %d", status);
        return;
    }
}

static CFDictionaryRef _create_attributes(int width, int height, OSType pix_fmt) {
    CFMutableDictionaryRef attributes;
    attributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef properties;
    properties = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    CFNumberRef w = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &width);
    CFNumberRef h = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &height);
    CFNumberRef pixelfmt = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pix_fmt);
    CFDictionarySetValue(attributes, kCVPixelBufferPixelFormatTypeKey, pixelfmt);

    CFDictionarySetValue(attributes, kCVPixelBufferIOSurfacePropertiesKey, properties);
    if (0<width && 0<height) {
        CFDictionarySetValue(attributes, kCVPixelBufferWidthKey, w);
        CFDictionarySetValue(attributes, kCVPixelBufferHeightKey, h);
    }
    CFDictionarySetValue(attributes, kCVPixelBufferOpenGLESCompatibilityKey, kCFBooleanTrue);
    
    CFRelease(properties);
    CFRelease(pixelfmt);
    CFRelease(w);
    CFRelease(h);

    return attributes;
}

- (void)_initVt {
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = vt_decode_callback;
    callBackRecord.decompressionOutputRefCon = NULL;

    int w = (int)_config.targetSize.width;
    int h = (int)_config.targetSize.width;
    CFDictionaryRef attrs = _create_attributes(w, h, kCVPixelFormatType_32BGRA);
    OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                   _config.vtDesc,
                                                   NULL,
                                                   attrs,
                                                   &callBackRecord,
                                                   &_decompressionSession);
    if (status != noErr) {
        NSLog(@"[yjx] VTDecompressionSessionCreate - %d", status);
    }
}

#pragma mark - MMSessionProcessProtocol
- (void)processSampleData:(MMSampleData *)sampleData {
    if (!_decompressionSession) return;
    
    CMSampleBufferRef parseBuffer = sampleData.sampleBuffer;
    OSStatus status = VTDecompressionSessionDecodeFrame(_decompressionSession,
                                                        parseBuffer,
                                                        kVTDecodeFrame_EnableAsynchronousDecompression,
                                                        NULL, NULL);
    if (status != noErr) {
        NSLog(@"[yjx] VTDecompressionSessionDecodeFrame - %d", status);
    }
    
    if (parseBuffer) {
        CFRelease(parseBuffer);
        parseBuffer = NULL;
    }
}
@end
