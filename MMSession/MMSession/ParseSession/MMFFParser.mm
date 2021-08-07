// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMFFParser.h"

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

@interface MMFFParser ()
{
    AVFormatContext *_fmtCtx;
    AVPacket *_packet;
    AVBSFContext *_bsfCtx;
}
@property (nonatomic, strong) dispatch_queue_t ffParseQueue;
@property (nonatomic, strong) MMParseConfig *config;
@property (nonatomic, assign) int videoIdx;
@property (nonatomic, assign) int audioIdx;

@property (nonatomic, assign) BOOL stopParse;
@end

@implementation MMFFParser
#pragma mark - Public
- (instancetype)initWithConfig:(MMParseConfig *)config {
    if (self = [super init]) {
        _ffParseQueue = dispatch_queue_create("mmsession_ff_parse_queue", DISPATCH_QUEUE_SERIAL);
        _config = config;
        [self _initFFParser];
    }
    return self;
}

- (MMSampleData *)pullSampleData:(MMSampleDataType)type {
    return nil;
}

- (void)startParse:(MMFFParseCallback)callback {
    dispatch_sync(_ffParseQueue, ^{
        AVFormatContext *fmtCtx = _fmtCtx;
        int videoIdx = _videoIdx;
        int audioIdx = _audioIdx;
        AVStream *videoStream = fmtCtx->streams[videoIdx];
        AVStream *audioStream = fmtCtx->streams[audioIdx];
        
        /// bsf对SPS、PPS等数据进行格式转换，使其可被解码器处理
        const AVBitStreamFilter *pFilter = NULL;
        MMVideoFormat videoFormat = NULL;
        if (videoStream->codecpar->codec_id == AV_CODEC_ID_H264) {
            pFilter = av_bsf_get_by_name("h264_mp4toannexb");
            videoFormat = MMVideoFormatH264;
        } else if (videoStream->codecpar->codec_id == AV_CODEC_ID_HEVC) {
            pFilter = av_bsf_get_by_name("hevc_mp4toannexb");
            videoFormat = MMVideoFormatH265;
        }
        av_bsf_alloc(pFilter, &_bsfCtx);
        avcodec_parameters_copy(_bsfCtx->par_in, videoStream->codecpar);
        av_bsf_init(_bsfCtx);
        
        int ret = -1;
        while (!_stopParse) {
            AVPacket *packet = _packet;
            av_init_packet(packet);
            ret = av_read_frame(fmtCtx, packet);
            if (ret == AVERROR_EOF) {
                [self _freeAll];
                NSLog(@"[yjx] ffparser end");
                break;
            }
            
            MMSampleData *sampleData = [[MMSampleData alloc] init];
            if (packet->stream_index == videoIdx) { /// 视频轨
                int pktSize = packet->size;
                uint8_t *videoData = (uint8_t *)malloc(pktSize);
                memcpy(videoData, packet->data, pktSize);
                
                int extraSize = videoStream->codecpar->extradata_size;
                uint8_t *extraData = (uint8_t *)malloc(extraSize);
                memcpy(extraData, videoStream->codecpar->extradata, extraSize);
                
                MMParseVideoInfo *videoInfo = [[MMParseVideoInfo alloc] init];
                videoInfo.rotate        = [self _getRotation];
                videoInfo.dataSize      = pktSize;
                videoInfo.data          = videoData;
                videoInfo.extradataSize = extraSize;
                videoInfo.extraData     = extraData;
                videoInfo.pts           = packet->pts * av_q2d(videoStream->time_base);
                videoInfo.dts           = packet->dts * av_q2d(videoStream->time_base);
                videoInfo.duration      = packet->duration * av_q2d(videoStream->time_base);
                videoInfo.videoIdx      = videoIdx;
                videoInfo.format        = videoFormat;
                
                /// bsf process
                av_bsf_send_packet(_bsfCtx, packet);
                av_bsf_receive_packet(_bsfCtx, packet);
                videoInfo.parsedData = packet;
                
                sampleData.dataType = MMSampleDataType_Parsed_Video;
                sampleData.videoInfo  = videoInfo;
            } else if (packet->stream_index == audioIdx) { /// 音频轨
                MMParseAudioInfo *audioInfo = [[MMParseAudioInfo alloc] init];
                uint8_t *data = (uint8_t *)malloc(packet->size);
                int pktSize = packet->size;
                memcpy(data, packet->data, pktSize);
                
                audioInfo.dataSize    = pktSize;
                audioInfo.channel     = audioStream->codecpar->channels;
                audioInfo.sampleRate  = audioStream->codecpar->sample_rate;
                audioInfo.pts         = packet->pts * av_q2d(audioStream->time_base);
                audioInfo.dts         = packet->dts * av_q2d(audioStream->time_base);
                audioInfo.duration    = packet->duration * av_q2d(audioStream->time_base);
                audioInfo.audioIdx    = audioIdx;
                audioInfo.parsedData  = packet;
                
                sampleData.dataType = MMSampleDataType_Parsed_Audio;
                sampleData.audioInfo  = audioInfo;
            }
            
            if (callback) {
                callback(sampleData);
            }
            
            av_packet_unref(packet);
        }
        
        [self _freeAll];
    });
}

