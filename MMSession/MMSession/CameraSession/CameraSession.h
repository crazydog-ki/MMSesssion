// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "CameraSessionConfig.h"
#import "VideoLayerPreview.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraSession : NSObject

- (instancetype)initWithConfig:(CameraSessionConfig *)config;

- (void)startCapture;

- (void)stopCapture;

- (void)setVideoPreviewLayerForSession:(AVCaptureVideoPreviewLayer *)previewLayer;

- (CGSize)videoSize;

typedef void (^FirstFrameCallback)(void);
@property (nonatomic, strong) FirstFrameCallback firstFrameBlk;

typedef void(^VideoOutputCallback)(CMSampleBufferRef sampleBuffer);
typedef void(^AudioOutputCallback)(CMSampleBufferRef sampleBuffer);
@property (nonatomic, strong) VideoOutputCallback _Nullable videoOutputCallback;
@property (nonatomic, strong) AudioOutputCallback _Nullable audioOutputCallback;

@end

NS_ASSUME_NONNULL_END
