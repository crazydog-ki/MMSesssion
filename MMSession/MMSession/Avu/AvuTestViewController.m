#import "AvuTestViewController.h"
#import "MMVideoGLPreview.h"
#import "AVAsset+Extension.h"
#import "MMAudioQueuePlayer.h"
#import "AvuEncodeUnit.h"
#import "AvuMultiAudioUnit.h"
#import "AvuMultiVideoUnit.h"

@interface AvuTestViewController () <TTGTextTagCollectionViewDelegate>
@property (nonatomic, strong) TTGTextTagCollectionView *collectionView;
@property (nonatomic, strong) UISlider *slider;

@property (nonatomic, strong) NSMutableArray<AVAsset *> *videoAssets;
@property (nonatomic, strong) NSMutableArray<NSData *> *imageDatas;
@property (nonatomic, strong) AVAsset *composition;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, assign) CGFloat videoRatio;
@property (nonatomic, assign) CGFloat videoDuration;

@property (nonatomic, strong) CADisplayLink *videoLink;

@property (nonatomic, strong) MMVideoGLPreview *glPreview1;
@property (nonatomic, strong) MMVideoGLPreview *glPreview2;
@property (nonatomic, strong) MMVideoGLPreview *glPreview3;
@property (nonatomic, strong) MMVideoGLPreview *glPreview4;
@property (nonatomic, strong) NSMutableArray<MMVideoGLPreview *> *glPreviews;
@property (nonatomic, strong) AvuEncodeUnit *encodeUnit;

@property (nonatomic, strong) AvuMultiAudioUnit *multiAudioUnit;
@property (nonatomic, strong) AvuMultiVideoUnit *multiVideoUnit;
@property (nonatomic, assign) double startTime;
@property (nonatomic, assign) BOOL debugDragSeek;
@end

@implementation AvuTestViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"AVU Module";
    self.view.backgroundColor = UIColor.blackColor;
    self.debugDragSeek = YES;
    
    [self _setupCollectionView];
    [self _setupSlider];
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
        make.height.equalTo(@150); /// 4排
    }];
    
    TTGTextTagStyle *style = [TTGTextTagStyle new];
    style.backgroundColor = kMMColor;
    style.exactWidth = 75.0f;
    style.exactHeight = 37.5f;
    style.cornerRadius = 0.0f;
    style.borderWidth = 0.0f;
    
    TTGTextTag *playTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"播放"] style:style];
    [tagCollectionView addTag:playTag];
    
    TTGTextTag *stopTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"暂停"] style:style];
    [tagCollectionView addTag:stopTag];
    
    TTGTextTag *seekTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"Seek"] style:style];
    [tagCollectionView addTag:seekTag];
}

- (void)_setupSlider {
    CGRect frame = CGRectMake(100, kScreenH-60, kScreenW-200, 40);
    UISlider *slider = [[UISlider alloc] initWithFrame:frame];
    [slider addTarget:self action:@selector(_sliderValueChange) forControlEvents:UIControlEventValueChanged];
    slider.minimumValue = 0.0f;
    slider.maximumValue = 1.0f;
    [self.view addSubview:slider];
    self.slider = slider;
}


