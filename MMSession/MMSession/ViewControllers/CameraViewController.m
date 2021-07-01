// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "CameraViewController.h"
#import "CameraSession.h"
#import "VideoLayerPreview.h"
#import "CameraCompileWriter.h"

#define weakify(var) __weak typeof(var) weak_##var = var;

#define strongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = weak_##var; \
_Pragma("clang diagnostic pop")

@interface CameraViewController ()

@property (nonatomic, strong) CameraSession *camera;
@property (nonatomic, strong) VideoLayerPreview *preview;
@property (nonatomic, strong) CameraCompileWriter *writer;

@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGFloat w = self.view.bounds.size.width;
    self.preview = [[VideoLayerPreview alloc] initWithFrame:CGRectMake(0, 0, w, w*16/9)];
    [self.view addSubview:self.preview];
    
    CameraSessionConfig *cameraConfig = [[CameraSessionConfig alloc] init];
    self.camera = [[CameraSession alloc] initWithConfig:cameraConfig];
    [self.camera setVideoPreviewLayerForSession:self.preview.videoPreviewLayer];
    
    CameraCompileWriterConfig *compileConfig = [[CameraCompileWriterConfig alloc] init];
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    
    NSString *ouputPath = [docPath stringByAppendingString:@"/yjx.mov"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:ouputPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:ouputPath error:nil];
    }
    
    compileConfig.outputUrl = [NSURL fileURLWithPath:ouputPath];
    compileConfig.videoSetttings = @{
        AVVideoCodecKey : AVVideoCodecTypeH264,
        AVVideoWidthKey : @(1080),
        AVVideoHeightKey: @(1920)
    };
    compileConfig.pixelBufferAttributes = @{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                  (__bridge NSString *)kCVPixelBufferWidthKey: @(1080),
                 (__bridge NSString *)kCVPixelBufferHeightKey: @(1920)
    };
    compileConfig.audioSetttings = @{
                AVFormatIDKey: @(kAudioFormatMPEG4AAC),
              AVSampleRateKey: @(44100),
        AVNumberOfChannelsKey: @(2)
    };
    self.writer = [[CameraCompileWriter alloc] initWithConfig:compileConfig];
    
    weakify(self);
    self.camera.videoOutputCallback = ^(CMSampleBufferRef  _Nonnull sampleBuffer) {
        strongify(self);
        [self.writer processVideoBuffer:sampleBuffer];
    };
    self.camera.audioOutputCallback = ^(CMSampleBufferRef  _Nonnull sampleBuffer) {
        strongify(self);
        [self.writer processAudioBuffer:sampleBuffer];
    };
}

- (IBAction)_startPreview:(UIButton *)btn {
    btn.selected = !btn.selected;
    [self.camera startCapture];
}

- (IBAction)_stopPreview:(UIButton *)btn {
    btn.selected = !btn.selected;
    [self.camera stopCapture];
}

- (IBAction)_startRecord:(UIButton *)btn {
    btn.selected = !btn.selected;
    [self.writer startRecord];
}

- (IBAction)_stopRecord:(UIButton *)btn {
    btn.selected = !btn.selected;
    [self.writer stopRecordWithCompleteHandle:^(NSURL * _Nullable fileUrl, NSError * _Nullable error) {
        NSLog(@"[yjx] writer output url: %@", fileUrl);
        // 保存相册，便于调试
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileUrl.path)) {
            UISaveVideoAtPathToSavedPhotosAlbum(fileUrl.path, nil, nil, nil);
        }
    }];
}

@end
