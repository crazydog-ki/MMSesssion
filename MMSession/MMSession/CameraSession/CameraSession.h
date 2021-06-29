// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "CameraSessionConfig.h"
#import <AVFoundation/AVFoundation.h>
#import "VideoPreview.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraSession : NSObject

- (instancetype)initWithConfig:(CameraSessionConfig *)config;

- (void)startCapture;

typedef void(^VideoOutputCallback)(CMSampleBufferRef sampleBuffer);
@property (nonatomic, strong) VideoOutputCallback videoOutputCallback;

@end

NS_ASSUME_NONNULL_END
