// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMCameraViewController.h"
#import "MMCameraSession.h"
#import "MMVideoLayerPreview.h"
#import "MMVideoGLPreview.h"
#import "MMEncodeWriter.h"

@interface MMCameraViewController () <TTGTextTagCollectionViewDelegate>
@property (nonatomic, strong) TTGTextTagCollectionView *collectionView;

@property (nonatomic, strong) MMCameraSession *camera;
@property (nonatomic, strong) MMVideoLayerPreview *layerPreview;
@property (nonatomic, strong) MMVideoGLPreview *glPreview;
@property (nonatomic, strong) MMEncodeWriter *writer;
@end

@implementation MMCameraViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Camera Module";
    self.view.backgroundColor = UIColor.blackColor;
    
    [self _setupCollectionView];
    [self _setupCamera];
    weakify(self);
    self.camera.firstFrameBlk = ^{ // 回调首帧
        strongify(self);
        [self _setupPreview];
        [self _setupWriter];
        
        weakify(self);
        self.camera.videoOutputCallback = ^(CMSampleBufferRef  _Nonnull sampleBuffer) {
            strongify(self);
            dispatch_sync(dispatch_get_main_queue(), ^{
                MMSampleData *videoData = [[MMSampleData alloc] init];
                videoData.dataType = MMSampleDataType_Decoded_Video;
                videoData.sampleBuffer = sampleBuffer;
                [self.glPreview processSampleData:videoData];
                [self.writer processSampleData:videoData];
            });
        };
        
        self.camera.audioOutputCallback = ^(CMSampleBufferRef  _Nonnull sampleBuffer) {
            strongify(self);
            dispatch_sync(dispatch_get_main_queue(), ^{
                MMSampleData *audioData = [[MMSampleData alloc] init];
                audioData.dataType = MMSampleDataType_Decoded_Audio;
                audioData.sampleBuffer = sampleBuffer;
                [self.writer processSampleData:audioData];
            });
        };
    };
}

- (void)dealloc {
    NSLog(@"[yjx] camera controller destroy");
}

#pragma mark - Private
- (void)_setupCamera {
    MMCameraSessionConfig *cameraConfig = [[MMCameraSessionConfig alloc] init];
    self.camera = [[MMCameraSession alloc] initWithConfig:cameraConfig];
    // [self.camera setVideoPreviewLayerForSession:self.layerPreview.videoPreviewLayer];
}

- (void)_setupPreview {
    CGFloat w = self.view.bounds.size.width;
    CGFloat videoRatio = self.camera.videoSize.height / self.camera.videoSize.width;
    MMVideoGLPreview *glPreview = [[MMVideoGLPreview alloc] initWithFrame:CGRectMake(0, kStatusBarH+kNavBarH, w, w*videoRatio)];
    glPreview.backgroundColor = UIColor.blackColor;
    [self.view insertSubview:glPreview atIndex:0];
    self.glPreview = glPreview;
    
    MMVideoPreviewConfig *config = [[MMVideoPreviewConfig alloc] init];
    config.renderYUV = YES;
    // config.rotation = M_PI;
    config.presentRect = CGRectMake(0, 0, w, w*videoRatio);
    self.glPreview.config = config;
    [self.glPreview setupGLEnv];
}

- (void)_setupWriter {
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;

    NSString *outputPath = [docPath stringByAppendingString:@"/yjx.mov"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    }

    MMEncodeConfig *compileConfig = [[MMEncodeConfig alloc] init];
    compileConfig.outputUrl = [NSURL fileURLWithPath:outputPath];
    CGFloat w = self.camera.videoSize.width;
    CGFloat h = self.camera.videoSize.height;
    compileConfig.videoSetttings = @{
        AVVideoCodecKey : AVVideoCodecTypeH264,
        AVVideoWidthKey : @(w),
        AVVideoHeightKey: @(h)
    };
    compileConfig.pixelBufferAttributes = @{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                  (__bridge NSString *)kCVPixelBufferWidthKey: @(w),
                 (__bridge NSString *)kCVPixelBufferHeightKey: @(h)
    };
    compileConfig.audioSetttings = @{
                AVFormatIDKey: @(kAudioFormatMPEG4AAC),
              AVSampleRateKey: @(44100),
        AVNumberOfChannelsKey: @(2)
    };
    self.writer = [[MMEncodeWriter alloc] initWithConfig:compileConfig];
}

