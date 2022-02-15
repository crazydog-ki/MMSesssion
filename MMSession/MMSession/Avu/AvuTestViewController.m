#import "AvuTestViewController.h"
#import "AvuVideoDecodeUnit.h"
#import "AvuAudioDecodeUnit.h"
#import "MMVideoGLPreview.h"
#import "AVAsset+Extension.h"
#import "MMAudioQueuePlayer.h"
#import "AvuEncodeUnit.h"
#import "AvuAudioQueue.h"

@interface AvuTestViewController () <TZImagePickerControllerDelegate, TTGTextTagCollectionViewDelegate>
@property (nonatomic, strong) TTGTextTagCollectionView *collectionView;

@property (nonatomic, strong) NSMutableArray<AVAsset *> *videoAssets;
@property (nonatomic, strong) NSMutableArray<NSData *> *imageDatas;

@property (nonatomic, strong) AVAsset *composition;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, assign) CGFloat videoRatio;

@property (nonatomic, strong) AvuVideoDecodeUnit *videoDecodeUnit;
@property (nonatomic, strong) AvuAudioDecodeUnit *audioDecodeUnit;
@property (nonatomic, strong) MMVideoGLPreview *glPreview;
@property (nonatomic, strong) AvuAudioQueue *audioPlayer;

@property (nonatomic, strong) NSThread *videoThread;
@property (nonatomic, strong) CADisplayLink *videoLink;
@property (nonatomic, strong) NSThread *audioThread;

@property (nonatomic, assign) double videoPts;
@property (nonatomic, assign) double audioPts;

@property (nonatomic, strong) AvuEncodeUnit *encodeUnit;
@end

@implementation AvuTestViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"AVU Module";
    self.view.backgroundColor = UIColor.blackColor;
    
    [self _setupCollectionView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self _stop];
    self.videoDecodeUnit = nil;
    self.audioDecodeUnit = nil;
    [self _stopThread];
}

#pragma mark - Priavte
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
    
    TTGTextTag *pickTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频导入"] style:style];
    [tagCollectionView addTag:pickTag];
    
    TTGTextTag *playTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"播放"] style:style];
    [tagCollectionView addTag:playTag];
    
    TTGTextTag *stopTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"停止播放"] style:style];
    [tagCollectionView addTag:stopTag];
    
    TTGTextTag *seekTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"seek"] style:style];
    [tagCollectionView addTag:seekTag];
}

- (void)_setupPreview {
    if (self.glPreview) return;
    
    CGFloat w = self.view.bounds.size.width;
    MMVideoGLPreview *glPreview = [[MMVideoGLPreview alloc] initWithFrame:CGRectMake(0, kStatusBarH+kNavBarH, w, w*self.videoRatio)];
    glPreview.backgroundColor = UIColor.blackColor;
    [self.view insertSubview:glPreview atIndex:0];
    self.glPreview = glPreview;
    
    MMVideoPreviewConfig *config = [[MMVideoPreviewConfig alloc] init];
    config.renderYUV = YES;
    config.presentRect = CGRectMake(0, 0, w, w*self.videoRatio);
    config.rotation = -self.composition.rotation;
    self.glPreview.config = config;
    [self.glPreview setupGLEnv];
}


- (void)_setupAudioPlayer {
    if (self.audioPlayer) return;
    
    AvuConfig *playerConfig = [[AvuConfig alloc] init];
    playerConfig.needPullData = NO;
    AvuAudioQueue *audioPlayer = [[AvuAudioQueue alloc] initWithConfig:playerConfig];
    self.audioPlayer = audioPlayer;
}

- (void)_startThread {
    self.videoPts = 0.0f;
    self.audioPts = 0.0f;
    
//    if (!self.videoThread) {
//        self.videoThread = [[NSThread alloc] initWithTarget:self selector:@selector(_playVideo) object:nil];
//        [self.videoThread start];
//    }
    if (!self.audioThread) {
        self.audioThread = [[NSThread alloc] initWithTarget:self selector:@selector(_playAudio) object:nil];
        [self.audioThread start];
    }
    
    if (!self.videoLink) {
        self.videoLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_playVideo)];
        self.videoLink.preferredFramesPerSecond = 60;
        [self.videoLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
}

