// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoLayerPreview : UIView

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) AVCaptureSession *captureSession;

@end

NS_ASSUME_NONNULL_END
