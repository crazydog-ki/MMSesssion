// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <UIKit/UIKit.h>
#import "MMSessionProcessProtocol.h"
#import "MMVideoPreviewConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMVideoGLPreview : UIView<MMSessionProcessProtocol>
@property (nonatomic, strong) MMVideoPreviewConfig *config;
- (void)setupGLEnv;
@end

NS_ASSUME_NONNULL_END
