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
@property (nonatomic, assign) BOOL hasSendKeyframe;
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
        _hasSendKeyframe = NO;
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

- (CMVideoFormatDescriptionRef)getVtDesc {
    CFMutableDictionaryRef extensions = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(extensions, kCVImageBufferChromaLocationBottomFieldKey, kCVImageBufferChromaLocation_Left);
    CFDictionarySetValue(extensions, kCVImageBufferChromaLocationTopFieldKey, kCVImageBufferChromaLocation_Left);
    CFDictionarySetValue(extensions, CFSTR("FullRangeVideo"), kCFBooleanFalse);
    
    //par
    CFMutableDictionaryRef par = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    _cfmap_setkeyvalue(par, kCVImageBufferPixelAspectRatioHorizontalSpacingKey, 0);
    _cfmap_setkeyvalue(par, kCVImageBufferPixelAspectRatioVerticalSpacingKey, 0);
    CFDictionarySetValue(extensions, CFSTR("CVPixelAspectRatio"), (CFTypeRef *)par);
    
    //atoms sps/pps/vps等信息
    CFMutableDictionaryRef atoms = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    AVCodecParameters *codecParam = _videoStream->codecpar;
    if (codecParam->codec_id == AV_CODEC_ID_H264) {
        _cfmap_setdata(atoms, CFSTR("avcC"), (uint8_t*)_videoStream->codecpar->extradata, _videoStream->codecpar->extradata_size); //h264
    } else if (codecParam->codec_id == AV_CODEC_ID_HEVC) {
        _cfmap_setdata(atoms, CFSTR("hvcC"), (uint8_t*)_videoStream->codecpar->extradata, _videoStream->codecpar->extradata_size);
    }
    CFDictionarySetValue(extensions, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms, (CFTypeRef *)atoms);
    
    CMVideoFormatDescriptionRef vtDesc = NULL;
    OSStatus ret = CMVideoFormatDescriptionCreate(NULL,
                                                  codecParam->codec_id == AV_CODEC_ID_H264 ? kCMVideoCodecType_H264 : kCMVideoCodecType_HEVC,
                                                  codecParam->width,
                                                  codecParam->height,
                                                  extensions,
                                                  &vtDesc);
    if (!vtDesc) {
        NSLog(@"[yjx] CMVideoFormatDescriptionCreate erro - %d", ret);
    }
    CFRelease(extensions);
    CFRelease(atoms);
    CFRelease(par);
    return vtDesc;
}

- (CGSize)size {
    return CGSizeMake(_videoStream->codecpar->width, _videoStream->codecpar->height);
}

void _cfmap_setkeyvalue(CFMutableDictionaryRef dict,
                     CFStringRef key,
                     int32_t value) {
    CFNumberRef number;
    number = CFNumberCreate(NULL, kCFNumberSInt32Type, &value);
    CFDictionarySetValue(dict, key, number);
    CFRelease(number);
}

void _cfmap_setdata(CFMutableDictionaryRef dict,
                    CFStringRef key,
                    uint8_t *value,
                    uint64_t length) {
    CFDataRef data;
    data = CFDataCreate(NULL, value, (CFIndex)length);
    CFDictionarySetValue(dict, key, data);
    if (data) {
        CFRelease(data);
        data = NULL;
    }
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
            
            if (ret < 0) { // error or eof
                if (ret == AVERROR_EOF) {
                    sampleData.statusFlag = MMSampleDataFlagEnd;
                    if (self.nextVideoNodes) {
                        sampleData.dataType = MMSampleDataType_Parsed_Video;
                        for (id<MMSessionProcessProtocol> node in self.nextVideoNodes) {
                            [node processSampleData:sampleData];
                        }
                    }
                    if (self.nextAudioNodes) {
                        sampleData.dataType = MMSampleDataType_Parsed_Audio;
                        for (id<MMSessionProcessProtocol> node in self.nextAudioNodes) {
                            [node processSampleData:sampleData];
                        }
                    }
                    [self _freeAll];
                } else {
                    NSLog(@"[yjx] av_read_frame error - %d", ret);
                }
                break;
            }
            
            if (packet->stream_index == videoIdx) { /// 视频轨
                if (!isVideo) continue;
                /// bsf对SPS、PPS等数据进行格式转换，使其可被解码器处理
                //const AVBitStreamFilter *pFilter = NULL;
                MMVideoFormat videoFormat = NULL;
                if (videoStream->codecpar->codec_id == AV_CODEC_ID_H264) {
                    //pFilter = av_bsf_get_by_name("h264_annexbtomp4");
                    videoFormat = MMVideoFormatH264;
                } else if (videoStream->codecpar->codec_id == AV_CODEC_ID_HEVC) {
                    // pFilter = av_bsf_get_by_name("hevc_annexbtomp4");
                    videoFormat = MMVideoFormatH265;
                }
                /*
                if (!_bsfCtx) {
                    av_bsf_alloc(pFilter, &_bsfCtx);
                    avcodec_parameters_copy(_bsfCtx->par_in, videoStream->codecpar);
                    av_bsf_init(_bsfCtx);
                }
                av_bsf_send_packet(_bsfCtx, packet);
                while (av_bsf_receive_packet(_bsfCtx, packet) == 0) {
                    
                }
                 */
                
                /// 确保发往decoder的第一个packet为Key-Frame
                // bool isKey = (packet->flags & AV_PKT_FLAG_KEY) == AV_PKT_FLAG_KEY;
                // NSLog(@"[yjx] packet is keyframe - %d, pts - %lld, dts - %lld", isKey, packet->pts, packet->dts);
                
                /// 填充demux数据
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
                videoInfo.parsedData    = packet;
                
                sampleData.dataType = MMSampleDataType_Parsed_Video;
                sampleData.videoInfo  = videoInfo;
                
                if (YES) { // todo: 这段代码仅针对vt解码适用
                    CMSampleBufferRef samplebuffer = [self _convert_to_samplebuffer:packet];
                    sampleData.sampleBuffer = samplebuffer;
                }
                
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

- (CMSampleBufferRef)_convert_to_samplebuffer:(AVPacket *)packet {
    int size = packet->size;
    void* buffer = packet->data;
    
    CMBlockBufferRef blockBuf = NULL;
    CMSampleBufferRef sampleBuf = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                         buffer,
                                                         size,
                                                         kCFAllocatorNull,
                                                         NULL,
                                                         0,
                                                         size,
                                                         false,
                                                         &blockBuf);

    if (!status) {
        CMSampleTimingInfo timestamp = kCMTimingInfoInvalid;
        timestamp.duration = CMTimeMake(packet->duration, USEC_PER_SEC);
        timestamp.presentationTimeStamp = CMTimeMake(packet->pts, USEC_PER_SEC);
        timestamp.decodeTimeStamp = CMTimeMake(packet->dts, USEC_PER_SEC);
        status = CMSampleBufferCreate(NULL,
                                      blockBuf,
                                      TRUE,
                                      0,
                                      0,
                                      self.getVtDesc,
                                      1,
                                      1,
                                      &timestamp,
                                      0,
                                      NULL,
                                      &sampleBuf);
    }
    if (blockBuf) {
        CFRelease(blockBuf);
        blockBuf = NULL;
    }
    return sampleBuf;
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
