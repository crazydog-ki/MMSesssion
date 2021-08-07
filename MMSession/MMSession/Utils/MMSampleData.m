// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMSampleData.h"

@implementation MMParseVideoInfo
- (void)dealloc {
    if (_data) {
        free(_data);
        _data = NULL;
    }
    
    if (_extraData) {
        free(_extraData);
        _extraData = NULL;
    }
}
@end

@implementation MMParseAudioInfo
- (void)dealloc {
    if (_data) {
        free(_data);
        _data = NULL;
    }
}
@end

@implementation MMSampleData
- (void)setSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_sampleBuffer) {
        CFRelease(_sampleBuffer);
        _sampleBuffer = nil;
    }
    
    if (sampleBuffer) {
       _sampleBuffer = (CMSampleBufferRef)CFRetain(sampleBuffer);
    }
}

- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = nil;
    }
    
    if (pixelBuffer) {
        _pixelBuffer = CVPixelBufferRetain(pixelBuffer);
    }
}

- (void)dealloc {
    if (_sampleBuffer) {
        CFRelease(_sampleBuffer);
        _sampleBuffer = nil;
    }
    
    if (_pixelBuffer) {
        CFRelease(_pixelBuffer);
        _pixelBuffer = nil;
    }
    // NSLog(@"[yjx] sample data destroy");
}
@end
