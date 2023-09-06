// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAVFFTBViewController.h"
#include "MMFFParser.h"
#include "MMVTDecoder.h"
#include "MMPreviewUnit.h"
#include "MMDriveUnit.h"
#include "MMFFDecoder.h"
#include "MMAudioPlayer.h"
using namespace std;

@interface MMAVFFTBViewController () <TZImagePickerControllerDelegate, TTGTextTagCollectionViewDelegate> {
    shared_ptr<MMFFParser> _ffVideoParser;
    shared_ptr<MMVTDecoder> _vtDecoder;
    shared_ptr<MMPreviewUnit> _previewUnit;
    shared_ptr<MMDriveUnit> _driveUnit;
    
    shared_ptr<MMFFParser> _ffAudioParser;
    shared_ptr<MMFFDecoder> _ffAudioDecoder;
    shared_ptr<MMAudioPlayer> _audioPlayer;
}
@property (nonatomic, strong) TTGTextTagCollectionView *collectionView;

@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, assign) CGFloat videoRatio;

@property (nonatomic, strong) NSThread *videoThread;
@property (nonatomic, strong) NSThread *audioThread;

@property (nonatomic, assign) BOOL isReady;
@end

@implementation MMAVFFTBViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.navigationItem.title = @"FFTB Module";
    
    [self _setupCollectionView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self _stopThread];
    
    _audioPlayer->stop();
}

- (void)dealloc {
    NSLog(@"[yjx] fftb controller destroy");
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
    
    TTGTextTagStyle *style1 = [TTGTextTagStyle new];
    style1.backgroundColor = kMMColor2;
    style1.exactWidth = 120.0f;
    style1.exactHeight = 37.5f;
    style1.cornerRadius = 0.0f;
    style1.borderWidth = 0.0f;
    //local video
    TTGTextTag *mp4_h264_avcc = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"mp4-h264-AvCc"] style:style1];
    [tagCollectionView addTag:mp4_h264_avcc];
    
    TTGTextTag *avi_h264_annexb = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"avi-h264-AnnexB"] style:style1];
    [tagCollectionView addTag:avi_h264_annexb];
    
    TTGTextTagStyle *style2 = [TTGTextTagStyle new];
    style2.backgroundColor = kMMColor3;
    style2.exactWidth = 70.0f;
    style2.exactHeight = 37.5f;
    style2.cornerRadius = 0.0f;
    style2.borderWidth = 0.0f;
    
    //album video
    TTGTextTag *pickTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"相册导入"] style:style2];
    [tagCollectionView addTag:pickTag];
    
    TTGTextTag *allPlayTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频播放"] style:style2];
    [tagCollectionView addTag:allPlayTag];
}

- (void)_setupParser {
    MMParseConfig videoConfig;
    videoConfig.parseType = MMFFParseType_Video;
    videoConfig.inPath = string([self.videoPath UTF8String]);
    _ffVideoParser = shared_ptr<MMFFParser>(new MMFFParser(videoConfig));
    
    MMParseConfig audioConfig;
    audioConfig.parseType = MMFFParseType_Audio;
    audioConfig.inPath = string([self.videoPath UTF8String]);
    _ffAudioParser = shared_ptr<MMFFParser>(new MMFFParser(audioConfig));
}

- (void)_setupDecoder {
    MMDecodeConfig videoConfig;
    videoConfig.decodeType = MMDecodeType_Video;
    videoConfig.fmtCtx = (void *)_ffVideoParser->getFmtCtx();
    videoConfig.vtDesc = _ffVideoParser->getVtDesc();
    videoConfig.targetSize = _ffVideoParser->getSize();
    videoConfig.pixelformat = MMPixelFormatTypeBGRA;
    _vtDecoder = shared_ptr<MMVTDecoder>(new MMVTDecoder(videoConfig));
    
    MMDecodeConfig audioConfig;
    audioConfig.decodeType = MMDecodeType_Audio;
    audioConfig.fmtCtx = _ffAudioParser->getFmtCtx();
    _ffAudioDecoder = shared_ptr<MMFFDecoder>(new MMFFDecoder(audioConfig));
}

- (void)_setupDriveUnit {
    _driveUnit = make_shared<MMDriveUnit>();
}

- (void)_setupPreview {
    if (_previewUnit) return;
    
    CGFloat w = self.view.bounds.size.width;
    
    MMPreviewConfig config;
    config.renderYUV = false;
    config.presentRect = CGRectMake(0, 0, w, w*self.videoRatio);
    config.viewFrame = CGRectMake(0, kStatusBarH+kNavBarH, w, w*self.videoRatio);
    _previewUnit = shared_ptr<MMPreviewUnit>(new MMPreviewUnit(config));
    
    MMVideoGLPreview *renderView = _previewUnit->getRenderView();
    renderView.backgroundColor = UIColor.blackColor;
    [self.view insertSubview:renderView atIndex:0];
    
    [renderView setupGLEnv];
}

