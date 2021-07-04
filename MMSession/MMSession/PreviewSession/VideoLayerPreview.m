// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "VideoLayerPreview.h"

@implementation VideoLayerPreview

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *)videoPreviewLayer {
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

@end
