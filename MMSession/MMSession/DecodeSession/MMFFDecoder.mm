// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMFFDecoder.h"
#import "MMBufferUtils.h"

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

static const NSUInteger kMaxSamplesCount = 1024;
static const NSUInteger kVideoTimeScale  = NSEC_PER_SEC;
static const NSUInteger kAudioTimeScale  = 44100;

@interface MMFFDecoder ()
{
    AVFormatContext *_fmtCtx;
    AVCodecContext  *_codecCtx;
    AVFrame         *_frame;
    AVBufferRef     *_hwDeviceCtx;
    SwrContext      *_swrCtx;
    AudioBufferList *_audioBufferList;
    
    CVPixelBufferPoolRef _pixelBufferPool;
}
@property (nonatomic, strong) dispatch_queue_t ffDecodeQueue;
@property (nonatomic, strong) MMDecodeConfig *config;
@property (nonatomic, assign) int videoIdx;
@property (nonatomic, assign) int audioIdx;

@property (nonatomic, strong) NSMutableArray *nextVideoNodes;
@property (nonatomic, strong) NSMutableArray *nextAudioNodes;

@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, assign) double beginTime;
@end

@implementation MMFFDecoder
#pragma mark - Public
- (instancetype)initWithConfig:(MMDecodeConfig *)config {
    if (self = [super init]) {
        _ffDecodeQueue = dispatch_queue_create("mmsession_ff_decode_queue", DISPATCH_QUEUE_SERIAL);
        _nextVideoNodes = [NSMutableArray array];
        _nextAudioNodes = [NSMutableArray array];
        _config = config;
        _audioBufferList = [MMBufferUtils produceAudioBufferList:MMBufferUtils.asbd
                                                    numberFrames:kMaxSamplesCount];
        NSLog(@"[yjx] ffdecoder audiobufferlist dataSize: %d", _audioBufferList->mBuffers[0].mDataByteSize);
        [self _initFFDecoder];
    }
    return self;
}

- (MMSampleData *)pullSampleData:(MMSampleDataType)type {
    return nil;
}

- (void)dealloc {
    [self _freeAll];
}

