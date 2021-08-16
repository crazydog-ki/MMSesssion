// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAVTBViewController.h"
#import "AVAsset+Extension.h"
#import "MMFFParser.h"
#import "MMFFDecoder.h"
#import "MMVideoGLPreview.h"
#import "MMAudioQueuePlayer.h"

@interface MMAVTBViewController () <TZImagePickerControllerDelegate, TTGTextTagCollectionViewDelegate>
@property (nonatomic, strong) TTGTextTagCollectionView *collectionView;

@property (nonatomic, strong) NSMutableArray<AVAsset *> *videoAssets;
@property (nonatomic, strong) NSMutableArray<NSData *> *imageDatas;

@property (nonatomic, strong) AVAsset *composition;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, assign) CGFloat videoRatio;

@property (nonatomic, strong) MMFFParser *ffVideoParser;
@property (nonatomic, strong) MMFFParser *ffAudioParser;
@property (nonatomic, strong) MMFFDecoder *ffVideoDecoder;
@property (nonatomic, strong) MMFFDecoder *ffAudioDecoder;
@property (nonatomic, strong) MMVideoGLPreview *glPreview;
@property (nonatomic, strong) MMAudioQueuePlayer *audioPlayer;

@property (nonatomic, strong) NSThread *videoThread;
@property (nonatomic, strong) NSThread *audioThread;

@property (nonatomic, assign) double videoPts;
@property (nonatomic, assign) double audioPts;

@property (nonatomic, assign) BOOL isReady;
@end

@implementation MMAVTBViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.navigationItem.title = @"AVTB Module";
    
    [self _setupCollectionView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self _stopThread];
}

- (void)dealloc {
    NSLog(@"[yjx] avtb controller destroy");
}

#pragma mark - Private
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
    
    TTGTextTag *allPlayTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频播放"] style:style];
    [tagCollectionView addTag:allPlayTag];
    
    TTGTextTag *exportTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频导出"] style:style];
    [tagCollectionView addTag:exportTag];
}

- (void)_setupParser {
    if (_ffVideoParser || _ffAudioParser) return;
    
    MMParseConfig *videoConfig = [[MMParseConfig alloc] init];
    videoConfig.parseType = MMFFParseType_Video;
    videoConfig.inPath = self.videoPath;
    _ffVideoParser = [[MMFFParser alloc] initWithConfig:videoConfig];
    
    MMParseConfig *audioConfig = [[MMParseConfig alloc] init];
    audioConfig.parseType = MMFFParseType_Audio;
    audioConfig.inPath = self.videoPath;
    _ffAudioParser = [[MMFFParser alloc] initWithConfig:audioConfig];
}

- (void)_setupDecoder {
    if (_ffVideoDecoder || _ffAudioDecoder) return;
    
    MMDecodeConfig *videoConfig = [[MMDecodeConfig alloc] init];
    videoConfig.decodeType = MMFFDecodeType_Video;
    videoConfig.fmtCtx = (void *)_ffVideoParser.getFmtCtx;
    _ffVideoDecoder = [[MMFFDecoder alloc] initWithConfig:videoConfig];
    
    MMDecodeConfig *audioConfig = [[MMDecodeConfig alloc] init];
    audioConfig.decodeType = MMFFDecodeType_Audio;
    audioConfig.fmtCtx = (void *)_ffAudioParser.getFmtCtx;
    _ffAudioDecoder = [[MMFFDecoder alloc] initWithConfig:audioConfig];
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
    
    MMAudioQueuePlayerConfig *playerConfig = [[MMAudioQueuePlayerConfig alloc] init];
    MMAudioQueuePlayer *audioPlayer = [[MMAudioQueuePlayer alloc] initWithConfig:playerConfig];
    self.audioPlayer = audioPlayer;
}

- (void)_startThread {
    self.isReady = YES;
    self.videoPts = 0.0f;
    self.audioPts = 0.0f;
    
    if (!self.videoThread) {
        self.videoThread = [[NSThread alloc] initWithTarget:self selector:@selector(_playVideo) object:nil];
        [self.videoThread start];
    }
    
    if (!self.audioThread) {
        self.audioThread = [[NSThread alloc] initWithTarget:self selector:@selector(_playAudio) object:nil];
        [self.audioThread start];
    }
}

- (void)_stopThread {
    self.isReady = NO;
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
    [self _setupParser];
    [self _setupDecoder];
    [self _setupPreview];
    [self _setupAudioPlayer];
    
    /// 视频处理链路
    [self.ffVideoParser addNextVideoNode:self.ffVideoDecoder];
    [self.ffVideoDecoder addNextVideoNode:self.glPreview];
    
    /// 音频处理链路
    [self.ffAudioParser addNextAudioNode:self.ffAudioDecoder];
    [self.ffAudioDecoder addNextAudioNode:self.audioPlayer];
    [self.audioPlayer play];
    
    [self _startThread];
}

- (void)_playVideo {
    while (self.isReady) {
        while (self.audioPts <= self.videoPts) {
            [NSThread sleepForTimeInterval:0.0001];
        }

        MMSampleData *sampleData = [[MMSampleData alloc] init];
        sampleData.dataType = MMSampleDataType_None_Video;
        [self.ffVideoParser processSampleData:sampleData];
        
        self.videoPts = self.glPreview.getPts;
    }
}

- (void)_playAudio {
    while (self.isReady) {
        MMSampleData *sampleData = [[MMSampleData alloc] init];
        sampleData.dataType = MMSampleDataType_None_Audio;
        [self.ffAudioParser processSampleData:sampleData];
        
        self.audioPts = self.audioPlayer.getPts;
    }
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
            NSLog(@"[yjx] picked image from album data: %@", imageData);
        }];
        
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:videoOptions resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
            if ([asset isKindOfClass:[AVURLAsset class]]) {
                AVURLAsset *urlAsset = (AVURLAsset *)asset;
                self.composition = urlAsset;
                self.videoPath = urlAsset.URL.path;
                double rotation = self.composition.rotation;
                if (rotation) {
                    NSLog(@"[yjx] import video with rotation msg: %lf", rotation);
                }
                AVAssetTrack *track = [urlAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
                if (track) {
                    CGFloat w = track.naturalSize.width;
                    CGFloat h = track.naturalSize.height;
                    self.videoRatio = MAX(w, h) / MIN(w, h);
                }
                [self.videoAssets addObject:urlAsset];
                NSLog(@"[yjx] picked video from album URL: %@", urlAsset.URL.path);
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
    } else if ([content.text isEqualToString:@"视频播放"]) {
        [self _play];
    } else if ([content.text isEqualToString:@"视频导出"]) {
        // [self _export];
    }
    return;
}
@end
