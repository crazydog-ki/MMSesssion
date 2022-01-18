// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAVFFTBViewController.h"
#import "AVAsset+Extension.h"
#import "MMFFParser.h"
#import "MMFFDecoder.h"
#import "MMVideoGLPreview.h"
#import "MMAudioQueuePlayer.h"
#import "MMEncodeWriter.h"
#import "MMVTEncoder.h"
#import "MMAudioRecorder.h"

#include <iostream>
#include <fstream>
using namespace std;

@interface MMAVFFTBViewController () <TZImagePickerControllerDelegate, TTGTextTagCollectionViewDelegate> {
    ofstream _yuvFileHandle;
}
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
@property (nonatomic, strong) MMEncodeWriter *encodeWriter;
@property (nonatomic, strong) MMVTEncoder *vtEncoder;

@property (nonatomic, strong) NSThread *videoThread;
@property (nonatomic, strong) NSThread *audioThread;

@property (nonatomic, assign) double videoPts;
@property (nonatomic, assign) double audioPts;

@property (nonatomic, assign) BOOL isReady;

@property (nonatomic, assign) BOOL needExport;

@property (nonatomic, assign) BOOL needWritePcm;
@property (nonatomic, strong) NSFileHandle *pcmFileHandle;
@property (nonatomic, assign) BOOL needWriteYuv;

@property (nonatomic, strong) MMAudioRecorder *audioRecorder;
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
    
    TTGTextTag *seekTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"seek-0"] style:style];
    [tagCollectionView addTag:seekTag];
    
    TTGTextTag *pcmTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"提取pcm"] style:style];
    [tagCollectionView addTag:pcmTag];
    
    TTGTextTag *yuvTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"提取yuv"] style:style];
    [tagCollectionView addTag:yuvTag];
    
    TTGTextTag *recordTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"开始录音"] style:style];
    [tagCollectionView addTag:recordTag];
    
    TTGTextTag *stopRecordTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"停止录音"] style:style];
    [tagCollectionView addTag:stopRecordTag];
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
    videoConfig.needYuv = self.needWriteYuv;
    _ffVideoDecoder = [[MMFFDecoder alloc] initWithConfig:videoConfig];
    
    MMDecodeConfig *audioConfig = [[MMDecodeConfig alloc] init];
    audioConfig.decodeType = MMFFDecodeType_Audio;
    audioConfig.fmtCtx = (void *)_ffAudioParser.getFmtCtx;
    audioConfig.needPcm = self.needWritePcm;
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

    weakify(self);
    [self.glPreview setRenderEndBlk:^{
        strongify(self);
        self.videoPts = 0.0f;
        
        [self.videoThread cancel];
        self.videoThread = nil;
    }];
}

- (void)_setupAudioPlayer {
    if (self.audioPlayer) return;
    
    MMAudioQueuePlayerConfig *playerConfig = [[MMAudioQueuePlayerConfig alloc] init];
    playerConfig.needPullData = NO;
    MMAudioQueuePlayer *audioPlayer = [[MMAudioQueuePlayer alloc] initWithConfig:playerConfig];
    self.audioPlayer = audioPlayer;
    
    weakify(self);
    [self.audioPlayer setPlayEndBlk:^{
        strongify(self);
        self.audioPts = 0.0f;
        
        [self.audioThread cancel];
        self.audioThread = nil;
    }];
}

- (void)_setupWriter {
    if (!_encodeWriter) {
        NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *outputPath = [docPath stringByAppendingString:@"/yjx.mov"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        }
        
        CGSize outputSize = CGSizeMake(720, 1280);
        
        MMEncodeConfig *compileConfig = [[MMEncodeConfig alloc] init];
        compileConfig.onlyMux = YES;
        compileConfig.outputUrl = [NSURL fileURLWithPath:outputPath];
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
        _encodeWriter = [[MMEncodeWriter alloc] initWithConfig:compileConfig];
        [_encodeWriter startEncode];
        
        weakify(self);
        [_encodeWriter setEndEncodeBlk:^{
            strongify(self);
            [self.encodeWriter stopEncodeWithCompleteHandle:^(NSURL * _Nullable fileUrl, NSError * _Nullable error) {
                NSLog(@"[yjx] writer output url: %@", fileUrl);
                /// 保存相册，便于调试
                if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileUrl.path)) {
                    UISaveVideoAtPathToSavedPhotosAlbum(fileUrl.path, nil, nil, nil);
                }
                self.encodeWriter = nil;
            }];
        }];
    }
    
    if (!_vtEncoder) {
        MMEncodeConfig *encodeConfg = [[MMEncodeConfig alloc] init];
        encodeConfg.pixelFormat = MMPixelFormatTypeFullRangeYUV;
        encodeConfg.videoSize = CGSizeMake(720, 1280);
        encodeConfg.keyframeInterval = 1.0f;
        encodeConfg.allowBFrame = NO;
        encodeConfg.allowRealtime = NO;
        encodeConfg.bitrate = 2560000;
        
        self.vtEncoder = [[MMVTEncoder alloc] initWithConfig:encodeConfg];
    }
}

