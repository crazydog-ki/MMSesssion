// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMBaseDefine.h"

struct MMDecodeConfig {
    NSURL *videoURL;
    AVAsset *videoAsset;
    void *fmtCtx;
    MMFFDecodeType decodeType;
    BOOL needPcm = false;
    BOOL needYuv = false;
    MMPixelFormatType pixelformat;
    
    CMVideoFormatDescriptionRef vtDesc;
    CGSize targetSize = CGSizeZero;
};
