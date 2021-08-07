// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki
#import "MMVTEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface MMVTEncoder()
@property (nonatomic, strong) MMEncodeConfig *config;
@property (nonatomic, strong) dispatch_queue_t vtEncoderQueue;
@property (nonatomic, assign) VTCompressionSessionRef encodeSession;
@end

@implementation MMVTEncoder
#pragma mark - Public
- (instancetype)initWithConfig:(MMEncodeConfig *)config {
    if (self = [super init]) {
        _config = config;
        _vtEncoderQueue = dispatch_queue_create("mmsession_vt_encoder_queue", DISPATCH_QUEUE_SERIAL);
        [self _initVtEncoder];
    }
    return self;
}

- (void)processSampleData:(MMSampleData *)sampleData {
    dispatch_sync(_vtEncoderQueue, ^{
        CMTime pts = sampleData.pts;
        OSStatus status = noErr;
        
        if (sampleData.flag == MMSampleDataFlagEnd) {
            [self _finishEncode];
            NSLog(@"[yjx] vt encode finish");
            return;
        }
        
        VTEncodeInfoFlags infoFlags;
        if (sampleData.dataType == MMSampleDataType_Parsed_Video) {
            CVPixelBufferRef pixelBuffer = sampleData.pixelBuffer;
            status = VTCompressionSessionEncodeFrame(_encodeSession, pixelBuffer, pts, kCMTimeInvalid, NULL, NULL, &infoFlags);
        } else if (sampleData.dataType == MMSampleDataType_Parsed_Audio) {
            
        }
        
        if (status != noErr) {
            VTCompressionSessionInvalidate(_encodeSession);
            CFRelease(_encodeSession);
            _encodeSession = NULL;
            NSLog(@"[yjx] vt encode frame failed: %d", status);
        }
    });
}

#pragma mark - Private
- (void)_initVtEncoder {
    dispatch_sync(_vtEncoderQueue, ^{
        OSType pixelFormat;
        if (_config.pixelFormat == MMPixelFormatTypeBGRA) {
            pixelFormat = kCVPixelFormatType_32BGRA;
        } else {
            pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        }
        
        CGFloat w = _config.videoSize.width;
        CGFloat h = _config.videoSize.height;
        NSDictionary *videoAttr = @{
            (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(pixelFormat),
            (__bridge NSString *)kCVPixelBufferWidthKey: @(w),
            (__bridge NSString *)kCVPixelBufferHeightKey: @(h),
        };
        
        OSStatus status = noErr;
        status = VTCompressionSessionCreate(kCFAllocatorDefault, w, h,
                                   kCMVideoCodecType_H264,
                                   NULL,
                                   (__bridge CFDictionaryRef)videoAttr,
                                   NULL,
                                   vt_encode_callback,
                                   (__bridge void *)self,
                                   &_encodeSession);
        if (status == noErr) {
            NSLog(@"[yjx] vt encoder create success");
        }
        
        status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge void *)[NSNumber numberWithFloat:_config.keyframeInterval]);
        CFBooleanRef isBFrame = _config.isBFrame ? kCFBooleanTrue : kCFBooleanFalse;
        status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_AllowFrameReordering, isBFrame);
        CFBooleanRef isRealtime = _config.isRealtime ? kCFBooleanTrue : kCFBooleanFalse;
        status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_RealTime, isRealtime);
        status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef _Nonnull)[NSNumber numberWithFloat:_config.bitrate]);
        if (status == noErr) {
            NSLog(@"[yjx] vt encoder set properties success");
            VTCompressionSessionPrepareToEncodeFrames(_encodeSession);
        }
    });
}

- (void)_finishEncode {
    if (_encodeSession) {
        VTCompressionSessionCompleteFrames(_encodeSession, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(_encodeSession);
        CFRelease(_encodeSession);
        _encodeSession = NULL;
    }
}

- (void)dealloc {
    [self _finishEncode];
}

void vt_encode_callback(void *outputCallbackRefCon,
                        void *sourceFrameRefCon,
                        OSStatus status,
                        VTEncodeInfoFlags infoFlags,
                        CMSampleBufferRef sampleBuffer) {
    MMVTEncoder *encoder = (__bridge MMVTEncoder *)outputCallbackRefCon;
    if (status != noErr) {
        NSLog(@"[yjx] vt encoder callback error: %d", status);
    }
    NSLog(@"[yjx] receive samplebuffer: %p", sampleBuffer);
}
@end