- (void)_playVideo {
    while (self.videoDecodeUnit && self.glPreview) {
        NSLog(@"[yjx] displayLink time: %lf", CFAbsoluteTimeGetCurrent());
        while (self.audioPts <= self.videoPts) {
            [NSThread sleepForTimeInterval:0.0001];
        }
        

        if (!self.videoDecodeUnit.isValid || !self.audioDecodeUnit.isValid) {
            // NSLog(@"[avu] video unit / audio unit not valid-1");
        } else {
            AvuBuffer *buffer = [self.videoDecodeUnit dequeue];
            if (buffer) {
                if (self.encodeUnit) {
                    [self.encodeUnit encode:buffer];
                }
                
                [self.glPreview processPixelBuffer:buffer.pixelBuffer];
                self.videoPts = buffer.pts;
            }
        }
    }
}

- (void)_playAudio {
    while (self.audioDecodeUnit && self.audioPlayer) {
        NSLog(@"[yjx] displayLink time: %lf", CFAbsoluteTimeGetCurrent());
        if (!self.videoDecodeUnit.isValid || !self.audioDecodeUnit.isValid) {
            // NSLog(@"[avu] video unit / audio unit not valid-2");
        } else {
            AvuBuffer *buffer = [self.audioDecodeUnit dequeue];
            if (buffer) {
                if (self.encodeUnit) {
                    [self.encodeUnit encode:buffer];
                }
                
                [self.audioPlayer processSampleBuffer:buffer.audioBuffer];
                self.audioPts = buffer.pts;
            }
        }
    }
}

- (void)_stopThread {
    self.videoPts = 0.0f;
    self.audioPts = 0.0f;
    
    if (self.videoThread) {
        [self.videoThread cancel];
        self.videoThread = nil;
    }
    
    if (self.audioThread) {
        [self.audioThread cancel];
        self.audioThread = nil;
    }
}

#pragma mark - Action
- (void)_startPick {
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:9 delegate:self];
    imagePickerVc.allowPickingMultipleVideo = YES;
    imagePickerVc.isSelectOriginalPhoto = YES;
    [self presentViewController:imagePickerVc animated:YES completion:nil];
}

