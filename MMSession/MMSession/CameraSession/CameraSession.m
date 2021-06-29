// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "CameraSession.h"

@interface CameraSession ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
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
@end

@implementation CameraSession

- (instancetype)initWithConfig:(CameraSessionConfig *)config {
    if (self = [super init]) {
        [self _setupCaptureSession];

        [_captureSession beginConfiguration];
        [self _setupVideoStream];
        [self _setupAudioStream];
        [_captureSession commitConfiguration];
    }
    return self;
}

- (void)startCapture {
    [_captureSession startRunning];
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
    
    [_videoOutput setSampleBufferDelegate:self queue:_videoQueue];
    
    // 设置竖屏
    AVCaptureConnection *videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
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
    if (output == _videoOutput && self.videoOutputCallback) {
        NSLog(@"youjianxia capture video");
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.videoOutputCallback(sampleBuffer);
        });
    } else if (output == _audioOutput) {
        NSLog(@"youjianxia capture audio");
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
}

@end
