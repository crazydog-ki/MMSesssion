// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAVFDViewController.h"
#import "AVMutableComposition+Extension.h"
#import "AVAsset+Extension.h"
#import "MMVideoGLPreview.h"
#import "MMAudioQueuePlayer.h"
#import "MMDecodeReader.h"
#import "MMCompileWriter.h"

static const NSUInteger kMaxSamplesCount = 8192;

@interface MMAVFDViewController () <TZImagePickerControllerDelegate, TTGTextTagCollectionViewDelegate>
{
    AudioBufferList *_bufferList;
}
@property (nonatomic, strong) TTGTextTagCollectionView *collectionView;

@property (nonatomic, strong) NSMutableArray<AVAsset *> *videoAssets;
@property (nonatomic, strong) NSMutableArray<NSData *> *imageDatas;

@property (nonatomic, strong) AVAsset *composition;
@property (nonatomic, assign) CGFloat videoRatio;

@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, strong) MMDecodeReader *reader;
@property (nonatomic, assign) BOOL alreadyDecode;
@property (nonatomic, strong) MMAudioQueuePlayer *audioPlayer;
@property (nonatomic, strong) MMVideoGLPreview *glPreview;

@property (nonatomic, assign) double audioPts;
@property (nonatomic, assign) double videoPts;

@property (nonatomic, strong) MMCompileWriter *writer;
@end

@implementation MMAVFDViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.navigationItem.title = @"AVFD Module";
    
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

- (void)dealloc {
    NSLog(@"[yjx] avfd controller destroy");
}

#pragma mark - Private
- (void)_setupPreview {
    if (self.glPreview) return;
    
    CGFloat w = self.view.bounds.size.width;
    MMVideoGLPreview *glPreview = [[MMVideoGLPreview alloc] initWithFrame:CGRectMake(0, kNavBarHeight, w, w*self.videoRatio)];
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
    style.backgroundColor = kMMColor;
    style.exactWidth = 75.0f;
    style.exactHeight = 37.5f;
    style.cornerRadius = 0.0f;
    style.borderWidth = 0.0f;
    
    TTGTextTag *pickTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频导入"] style:style];
    [tagCollectionView addTag:pickTag];
    
    TTGTextTag *concatTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频拼接"] style:style];
    [tagCollectionView addTag:concatTag];
    
    TTGTextTag *allPlayTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频播放"] style:style];
    [tagCollectionView addTag:allPlayTag];
    
    TTGTextTag *exportTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频导出"] style:style];
    [tagCollectionView addTag:exportTag];
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
        
        /// 自定义裁切范围
        CMTime cmStart = CMTimeMake(start*videoTrack.timeRange.start.timescale, videoTrack.timeRange.start.timescale);
        CMTime cmDuration = CMTimeMake(duration*videoTrack.timeRange.duration.timescale, videoTrack.timeRange.duration.timescale);

        [composition concatVideo:self.videoAssets[idx] timeRange:CMTimeRangeMake(cmStart, cmDuration)];
        // [composition concatVideo:self.videoAssets[idx] timeRange:videoTrack.timeRange];
        
        NSLog(@"[yjx] video asset start: %lf, duration: %lf", CMTimeGetSeconds(videoTrack.timeRange.start), CMTimeGetSeconds(videoTrack.timeRange.duration));
        NSLog(@"[yjx] video asset after clip start: %lf, duration: %lf", start, duration);
    }
    [self.videoAssets removeAllObjects];
    self.composition = composition;
}

- (void)_play {
    /// 音视频解码
    [self _startDecode];
    
    /// 视频驱动
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_playVideo)];
        [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        [self.displayLink setPaused:NO];
    }
    
    /// 音频驱动
    [self _playAudio];
}

- (void)_playVideo {
    while (self.audioPts <= self.videoPts) {
        sleep(0.0001);
        if (!self.alreadyDecode) break;
    }
    
    if (self.reader) {
        [self _setupPreview];
        
        MMSampleData *videoData = [self.reader pullSampleBuffer:MMSampleDataTypeVideo];
        if (videoData.flag == MMSampleDataFlagEnd) {
            [self.displayLink setPaused:YES];
            NSLog(@"[yjx] pull video buffer end");
            return;
        }
        CMSampleBufferRef videoBuffer = videoData.sampleBuffer;
        if (self.writer) {
            [self.writer processVideoBuffer:videoBuffer];
        }
        
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
        MMSampleData *sampleData = [self.reader pullSampleBuffer:MMSampleDataTypeAudio];
        if (sampleData.flag == MMSampleDataFlagEnd) {
            NSLog(@"[yjx] pull audio buffer end");
            self.reader = nil;
            
            [self.writer stopEncodeWithCompleteHandle:^(NSURL * _Nullable fileUrl, NSError * _Nullable error) {
                NSLog(@"[yjx] writer output url: %@", fileUrl);
                /// 保存相册，便于调试
                if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileUrl.path)) {
                    UISaveVideoAtPathToSavedPhotosAlbum(fileUrl.path, nil, nil, nil);
                }
                self.writer = nil;
            }];
            
            self.alreadyDecode = NO;
            self.audioPts = 0.0f;
            self.videoPts = 0.0f;
            
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
            if (self.writer) {
                [self.writer processAudioBuffer:sampleBuffer];
            }
            
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
    if (_alreadyDecode || _reader) {
        NSLog(@"[yjx] reader is not available now");
        return;
    }
    
    MMDecodeReaderConfig *readerConfig = [[MMDecodeReaderConfig alloc] init];
    readerConfig.videoAsset = self.composition;
    _reader = [[MMDecodeReader alloc] initWithConfig:readerConfig];

    [self.reader startDecode];
    _alreadyDecode = YES;
}

- (void)_export {
    if (!_writer) {
        NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *outputPath = [docPath stringByAppendingString:@"/yjx.mov"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        }
        
        CGSize outputSize = CGSizeMake(720, 1280);
        if (self.composition.rotation == M_PI_2 ||
            self.composition.rotation == 3*M_PI_2) {
            outputSize = CGSizeMake(1280, 720);
        }
        
        MMCompileWriterConfig *compileConfig = [[MMCompileWriterConfig alloc] init];
        compileConfig.outputUrl = [NSURL fileURLWithPath:outputPath];
        compileConfig.roration = self.composition.rotation;
        compileConfig.videoSetttings = @{
            AVVideoCodecKey : AVVideoCodecTypeH264,
            AVVideoWidthKey : @(outputSize.width),
            AVVideoHeightKey: @(outputSize.height)
        };
        compileConfig.pixelBufferAttributes = @{
            (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                      (__bridge NSString *)kCVPixelBufferWidthKey: @(outputSize.width),
                     (__bridge NSString *)kCVPixelBufferHeightKey: @(outputSize.height)
        };
        compileConfig.audioSetttings = @{
                    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                  AVSampleRateKey: @(44100),
            AVNumberOfChannelsKey: @(2)
        };
        _writer = [[MMCompileWriter alloc] initWithConfig:compileConfig];
        [_writer startEncode];
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
    } else if ([content.text isEqualToString:@"视频拼接"]) {
        [self _startConcat];
    } else if ([content.text isEqualToString:@"视频播放"]) {
        [self _play];
    } else if ([content.text isEqualToString:@"视频导出"]) {
        [self _export];
    }
    return;
}
@end
