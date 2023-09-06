// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <UIKit/UIKit.h>
#import "MMVideoPreviewConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMVideoGLPreview : UIView
- (instancetype)initWithConfig:(MMVideoPreviewConfig *)config;
- (void)setupGLEnv;

typedef void(^RenderEndBlock)(void);
@property (nonatomic, strong) RenderEndBlock renderEndBlk;

- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

NS_ASSUME_NONNULL_END
