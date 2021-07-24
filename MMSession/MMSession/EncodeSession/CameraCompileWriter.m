// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "CameraCompileWriter.h"

@interface CameraCompileWriter ()

@property (nonatomic, strong) CameraCompileWriterConfig *config;
@property (nonatomic, strong) dispatch_queue_t writerQueue;
@property (nonatomic, strong) AVAssetWriter *assetWriter;

@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *videoAdaptor;

@property (nonatomic, strong) AVAssetWriterInput *audioWriterInput;

@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, assign) BOOL stopFlag;

@end

@implementation CameraCompileWriter

- (instancetype)initWithConfig:(CameraCompileWriterConfig *)config {
    if (self = [super init]) {
        _config = config;
        _writerQueue = dispatch_queue_create("mmsession_camera_compile_queue", DISPATCH_QUEUE_SERIAL);
        _isFirstFrame = YES;
        _stopFlag = YES;
        [self _initWriter];
    }
    return self;
}

- (void)startRecord {
    dispatch_sync(_writerQueue, ^{
        _stopFlag = NO;
        if (self.assetWriter.status == AVAssetWriterStatusUnknown && [self.assetWriter startWriting]) {
            NSLog(@"[yjx] start writing");
        } else {
            NSLog(@"[yjx] start writing error status: %zd", self.assetWriter.status);
        }
    });
}

- (void)stopRecordWithCompleteHandle:(CompleteHandle)handler {
    void (^completionHandler)(void) = ^{
        if (self.assetWriter.error || self.assetWriter.status != AVAssetWriterStatusCompleted) {
            handler(nil, [[NSError alloc] init]);
        } else {
            handler(self.config.outputUrl, nil);
        }
        NSLog(@"[yjx] stop writing");
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

- (void)processVideoBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_stopFlag) {
        return;
    }
    
    CFRetain(sampleBuffer);
    dispatch_async(_writerQueue, ^{
        CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        NSLog(@"[yjx] video pts: %lf", CMTimeGetSeconds(frameTime));
        
        if (self.isFirstFrame) {
            // startRecord可提前初始化编码器
            if (self.assetWriter.status == AVAssetWriterStatusUnknown && [self.assetWriter startWriting]) {
                NSLog(@"[yjx] start writing success");
            }
            [self.assetWriter startSessionAtSourceTime:frameTime];
            self.isFirstFrame = NO;
        }
        
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (self.videoWriterInput.readyForMoreMediaData && self.assetWriter.status == AVAssetWriterStatusWriting) {
            if (![self.videoAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:frameTime]) {
                NSLog(@"[youjianxia] drop video frame-1");
            }
        } else {
            NSLog(@"[youjianxia] drop video frame-2");
        }
        CFRelease(sampleBuffer);
    });
}

- (void)processAudioBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_stopFlag) {
        return;
    }
    
    CFRetain(sampleBuffer);
    dispatch_async(_writerQueue, ^{
        CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        NSLog(@"[yjx] audio pts: %lf", CMTimeGetSeconds(frameTime));
        
        if (self.isFirstFrame) {
            // startRecord可提前初始化编码器
            if (self.assetWriter.status == AVAssetWriterStatusUnknown && [self.assetWriter startWriting]) {
                NSLog(@"[yjx] start writing success");
            }
            [self.assetWriter startSessionAtSourceTime:frameTime];
            self.isFirstFrame = NO;
        }
        
        if (self.audioWriterInput.readyForMoreMediaData && self.assetWriter.status == AVAssetWriterStatusWriting) {
            [self.audioWriterInput appendSampleBuffer:sampleBuffer];
        }
        CFRelease(sampleBuffer);
    });
}

#pragma mark - Private
- (void)_initWriter {
    NSError *error;
    _assetWriter = [[AVAssetWriter alloc] initWithURL:_config.outputUrl fileType:AVFileTypeQuickTimeMovie error:&error];
    
    // video
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:_config.videoSetttings];
    _videoWriterInput.expectsMediaDataInRealTime = YES;
    _videoAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoWriterInput sourcePixelBufferAttributes:_config.pixelBufferAttributes];

    if ([_assetWriter canAddInput:_videoWriterInput]) {
        [_assetWriter addInput:_videoWriterInput];
    }
    
    // audio
    _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:_config.audioSetttings];
    _audioWriterInput.expectsMediaDataInRealTime = YES;
    if ([_assetWriter canAddInput:_audioWriterInput]) {
        [_assetWriter addInput:_audioWriterInput];
    }
}

@end
