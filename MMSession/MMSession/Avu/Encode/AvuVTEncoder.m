#import "AvuVTEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@implementation AvuVideoEncodeAttr
@end

@interface AvuVTEncoder()
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) dispatch_queue_t vtEncodeQueue;
@property (nonatomic, strong) NSMutableArray *nextNodes;
@property (nonatomic, assign) VTCompressionSessionRef encodeSession;
@end

@implementation AvuVTEncoder
#pragma mark - AvuBufferProcessProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _vtEncodeQueue = dispatch_queue_create("avu_vt_encode_queue", DISPATCH_QUEUE_SERIAL);
        _nextNodes = [NSMutableArray array];
        [self _initVtEncoder];
    }
    return self;
}

- (void)processBuffer:(AvuBuffer *)buffer {
    dispatch_sync(self.vtEncodeQueue, ^{
        OSStatus status = noErr;
        // CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime pts = CMTimeMake(buffer.pts * 10000, 10000);
        NSLog(@"[avu] encode pts: %lf, %p", buffer.pts, buffer.pixelBuffer);
        
        AvuVideoEncodeAttr *attr = [[AvuVideoEncodeAttr alloc] init];
        VTEncodeInfoFlags infoFlags;
        CVPixelBufferRef pixelBuffer = buffer.pixelBuffer;
        status = VTCompressionSessionEncodeFrame(_encodeSession, pixelBuffer, pts, kCMTimeInvalid, NULL, (void *)CFBridgingRetain(attr), &infoFlags);
        
        if (status != noErr) {
            VTCompressionSessionInvalidate(_encodeSession);
            CFRelease(_encodeSession);
            _encodeSession = NULL;
            NSLog(@"[avu] vt encode frame failed: %d", status);
        }
    });
}

- (void)addNextNode:(id<AvuBufferProcessProtocol>)node {
    dispatch_sync(self.vtEncodeQueue, ^{
        [self.nextNodes addObject:node];
    });
}

#pragma mark - Public
- (void)cleanupSession {
    if (_encodeSession) {
        OSStatus status = VTCompressionSessionCompleteFrames(_encodeSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(_encodeSession);
        CFRelease(_encodeSession);
        _encodeSession = nil;
    }
}

- (void)dealloc {
    [self _finishEncode];
}

#pragma mark - Private
- (void)_initVtEncoder {
    dispatch_sync(_vtEncodeQueue, ^{
        OSType pixelFormat;
        if (_config.pixelFormat == AvuPixelFormatType_RGBA) {
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
                                   avu_vt_encode_callback,
                                   (__bridge void *)self,
                                   &_encodeSession);
        if (status == noErr) {
            NSLog(@"[avu] vt encoder create success");
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
            NSLog(@"[avu] vt encoder set properties success");
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

void avu_vt_encode_callback(void *outputCallbackRefCon,
                        void *sourceFrameRefCon,
                        OSStatus status,
                        VTEncodeInfoFlags infoFlags,
                        CMSampleBufferRef sampleBuffer) {
    AvuVTEncoder *encoder = (__bridge AvuVTEncoder *)outputCallbackRefCon;
    if (status != noErr) {
        NSLog(@"[avu] vt encoder callback error: %d", status);
        return;
    }
    
    // AvuVideoEncodeAttr *attrib = (AvuVideoEncodeAttr *)CFBridgingRelease(sourceFrameRefCon);
    
    AvuBuffer *buffer = [[AvuBuffer alloc] init];
    buffer.type = AvuBufferType_Video;
    buffer.sampleBuffer = sampleBuffer;
    
    for (id<AvuBufferProcessProtocol> node in encoder.nextNodes) {
        [node processBuffer:buffer];
    }
}
@end
