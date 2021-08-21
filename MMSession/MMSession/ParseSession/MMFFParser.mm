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
    AVBSFContext    *_bsfCtx;
    AVPacket        *_packet;
    AVStream        *_videoStream;
    AVStream        *_audioStream;
}
@property (nonatomic, strong) dispatch_queue_t ffParseQueue;
@property (nonatomic, strong) MMParseConfig *config;
@property (nonatomic, assign) int videoIdx;
@property (nonatomic, assign) int audioIdx;
@property (nonatomic, strong) NSMutableArray *nextVideoNodes;
@property (nonatomic, strong) NSMutableArray *nextAudioNodes;
@property (nonatomic, assign) BOOL stopFlag;
@end

@implementation MMFFParser
#pragma mark - Public
- (instancetype)initWithConfig:(MMParseConfig *)config {
    if (self = [super init]) {
        _ffParseQueue = dispatch_queue_create("mmsession_ff_parse_queue", DISPATCH_QUEUE_SERIAL);
        _nextVideoNodes = [NSMutableArray array];
        _nextAudioNodes = [NSMutableArray array];
        _config = config;
        _stopFlag = NO;
        [self _initFFParser];
    }
    return self;
}

- (void)seekToTime:(double)time {
    if (!_fmtCtx) {
        NSLog(@"[yjx] not suppport seek because of fmtCtx is nil");
        return;
    }
    
    dispatch_sync(_ffParseQueue, ^{
        BOOL isVideo = (_config.parseType==MMFFParseType_Video);
        int64_t seekTime = -1;
        int ret = -1;
        if (isVideo) {
            seekTime = (int64_t)time*_videoStream->time_base.den;
            ret = av_seek_frame(self->_fmtCtx, _videoIdx, seekTime, AVSEEK_FLAG_FRAME);
        } else {
            seekTime = (int64_t)time*_audioStream->time_base.den;
            ret = av_seek_frame(self->_fmtCtx, _audioIdx, seekTime, AVSEEK_FLAG_FRAME);
        }
    });
}

- (void *)getFmtCtx {
    if (!_fmtCtx) {
        return NULL;
    }
    return (void *)_fmtCtx;
}

- (void)dealloc {
    [self _freeAll];
}

#pragma mark - MMSessionProcessProtocol
- (void)processSampleData:(MMSampleData *)sampleData {
    dispatch_sync(_ffParseQueue, ^{
        BOOL isVideo = (sampleData.dataType==MMSampleDataType_None_Video);
        while (YES) {
            if (!_fmtCtx) return;
            
            AVFormatContext *fmtCtx = self->_fmtCtx;
            int videoIdx = self->_videoIdx;
            int audioIdx = self->_audioIdx;
            AVStream *videoStream = _videoStream;
            AVStream *audioStream = _audioStream;
            
            AVPacket *packet = self->_packet;
            av_packet_unref(packet);
            av_init_packet(packet);
            
            int ret = -1;
            ret = av_read_frame(fmtCtx, packet);
            
            if (ret == AVERROR_EOF) {
                sampleData.statusFlag = MMSampleDataFlagEnd;
                if (self.nextVideoNodes) {
                    for (id<MMSessionProcessProtocol> node in self.nextVideoNodes) {
                        [node processSampleData:sampleData];
                    }
                }
                if (self.nextAudioNodes) {
                    for (id<MMSessionProcessProtocol> node in self.nextAudioNodes) {
                        [node processSampleData:sampleData];
                    }
                }
                [self _freeAll];
            } else if (packet->stream_index == videoIdx) { /// 视频轨
                if (!isVideo) continue;
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
                if (!self->_bsfCtx) {
                    av_bsf_alloc(pFilter, &self->_bsfCtx);
                    avcodec_parameters_copy(self->_bsfCtx->par_in, videoStream->codecpar);
                    av_bsf_init(self->_bsfCtx);
                }
                
                int pktSize = packet->size;
                uint8_t *videoData = (uint8_t *)malloc(pktSize);
                memcpy(videoData, packet->data, pktSize);
                
                int extraSize = videoStream->codecpar->extradata_size;
                uint8_t *extraData = (uint8_t *)malloc(extraSize);
                memcpy(extraData, videoStream->codecpar->extradata, extraSize);
                
                MMParsedVideoInfo *videoInfo = [[MMParsedVideoInfo alloc] init];
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
                av_bsf_send_packet(self->_bsfCtx, packet);
                av_bsf_receive_packet(self->_bsfCtx, packet);
                videoInfo.parsedData = packet;
                
                sampleData.dataType = MMSampleDataType_Parsed_Video;
                sampleData.videoInfo  = videoInfo;
                
                if (self.nextVideoNodes) {
                    for (id<MMSessionProcessProtocol> node in self.nextVideoNodes) {
                        [node processSampleData:sampleData];
                    }
                }
            } else if (packet->stream_index == audioIdx) { /// 音频轨
                if (isVideo) continue;
                MMParsedAudioInfo *audioInfo = [[MMParsedAudioInfo alloc] init];
                uint8_t *data = (uint8_t *)malloc(packet->size);
                int pktSize = packet->size;
                memcpy(data, packet->data, pktSize);

                audioInfo.data        = data;
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
                
                if (self.nextAudioNodes) {
                    for (id<MMSessionProcessProtocol> node in self.nextAudioNodes) {
                        [node processSampleData:sampleData];
                    }
                }
            }
            break;
        }
    });
}

- (void)addNextVideoNode:(id<MMSessionProcessProtocol>)node {
    dispatch_sync(_ffParseQueue, ^{
        [self.nextVideoNodes addObject:node];
    });
}

- (void)addNextAudioNode:(id<MMSessionProcessProtocol>)node {
    dispatch_sync(_ffParseQueue, ^{
        [self.nextAudioNodes addObject:node];
    });
}

#pragma mark - Private
- (void)_initFFParser {
    int ret = -1;
    AVFormatContext *fmtCtx = avformat_alloc_context();
    
    ret = avformat_open_input(&fmtCtx, _config.inPath.UTF8String, NULL, NULL);
    if (ret < 0) {
        if (fmtCtx) {
            avformat_free_context(fmtCtx);
            fmtCtx = NULL;
        }
        return;
    }
    
    ret = avformat_find_stream_info(fmtCtx, NULL);
    if (ret < 0) {
        avformat_close_input(&fmtCtx);
        return;
    }
    
    for (int i = 0; i < fmtCtx->nb_streams; i++) {
        FFAVMediaType type = fmtCtx->streams[i]->codecpar->codec_type;
        if (type == AVMEDIA_TYPE_VIDEO) {
            _videoIdx = i;
            _videoStream = fmtCtx->streams[i];
        } else if (type == AVMEDIA_TYPE_AUDIO) {
            _audioIdx = i;
            _audioStream = fmtCtx->streams[i];
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
                rotation = M_PI_2; break;
            case 180:
                rotation = M_PI; break;
            case 270:
                rotation = 3*M_PI_2; break;
            default:
                rotation = 0; break;
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
@end
