// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki
#import "MMVTEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface MMVTEncoder()
@property (nonatomic, strong) MMEncodeConfig *config;
@property (nonatomic, strong) dispatch_queue_t vtEncoderQueue;
@property (nonatomic, assign) VTCompressionSessionRef encodeSession;
@property (nonatomic, strong) NSMutableArray *nextVideoNodes;
@end

@implementation MMVTEncoder
#pragma mark - Public
- (instancetype)initWithConfig:(MMEncodeConfig *)config {
    if (self = [super init]) {
        _config = config;
        _nextVideoNodes = [NSMutableArray array];
        _vtEncoderQueue = dispatch_queue_create("mmsession_vt_encoder_queue", DISPATCH_QUEUE_SERIAL);
        [self _initVtEncoder];
    }
    return self;
}

- (void)dealloc {
    [self _finishEncode];
}

#pragma mark - MMSessionProcessProtocol
//- (void)processSampleData:(MMSampleData *)sampleData {
//    dispatch_sync(_vtEncoderQueue, ^{
//        OSStatus status = noErr;
//        
//        if (sampleData.statusFlag == MMSampleDataFlagEnd) {
//            [self _finishEncode];
//            NSLog(@"[mm] vt encode finish");
//            return;
//        }
//        
//        CMSampleBufferRef sampleBuffer = sampleData.sampleBuffer;
//        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
//        
//        VTEncodeInfoFlags infoFlags;
//        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//        status = VTCompressionSessionEncodeFrame(_encodeSession, pixelBuffer, pts, kCMTimeInvalid, NULL, NULL, &infoFlags);
//        
//        if (status != noErr) {
//            VTCompressionSessionInvalidate(_encodeSession);
//            CFRelease(_encodeSession);
//            _encodeSession = NULL;
//            NSLog(@"[mm] vt encode frame failed: %d", status);
//        }
//    });
//}

//- (void)addNextVideoNode:(id<MMSessionProcessProtocol>)node {
//    dispatch_sync(_vtEncoderQueue, ^{
//        [self.nextVideoNodes addObject:node];
//    });
//}

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
            NSLog(@"[mm] vt encoder create success");
        }
        
        /// 最大关键帧间隔
        status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge void *)[NSNumber numberWithFloat:_config.keyframeInterval]);
        
        /// B帧
        CFBooleanRef isBFrame = _config.allowBFrame ? kCFBooleanTrue : kCFBooleanFalse;
        status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_AllowFrameReordering, isBFrame);
        
        /// 实时编码
        CFBooleanRef isRealtime = _config.allowRealtime ? kCFBooleanTrue : kCFBooleanFalse;
        status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_RealTime, isRealtime);
        
        /// 码率
        status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef _Nonnull)[NSNumber numberWithFloat:_config.bitrate]);
        if (status == noErr) {
            NSLog(@"[mm] vt encoder set properties success");
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

void vt_encode_callback(void *outputCallbackRefCon,
                        void *sourceFrameRefCon,
                        OSStatus status,
                        VTEncodeInfoFlags infoFlags,
                        CMSampleBufferRef sampleBuffer) {
    MMVTEncoder *encoder = (__bridge MMVTEncoder *)outputCallbackRefCon;
    if (status != noErr) {
        NSLog(@"[mm] vt encoder callback error: %d", status);
        return;
    }
    
    if (encoder.nextVideoNodes) {
//        for (id<MMSessionProcessProtocol> node in encoder.nextVideoNodes) {
//            MMSampleData *sampleData = [[MMSampleData alloc] init];
//            sampleData.sampleBuffer = sampleBuffer;
//            sampleData.dataType = MMSampleDataType_Decoded_Video;
//            [node processSampleData:sampleData];
//        }
    }
}
@end
