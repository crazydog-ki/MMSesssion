// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMFFParser.h"

MMFFParser::MMFFParser(MMParseConfig config): m_config(config) {
    _init();
}

void MMFFParser::seekToTime(double time) {
    if (!m_fmtCtx) {
        return;
    }
    
    doTask(MMTaskSync, ^{
        bool isVideo = (m_config.parseType==MMFFParseType_Video);
        int64_t seekTime = -1;
        int ret = -1;
        if (isVideo) {
            seekTime = (int64_t)time*m_videoStream->time_base.den;
            ret = av_seek_frame(m_fmtCtx, m_videoIdx, seekTime, AVSEEK_FLAG_FRAME);
        } else {
            seekTime = (int64_t)time*m_audioStream->time_base.den;
            ret = av_seek_frame(m_fmtCtx, m_audioIdx, seekTime, AVSEEK_FLAG_FRAME);
        }
    });
}

CGSize MMFFParser::getSize() {
    return CGSizeMake(m_videoStream->codecpar->width, m_videoStream->codecpar->height);
}

void* MMFFParser::getFmtCtx() {
    if (!m_fmtCtx) {
        return NULL;
    }
    return (void *)m_fmtCtx;
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

CMSampleBufferRef MMFFParser::_convert_to_samplebuffer(AVPacket *packet) {
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
                                      getVtDesc(),
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

CMVideoFormatDescriptionRef MMFFParser::getVtDesc() {
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
    AVCodecParameters *codecParam = m_videoStream->codecpar;
    if (codecParam->codec_id == AV_CODEC_ID_H264) {
        _cfmap_setdata(atoms, CFSTR("avcC"), (uint8_t*)m_videoStream->codecpar->extradata, m_videoStream->codecpar->extradata_size); //h264
    } else if (codecParam->codec_id == AV_CODEC_ID_HEVC) {
        _cfmap_setdata(atoms, CFSTR("hvcC"), (uint8_t*)m_videoStream->codecpar->extradata, m_videoStream->codecpar->extradata_size);
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

void MMFFParser::process(std::shared_ptr<MMSampleData> &data) {
    doTask(MMTaskSync, ^{
        BOOL isVideo = (data->dataType==MMSampleDataType_None_Video);
        while (YES) {
            if (!m_fmtCtx) return;

            AVFormatContext *fmtCtx = m_fmtCtx;
            int videoIdx = m_videoIdx;
            int audioIdx = m_audioIdx;
            AVStream *videoStream = m_videoStream;
            AVStream *audioStream = m_audioStream;

            AVPacket *packet = m_packet;
            av_packet_unref(packet);
            av_init_packet(packet);

            int ret = -1;
            ret = av_read_frame(fmtCtx, packet);

            if (ret < 0) { // error or eof
                if (ret == AVERROR_EOF) {
                    cout << "[yjx] ff parse end" << endl;
                    data->isEof = true;
                    cout << "[yjx] ffmpeg parse eof" << endl;
                    if (m_nextVideoUnits.size() != 0) {
                        data->dataType = MMSampleDataType_Parsed_Video;
                        for (shared_ptr<MMUnitBase> unit : m_nextVideoUnits) {
                            unit->process(data);
                        }
                    }

                    if (m_nextAudioUnits.size() != 0) {
                        data->dataType = MMSampleDataType_Parsed_Audio;
                        for (shared_ptr<MMUnitBase> unit : m_nextAudioUnits) {
                            unit->process(data);
                        }
                    }
                    _freeAll();
                } else {
                    std::cout << "[yjx] av_read_frame error - " << ret << std::endl;
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
                if (isFirstPacket) { //信息打印
                    AVCodecParameters *videoCodecpar = videoStream->codecpar;
                    if (4 <= videoCodecpar->extradata_size && videoCodecpar->extradata[0] == 1) {
                        cout << "[yjx] 码流格式为 AvCc" << endl;
                    } else if (videoCodecpar->extradata_size >= 4 &&
                               (memcmp(videoCodecpar->extradata, "\x00\x00\x00\x01", 4) == 0 ||
                                memcmp(videoCodecpar->extradata, "\x00\x00\x01", 3) == 0)) {
                        cout << "[yjx] 码流格式为 AnnexB" << endl;
                    } else {
                        cout << "[yjx] 码流格式不确定" << endl;
                    }
                    isFirstPacket = false;
                }

                /// 确保发往decoder的第一个packet为Key-Frame
                bool isKey = (packet->flags & AV_PKT_FLAG_KEY) == AV_PKT_FLAG_KEY;

                /// 填充demux数据
                int pktSize = packet->size;
                uint8_t *videoData = (uint8_t *)malloc(pktSize);
                memcpy(videoData, packet->data, pktSize);

                int extraSize = videoStream->codecpar->extradata_size;
                uint8_t *extraData = (uint8_t *)malloc(extraSize);
                memcpy(extraData, videoStream->codecpar->extradata, extraSize);

                data->rotate        = _getRotation();
                data->dataSize      = pktSize;
                data->data          = videoData;
                data->extradataSize = extraSize;
                data->extraData     = extraData;
                data->pts           = packet->pts * av_q2d(videoStream->time_base);
                data->dts           = packet->dts * av_q2d(videoStream->time_base);
                data->duration      = packet->duration * av_q2d(videoStream->time_base);
                data->videoIdx      = videoIdx;
                data->format        = videoFormat;
                data->parsedData    = packet;
                data->isKeyFrame    = isKey;
                
                //NSLog(@"[yjx] video packet is keyframe - %d, pts - %lf, dts - %lf", isKey, data->pts, data->dts);

                data->dataType = MMSampleDataType_Parsed_Video;

                CMSampleBufferRef samplebuffer = _convert_to_samplebuffer(packet);
                data->videoSample = samplebuffer;
                
                if (!m_nextVideoUnits.empty()) {
                    for (shared_ptr<MMUnitBase> unit : m_nextVideoUnits) {
                        unit->process(data);
                    }
                }
            } else if (packet->stream_index == audioIdx) { /// 音频轨
                if (isVideo) continue;
                uint8_t *audioData = (uint8_t *)malloc(packet->size);
                int pktSize = packet->size;
                memcpy(audioData, packet->data, pktSize);

                data->data        = audioData;
                data->dataSize    = pktSize;
                data->channel     = audioStream->codecpar->channels;
                data->sampleRate  = audioStream->codecpar->sample_rate;
                data->pts         = packet->pts * av_q2d(audioStream->time_base);
                data->dts         = packet->dts * av_q2d(audioStream->time_base);
                data->duration    = packet->duration * av_q2d(audioStream->time_base);
                data->audioIdx    = audioIdx;
                data->parsedData  = packet;
                
                //NSLog(@"[yjx] audio packet pts - %lf, dts - %lf", data->pts, data->dts);

                data->dataType = MMSampleDataType_Parsed_Audio;
                
                if (!m_nextAudioUnits.empty()) {
                    for (shared_ptr<MMUnitBase> unit : m_nextAudioUnits) {
                        unit->process(data);
                    }
                }
            }
            break;
        }
    });
}

MMFFParser::~MMFFParser() {
    cout << "[yjx] MMFFParser::~MMFFParser()" << endl;
    _freeAll();
}

#pragma mark - Private
void MMFFParser::_init() {
    int ret = -1;
    AVFormatContext *fmtCtx = avformat_alloc_context();
    
    ret = avformat_open_input(&fmtCtx, m_config.inPath.c_str(), NULL, NULL);
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
            m_videoIdx = i;
            m_videoStream = fmtCtx->streams[i];
        } else if (type == AVMEDIA_TYPE_AUDIO) {
            m_audioIdx = i;
            m_audioStream = fmtCtx->streams[i];
        }
    }
    
    m_packet = (AVPacket *)malloc(sizeof(AVPacket));
    av_init_packet(m_packet);
    
    m_fmtCtx = fmtCtx;
}

CGFloat MMFFParser::_getRotation() {
    AVDictionaryEntry *rotationEntry = NULL;
    rotationEntry = av_dict_get(m_fmtCtx->streams[m_videoIdx]->metadata, "rotate", rotationEntry, 0);
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

void MMFFParser::_freeAll() {
    if (m_fmtCtx) {
        avformat_close_input(&m_fmtCtx);
        m_fmtCtx = NULL;
    }
    
    if (m_bsfCtx) {
        av_bsf_free(&m_bsfCtx);
        m_bsfCtx = NULL;
    }
    
    if (m_packet) {
        av_packet_unref(m_packet);
        free(m_packet);
        m_packet = nil;
    }
}