- (void)_setupAudioPlayer {
    MMAudioPlayConfig config;
    config.needPullData = false; //推数据
    _audioPlayer = shared_ptr<MMAudioPlayer>(new MMAudioPlayer(config));
}

- (void)_startThread {
    self.isReady = YES;
    
    _audioPlayer->play(); //驱动
    
    if (!self.videoThread) {
        self.videoThread = [[NSThread alloc] initWithTarget:self selector:@selector(_driveVideo) object:nil];
        [self.videoThread start];
    }
    
    if (!self.audioThread) {
        self.audioThread = [[NSThread alloc] initWithTarget:self selector:@selector(_driveAudio) object:nil];
        [self.audioThread start];
    }
}

- (void)_stopThread {
    self.isReady = NO;
    
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

- (void)_buildChainAndPlay {
    if (self.isReady) {
        NSLog(@"[yjx] video & audio is already playing");
        return;
    }
    
    [self _setupParser];
    [self _setupDecoder];
    [self _setupDriveUnit];
    [self _setupPreview];
    [self _setupAudioPlayer];
    
    /**视频处理链路*/
    _ffVideoParser->addNextVideoNode(_vtDecoder);
    _vtDecoder->addNextVideoNode(_driveUnit);
    _driveUnit->addNextVideoNode(_previewUnit);
    
    /**音频处理链路*/
    _ffAudioParser->addNextAudioNode(_ffAudioDecoder);
    _ffAudioDecoder->addNextAudioNode(_audioPlayer);
    
    [self _startThread];
}

- (void)_driveVideo {
    while (self.isReady && _ffVideoParser && _vtDecoder && _previewUnit) {
        shared_ptr<MMSampleData> sampleData = make_shared<MMSampleData>();
        sampleData->dataType = MMSampleDataType_None_Video;
        _ffVideoParser->process(sampleData);
    }
}

- (void)_driveAudio {
    while (self.isReady && _ffAudioParser && _ffAudioDecoder) {
        shared_ptr<MMSampleData> sampleData = make_shared<MMSampleData>();
        sampleData->dataType = MMSampleDataType_None_Audio;
        _ffAudioParser->process(sampleData);
    }
}

#pragma mark - TZImagePickerControllerDelegate
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingPhotos:(NSArray<UIImage *> *)photos sourceAssets:(NSArray *)assets isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto infos:(NSArray<NSDictionary *> *)infos {
    PHVideoRequestOptions *videoOptions = [[PHVideoRequestOptions alloc] init];
    videoOptions.version = PHVideoRequestOptionsVersionOriginal;
    
    for (PHAsset *asset in assets) {
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:videoOptions resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
            if ([asset isKindOfClass:[AVURLAsset class]]) {
                AVURLAsset *urlAsset = (AVURLAsset *)asset;
                self.videoPath = urlAsset.URL.path;
                AVAssetTrack *track = [urlAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
                if (track) {
                    CGFloat w = track.naturalSize.width;
                    CGFloat h = track.naturalSize.height;
                    self.videoRatio = h/w;
                }
                NSLog(@"[yjx] picked video from album URL: %@", urlAsset.URL.path);
            }
        }];
    }
}

#pragma mark - TTGTextTagCollectionViewDelegate
- (void)_getParamFormPath:(NSString *)path {
    AVAsset *urlAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
    AVAssetTrack *track = [urlAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (track) {
        CGFloat w = track.naturalSize.width;
        CGFloat h = track.naturalSize.height;
        self.videoRatio = h/w;
    }
}

- (void)textTagCollectionView:(TTGTextTagCollectionView *)textTagCollectionView
                    didTapTag:(TTGTextTag *)tag
                      atIndex:(NSUInteger)index {
    TTGTextTagStringContent *content = (TTGTextTagStringContent *)tag.content;
    if ([content.text isEqualToString:@"mp4-h264-AvCc"]) {
        self.videoPath = [NSString stringWithFormat:@"%@/mp4_h264_avcc.mp4", NSBundle.mainBundle.bundleURL.path];
    } else if([content.text isEqualToString:@"avi-h264-AnnexB"]) {
        self.videoPath = [NSString stringWithFormat:@"%@/avi_h264-annexb.avi", NSBundle.mainBundle.bundleURL.path];
    } else if ([content.text isEqualToString:@"相册导入"]) {
        [self _startPick];
    } else if ([content.text isEqualToString:@"视频播放"]) {
        [self _buildChainAndPlay];
    }
    
    if (self.videoPath) { //非相册导入
        [self _getParamFormPath:self.videoPath];
        NSLog(@"[yjx] pick local video path: %@, ratio: %lf", self.videoPath, self.videoRatio);
    }
    return;
}
@end
