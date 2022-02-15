#import "AvuBuffer.h"

@implementation AvuBuffer
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

- (void)setAudioBuffer:(CMSampleBufferRef)audioBuffer {
    if (_audioBuffer) {
        CFRelease(_audioBuffer);
        _audioBuffer = nil;
    }
    
    if (audioBuffer) {
        _audioBuffer = (CMSampleBufferRef)CFRetain(audioBuffer);
    }
}

- (void)dealloc {
    if (_sampleBuffer) {
        CFRelease(_sampleBuffer);
        _sampleBuffer = nil;
    }
    
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = nil;
    }
//    
//    if (_audioBuffer) {
//        CFRelease(_audioBuffer);
//        _audioBuffer = NULL;
//    }
}
@end