- (void)_setupPreviews {
    if (!self.glPreviews) {
        self.glPreviews = [NSMutableArray array];
    }
    if (self.glPreview1) return;
    
    CGFloat w = self.view.bounds.size.width/4;
    MMVideoGLPreview *glPreview1 = [[MMVideoGLPreview alloc] initWithFrame:CGRectMake(0, kStatusBarH+kNavBarH, w, w*16/9)];
    glPreview1.backgroundColor = UIColor.blackColor;
    [self.view insertSubview:glPreview1 atIndex:0];
    self.glPreview1 = glPreview1;
    
    MMVideoPreviewConfig *config = [[MMVideoPreviewConfig alloc] init];
    config.renderYUV = YES;
    config.presentRect = CGRectMake(0, 0, w, w*16/9);
    config.rotation = -self.composition.rotation;
    self.glPreview1.config = config;
    [self.glPreview1 setupGLEnv];
    
    if (self.glPreview2) return;
    MMVideoGLPreview *glPreview2 = [[MMVideoGLPreview alloc] initWithFrame:CGRectMake(w, kStatusBarH+kNavBarH, w, w*16/9)];
    glPreview2.backgroundColor = UIColor.blackColor;
    [self.view insertSubview:glPreview2 atIndex:0];
    self.glPreview2 = glPreview2;
    self.glPreview2.config = config;
    [self.glPreview2 setupGLEnv];
    
    if (self.glPreview3) return;
    MMVideoGLPreview *glPreview3 = [[MMVideoGLPreview alloc] initWithFrame:CGRectMake(2*w, kStatusBarH+kNavBarH, w, w*16/9)];
    glPreview3.backgroundColor = UIColor.blackColor;
    [self.view insertSubview:glPreview3 atIndex:0];
    self.glPreview3 = glPreview3;
    self.glPreview3.config = config;
    [self.glPreview3 setupGLEnv];
    
    if (self.glPreview4) return;
    MMVideoGLPreview *glPreview4 = [[MMVideoGLPreview alloc] initWithFrame:CGRectMake(3*w, kStatusBarH+kNavBarH, w, w*16/9)];
    glPreview4.backgroundColor = UIColor.blackColor;
    [self.view insertSubview:glPreview4 atIndex:0];
    self.glPreview4 = glPreview4;
    self.glPreview4.config = config;
    [self.glPreview4 setupGLEnv];
    
    [self.glPreviews addObject:glPreview1];
    [self.glPreviews addObject:glPreview2];
    [self.glPreviews addObject:glPreview3];
    [self.glPreviews addObject:glPreview4];
}

- (void)_setupEncodeUnit {
    if (self.encodeUnit) return;
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

- (void)_setupMultiAudioUnit {
    NSString *path1 = [NSBundle.mainBundle.bundlePath stringByAppendingString:@"/basket.mp4"];
    NSString *path2 = [NSBundle.mainBundle.bundlePath stringByAppendingString:@"/beauty.mp4"];
    NSString *path3 = [NSBundle.mainBundle.bundlePath stringByAppendingString:@"/dilireba.mp4"];
    NSString *path4 = [NSBundle.mainBundle.bundlePath stringByAppendingString:@"/yangmi.mp4"];
    // NSString *path5 = [NSBundle.mainBundle.bundlePath stringByAppendingString:@"/GXFC-LDH.mp3"];
    
    AvuClipRange *range1 = [AvuClipRange clipRangeAttach:0 start:0 end:10];
    AvuClipRange *range2 = [AvuClipRange clipRangeAttach:0 start:0 end:10];
    AvuClipRange *range3 = [AvuClipRange clipRangeAttach:0 start:0 end:10];
    AvuClipRange *range4 = [AvuClipRange clipRangeAttach:0 start:0 end:10];
    // AvuClipRange *range5 = [AvuClipRange clipRangeAttach:5 start:0 end:30];

    AvuConfig *config = [[AvuConfig alloc] init];
    [config.audioPaths addObject:path1];
    [config.audioPaths addObject:path2];
    [config.audioPaths addObject:path3];
    [config.audioPaths addObject:path4];
    // [config.audioPaths addObject:path5];
    
    config.clipRanges[path1] = range1;
    config.clipRanges[path2] = range2;
    config.clipRanges[path3] = range3;
    config.clipRanges[path4] = range4;
    // config.clipRanges[path5] = range5;

    self.multiAudioUnit = [[AvuMultiAudioUnit alloc] initWithConfig:config];
}

- (void)_setupMultiVideoUnit {
    NSString *path1 = [NSBundle.mainBundle.bundlePath stringByAppendingString:@"/basket.mp4"];
    NSString *path2 = [NSBundle.mainBundle.bundlePath stringByAppendingString:@"/beauty.mp4"];
    NSString *path3 = [NSBundle.mainBundle.bundlePath stringByAppendingString:@"/dilireba.mp4"];
    NSString *path4 = [NSBundle.mainBundle.bundlePath stringByAppendingString:@"/yangmi.mp4"];
    
    AvuClipRange *range1 = [AvuClipRange clipRangeAttach:0 start:0 end:10];
    AvuClipRange *range2 = [AvuClipRange clipRangeAttach:0 start:0 end:10];
    AvuClipRange *range3 = [AvuClipRange clipRangeAttach:0 start:0 end:10];
    AvuClipRange *range4 = [AvuClipRange clipRangeAttach:0 start:0 end:10];
    
    AvuConfig *config = [[AvuConfig alloc] init];
    [config.videoPaths addObject:path1];
    [config.videoPaths addObject:path2];
    [config.videoPaths addObject:path3];
    [config.videoPaths addObject:path4];

    config.clipRanges[path1] = range1;
    config.clipRanges[path2] = range2;
    config.clipRanges[path3] = range3;
    config.clipRanges[path4] = range4;
    self.multiVideoUnit = [[AvuMultiVideoUnit alloc] initWithConfig:config];
}

- (void)_playVideo {
    if (self.startTime == 0.0f) {
        self.startTime = CFAbsoluteTimeGetCurrent();
        [self.multiAudioUnit start];
    }
    
    double reqTime = CFAbsoluteTimeGetCurrent()-self.startTime;
    if (0.1 < fabs(reqTime-self.multiAudioUnit.getAudioPts)) {
        NSLog(@"[yjx] audio modify video, video time: %lf, audio time: %lf", reqTime, self.multiAudioUnit.getAudioPts);
        reqTime = self.multiAudioUnit.getAudioPts;
    }
    
    NSArray<NSDictionary<NSString *, AvuBuffer *> *> *buffers = [self.multiVideoUnit requestVideoBuffersAt:reqTime];
    for (int i = 0; i < buffers.count; i++) {
        AvuBuffer *buffer = buffers[i].allValues[0];
        if (buffer.pixelBuffer) {
            NSLog(@"[yjx] render index: %d, reqTime: %lf, buffer pts: %lf", i, reqTime, buffer.pts);
            [self.glPreviews[i] processPixelBuffer:buffer.pixelBuffer];
        }
    }
    // NSLog(@"[yjx] request video buffer time: %lf", CFAbsoluteTimeGetCurrent()-self.startTime);
    // NSLog(@"[yjx] audio time: %lf", [self.multiAudioUnit getAudioPts]);
}

#pragma mark - Action
- (void)_play {
    self.startTime = 0.0f;
    
    if (!self.glPreviews) {
        [self _setupPreviews];
    }
    
    if (!self.encodeUnit) {
        [self _setupEncodeUnit];
    }
    
    if (!self.multiAudioUnit) {
        [self _setupMultiAudioUnit];
    }
    
    if (!self.multiVideoUnit) {
        [self _setupMultiVideoUnit];
    }
    
    if (!self.debugDragSeek) {
        if (!self.videoLink) {
            self.videoLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_playVideo)];
            self.videoLink.preferredFramesPerSecond = 30;
            [self.videoLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        }
    }
}

