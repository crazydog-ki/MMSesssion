#import "AvuWriterEncoder.h"
#import <AVFoundation/AVFoundation.h>

@interface AvuWriterEncoder()
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) dispatch_queue_t writerQueue;

@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *videoAdaptor;
@property (nonatomic, strong) AVAssetWriterInput *audioWriterInput;

@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, assign) BOOL stopFlag;
@end

@implementation AvuWriterEncoder
#pragma mark - AvuBufferProcessProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _writerQueue = dispatch_queue_create("avu_encode_writer_queue", DISPATCH_QUEUE_SERIAL);
        _isFirstFrame = YES;
        _stopFlag = YES;
        [self _initWriter];
    }
    return self;
}

- (void)processBuffer:(AvuBuffer *)buffer {
    dispatch_sync(self.writerQueue, ^{
        if (_stopFlag) {
            return;
        }
        
        BOOL isVideo = buffer.type==AvuBufferType_Video;
        CMSampleBufferRef sampleBuffer = isVideo ? buffer.sampleBuffer : buffer.audioBuffer;
        
        CFRetain(sampleBuffer);
        dispatch_async(_writerQueue, ^{
            if (isVideo) {
                CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                double ptsSec = CMTimeGetSeconds(frameTime);
                
                if (self.isFirstFrame) {
                    if (self.assetWriter.status == AVAssetWriterStatusUnknown && [self.assetWriter startWriting]) {
                        NSLog(@"[avu] start encode success, pts: %lf", ptsSec);
                    }
                    [self.assetWriter startSessionAtSourceTime:frameTime];
                    self.isFirstFrame = NO;
                }
                
                BOOL onlyMux = self->_config.onlyMux;
                CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                if (self.videoWriterInput.readyForMoreMediaData && self.assetWriter.status == AVAssetWriterStatusWriting) {
                    BOOL ret = false;
                    if (onlyMux) {
                        ret = [self.videoWriterInput appendSampleBuffer:sampleBuffer];
                    } else {
                        ret = [self.videoAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:frameTime];
                    }
                } else {
                    NSLog(@"[avu] encode drop video frame-2, pts: %lf", ptsSec);
                }
            } else {
                CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                double ptsSec = CMTimeGetSeconds(frameTime);
                
                if (self.isFirstFrame) {
                    if (self.assetWriter.status == AVAssetWriterStatusUnknown && [self.assetWriter startWriting]) {
                        NSLog(@"[avu] start encode success, pts: %lf", ptsSec);
                    }
                    [self.assetWriter startSessionAtSourceTime:frameTime];
                    self.isFirstFrame = NO;
                }
                
                if (self.audioWriterInput.readyForMoreMediaData && self.assetWriter.status == AVAssetWriterStatusWriting) {
                    if (![self.audioWriterInput appendSampleBuffer:sampleBuffer]) {
                        NSLog(@"[avu] encode drop audio frame-1, pts: %lf", ptsSec);
                    }
                } else {
                    NSLog(@"[avu] encode drop audio frame-2, pts: %lf", ptsSec);
                }
            }
            
            CFRelease(sampleBuffer);
        });
    });
}

#pragma mark - Public
- (void)startEncode {
    dispatch_sync(_writerQueue, ^{
        _stopFlag = NO;
        if (self.assetWriter.status == AVAssetWriterStatusUnknown && [self.assetWriter startWriting]) {
            NSLog(@"[avu] start encode success");
        } else {
            NSLog(@"[avu] start encode error status: %zd", self.assetWriter.status);
        }
    });
}

- (void)cancelEncode {
    dispatch_sync(_writerQueue, ^{
        [self.videoWriterInput markAsFinished];
        [self.audioWriterInput markAsFinished];
        [self.assetWriter cancelWriting];
    });
}

- (void)stopEncodeWithCompleteHandle:(AvuCompleteHandle)handler {
    void (^completionHandler)(void) = ^{
        if (self.assetWriter.error || self.assetWriter.status != AVAssetWriterStatusCompleted) {
            handler(nil, [[NSError alloc] init]);
        } else {
            handler(self.config.outputUrl, nil);
        }
        NSLog(@"[avu] complete encode success");
    };
    
    dispatch_sync(_writerQueue, ^{
        _stopFlag = YES;
        if (self.assetWriter.status == AVAssetWriterStatusWriting) {
            [self.videoWriterInput markAsFinished];
            
            if ([self.assetWriter respondsToSelector:@selector(finishWritingWithCompletionHandler:)]) {
                [self.assetWriter finishWritingWithCompletionHandler:completionHandler];
            }
        }
    });
}

#pragma mark - Private
- (void)_initWriter {
    NSError *error;
    _assetWriter = [[AVAssetWriter alloc] initWithURL:_config.outputUrl fileType:AVFileTypeQuickTimeMovie error:&error];
    _assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, 1000);
    
    BOOL onlyMux = _config.onlyMux;
    NSDictionary *videoSettings = onlyMux ? nil : _config.videoSetttings;
    /// video
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    if (!onlyMux) {
        _videoWriterInput.expectsMediaDataInRealTime = YES;
        // _videoWriterInput.transform = CGAffineTransformMakeRotation(_config.roration);
        _videoAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoWriterInput sourcePixelBufferAttributes:_config.pixelBufferAttributes];
    }

    if ([_assetWriter canAddInput:_videoWriterInput]) {
        [_assetWriter addInput:_videoWriterInput];
    }
    
    /// audio
    _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:_config.audioSetttings];
    if (!onlyMux) {
        _audioWriterInput.expectsMediaDataInRealTime = YES;
    }
    if ([_assetWriter canAddInput:_audioWriterInput]) {
        [_assetWriter addInput:_audioWriterInput];
    }
}
@end
