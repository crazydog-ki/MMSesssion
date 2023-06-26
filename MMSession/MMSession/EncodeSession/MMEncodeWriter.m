// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMEncodeWriter.h"

static const char *WRITER_QUEUE = "mmsession_camera_compile_queue";

@interface MMEncodeWriter ()
@property (nonatomic, strong) MMEncodeConfig *config;
@property (nonatomic, strong) dispatch_queue_t writerQueue;
@property (nonatomic, strong) AVAssetWriter *assetWriter;

@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *videoAdaptor;

@property (nonatomic, strong) AVAssetWriterInput *audioWriterInput;

@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, assign) BOOL stopFlag;
@end

@implementation MMEncodeWriter
#pragma mark - Public
- (instancetype)initWithConfig:(MMEncodeConfig *)config {
    if (self = [super init]) {
        _config = config;
        _writerQueue = dispatch_queue_create(WRITER_QUEUE, DISPATCH_QUEUE_SERIAL);
        _isFirstFrame = YES;
        _stopFlag = YES;
        [self _initWriter];
    }
    return self;
}

- (void)startEncode {
    dispatch_sync(_writerQueue, ^{
        _stopFlag = NO;
        if (self.assetWriter.status == AVAssetWriterStatusUnknown && [self.assetWriter startWriting]) {
            NSLog(@"[yjx] start encode success");
        } else {
            NSLog(@"[yjx] start encode error status: %zd", self.assetWriter.status);
        }
    });
}

- (void)stopEncodeWithCompleteHandle:(CompleteHandle)handler {
    void (^completionHandler)(void) = ^{
        if (self.assetWriter.error || self.assetWriter.status != AVAssetWriterStatusCompleted) {
            handler(nil, [[NSError alloc] init]);
        } else {
            handler(self.config.outputUrl, nil);
        }
        NSLog(@"[yjx] write encode finish");
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

#pragma mark - MMSessionProcessProtocol
- (void)processSampleData:(MMSampleData *)sampleData {
    if (_stopFlag) {
        return;
    }
    
    if (sampleData.statusFlag == MMSampleDataFlagEnd) {
        if (self.endEncodeBlk) {
            self.endEncodeBlk();
        }
        return;
    }
    
    BOOL isVideo = (sampleData.dataType==MMSampleDataType_Decoded_Video);
    CMSampleBufferRef sampleBuffer = sampleData.sampleBuffer;
    
    CFRetain(sampleBuffer);
    dispatch_async(_writerQueue, ^{
        CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        double ptsSec = CMTimeGetSeconds(frameTime);
        if (self.isFirstFrame) {
            if (self.assetWriter.status == AVAssetWriterStatusUnknown && [self.assetWriter startWriting]) {
                NSLog(@"[yjx] start encode success, pts: %lf", ptsSec);
            }
            [self.assetWriter startSessionAtSourceTime:frameTime];
            self.isFirstFrame = NO;
        }
        if (isVideo) {
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
                NSLog(@"[yjx] encode drop video frame-2, pts: %lf", ptsSec);
            }
        } else {
            if (self.audioWriterInput.readyForMoreMediaData && self.assetWriter.status == AVAssetWriterStatusWriting) {
                if (![self.audioWriterInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"[yjx] encode drop audio frame-1, pts: %lf", ptsSec);
                }
            } else {
                NSLog(@"[yjx] encode drop audio frame-2, pts: %lf", ptsSec);
            }
        }
        
        CFRelease(sampleBuffer);
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
        _videoWriterInput.transform = CGAffineTransformMakeRotation(_config.roration);
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
