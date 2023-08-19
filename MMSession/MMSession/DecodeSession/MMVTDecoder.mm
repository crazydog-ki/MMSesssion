// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMVTDecoder.h"

void vt_decode_callback(void *decompressionOutputRefCon,
                        void *sourceFrameRefCon,
                        OSStatus status,
                        VTDecodeInfoFlags infoFlags,
                        CVImageBufferRef imageBuffer,
                        CMTime presentationTimeStamp,
                        CMTime presentationDuration) {
    if (status != noErr) {
        std::cout << "[yjx] vt_decode_callback - " << status << std::endl;
        return;
    }
    MMVTDecoder *vtDecoder = (MMVTDecoder *)(decompressionOutputRefCon);
    if (!vtDecoder) {
        return;
    }
    
    MMSampleData *rawData = (MMSampleData *)sourceFrameRefCon;
    rawData->videoBuffer = (CVPixelBufferRef)imageBuffer;
    
    std::shared_ptr<MMSampleData> data(rawData); //接管其声明周期
    if (!vtDecoder->m_nextVideoUnits.empty()) {
        for (MMUnitBase *unit : vtDecoder->m_nextVideoUnits) {
            unit->process(data);
        }
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

MMVTDecoder::MMVTDecoder(MMDecodeConfig config): m_config(config) {
}

void MMVTDecoder::process(std::shared_ptr<MMSampleData> &data) {
    if (!m_vtDecodeSession) return;
    CMSampleBufferRef parsedBuffer = data->videoSample;
    
    CFRetain(parsedBuffer);
    
    VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
    VTDecodeInfoFlags flagOut;
    OSStatus status = VTDecompressionSessionDecodeFrame(m_vtDecodeSession,
                                                        parsedBuffer,
                                                        flags,
                                                        (void *)data.get(), //其他参数传递
                                                        &flagOut); //获取解码操作信息
    if (status != noErr) {
        std::cout << "[yjx] VTDecompressionSessionDecodeFrame - " << status << std::endl;
    }
    
    if (parsedBuffer) {
        CFRelease(parsedBuffer);
    }
}

#pragma mark - Private
void MMVTDecoder::_initVt() {
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = vt_decode_callback;
    callBackRecord.decompressionOutputRefCon = (void *)this;
    
    int w = (int)m_config.targetSize.width;
    int h = (int)m_config.targetSize.width;
    OSType pixelformat = NULL;
    switch (m_config.pixelformat) {
        case MMPixelFormatTypeBGRA:
            pixelformat = kCVPixelFormatType_32BGRA;
            break;
        case MMPixelFormatTypeFullRangeYUV:
            pixelformat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
            break;
        case MMPixelFormatTypeVideoRangeYUV:
            pixelformat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
            break;
        default:
            break;
    }
    CFDictionaryRef attrs = _create_attributes(w, h, pixelformat);
    OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                   m_config.vtDesc,
                                                   NULL,
                                                   attrs,
                                                   &callBackRecord,
                                                   &m_vtDecodeSession);
    if (status != noErr) {
        std::cout << "[yjx] VTDecompressionSessionCreate - " << status << std::endl;
    }
}