#pragma mark - Action
- (void)_setupCollectionView {
    TTGTextTagCollectionView *tagCollectionView = [[TTGTextTagCollectionView alloc] init];
    tagCollectionView.delegate = self;
    [self.view addSubview:tagCollectionView];
    self.collectionView = tagCollectionView;
    [tagCollectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.view);
        make.top.equalTo(self.view).offset(kStatusBarH+kNavBarH);
        make.bottom.equalTo(self.view);
    }];
    
    TTGTextTagStyle *style = [TTGTextTagStyle new];
    style.backgroundColor = kMMColor;
    style.exactWidth = 75.0f;
    style.exactHeight = 37.5f;
    style.cornerRadius = 0.0f;
    style.borderWidth = 0.0f;
    
    TTGTextTag *pickTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"开始预览"] style:style];
    [tagCollectionView addTag:pickTag];
    
    TTGTextTag *concatTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"停止预览"] style:style];
    [tagCollectionView addTag:concatTag];
    
    TTGTextTag *decodeTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"开始录制"] style:style];
    [tagCollectionView addTag:decodeTag];
    
    TTGTextTag *playVideoTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"停止录制"] style:style];
    [tagCollectionView addTag:playVideoTag];
    
    TTGTextTag *switchPositionTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"切换摄像头"] style:style];
    [tagCollectionView addTag:switchPositionTag];
    
    TTGTextTag *focusTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"中心点对焦"] style:style];
    [tagCollectionView addTag:focusTag];
    
    TTGTextTag *exposureTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"中心点曝光"] style:style];
    [tagCollectionView addTag:exposureTag];
}

- (void)_startPreview {
    [self.camera startCapture];
}

- (void)_stopPreview {
    [self.camera stopCapture];
}

- (void)_startRecord {
    [self.writer startEncode];
}

- (void)_finishRecord {
    [self.writer stopEncodeWithCompleteHandle:^(NSURL * _Nullable fileUrl, NSError * _Nullable error) {
        NSLog(@"[yjx] writer output url: %@", fileUrl);
        /// 保存相册，便于调试
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileUrl.path)) {
            UISaveVideoAtPathToSavedPhotosAlbum(fileUrl.path, nil, nil, nil);
        }
    }];
}

- (void)_switchCamera {
    [self.camera switchPosition];
}

- (void)_focusAtCenter {
    [self.camera tapFocusAtPoint:CGPointMake(0.5f, 0.5f) mode:AVCaptureFocusModeContinuousAutoFocus];
}

- (void)_exposeAtCenter {
    [self.camera exposureAtPoint:CGPointMake(0.5f, 0.5f) mode:AVCaptureExposureModeContinuousAutoExposure];
}

#pragma mark - TTGTextTagCollectionViewDelegate
- (void)textTagCollectionView:(TTGTextTagCollectionView *)textTagCollectionView
                    didTapTag:(TTGTextTag *)tag
                      atIndex:(NSUInteger)index {
    TTGTextTagStringContent *content = (TTGTextTagStringContent *)tag.content;
    NSString *text = content.text;
    if ([text isEqualToString:@"开始预览"]) {
        [self _startPreview];
    } else if ([text isEqualToString:@"停止预览"]) {
        [self _stopPreview];
    } else if ([text isEqualToString:@"开始录制"]) {
        [self _startRecord];
    } else if ([text isEqualToString:@"停止录制"]) {
        [self _finishRecord];
    } else if ([text isEqualToString:@"切换摄像头"]) {
        [self _switchCamera];
    } else if ([text isEqualToString:@"中心点对焦"]) {
        [self _focusAtCenter];
    } else if ([text isEqualToString:@"中心点曝光"]) {
        [self _exposeAtCenter];
    }
    return;
}
@end
