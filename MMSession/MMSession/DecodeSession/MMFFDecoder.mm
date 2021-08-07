// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMFFDecoder.h"

#ifdef __cplusplus
extern "C" {
#endif
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/samplefmt.h"
#include "libswresample/swresample.h"
#ifdef __cplusplus
};
#endif

@interface MMFFDecoder ()
{
    AVFormatContext *_fmtCtx;
    AVCodecContext  *_codecCtx;
    AVFrame         *_videoFrame;
    AVBufferRef     *_hwDeviceCtx;
}
@property (nonatomic, strong) dispatch_queue_t ffDecodeQueue;
@property (nonatomic, strong) MMDecodeConfig *config;
@end

@implementation MMFFDecoder
#pragma mark - Public
- (instancetype)initWithConfig:(MMDecodeConfig *)config {
    if (self = [super init]) {
        _ffDecodeQueue = dispatch_queue_create("mmsession_ff_decode_queue", DISPATCH_QUEUE_SERIAL);
        _config = config;
        [self _initFFDecoder];
    }
    return self;
}

- (MMSampleData *)decodeParsedData:(MMSampleData *)sampleData {
    MMSampleData *decodedData = [[MMSampleData alloc] init];
    dispatch_sync(_ffDecodeQueue, ^{
        AVCodecContext *codecCtx = _codecCtx;
        AVPacket packet = *(AVPacket *)(sampleData.videoInfo.parsedData);
        avcodec_send_packet(codecCtx, &packet);
        while (0 == avcodec_receive_frame(codecCtx, _videoFrame)) {
            if (sampleData.dataType == MMSampleDataType_Pull_Video) {
                /// 解码视频
                CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)_videoFrame->data[3];
                /// pts
                CMClockRef hostTime = CMClockGetHostTimeClock();
                CMTime videoPts = CMClockGetTime(hostTime);;
                
                CMSampleBufferRef sampleBuffer = [self _produceSampleBuffer:pixelBuffer withPts:videoPts];
                if (sampleBuffer) {
                    decodedData.sampleBuffer = sampleBuffer;
                    decodedData.dataType = MMSampleDataType_Decoded_Video;
                    CFRelease(sampleBuffer);
                }
            } else if (sampleData.dataType == MMSampleDataType_Pull_Audio) {
                /// 解码音频
            }
        }
    });
    return decodedData;
}

#pragma mark - Private
- (void)_initFFDecoder {
    AVFormatContext *fmtCtx = (AVFormatContext *)_config.fmtCtx;
    int videoIdx = -1, audioIdx = -1;
    
    /// 获取视频流索引
    for (int i = 0; i < fmtCtx->nb_streams; i++) {
        FFAVMediaType type = fmtCtx->streams[i]->codecpar->codec_type;
        if (type == AVMEDIA_TYPE_VIDEO) {
            videoIdx = i;
        } else if (type == AVMEDIA_TYPE_AUDIO) {
            audioIdx = i;
        }
    }
    AVStream *videoStream = fmtCtx->streams[videoIdx];
    // AVStream *audioStream = fmtCtx->streams[audioIdx];
    
    AVCodec *codec = NULL;
    int ret = av_find_best_stream(fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
    AVCodecContext *codecCtx = NULL;
    codecCtx = avcodec_alloc_context3(codec);
    ret = avcodec_parameters_to_context(codecCtx, videoStream->codecpar);
    
    const char *codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
    enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
    ret = av_hwdevice_ctx_create(&_hwDeviceCtx, type, NULL, NULL, 0);
    codecCtx->hw_device_ctx = av_buffer_ref(_hwDeviceCtx);
    ret = avcodec_open2(codecCtx, codec, NULL);
    if (ret == 0) {
        NSLog(@"[yjx] ffdecoder setup success");
    }
    
    _videoFrame = av_frame_alloc();
    _fmtCtx = fmtCtx;
    _codecCtx = codecCtx;
}

- (CMSampleBufferRef)_produceSampleBuffer:(CVImageBufferRef)pixelBuffer
                                  withPts:(CMTime)videoPts {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    CMSampleTimingInfo timingInfo;
    timingInfo.duration              = kCMTimeInvalid;
    timingInfo.decodeTimeStamp       = videoPts;
    timingInfo.presentationTimeStamp = videoPts;
    
    OSStatus ret = -1;
    CMVideoFormatDescriptionRef videoInfo = NULL;
    ret = CMVideoFormatDescriptionCreateForImageBuffer(NULL,
                                                       pixelBuffer,
                                                       &videoInfo);
    
    CMSampleBufferRef sampleBuffer = NULL;
    ret = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                             pixelBuffer,
                                             true,
                                             NULL,
                                             NULL,
                                             videoInfo,
                                             &timingInfo,
                                             &sampleBuffer);
    CFRelease(videoInfo);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CFRetain(sampleBuffer); /// 保证其生命周期
    return sampleBuffer;
}

- (void)_freeAll {
    if (_codecCtx) {
        avcodec_send_packet(_codecCtx, NULL);
        avcodec_flush_buffers(_codecCtx);
        
        if (_hwDeviceCtx) {
            av_buffer_unref(&_hwDeviceCtx);
            _hwDeviceCtx = NULL;
        }
        
        avcodec_close(_codecCtx);
        _codecCtx = NULL;
    }
    
    if (_videoFrame) {
        av_free(_videoFrame);
        _videoFrame = NULL;
    }
    NSLog(@"[yjx] ffDecoder destroy");
}
@end
