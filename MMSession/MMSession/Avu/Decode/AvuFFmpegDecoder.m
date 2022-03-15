#import "AvuFFmpegDecoder.h"
#import "AvuUtils.h"

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
// static const NSUInteger kVideoTimeScale  = NSEC_PER_SEC;
static const NSUInteger kAudioTimeScale  = 44100;

@interface AvuFFmpegDecoder ()
{
    AVFormatContext *_fmtCtx;
    AVCodecContext  *_codecCtx;
    AVFrame         *_frame;
    AVBufferRef     *_hwDeviceCtx;
    SwrContext      *_swrCtx;
    AudioBufferList *_audioBufferList;
}
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) dispatch_queue_t ffDecodeQueue;
@property (nonatomic, strong) NSMutableArray *nextNodes;

@property (nonatomic, assign) int videoIdx;
@property (nonatomic, assign) int audioIdx;
@end

@implementation AvuFFmpegDecoder
#pragma mark - AvuBufferProcessProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _ffDecodeQueue = dispatch_queue_create("avu_ffmpeg_decode_queue", DISPATCH_QUEUE_SERIAL);
        _nextNodes = [NSMutableArray array];
        _audioBufferList = [AvuUtils produceAudioBufferList:AvuUtils.asbd
                                               numberFrames:kMaxSamplesCount];
        NSLog(@"[avu] ffdecoder audiobufferlist dataSize: %d", _audioBufferList->mBuffers[0].mDataByteSize);
        [self _initFFDecoder];
    }
    return self;
}

- (void)processBuffer:(nonnull AvuBuffer *)buffer {
    dispatch_sync(_ffDecodeQueue, ^{
        BOOL isAudio = buffer.type==AvuType_Audio;
        AVCodecContext *codecCtx = _codecCtx;
        AVPacket packet;
        
        if (isAudio) {
            packet = *(AVPacket *)(buffer.parsedData);
        } else {
            /// ToDo: 视频流解码
        }
        
        avcodec_send_packet(codecCtx, &packet);
        while (0 == avcodec_receive_frame(codecCtx, _frame)) {
            AVFrame *frame = self->_frame;
            if (!isAudio) {
                /// ToDo: 视频流解码
            } else { /// 解码音频
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
                // 转换
                swr_convert(self->_swrCtx,
                            &outBuffer,
                            outLineSize,
                            (const uint8_t **)frame->data,
                            samplesNum);
                
                AudioBufferList *bufferList = self->_audioBufferList;
                [AvuUtils resetAudioBufferList:bufferList];
                memcpy(bufferList->mBuffers[0].mData, outBuffer, outBufferSize);
                self->_audioBufferList->mBuffers[0].mDataByteSize = outBufferSize;
                buffer.bufferList = self->_audioBufferList;
                
                /// bufferList -> CMSampleBufferRef
//                CMSampleTimingInfo timingInfo;
//                timingInfo.duration              = CMTimeMake(1, kAudioTimeScale);
//                timingInfo.presentationTimeStamp = CMTimeMake(buffer.dts*kAudioTimeScale, kAudioTimeScale);
//                timingInfo.decodeTimeStamp       = CMTimeMake(buffer.dts*kAudioTimeScale, kAudioTimeScale);
//                 CMSampleBufferRef sampleBuffer = [AvuUtils produceAudioBuffer:bufferList
//                                                                    timingInfo:timingInfo
//                                                                     frameNums:samplesNum];
//                buffer.audioBuffer = sampleBuffer;
                if (self.nextNodes) {
                    for (id<AvuBufferProcessProtocol> node in self.nextNodes) {
                        [node processBuffer:buffer];
                    }
                }

//                if (sampleBuffer) {
//                    CFRelease(sampleBuffer);
//                    sampleBuffer = NULL;
//                }
                av_free(outBuffer);
            }
        }
    });
}

- (void)addNextNode:(id<AvuBufferProcessProtocol>)node {
    dispatch_sync(_ffDecodeQueue, ^{
        [self.nextNodes addObject:node];
    });
}

#pragma mark - Public
- (void)stopDecode {
    dispatch_sync(self.ffDecodeQueue, ^{
        [self _freeAll];
    });
}

#pragma mark - Private
- (void)_initFFDecoder {
    AVFormatContext *fmtCtx = (AVFormatContext *)_config.fmtCtx;
    int videoIdx = -1, audioIdx = -1;
    for (int i = 0; i < fmtCtx->nb_streams; i++) {
        enum FFAVMediaType type = fmtCtx->streams[i]->codecpar->codec_type;
        if (type == AVMEDIA_TYPE_VIDEO) {
            videoIdx = i;
        } else if (type == AVMEDIA_TYPE_AUDIO) {
            audioIdx = i;
        }
    }
    _videoIdx = videoIdx;
    _audioIdx = audioIdx;
    
    AVStream *videoStream = fmtCtx->streams[videoIdx];
    AVStream *audioStream = fmtCtx->streams[audioIdx];
    
    AVCodec *codec = NULL;
    AVCodecContext *codecCtx = NULL;
    int ret = -1;
    BOOL isVideo = _config.type==AvuType_Video;
    if (isVideo) {
        /**硬解码
         ret = av_find_best_stream(fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
         codecCtx = avcodec_alloc_context3(codec);
         ret = avcodec_parameters_to_context(codecCtx, videoStream->codecpar);
         
         const char *codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
         enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
         ret = av_hwdevice_ctx_create(&_hwDeviceCtx, type, NULL, NULL, 0);
         codecCtx->hw_device_ctx = av_buffer_ref(_hwDeviceCtx);
         */
        
        /// 软解码，解码后格式为YUV420P
        codec = avcodec_find_decoder(videoStream->codecpar->codec_id);
        codecCtx = avcodec_alloc_context3(codec);
        ret = avcodec_parameters_to_context(codecCtx, videoStream->codecpar);
    } else {
        codec = avcodec_find_decoder(audioStream->codecpar->codec_id);
        codecCtx = avcodec_alloc_context3(codec);
        ret = avcodec_parameters_to_context(codecCtx, audioStream->codecpar);
    }
    
    ret = avcodec_open2(codecCtx, codec, NULL);
    if (ret < 0) {
        if (self.decodeErrorCallback) {
            NSError *error = [NSError errorWithDomain:@"avu_decode"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"avu_decode_ffmpeg_codec_open_error"}];
            self.decodeErrorCallback(AvuDecodeErrorType_Decode, error);
        }
        NSLog(@"[avu] ffmpeg decoder open error: %d", ret);
    }
    
    _frame = av_frame_alloc();
    _fmtCtx = fmtCtx;
    _codecCtx = codecCtx;
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
        [AvuUtils freeAudioBufferList:_audioBufferList];
        _audioBufferList = NULL;
    }
}
@end