#pragma mark - MMSessionProcessProtocol
- (void)processSampleData:(MMSampleData *)sampleData {
    if (!self.isFirstFrame) {
        self.beginTime = CACurrentMediaTime();
        self.isFirstFrame = YES;
    }
    
    dispatch_sync(_ffDecodeQueue, ^{
        BOOL isEnd = (sampleData.statusFlag==MMSampleDataFlagEnd);
        BOOL isVideo = (sampleData.dataType==MMSampleDataType_Parsed_Video);
        if (isEnd) { /// ???????????????????????????
            if (isVideo) {
                for (id<MMSessionProcessProtocol> node in self.nextVideoNodes) {
                    [node processSampleData:sampleData];
                }
            } else {
                for (id<MMSessionProcessProtocol> node in self.nextAudioNodes) {
                    [node processSampleData:sampleData];
                }
            }
            return;
        }
        
        AVCodecContext *codecCtx = _codecCtx;
        AVPacket packet;
        if (isVideo) {
            packet = *(AVPacket *)(sampleData.videoInfo.parsedData);
        } else {
            packet = *(AVPacket *)(sampleData.audioInfo.parsedData);
        }
        
        avcodec_send_packet(codecCtx, &packet);
        while (0 == avcodec_receive_frame(codecCtx, _frame)) {
            AVFrame *frame = self->_frame;
            if (isVideo) { /// ????????????
                /// YUV?????????
                if (_config.needYuv && self.yuvCallback) {
                    int w = frame->width;
                    int h = frame->height;
                    /// Y Plane
                    int yW = w;
                    int yH = h;
                    for (int i = 0; i < yH; i++) {
                        self.yuvCallback((char *)(frame->data[0]+i*frame->linesize[0]), yW, MMYUVType_Y);
                    }
                    /// UV Plane
                    int uvW = w/2;
                    int uvH = h/2;
                    for (int i = 0; i < uvH; i++) {
                        self.yuvCallback((char *)(frame->data[1]+i*frame->linesize[1]), uvW, MMYUVType_U);
                    }
                    for (int i = 0; i < uvH; i++) {
                        self.yuvCallback((char *)(frame->data[2]+i*frame->linesize[2]), uvW, MMYUVType_V);
                    }
                }
                // continue;
                
                /** ????????? */
                CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)frame->data[3];
                
                /** ????????? */
                ///  AVFrame(YUV420P) -> CVPixelBufferRef(NV12)???????????????
                /// CVPixelBufferRef pixelBuffer = [self _getPixelBuffer:frame];
                if (!pixelBuffer) continue;
                CMSampleTimingInfo timingInfo;
                timingInfo.duration              = kCMTimeInvalid;
                timingInfo.decodeTimeStamp       = CMTimeMake(sampleData.videoInfo.dts*kVideoTimeScale, kVideoTimeScale);
                timingInfo.presentationTimeStamp = CMTimeMake(sampleData.videoInfo.dts*kVideoTimeScale, kVideoTimeScale);
                CMSampleBufferRef sampleBuffer = [MMBufferUtils produceVideoBuffer:pixelBuffer timingInfo:timingInfo];
                if (sampleBuffer) {
                    sampleData.sampleBuffer = sampleBuffer;
                    sampleData.dataType = MMSampleDataType_Decoded_Video;
                    if (self.nextVideoNodes) {
                        for (id<MMSessionProcessProtocol> node in self.nextVideoNodes) {
                            [node processSampleData:sampleData];
                        }
                    }
                }

                if (sampleBuffer) {
                    CFRelease(sampleBuffer);
                    sampleBuffer = NULL;
                }
            } else { /// ????????????
                if (!self->_swrCtx) {
                    struct SwrContext *swrCtx = swr_alloc();
                    swrCtx = swr_alloc_set_opts(swrCtx,
                                                AV_CH_LAYOUT_STEREO,
                                                AV_SAMPLE_FMT_FLT,
                                                kAudioTimeScale,
                                                codecCtx->channel_layout,
                                                codecCtx->sample_fmt,
                                                codecCtx->sample_rate,
                                                0,
                                                NULL);
                    swr_init(swrCtx);
                    self->_swrCtx = swrCtx;
                }
                
                int outLineSize;
                int samplesNum = frame->nb_samples;
                int swrOutSamples = swr_get_out_samples(self->_swrCtx, samplesNum);
                int outBufferSize = av_samples_get_buffer_size(&outLineSize,
                                                               2,
                                                               swrOutSamples,
                                                               AV_SAMPLE_FMT_FLT,
                                                               1);
                
                uint8_t *outBuffer = (uint8_t *)av_malloc(outBufferSize);
                // ??????
                swr_convert(self->_swrCtx,
                            &outBuffer,
                            outLineSize,
                            (const uint8_t **)frame->data,
                            samplesNum);
                
                AudioBufferList *bufferList = self->_audioBufferList;
                [MMBufferUtils resetAudioBufferList:bufferList];
                memcpy(bufferList->mBuffers[0].mData, outBuffer, outBufferSize);
                self->_audioBufferList->mBuffers[0].mDataByteSize = outBufferSize;
                
                /// ????????????PCM?????????
                if (_config.needPcm && self.pcmCallback) {
                    NSData *data = [NSData dataWithBytes:outBuffer length:outBufferSize];
                    self.pcmCallback(data);
                }
                
                /// bufferList -> CMSampleBufferRef
                CMSampleTimingInfo timingInfo;
                timingInfo.duration              = CMTimeMake(1, kAudioTimeScale);
                timingInfo.presentationTimeStamp = CMTimeMake(sampleData.audioInfo.dts*kAudioTimeScale, kAudioTimeScale);
                timingInfo.decodeTimeStamp       = CMTimeMake(sampleData.audioInfo.dts*kAudioTimeScale, kAudioTimeScale);
                CMSampleBufferRef sampleBuffer = [MMBufferUtils produceAudioBuffer:bufferList
                                                                        timingInfo:timingInfo
                                                                         frameNums:samplesNum];
                sampleData.sampleBuffer = sampleBuffer;
                sampleData.dataType = MMSampleDataType_Decoded_Audio;
                if (self.nextAudioNodes) {
                    for (id<MMSessionProcessProtocol> node in self.nextAudioNodes) {
                        [node processSampleData:sampleData];
                    }
                }
                
                if (sampleBuffer) {
                    CFRelease(sampleBuffer);
                    sampleBuffer = NULL;
                }
                av_free(outBuffer);
            }
        }
    });
}

