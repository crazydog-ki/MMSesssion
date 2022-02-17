#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, AvuType) {
    AvuType_Video = 1 << 0,
    AvuType_Audio = 1 << 1,
};

typedef NS_OPTIONS(NSUInteger, AvuPixelFormatType) {
    AvuPixelFormatType_YUV = 1 << 0,
    AvuPixelFormatType_RGBA = 1 << 1,
};

typedef NS_OPTIONS(NSUInteger, AvuDecodeStatus) {
    AvuDecodeStatus_Init  = 1 << 0,
    AvuDecodeStatus_Start = 1 << 1,
    AvuDecodeStatus_Pause = 1 << 2,
    AvuDecodeStatus_Stop  = 1 << 3,
};

@interface AvuClipRange : NSObject
@property (nonatomic, assign) double attachTime;
@property (nonatomic, assign) double startTime;
@property (nonatomic, assign) double endTime;
+ (instancetype)clipRangeStart:(double)start end:(double)end;
+ (instancetype)clipRangeAttach:(double)attach start:(double)start end:(double)end;
@end

@interface AvuConfig : NSObject
/***************************解码***********************************************/
/// Unit
@property (nonatomic, assign) AvuType type; // 片源类型
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, strong) NSString *audioPath;
@property (nonatomic, strong) AvuClipRange *clipRange;
@property (nonatomic, assign) int      videoId;

/// VT硬解
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) AvuPixelFormatType formatType;
@property (nonatomic, assign) CMVideoFormatDescriptionRef vtDesc; // 不管理生命周期

/// FFmpeg软解
@property (nonatomic, assign) void *fmtCtx;

/// 缓存

/***************************编码***********************************************/
/// VT硬编
@property (nonatomic, assign) AvuPixelFormatType pixelFormat;
@property (nonatomic, assign) NSTimeInterval keyframeInterval;
@property (nonatomic, assign) BOOL allowRealtime;
@property (nonatomic, assign) BOOL allowBFrame;
@property (nonatomic, assign) double bitrate;

/// Writer
@property (nonatomic, assign) BOOL onlyMux;
@property (nonatomic, strong) NSURL *outputUrl;
@property (nonatomic, strong) NSDictionary *videoSetttings;
@property (nonatomic, strong) NSDictionary *pixelBufferAttributes;
@property (nonatomic, strong) NSDictionary *audioSetttings;

/***************************Render***********************************************/
/// Audio Queue
@property (nonatomic, assign) BOOL needPullData;

/***************************MultiTrack***********************************************/
@property (nonatomic, strong) NSMutableArray<NSString *> *audioPaths;
@property (nonatomic, strong) NSMutableArray<NSString *> *videoPaths;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AvuClipRange *> *clipRanges;
@end

NS_ASSUME_NONNULL_END
