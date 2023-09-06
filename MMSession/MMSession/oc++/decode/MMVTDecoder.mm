// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMVTDecoder.h"

struct MMVTAttribute {
    double pts = 0.0f;
    bool reachEof = false;
};

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
    
    MMVTAttribute* attr = (MMVTAttribute*)sourceFrameRefCon;
    
    std::shared_ptr<MMSampleData> data = make_shared<MMSampleData>();
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)imageBuffer;
    CVPixelBufferRetain(pixelBuffer);
    data->videoBuffer = pixelBuffer;
    data->pts = attr->pts;
    data->isEof = attr->reachEof;
    if (!vtDecoder->m_nextVideoUnits.empty()) {
        for (shared_ptr<MMUnitBase> unit : vtDecoder->m_nextVideoUnits) {
            unit->process(data);
        }
    }
    CVPixelBufferRelease(pixelBuffer);
    if (attr) {
        delete attr;
        attr = nullptr;
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
    _initVt();
}

void MMVTDecoder::process(std::shared_ptr<MMSampleData> &data) {
    if (!m_vtDecodeSession) return;
    CMSampleBufferRef parsedBuffer = data->videoSample; //被压缩的视频帧
    if (!parsedBuffer || data->isEof) {
        for (auto unit : m_nextVideoUnits) {
            unit->process(data);
        }
        return;
    }
    
    CFRetain(parsedBuffer);
    
    MMVTAttribute *attr = new MMVTAttribute(); //需要传指针，解码是异步
    attr->pts = data->pts;
    attr->reachEof = data->isEof;
    
    VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
    VTDecodeInfoFlags flagOut;
    OSStatus status = VTDecompressionSessionDecodeFrame(m_vtDecodeSession,
                                                        parsedBuffer,
                                                        flags,
                                                        attr, //其他参数传递
                                                        &flagOut); //获取解码操作信息
    if (status != noErr) {
        std::cout << "[yjx] VTDecompressionSessionDecodeFrame - " << status << std::endl;
        if (attr) {
            delete attr;
            attr = nullptr;
        }
    }
    
    CFRelease(parsedBuffer);
    data->videoSample = nullptr; //这里不置空，MMSampleData析构函数内部可能会double free
}

MMVTDecoder::~MMVTDecoder() {
    cout << "[yjx] MMVTDecoder::~MMVTDecoder()" << endl;
    if (m_vtDecodeSession) {
        VTDecompressionSessionInvalidate(m_vtDecodeSession);
        CFRelease(m_vtDecodeSession);
        m_vtDecodeSession = nullptr;
        cout << "[yjx] vt decoder destroyed" << endl;
    }
}

#pragma mark - Private
void MMVTDecoder::_initVt() {
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = vt_decode_callback;
    callBackRecord.decompressionOutputRefCon = (void *)this;
    
    int w = (int)m_config.targetSize.width;
    int h = (int)m_config.targetSize.height;
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
