// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMCameraSession.h"

@interface MMCameraSession ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
@property (nonatomic, strong) dispatch_queue_t cameraQueue;
@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, strong) AVCaptureDevice *videoDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;

@property (nonatomic, strong) dispatch_queue_t audioQueue;
@property (nonatomic, strong) AVCaptureDevice *audioDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;

@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) BOOL isFirstFrame;
@end

@implementation MMCameraSession
- (instancetype)initWithConfig:(MMCameraSessionConfig *)config {
    if (self = [super init]) {
        _videoSize = CGSizeZero;
        _isFirstFrame = YES;
        [self _setupCaptureSession];

        [_captureSession beginConfiguration];
        [self _setupVideoStream];
        [self _setupAudioStream];
        [_captureSession commitConfiguration];
    }
    return self;
}

- (void)startCapture {
    dispatch_sync(_cameraQueue, ^{
        [_captureSession startRunning];
    });
}

- (void)stopCapture {
    dispatch_sync(_cameraQueue, ^{
        [_captureSession stopRunning];
    });
}

- (void)switchPosition {
    AVCaptureDevicePosition pos = self.videoDevice.position;
    if (pos == AVCaptureDevicePositionFront) {
        [self switchPosition:AVCaptureDevicePositionBack];
    } else {
        [self switchPosition:AVCaptureDevicePositionFront];
    }
}

- (void)switchPosition:(AVCaptureDevicePosition)position {
    dispatch_sync(_cameraQueue, ^{
        [_captureSession beginConfiguration];
        [_captureSession removeInput:_videoDeviceInput];
        _videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:position];
        NSError *error;
        _videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice error:&error];
        if ([_captureSession canAddInput:_videoDeviceInput]) {
            [_captureSession addInput:_videoDeviceInput];
        }
        
        /// 竖屏
        AVCaptureConnection *videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([videoConnection isVideoOrientationSupported]) {
            [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        }
        
        /// 处理前置摄像头镜像
        if (position == AVCaptureDevicePositionFront) {
            if ([videoConnection isVideoMirroringSupported]) {
                [videoConnection setVideoMirrored:YES];
            }
        }
        [_captureSession commitConfiguration];
    });
}

- (void)tapFocusAtPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode {
    dispatch_sync(_cameraQueue, ^{
        if (![_videoDevice isFocusPointOfInterestSupported] ||
            ![_videoDevice isFocusModeSupported:mode]) {
            return;
        }
        
        NSError *error;
        [_videoDevice lockForConfiguration:&error];
        [_videoDevice setFocusPointOfInterest:point];
        [_videoDevice setFocusMode:mode];
        [_videoDevice unlockForConfiguration];
        NSLog(@"[yjx] set camera focus success, point: [%lf, %lf], mode: %ld", point.x, point.y, mode);
    });
}

- (void)exposureAtPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode {
    dispatch_sync(_cameraQueue, ^{
        if (![_videoDevice isExposurePointOfInterestSupported] ||
            ![_videoDevice isExposureModeSupported:mode]) {
            return;
        }
        
        NSError *error;
        [_videoDevice lockForConfiguration:&error];
        [_videoDevice setExposurePointOfInterest:point];
        [_videoDevice setExposureMode:mode];
        [_videoDevice unlockForConfiguration];
        NSLog(@"[yjx] set camera focus success, point: [%lf, %lf], mode: %ld", point.x, point.y, mode);
        
    });
}

- (void)setVideoPreviewLayerForSession:(AVCaptureVideoPreviewLayer *)previewLayer {
    dispatch_sync(_cameraQueue, ^{
        [previewLayer setSession:_captureSession];
    });
}

- (CGSize)videoSize {
    return _videoSize;
}

#pragma mark - Private
- (void)_setupCaptureSession {
    _cameraQueue = dispatch_queue_create("mmsession_camera_queue", DISPATCH_QUEUE_SERIAL);
    _captureSession = [[AVCaptureSession alloc] init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
        [_captureSession setSessionPreset:AVCaptureSessionPreset1920x1080];
    }
}

- (void)_setupVideoStream {
    _videoQueue = dispatch_queue_create("mmsession_camera_video_queue", DISPATCH_QUEUE_SERIAL);
    
    _videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
    NSError *error = nil;
    _videoDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:&error];
    if ([_captureSession canAddInput:_videoDeviceInput]) {
        [_captureSession addInput:_videoDeviceInput];
    }
    
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    if ([_captureSession canAddOutput:_videoOutput]) {
        [_captureSession addOutput:_videoOutput];
    }
    _videoOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    
    [_videoOutput setSampleBufferDelegate:self queue:_videoQueue];
    
    /// 竖屏
    AVCaptureConnection *videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    if ([videoConnection isVideoOrientationSupported]) {
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    /// 镜像
    if ([videoConnection isVideoMirroringSupported]) {
        [videoConnection setVideoMirrored:YES];
    }
}

- (void)_setupAudioStream {
    _audioQueue = dispatch_queue_create("mmsession_camera_audio_queue", DISPATCH_QUEUE_SERIAL);
    
    _audioDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInMicrophone mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    NSError *error = nil;
    _audioDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:_audioDevice error:&error];
    if ([_captureSession canAddInput:_audioDeviceInput]) {
        [_captureSession addInput:_audioDeviceInput];
    }
    
    _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    if ([_captureSession canAddOutput:_audioOutput]) {
        [_captureSession addOutput:_audioOutput];
    }
    
    [_audioOutput setSampleBufferDelegate:self queue:_audioQueue];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_isFirstFrame && _firstFrameBlk && output == _videoOutput) {
        if (CGSizeEqualToSize(_videoSize, CGSizeZero)) {
            CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            CGFloat w = CVPixelBufferGetWidth(pixelBuffer);
            CGFloat h = CVPixelBufferGetHeight(pixelBuffer);
            _videoSize = CGSizeMake(w, h);
            NSLog(@"[yjx] camera capture video size: [%lf, %lf]", w, h);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.firstFrameBlk();
        });
        
        _isFirstFrame = NO;
    }
    
    if (output == _videoOutput && self.videoOutputCallback) {
        self.videoOutputCallback(sampleBuffer);
    } else if (output == _audioOutput && self.audioOutputCallback) {
        self.audioOutputCallback(sampleBuffer);
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"[yjx] camera drop sampleBuffer");
}
@end
