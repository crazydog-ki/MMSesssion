// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAVFFTBViewController.h"
#import "MMGraph.h"
using namespace std;

@interface MMAVFFTBViewController () <TZImagePickerControllerDelegate, TTGTextTagCollectionViewDelegate> {
    shared_ptr<MMGraph> _graph;
}
@property (nonatomic, strong) TTGTextTagCollectionView *collectionView;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, assign) CGFloat videoRatio;
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
}

- (void)dealloc {
    if (_graph) {
        _graph->destroy(); //销毁资源
        _graph = nullptr;
    }
    NSLog(@"[mm] fftb controller destroy");
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

#pragma mark - Action
- (void)_startPick {
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:9 delegate:self];
    imagePickerVc.allowPickingMultipleVideo = YES;
    imagePickerVc.isSelectOriginalPhoto = YES;
    [self presentViewController:imagePickerVc animated:YES completion:nil];
}

- (void)_buildChainAndPlay {
    if (self.videoPath) { //非相册导入
        [self _getParamFormPath:self.videoPath];
        NSLog(@"[mm] pick video path: %@, ratio: %lf", self.videoPath, self.videoRatio);
    }
    
    CGFloat w = self.view.bounds.size.width;
    
    MMGraphConfig config = MMGraphConfig();
    config.videoPath = string([self.videoPath UTF8String]);
    config.view = self.view;
    config.presentRect = CGRectMake(0, 0, w, w*self.videoRatio);
    config.viewRect = CGRectMake(0, kStatusBarH+kNavBarH, w, w*self.videoRatio);
    
    _graph = make_shared<MMGraph>(config);
    _graph->drive();
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
                NSLog(@"[mm] picked album video path: %@, ratio: %lf", self.videoPath, self.videoRatio);
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
    return;
}
@end
