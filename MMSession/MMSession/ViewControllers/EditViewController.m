// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "EditViewController.h"
#import "AVMutableComposition+Concat.h"
#import "VideoGLPreview.h"
#import "MMAudioQueuePlayer.h"
#import "MMAssetReader.h"

static const NSUInteger kMaxSamplesCount = 8192;

@interface EditViewController () <TZImagePickerControllerDelegate, TTGTextTagCollectionViewDelegate>
{
    AudioBufferList *_bufferList;
}
@property (nonatomic, strong) TTGTextTagCollectionView *collectionView;

@property (nonatomic, strong) NSMutableArray<AVAsset *> *videoAssets;
@property (nonatomic, strong) NSMutableArray<NSData *> *imageDatas;

@property (nonatomic, strong) AVAsset *composition;
@property (nonatomic, assign) CGFloat videoRatio;

@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, strong) MMAssetReader *assetReader;
@property (nonatomic, assign) BOOL alreadyDecode;
@property (nonatomic, strong) MMAudioQueuePlayer *audioPlayer;
@property (nonatomic, strong) VideoGLPreview *glPreview;

@property (nonatomic, assign) double audioPts;
@property (nonatomic, assign) double videoPts;
@end

@implementation EditViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.navigationItem.title = @"Edit Module";
    
    _alreadyDecode = NO;
    _audioPts = 0.0f;
    _videoPts = 0.0f;
    
    self.videoAssets = [NSMutableArray array];
    self.imageDatas = [NSMutableArray array];
    
    [self _setupCollectionView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.audioPlayer) {
        [self.audioPlayer stop];
        self.audioPlayer = nil;
    }
    
    if (self.displayLink) {
        [self.displayLink setPaused:YES];
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

#pragma mark - Private
- (void)_setupPreview {
    if (self.glPreview) return;
    
    CGFloat w = self.view.bounds.size.width;
    VideoGLPreview *glPreview = [[VideoGLPreview alloc] initWithFrame:CGRectMake(0, kNavBarHeight, w, w*self.videoRatio)];
    glPreview.backgroundColor = UIColor.blackColor;
    [self.view insertSubview:glPreview atIndex:0];
    self.glPreview = glPreview;
    
    VideoPreviewConfig *config = [[VideoPreviewConfig alloc] init];
    config.renderYUV = YES;
    config.presentRect = CGRectMake(0, 0, w, w*self.videoRatio);
    self.glPreview.config = config;
    [self.glPreview setupGLEnv];
}

- (void)_setupCollectionView {
    TTGTextTagCollectionView *tagCollectionView = [[TTGTextTagCollectionView alloc] init];
    tagCollectionView.delegate = self;
    [self.view addSubview:tagCollectionView];
    self.collectionView = tagCollectionView;
    [tagCollectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.view);
        make.top.equalTo(self.view).offset(kNavBarHeight);
        make.bottom.equalTo(self.view);
    }];
    
    TTGTextTagStyle *style = [TTGTextTagStyle new];
    style.backgroundColor = kStyleColor;
    style.exactWidth = 75.0f;
    style.exactHeight = 37.5f;
    style.cornerRadius = 0.0f;
    
    TTGTextTag *pickTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频导入"] style:style];
    [tagCollectionView addTag:pickTag];
    
    TTGTextTag *concatTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频拼接"] style:style];
    [tagCollectionView addTag:concatTag];
    
    TTGTextTag *allPlayTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频播放"] style:style];
    [tagCollectionView addTag:allPlayTag];
}

- (AudioBufferList *)_createAudioBufferList:(AudioStreamBasicDescription)audioFormat
                               numberFrames:(UInt32)frameCount {
    BOOL isInterleaved = !(audioFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
    int bufferNum = isInterleaved ? 1:audioFormat.mChannelsPerFrame;
    int channelsPerBuffer = isInterleaved ? audioFormat.mChannelsPerFrame:1;
    int bytesPerBuffer = audioFormat.mBytesPerFrame * frameCount;

    AudioBufferList *audioBuffer = calloc(1, sizeof(AudioBufferList) + (bufferNum-1) * sizeof(AudioBuffer));
    audioBuffer->mNumberBuffers = bufferNum;
    for (int i = 0; i < bufferNum; i++) {
        audioBuffer->mBuffers[i].mData = calloc(bytesPerBuffer, 1);
        audioBuffer->mBuffers[i].mDataByteSize = bytesPerBuffer;
        audioBuffer->mBuffers[i].mNumberChannels = channelsPerBuffer;
    }
    return audioBuffer;
}

#pragma mark - Action
- (void)_startPick {
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:9 delegate:self];
    imagePickerVc.allowPickingMultipleVideo = YES;
    imagePickerVc.isSelectOriginalPhoto = YES;
    [self presentViewController:imagePickerVc animated:YES completion:nil];
}

- (void)_startConcat {
    if (!self.videoAssets.count) {
        NSLog(@"[yjx] video assets is empty");
        return;
    }
    
    double start = 3.0f;
    double duration = 5.0f;
    AVMutableComposition *composition = [AVMutableComposition composition];
    for (NSUInteger idx = 0; idx < self.videoAssets.count; idx++) {
        AVAsset *asset = self.videoAssets[idx];
        AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        
        // 自定义裁切范围
        CMTime cmStart = CMTimeMake(start*videoTrack.timeRange.start.timescale, videoTrack.timeRange.start.timescale);
        CMTime cmDuration = CMTimeMake(duration*videoTrack.timeRange.duration.timescale, videoTrack.timeRange.duration.timescale);

        [composition concatVideo:self.videoAssets[idx] timeRange:CMTimeRangeMake(cmStart, cmDuration)];
//        [composition concatVideo:self.videoAssets[idx] timeRange:videoTrack.timeRange];
        
        NSLog(@"[yjx] video asset start: %lf, duration: %lf", CMTimeGetSeconds(videoTrack.timeRange.start), CMTimeGetSeconds(videoTrack.timeRange.duration));
        NSLog(@"[yjx] video asset after clip start: %lf, duration: %lf", start, duration);
    }
    [self.videoAssets removeAllObjects];
    self.composition = composition;
}