- (void)_play {
    if (!self.videoDecodeUnit) {
        AvuConfig *config = [[AvuConfig alloc] init];
        config.videoPath = self.videoPath;
        config.type = AvuType_Video;
        // config.clipRange = [AvuClipRange clipRangeStart:5 end:8];
        self.videoDecodeUnit = [[AvuVideoDecodeUnit alloc] initWithConfig:config];
        
        weakify(self);
        [self.videoDecodeUnit setDecodeEndCallback:^{
            strongify(self);
            [self.videoDecodeUnit pause];
        }];
    }
    
    if (!self.audioDecodeUnit) {
        AvuConfig *config = [[AvuConfig alloc] init];
        config.audioPath = self.videoPath;
        config.type = AvuType_Audio;
        // config.clipRange = [AvuClipRange clipRangeStart:5 end:8];
        self.audioDecodeUnit = [[AvuAudioDecodeUnit alloc] initWithConfig:config];
        
        weakify(self);
        [self.audioDecodeUnit setDecodeEndCallback:^{
            strongify(self);
            [self.audioDecodeUnit pause];
        }];
    }
    
    if (!self.encodeUnit) {
        /// vt相关
        AvuConfig *config = [[AvuConfig alloc] init];
        config.pixelFormat = AvuPixelFormatType_YUV;
        config.videoSize = CGSizeMake(720, 1280);
        config.keyframeInterval = 1.0f;
        config.allowBFrame = NO;
        config.allowRealtime = NO;
        config.bitrate = 2560000;
        
        /// writer相关
        NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *outputPath = [docPath stringByAppendingString:@"/yjx.mov"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        }
        
        CGSize outputSize = CGSizeMake(720, 1280);
        config.onlyMux = YES;
        config.outputUrl = [NSURL fileURLWithPath:outputPath];
        config.videoSetttings = @{
            AVVideoCodecKey : AVVideoCodecTypeH264,
            AVVideoWidthKey : @(outputSize.width),
            AVVideoHeightKey: @(outputSize.height)
        };
        config.pixelBufferAttributes = @{
            (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                      (__bridge NSString *)kCVPixelBufferWidthKey: @(outputSize.width),
                     (__bridge NSString *)kCVPixelBufferHeightKey: @(outputSize.height)
        };
        config.audioSetttings = @{
                    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                  AVSampleRateKey: @(44100),
            AVNumberOfChannelsKey: @(2)
        };
        
        self.encodeUnit = [[AvuEncodeUnit alloc] initWithConfig:config];
    }
    
//    [self.videoDecodeUnit seekToTime:5.0];
//    [self.audioDecodeUnit seekToTime:5.0];
//    self.videoPts = self.audioPts = 5.0f;
    
    if (!self.glPreview) {
        [self _setupPreview];
    }
    
    if (!self.audioPlayer) {
        [self _setupAudioPlayer];
    }
    
    [self.audioPlayer play];
    [self _startThread];
}

- (void)_stop {
    [self.videoDecodeUnit stop];
    [self.audioDecodeUnit stop];
    
    [self.encodeUnit stopEncode:^(NSURL * _Nullable fileUrl, NSError * _Nullable error) {
        NSLog(@"[avu] encode file path: %@, error: %@", fileUrl.path, error);
    }];
}

- (void)_seek {
    [self.audioDecodeUnit seekToTime:5];
    [self.videoDecodeUnit seekToTime:5];
    self.videoPts = self.audioPts = 5;
}

#pragma mark - TZImagePickerControllerDelegate
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingPhotos:(NSArray<UIImage *> *)photos sourceAssets:(NSArray *)assets isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto infos:(NSArray<NSDictionary *> *)infos {
    
    /// 图片
    PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
    imageOptions.version = PHImageRequestOptionsVersionOriginal;
    
    /// 视频
    PHVideoRequestOptions *videoOptions = [[PHVideoRequestOptions alloc] init];
    videoOptions.version = PHVideoRequestOptionsVersionOriginal;
    
    for (PHAsset *asset in assets) {
        [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:asset options:imageOptions resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, CGImagePropertyOrientation orientation, NSDictionary * _Nullable info) {
            [self.imageDatas addObject:imageData];
            NSLog(@"[avu] picked image from album data: %@", imageData);
        }];
        
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:videoOptions resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
            if ([asset isKindOfClass:[AVURLAsset class]]) {
                AVURLAsset *urlAsset = (AVURLAsset *)asset;
                self.composition = urlAsset;
                self.videoPath = urlAsset.URL.path;
                double rotation = self.composition.rotation;
                if (rotation) {
                    NSLog(@"[avu] import video with rotation msg: %lf", rotation);
                }
                AVAssetTrack *track = [urlAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
                if (track) {
                    CGFloat w = track.naturalSize.width;
                    CGFloat h = track.naturalSize.height;
                    self.videoRatio = h/w;
                }
                [self.videoAssets addObject:urlAsset];
                NSLog(@"[avu] picked video from album URL: %@", urlAsset.URL.path);
            }
        }];
    }
}

#pragma mark - TTGTextTagCollectionViewDelegate
- (void)textTagCollectionView:(TTGTextTagCollectionView *)textTagCollectionView
                    didTapTag:(TTGTextTag *)tag
                      atIndex:(NSUInteger)index {
    TTGTextTagStringContent *content = (TTGTextTagStringContent *)tag.content;
    if ([content.text isEqualToString:@"视频导入"]) {
        [self _startPick];
    } else if ([content.text isEqualToString:@"播放"]) {
        [self _play];
    } else if ([content.text isEqualToString:@"停止播放"]) {
        [self _stop];
    } else if ([content.text isEqualToString:@"seek"]) {
        [self _seek];
    }
    return;
}
@end
