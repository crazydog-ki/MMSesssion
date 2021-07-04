// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <UIKit/UIKit.h>
#import "MMSessionProcessProtocol.h"
#import "VideoPreviewConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface VideoGLPreview : UIView<MMSessionProcessProtocol>

@property (nonatomic, strong) VideoPreviewConfig *config;

- (void)setupGLEnv;

@end

NS_ASSUME_NONNULL_END
