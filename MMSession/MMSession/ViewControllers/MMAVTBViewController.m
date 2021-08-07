// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAVTBViewController.h"
#import "AVAsset+Extension.h"
#import "MMFFParser.h"
#import "MMFFDecoder.h"

@interface MMAVTBViewController () <TZImagePickerControllerDelegate, TTGTextTagCollectionViewDelegate>
@property (nonatomic, strong) TTGTextTagCollectionView *collectionView;

@property (nonatomic, strong) NSMutableArray<AVAsset *> *videoAssets;
@property (nonatomic, strong) NSMutableArray<NSData *> *imageDatas;

@property (nonatomic, strong) AVAsset *composition;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, assign) CGFloat videoRatio;

@property (nonatomic, strong) MMFFParser *ffParser;
@property (nonatomic, strong) MMFFDecoder *ffDecoder;

@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation MMAVTBViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.navigationItem.title = @"AVTB Module";
    
    [self _setupCollectionView];
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
    
    TTGTextTag *allPlayTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频播放"] style:style];
    [tagCollectionView addTag:allPlayTag];
    
    TTGTextTag *exportTag = [TTGTextTag tagWithContent:[TTGTextTagStringContent contentWithText:@"视频导出"] style:style];
    [tagCollectionView addTag:exportTag];
}

#pragma mark - Action
- (void)_startPick {
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:9 delegate:self];
    imagePickerVc.allowPickingMultipleVideo = YES;
    imagePickerVc.isSelectOriginalPhoto = YES;
    [self presentViewController:imagePickerVc animated:YES completion:nil];
}

- (void)_play {
    if (!_ffParser) {
        MMParseConfig *config = [[MMParseConfig alloc] init];
        config.inPath = self.videoPath;
        _ffParser = [[MMFFParser alloc] initWithConfig:config];
    }
    
    if (!_ffDecoder) {
        MMDecodeConfig *config = [[MMDecodeConfig alloc] init];
        config.fmtCtx = (void *)_ffParser.getFmtCtx;
        _ffDecoder = [[MMFFDecoder alloc] initWithConfig:config];
    }
    
    weakify(self);
    [_ffParser startParse:^(MMSampleData * _Nonnull data) {
        strongify(self);
        if (data.dataType == MMSampleDataType_Parsed_Video) {
            NSLog(@"[yjx] get parsed video, size: %d, pts: %lf", data.videoInfo.dataSize, data.videoInfo.pts);
            data.dataType = MMSampleDataType_Pull_Video;
            MMSampleData *videoData = [self.ffDecoder decodeParsedData:data];
            CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(videoData.sampleBuffer);
            NSLog(@"[yjx] get decoded video data: %p", pixelBuffer);
        } else if (data.dataType == MMSampleDataType_Parsed_Audio) {
            NSLog(@"[yjx] get parsed audio, size: %d, pts: %lf", data.audioInfo.dataSize, data.audioInfo.pts);
            data.dataType = MMSampleDataType_Pull_Audio;
        }
    }];
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
