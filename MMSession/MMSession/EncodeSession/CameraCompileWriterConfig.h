// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CameraCompileWriterConfig : NSObject

@property (nonatomic, strong) NSURL *outputUrl;
@property (nonatomic, strong) NSDictionary *videoSetttings;
@property (nonatomic, strong) NSDictionary *pixelBufferAttributes;

@property (nonatomic, strong) NSDictionary *audioSetttings;

@end

NS_ASSUME_NONNULL_END
