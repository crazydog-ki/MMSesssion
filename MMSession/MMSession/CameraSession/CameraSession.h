// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "CameraSessionConfig.h"
#import <AVFoundation/AVFoundation.h>
#import "VideoLayerPreview.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraSession : NSObject

- (instancetype)initWithConfig:(CameraSessionConfig *)config;

- (void)startCapture;

- (void)stopCapture;

- (void)setVideoPreviewLayerForSession:(AVCaptureVideoPreviewLayer *)previewLayer;

typedef void(^VideoOutputCallback)(CMSampleBufferRef sampleBuffer);
typedef void(^AudioOutputCallback)(CMSampleBufferRef sampleBuffer);
@property (nonatomic, strong) VideoOutputCallback videoOutputCallback;
@property (nonatomic, strong) AudioOutputCallback audioOutputCallback;

@end

NS_ASSUME_NONNULL_END
