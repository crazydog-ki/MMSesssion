#import "AvuVTDecoder.h"
#import <VideoToolbox/VideoToolbox.h>

@implementation AvuVideoFrameInfo
@end

@interface AvuVTDecoder ()
{
    VTDecompressionSessionRef _vtSession;
}
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) NSMutableArray *nextNodes;
@property (nonatomic, strong) dispatch_queue_t vtDecodeQueue;
@end

@implementation AvuVTDecoder
#pragma mark - AvuBufferProcessProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _nextNodes = [NSMutableArray array];
        _vtDecodeQueue = dispatch_queue_create("avu_vt_decode_queue", DISPATCH_QUEUE_SERIAL);
        [self _initVtSession];
    }
    return self;
}

- (void)processBuffer:(AvuBuffer *)buffer {
    dispatch_sync(self.vtDecodeQueue, ^{
        [self _decode:buffer];
    });
}

- (void)addNextNode:(id<AvuBufferProcessProtocol>)node {
    dispatch_sync(self.vtDecodeQueue, ^{
        [self.nextNodes addObject:node];
    });
}

#pragma mark - Public
- (void)stopDecode {
    dispatch_sync(self.vtDecodeQueue, ^{
        if (_vtSession) {
            VTDecompressionSessionWaitForAsynchronousFrames(_vtSession);
            VTDecompressionSessionInvalidate(_vtSession);
            CFRelease(_vtSession);
            _vtSession = nil;
        }
    });
}

- (void)flush {
    dispatch_sync(self.vtDecodeQueue, ^{
        VTDecompressionSessionWaitForAsynchronousFrames(_vtSession);
    });
}

- (void)dealloc {
    [self stopDecode];
}

#pragma mark - Private
- (void)_initVtSession {
    int width = (int)_config.videoSize.width;
    int height = (int)_config.videoSize.height;
    
    OSType pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    if (_config.formatType == AvuPixelFormatType_RGBA) {
        pixelFormat = kCVPixelFormatType_32BGRA;
    }
    
    /// vt attribute
    const void *keys[] = {
        kCVPixelBufferPixelFormatTypeKey,
        kCVPixelBufferWidthKey,
        kCVPixelBufferHeightKey};
    const void *values[] = {
        CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pixelFormat),
        CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &width),
        CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &height)
    };
    CFDictionaryRef attrs = CFDictionaryCreate(NULL, keys, values, 3, NULL, NULL);
    
    /// vt callback
    VTDecompressionOutputCallbackRecord callbackFunc;
    callbackFunc.decompressionOutputCallback = VTDecodeCallback;
    callbackFunc.decompressionOutputRefCon = (__bridge void *_Nullable)(self);
    
    /// vt session
    VTDecompressionSessionRef session = nil;
    OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                   _config.vtDesc,
                                                   NULL,
                                                   attrs,
                                                   &callbackFunc,
                                                   &session);
    if (status != noErr) {
        if (self.decodeErrorCallback) {
            NSError *error = [NSError errorWithDomain:@"avu_decode"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"avu_decode_vt_session_create_error"}];
            self.decodeErrorCallback(AvuDecodeErrorType_Decode, error);
        }
        NSLog(@"[avu] create vt session error: %d", status);
    }
    if (attrs) {
        CFRelease(attrs);
        attrs = NULL;
    }
    _vtSession = session;
}

- (BOOL)_decode:(AvuBuffer *)buffer {
    AvuVideoFrameInfo *bufferInfo = [[AvuVideoFrameInfo alloc] init];
    bufferInfo.dts = buffer.dts;
    bufferInfo.pts = buffer.pts;
    bufferInfo.duration = buffer.duration;
    OSStatus status = VTDecompressionSessionDecodeFrame(_vtSession,
                                                        buffer.sampleBuffer, 0,
                                                        (void *)CFBridgingRetain(bufferInfo), 0);
    if (status == noErr) {
        return YES;
    } else {
        if (self.decodeErrorCallback) {
            NSError *error = [NSError errorWithDomain:@"avu_decode"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"avu_decode_vt_session_decode_error"}];
            self.decodeErrorCallback(AvuDecodeErrorType_Decode, error);
        }
        return NO;
    }
}

void VTDecodeCallback(void *decompressionOutputRefCon,
                      void *sourceFrameRefCon,
                      OSStatus status,
                      VTDecodeInfoFlags infoFlags,
                      CVImageBufferRef imageBuffer,
                      CMTime presentationTimeStamp,
                      CMTime presentationDuration) {
    AvuVideoFrameInfo *info = (AvuVideoFrameInfo *)CFBridgingRelease(sourceFrameRefCon);
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)imageBuffer;
    AvuBuffer *buffer = [[AvuBuffer alloc] init];
    buffer.type = AvuBufferType_Video;
    buffer.pts = info.pts;
    buffer.dts = info.dts;
    buffer.duration = info.duration;
    buffer.pixelBuffer = pixelBuffer;
    
    AvuVTDecoder *vtDecoder = (__bridge AvuVTDecoder *)decompressionOutputRefCon;
    for (id<AvuBufferProcessProtocol> node in vtDecoder.nextNodes) {
        [node processBuffer:buffer];
    }
}
@end
