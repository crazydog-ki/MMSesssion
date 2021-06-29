// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "ViewController.h"
#import "CameraSession.h"
#import "VideoPreview.h"

@interface ViewController ()

@property (nonatomic, strong) CameraSession *camera;
@property (nonatomic, strong) VideoPreview *preview;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.preview = [[VideoPreview alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.preview];
    
    self.camera = [[CameraSession alloc] initWithConfig:nil];
    [self.camera startCapture];
    __weak typeof(self) weakSelf = self;
    self.camera.videoOutputCallback = ^(CMSampleBufferRef  _Nonnull sampleBuffer) {
        NSLog(@"youjianxia video callback");
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        
        CIContext *ciontext = [CIContext contextWithOptions:nil];
        CGImageRef videoImage = [ciontext createCGImage:ciImage
                                               fromRect:CGRectMake(0, 0,
                                                        CVPixelBufferGetWidth(pixelBuffer),
                                                        CVPixelBufferGetHeight(pixelBuffer))];
         
        UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
        weakSelf.preview.imageView.image = uiImage;
        CGImageRelease(videoImage);
    };
}


@end
