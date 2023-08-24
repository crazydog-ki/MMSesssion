// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMVideoPreviewConfig : NSObject
@property (nonatomic, assign) BOOL renderYUV;
@property (nonatomic, assign) CGFloat rotation; //弧度
@property (nonatomic, assign) CGRect presentRect;
@end

NS_ASSUME_NONNULL_END