- (void)_play {
    // 音视频解码
    [self _startDecode];
    
    // 视频驱动
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_playVideo)];
        [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        [self.displayLink setPaused:NO];
    }
    
    // 音频驱动
    [self _playAudio];
}

- (void)_playVideo {
    while (self.audioPts <= self.videoPts) {
        sleep(0.0001);
        if (!self.alreadyDecode) break;
    }
    
    if (self.assetReader) {
        [self _setupPreview];
        
        MMSampleData *videoData = [self.assetReader pullSampleBuffer:MMSampleDataTypeVideo];
        if (videoData.flag == MMSampleDataFlagEnd) {
            [self.displayLink setPaused:YES];
            NSLog(@"[yjx] pull video buffer end");
            return;
        }
        CMSampleBufferRef videoBuffer = videoData.sampleBuffer;
        self.videoPts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(videoBuffer));
        NSLog(@"[yjx] pull video buffer, pts: %lf", self.videoPts);
        
        if (self.glPreview) {
            [self.glPreview processVideoBuffer:videoBuffer];
        }
        if (videoBuffer) {
            CFRelease(videoBuffer);
            videoBuffer = nil;
        }
    }
}

- (void)_playAudio {
    if (!self.audioPlayer) {
        MMAudioQueuePlayerConfig *playerConfig = [[MMAudioQueuePlayerConfig alloc] init];
        MMAudioQueuePlayer *audioPlayer = [[MMAudioQueuePlayer alloc] initWithConfig:playerConfig];
        self.audioPlayer = audioPlayer;
    } else {
        NSLog(@"[yjx] audio is playing now, can not interrupt");
        return;
    }
    
    weakify(self);
    _bufferList = [self _createAudioBufferList:self.audioPlayer.asbd numberFrames:kMaxSamplesCount];
    self.audioPlayer.pullDataBlk = ^(AudioBufferBlock  _Nonnull block) {
        strongify(self);
        MMSampleData *sampleData = [self.assetReader pullSampleBuffer:MMSampleDataTypeAudio];
        if (sampleData.flag == MMSampleDataFlagEnd) {
            NSLog(@"[yjx] pull audio buffer end");
            self.assetReader = nil;
            
            self.alreadyDecode = NO;
            self.audioPts = 0.0f;
            self.videoPts = 0.0f;
            
            [self.displayLink removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
            [self.displayLink setPaused:YES];
            [self.displayLink invalidate];
            self.displayLink = nil;
            
            [self.audioPlayer stop];
            self.audioPlayer = nil;
            return;
        }
        CMSampleBufferRef sampleBuffer = sampleData.sampleBuffer;
        
        NSUInteger samplesCount = (long)CMSampleBufferGetNumSamples(sampleBuffer);
        self.audioPts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer));
    
        NSLog(@"[yjx] pull audio buffer, samples: %ld, pts: %lf", samplesCount, self.audioPts);
        
        if (sampleBuffer) {
            UInt32 samples = (UInt32)CMSampleBufferGetNumSamples(sampleBuffer);
            self->_bufferList->mBuffers[0].mDataByteSize = samples * self.audioPlayer.asbd.mBytesPerFrame;
            CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, 0, samples, self->_bufferList);
            CFRelease(sampleBuffer);
        }
        block(self->_bufferList);
        
        /**直接CMSampleBuffer->AudioBufferList
         AudioBufferList audioBufferList;
         CMBlockBufferRef blockbuffer;
         CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
               sampleBuffer,
               NULL,
               &audioBufferList,
               sizeof(audioBufferList),
               NULL,
               NULL,
               kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
               &blockbuffer);
         block(&audioBufferList);
         CFRelease(sampleBuffer);
         CFRelease(blockbuffer);
         */
    };
    
    [self.audioPlayer play];
}

- (void)_startDecode {
    if (_alreadyDecode || _assetReader) {
        NSLog(@"[yjx] reader is not available now");
        return;
    }
    
    MMAssetReaderConfig *readerConfig = [[MMAssetReaderConfig alloc] init];
    readerConfig.videoAsset = self.composition;
    _assetReader = [[MMAssetReader alloc] initWithConfig:readerConfig];

    [self.assetReader startReading];
    _alreadyDecode = YES;
}

#pragma mark - TZImagePickerControllerDelegate
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingPhotos:(NSArray<UIImage *> *)photos sourceAssets:(NSArray *)assets isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto infos:(NSArray<NSDictionary *> *)infos {
    
    // 图片
    PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
    imageOptions.version = PHImageRequestOptionsVersionOriginal;
    
    // 视频
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
                AVAssetTrack *track = [urlAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
                if (track) {
                    self.videoRatio = track.naturalSize.height / track.naturalSize.width;
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
    } else if ([content.text isEqualToString:@"视频拼接"]) {
        [self _startConcat];
    } else if ([content.text isEqualToString:@"视频播放"]) {
        [self _play];
    }
    return;
}
@end
