// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMSampleData.h"

MMSampleData::~MMSampleData() {
    if (data) {
        free(data);
        data = NULL;
    }
    
    if (extraData) {
        free(extraData);
        extraData = NULL;
    }
    
    if (audioSample) {
        CFRelease(audioSample);
        audioSample = NULL;
    }
    
    if (videoSample) {
        CFRelease(videoSample);
        videoSample = NULL;
    }
    
    if (videoBuffer) {
        CVPixelBufferRelease(videoBuffer);
        videoBuffer = NULL;
    }
}