- (void)addNextVideoNode:(id<MMSessionProcessProtocol>)node {
    dispatch_sync(_ffDecodeQueue, ^{
        [self.nextVideoNodes addObject:node];
    });
}

- (void)addNextAudioNode:(id<MMSessionProcessProtocol>)node {
    dispatch_sync(_ffDecodeQueue, ^{
        [self.nextAudioNodes addObject:node];
    });
}

#pragma mark - Private
- (void)_initFFDecoder {
    AVFormatContext *fmtCtx = (AVFormatContext *)_config.fmtCtx;
    int videoIdx = -1, audioIdx = -1;
    
    /// ?????????????????????
    for (int i = 0; i < fmtCtx->nb_streams; i++) {
        FFAVMediaType type = fmtCtx->streams[i]->codecpar->codec_type;
        if (type == AVMEDIA_TYPE_VIDEO) {
            videoIdx = i;
        } else if (type == AVMEDIA_TYPE_AUDIO) {
            audioIdx = i;
        }
    }
    AVStream *videoStream = fmtCtx->streams[videoIdx];
    AVStream *audioStream = fmtCtx->streams[audioIdx];
    
    AVCodec *codec = NULL;
    AVCodecContext *codecCtx = NULL;
    int ret = -1;
    MMFFDecodeType type = _config.decodeType;
    if (type == MMFFDecodeType_Video) {
        /** ????????? */
        ret = av_find_best_stream(fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
        codecCtx = avcodec_alloc_context3(codec);
        ret = avcodec_parameters_to_context(codecCtx, videoStream->codecpar);
        
        const char *codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
        enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
        ret = av_hwdevice_ctx_create(&_hwDeviceCtx, type, NULL, NULL, 0);
        codecCtx->hw_device_ctx = av_buffer_ref(_hwDeviceCtx);
        
        /**??????????????????????????????YUV420P
        codec = avcodec_find_decoder(videoStream->codecpar->codec_id);
        codecCtx = avcodec_alloc_context3(codec);
        ret = avcodec_parameters_to_context(codecCtx, videoStream->codecpar);
         */
    } else if (type == MMFFDecodeType_Audio) {
        codec = avcodec_find_decoder(audioStream->codecpar->codec_id);
        codecCtx = avcodec_alloc_context3(codec);
        ret = avcodec_parameters_to_context(codecCtx, audioStream->codecpar);
    }
    
    ret = avcodec_open2(codecCtx, codec, NULL);
    
    _frame = av_frame_alloc();
    _fmtCtx = fmtCtx;
    _codecCtx = codecCtx;
    _videoIdx = videoIdx;
    _audioIdx = audioIdx;
}

- (CVPixelBufferRef)_getPixelBuffer:(AVFrame *)frame {
    if(!frame || !frame->data[0]){
        return NULL;
    }
 
    CVReturn error;
    if (!_pixelBufferPool) {
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:frame->width] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:frame->height] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(frame->linesize[0]) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        error = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &_pixelBufferPool);
        if (error != kCVReturnSuccess) {
            NSLog(@"[yjx] pixelbuffer pool create error: %d", error);
        }
    }
    
    CVPixelBufferRef pixelBuffer = NULL;
    error = CVPixelBufferPoolCreatePixelBuffer(NULL, _pixelBufferPool, &pixelBuffer);
    if (error != kCVReturnSuccess) {
        NSLog(@"[yjx] pixelbuffer create error: %d", error);
    }
    
    uint32_t size = frame->linesize[1]*frame->height;
    uint8_t* dstData = new uint8_t[2*size];
    for (int i = 0; i < 2*size; i++){
        if (i%2 == 0){
            dstData[i] = frame->data[1][i/2];
        }else {
            dstData[i] = frame->data[2][i/2];
        }
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    size_t bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    void* base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(base, frame->data[0], bytePerRowY*frame->height);
    
    size_t bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    memcpy(base, dstData, bytesPerRowUV*frame->height/2);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    if (dstData) {
        delete [] dstData;
        dstData = nullptr;
    }
    
    return pixelBuffer;
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
    
    if (_frame) {
        av_free(_frame);
        _frame = NULL;
    }
    
    if (_swrCtx) {
        swr_free(&_swrCtx);
        _swrCtx = NULL;
    }
    
    if (_audioBufferList) {
        [MMBufferUtils freeAudioBufferList:_audioBufferList];
        _audioBufferList = NULL;
    }
}
@end