- (void)_seek {
    [self.multiVideoUnit seekToTime:0 isForce:YES];
    [self.multiAudioUnit seekToTime:0];
}

- (void)_pause {
}

- (void)_sliderValueChange {
    if (!self.debugDragSeek) return;
    
    double reqTime = _slider.value * 10;
    [self.multiVideoUnit seekToTime:reqTime];
    NSArray<NSDictionary<NSString *, AvuBuffer *> *> *buffers = [self.multiVideoUnit requestVideoBuffersAt:reqTime];
    for (int i = 0; i < buffers.count; i++) {
        AvuBuffer *buffer = buffers[i].allValues[0];
        if (buffer.pixelBuffer) {
            NSLog(@"[yjx] render index: %d, reqTime: %lf, buffer pts: %lf", i, reqTime, buffer.pts);
            [self.glPreviews[i] processPixelBuffer:buffer.pixelBuffer];
        }
    }
}

#pragma mark - TTGTextTagCollectionViewDelegate
- (void)textTagCollectionView:(TTGTextTagCollectionView *)textTagCollectionView
                    didTapTag:(TTGTextTag *)tag
                      atIndex:(NSUInteger)index {
    TTGTextTagStringContent *content = (TTGTextTagStringContent *)tag.content;
    if ([content.text isEqualToString:@"播放"]) {
        [self _play];
    } else if ([content.text isEqualToString:@"暂停"]) {
        [self _pause];
    } else if ([content.text isEqualToString:@"Seek"]) {
        [self _seek];
    }
    return;
}
@end
