// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "CameraViewController.h"
#import "CameraSession.h"
#import "VideoLayerPreview.h"
#import "VideoGLPreview.h"
#import "CameraCompileWriter.h"
#import <Masonry/Masonry.h>

#define weakify(var) __weak typeof(var) weak_##var = var;

#define strongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = weak_##var; \
_Pragma("clang diagnostic pop")

static const CGFloat kNavBarHeight = 88.0f;

@interface CameraViewController ()

@property (nonatomic, strong) CameraSession *camera;
@property (nonatomic, strong) VideoLayerPreview *layerPreview;
@property (nonatomic, strong) VideoGLPreview *glPreview;
@property (nonatomic, strong) CameraCompileWriter *writer;
@property (nonatomic, strong) UIView *containerView;

@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self _setupCamera];
    [self _setupPreview];
    [self _setupWriter];
    
    weakify(self);
    self.camera.videoOutputCallback = ^(CMSampleBufferRef  _Nonnull sampleBuffer) {
        strongify(self);
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.glPreview processVideoBuffer:sampleBuffer];
            [self.writer processVideoBuffer:sampleBuffer];
        });
    };
    
    self.camera.audioOutputCallback = ^(CMSampleBufferRef  _Nonnull sampleBuffer) {
        strongify(self);
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.writer processAudioBuffer:sampleBuffer];
        });
    };
    
    [self _setupContainerView];
}

#pragma mark - Private

- (void)_setupCamera {
    CameraSessionConfig *cameraConfig = [[CameraSessionConfig alloc] init];
    self.camera = [[CameraSession alloc] initWithConfig:cameraConfig];
    // [self.camera setVideoPreviewLayerForSession:self.layerPreview.videoPreviewLayer];
}

- (void)_setupPreview {
    CGFloat w = self.view.bounds.size.width;
    VideoGLPreview *glPreview = [[VideoGLPreview alloc] initWithFrame:CGRectMake(0, 0, w, w*16/9)];
    glPreview.backgroundColor = UIColor.yellowColor;
    [self.view addSubview:glPreview];
    
    [glPreview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view).offset(kNavBarHeight);
        make.width.equalTo(@(w));
        make.height.equalTo(@(w*16/9));
    }];
    self.glPreview = glPreview;
    
    VideoPreviewConfig *config = [[VideoPreviewConfig alloc] init];
    config.renderYUV = YES;
    // config.rotation = 180;
    config.presentRect = CGRectMake(0, 0, w, w*16/9);
    self.glPreview.config = config;
    [self.glPreview setupGLEnv];
}

- (void)_setupWriter {
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;

    NSString *outputPath = [docPath stringByAppendingString:@"/yjx.mov"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    }

    CameraCompileWriterConfig *compileConfig = [[CameraCompileWriterConfig alloc] init];
    compileConfig.outputUrl = [NSURL fileURLWithPath:outputPath];
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
}

#pragma mark - Action

- (void)_setupContainerView {
    UIView *containerView = [[UIView alloc] init];
    containerView.backgroundColor = UIColor.purpleColor;
    [self.view addSubview:containerView];
    [containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.view);
        make.top.equalTo(self.glPreview.mas_bottom);
        make.bottom.equalTo(self.view);
    }];
    self.containerView = containerView;
    
    // 预览
    UIButton *previewBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    previewBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [previewBtn setTitle:@"视频预览" forState:UIControlStateNormal];
    [previewBtn setTitle:@"停止预览" forState:UIControlStateSelected];
    previewBtn.backgroundColor = UIColor.redColor;
    [self.containerView addSubview:previewBtn];
    [previewBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@75);
        make.height.equalTo(@37.5);
        make.left.equalTo(self.containerView).offset(10);
        make.top.equalTo(self.containerView).offset(10);
    }];
    [previewBtn addTarget:self action:@selector(_startPreview:) forControlEvents:UIControlEventTouchUpInside];
    
    // 录制
    UIButton *recordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    recordBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [recordBtn setTitle:@"视频录制" forState:UIControlStateNormal];
    [recordBtn setTitle:@"停止录制" forState:UIControlStateSelected];
    recordBtn.backgroundColor = UIColor.redColor;
    [self.containerView addSubview:recordBtn];
    [recordBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@75);
        make.height.equalTo(@37.5);
        make.left.equalTo(previewBtn.mas_right).offset(10);
        make.top.equalTo(self.containerView).offset(10);
    }];
    [recordBtn addTarget:self action:@selector(_startRecord:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)_startPreview:(UIButton *)btn {
    btn.selected = !btn.selected;
    if (btn.selected) {
        [self.camera startCapture];
    } else {
        [self.camera stopCapture];
        self.camera.videoOutputCallback = nil;
    }
}

- (void)_startRecord:(UIButton *)btn {
    btn.selected = !btn.selected;
    
    if (btn.selected) {
        [self.writer startRecord];
    } else {
        [self.writer stopRecordWithCompleteHandle:^(NSURL * _Nullable fileUrl, NSError * _Nullable error) {
            NSLog(@"[yjx] writer output url: %@", fileUrl);
            // 保存相册，便于调试
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileUrl.path)) {
                UISaveVideoAtPathToSavedPhotosAlbum(fileUrl.path, nil, nil, nil);
            }
        }];
    }
}

@end
