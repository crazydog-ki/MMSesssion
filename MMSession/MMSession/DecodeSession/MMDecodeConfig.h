// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MMFFDecodeType) {
    MMFFDecodeType_Video = 1,
    MMFFDecodeType_Audio = 2
};

@interface MMDecodeConfig : NSObject
@property (nonatomic, strong) NSURL *videoURL;
@property (nonatomic, strong) AVAsset *videoAsset;
@property (nonatomic, assign) void *fmtCtx;
@property (nonatomic, assign) MMFFDecodeType decodeType;
@property (nonatomic, assign) BOOL needPcm;
@end

NS_ASSUME_NONNULL_END
