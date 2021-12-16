// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSInteger, MMPixelFormatType) {
    MMPixelFormatTypeFullRangeYUV  = 1 << 0,
    MMPixelFormatTypeVideoRangeYUV = 1 << 1,
    MMPixelFormatTypeBGRA          = 1 << 2,
};

@interface MMEncodeConfig : NSObject
@property (nonatomic, strong) NSURL *outputUrl;
@property (nonatomic, strong) NSDictionary *videoSetttings;
@property (nonatomic, strong) NSDictionary *pixelBufferAttributes;
@property (nonatomic, assign) double roration;
@property (nonatomic, strong) NSDictionary *audioSetttings;
@property (nonatomic, assign) BOOL onlyMux;

@property (nonatomic, assign) MMPixelFormatType pixelFormat;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) NSTimeInterval keyframeInterval;
@property (nonatomic, assign) BOOL allowRealtime;
@property (nonatomic, assign) BOOL allowBFrame;
@property (nonatomic, assign) double bitrate;
@end

NS_ASSUME_NONNULL_END