- (void)startParse {
    dispatch_sync(_ffParseQueue, ^{
        _stopParse = NO;
    });
}

- (void)finishParse {
    dispatch_sync(_ffParseQueue, ^{
        _stopParse = YES;
    });
}

- (void *)getFmtCtx {
    if (!_fmtCtx) {
        return NULL;
    }
    return (void *)_fmtCtx;
}

#pragma mark - Private
- (void)_initFFParser {
    int ret = -1;
    AVFormatContext *fmtCtx = avformat_alloc_context();
    
    ret = avformat_open_input(&fmtCtx, _config.inPath.UTF8String, NULL, NULL);
    if (ret < 0) {
        NSLog(@"[yjx] ffparser open input failed: %d", ret);
        if (fmtCtx) {
            avformat_free_context(fmtCtx);
            fmtCtx = NULL;
        }
        return;
    }
    
    ret = avformat_find_stream_info(fmtCtx, NULL);
    if (ret < 0) {
        NSLog(@"[yjx] ffparser find stream info failed: %d", ret);
        avformat_close_input(&fmtCtx);
        return;
    }
    
    for (int i = 0; i < fmtCtx->nb_streams; i++) {
        FFAVMediaType type = fmtCtx->streams[i]->codecpar->codec_type;
        if (type == AVMEDIA_TYPE_VIDEO) {
            _videoIdx = i;
        } else if (type == AVMEDIA_TYPE_AUDIO) {
            _audioIdx = i;
        }
    }
    
    _packet = (AVPacket *)malloc(sizeof(AVPacket));
    av_init_packet(_packet);
    
    _fmtCtx = fmtCtx;
}

- (CGFloat)_getRotation {
    AVDictionaryEntry *rotationEntry = NULL;
    rotationEntry = av_dict_get(_fmtCtx->streams[_videoIdx]->metadata, "rotate", rotationEntry, 0);
    CGFloat rotation = 0.0f;
    if (rotationEntry != NULL) {
        int rotate = [[NSString stringWithFormat:@"%s", rotationEntry->value] intValue];
        switch (rotate) {
            case 90:
                rotation = M_PI_2;
                break;
            case 180:
                rotation = M_PI;
                break;
            case 270:
                rotation = 3*M_PI_2;
                break;
            default:
                rotation = 0;
                break;
        }
    }
    return rotation;
}

- (void)_freeAll {
    if (_fmtCtx) {
        avformat_close_input(&_fmtCtx);
        _fmtCtx = NULL;
    }
    
    if (_bsfCtx) {
        av_bsf_free(&_bsfCtx);
        _bsfCtx = NULL;
    }
    
    if (_packet) {
        av_packet_unref(_packet);
        free(_packet);
        _packet = nil;
    }
}

- (void)dealloc {
    [self _freeAll];
    NSLog(@"[yjx] ffParser destroy");
}
@end