- (void)_setupPcmExtractor {
    NSString *pcmPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"44100_2_f32le.pcm"];
    __block NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:pcmPath error:&error];
    [[NSFileManager defaultManager] createFileAtPath:pcmPath contents:nil attributes:nil];
    NSLog(@"[yjx] start extract pcm, path: %@", pcmPath);
    self.pcmFileHandle = [NSFileHandle fileHandleForWritingAtPath:pcmPath];
    weakify(self);
    self.ffAudioDecoder.pcmCallback = ^(NSData * _Nonnull data) {
        strongify(self);
        [self.pcmFileHandle writeData:data error:&error];
        if (error) {
            NSLog(@"[yjx] extract pcm error: %@", error);
        }
    };
}

- (void)_setupYuvExtractor {
    NSString *yuvPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"420p.yuv"];
    __block NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:yuvPath error:&error];
    [[NSFileManager defaultManager] createFileAtPath:yuvPath contents:nil attributes:nil];
    NSLog(@"[yjx] start extract yuv, path: %@", yuvPath);
    self->_yuvFileHandle = ofstream(yuvPath.UTF8String, ios_base::binary);
    weakify(self);
    self.ffVideoDecoder.yuvCallback = ^(void * _Nonnull data, int size, MMYUVType type) {
        strongify(self);
        self->_yuvFileHandle.write((const char *)data, size);
    };
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
    if (self.isReady) {
        NSLog(@"[yjx] video & audio is already playing");
        return;
    }
    
    [self _setupParser];
    [self _setupDecoder];
    [self _setupPreview];
    [self _setupAudioPlayer];
    if (self.needExport) {
        [self _setupWriter];
    }
    if (self.needWritePcm) {
        [self _setupPcmExtractor];
    }
    
    if (self.needWriteYuv) {
        [self _setupYuvExtractor];
    }
    
    /**视频处理链路
     Demux(FFmpeg) -> Decode(FFmpeg) -> Render(OpenGL ES)
                                     -> Encode(VideoToolBox) -> Mux(AVAssetWriter)
     */
    [self.ffVideoParser addNextVideoNode:self.ffVideoDecoder];
    [self.ffVideoDecoder addNextVideoNode:self.glPreview];
    if (self.vtEncoder) {
        [self.ffVideoDecoder addNextVideoNode:self.vtEncoder];
    }
    if (self.encodeWriter) {
        [self.vtEncoder addNextVideoNode:self.encodeWriter];
    }
    
    /**音频处理链路
     Demux(FFmpeg) -> Decode(FFmpeg) -> Render(AudioQueueRef)
                                     -> Encode & Mux(AVAssetWriter)
     */
    [self.ffAudioParser addNextAudioNode:self.ffAudioDecoder];
    [self.ffAudioDecoder addNextAudioNode:self.audioPlayer];
    if (self.encodeWriter) {
        [self.ffAudioDecoder addNextAudioNode:self.encodeWriter];
    }
    
    [self.audioPlayer play];
    [self _startThread];
}

- (void)_playVideo {
    while (self.isReady && self.ffVideoParser && self.ffVideoDecoder && self.glPreview) {
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
    while (self.isReady && self.ffAudioParser && self.ffAudioDecoder && self.audioPlayer) {
        MMSampleData *sampleData = [[MMSampleData alloc] init];
        sampleData.dataType = MMSampleDataType_None_Audio;
        [self.ffAudioParser processSampleData:sampleData];
        self.audioPts = self.audioPlayer.getPts;
    }
}

- (void)_export {
    self.needExport = YES;
}

- (void)_seek {
    self.videoPts = 0.0f;
    self.audioPts = 0.0f;
    
    [self.ffVideoParser seekToTime:0.0f];
    [self.ffAudioParser seekToTime:0.0f];
}

- (void)_extractPcm {
    self.needWritePcm = YES;
}

- (void)_extractYuv {
    self.needWriteYuv = YES;
}

- (void)_startRecordAudio {
    if (!_audioRecorder) {
        MMAudioRecorderConfig *audioRecordConfig = [[MMAudioRecorderConfig alloc] init];
        audioRecordConfig.audioFormat = MMAudioFormatPCM;
        audioRecordConfig.sampleRate = 44100;
        audioRecordConfig.channelsCount = 1;
        NSString *audioPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *outputPath = [audioPath stringByAppendingString:@"/yjx.caf"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        }
        audioRecordConfig.audioFilePath = outputPath;
        _audioRecorder = [[MMAudioRecorder alloc] initWithConfig:audioRecordConfig];
    }
    
    [_audioRecorder startRecord];
}

- (void)_stopRecordAudio {
    [_audioRecorder stopRecord];
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
                    self.videoRatio = h/w;
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
        [self _export];
    } else if ([content.text isEqualToString:@"seek-0"]) {
        [self _seek];
    } else if ([content.text isEqualToString:@"提取pcm"]) {
        [self _extractPcm];
    } else if ([content.text isEqualToString:@"提取yuv"]) {
        [self _extractYuv];
    } else if ([content.text isEqualToString:@"开始录音"]) {
        [self _startRecordAudio];
    } else if ([content.text isEqualToString:@"停止录音"]) {
        [self _stopRecordAudio];
    }
    return;
}
@end
