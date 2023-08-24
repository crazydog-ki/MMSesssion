// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include <stdio.h>
#include "MMBaseDefine.h"

struct MMSampleData {
    ~MMSampleData();
    uint8_t *data = nullptr;
    int dataSize;
    double pts;
    double dts;
    void *parsedData = nullptr;
    double duration;
    // For Video
    MMVideoFormat format;
    uint8_t *extraData = nullptr;
    int extradataSize;
    bool isKeyFrame;
    int videoIdx;
    double rotate;
    // For Audio
    int channel;
    int sampleRate;
    int audioIdx;
    
    MMSampleDataType dataType;
    MMSampleDataFlag statusFlag;
    // for audio
    CMSampleBufferRef audioSample;
    // for video
    CMSampleBufferRef videoSample; //压缩
    CVPixelBufferRef videoBuffer; //非压缩
};

