// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#pragma once
#import "MMBaseDefine.h"

struct MMDecodeConfig {
    void *fmtCtx;
    MMDecodeType decodeType;
    BOOL needPcm = false;
    MMPixelFormatType pixelformat;
    
    CMVideoFormatDescriptionRef vtDesc;
    CGSize targetSize = CGSizeZero;
};
