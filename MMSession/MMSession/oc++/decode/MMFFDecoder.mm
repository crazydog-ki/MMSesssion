//// Created by crazydog-ki
//// Email  : jxyou.ki@gmail.com
//// Github : https://github.com/crazydog-ki

#include "MMFFDecoder.h"
#include "MMBufferUtils.h"

static const NSUInteger kMaxSamplesCount = 1024;
static const NSUInteger kVideoTimeScale  = NSEC_PER_SEC;
static const NSUInteger kAudioTimeScale  = 44100;

MMFFDecoder::MMFFDecoder(MMDecodeConfig config): m_config(config) {
    m_audioBufferList = [MMBufferUtils produceAudioBufferList:MMBufferUtils.asbd
                                                 numberFrames:kMaxSamplesCount];
    //NSLog(@"[mm] ffdecoder audiobufferlist dataSize: %d", m_audioBufferList->mBuffers[0].mDataByteSize);
    _initFFDecoder();
}

void MMFFDecoder::process(std::shared_ptr<MMSampleData> &data) {
    doTask(MMTaskSync, ^{
        bool isEnd = data->isEof;
        bool isVideo = (data->dataType==MMSampleDataType_Parsed_Video);
        if (isEnd) { /// eof
            for (auto unit : isVideo?m_nextVideoUnits:m_nextAudioUnits) {
                unit->process(data);
            }
            return;
        }
        
        AVCodecContext *codecCtx = m_codecCtx;
        AVPacket packet = *(AVPacket *)(data->parsedData);
        
        /*
         会存在avcodec_send_packet返回0，但是avcodec_receive_frame返回-35（对应`EAGAIN`）的现象，这个情况是符合预期的
         在当前的上下文中，代表输出不可用，需要更多的输入
         */
        int ret = avcodec_send_packet(codecCtx, &packet);
        while (0 == avcodec_receive_frame(codecCtx, m_frame)) {
            AVFrame *frame = m_frame;
            if (isVideo) {
                /** 硬解码 */
                //CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)frame->data[3];
                
                /** 软解码
                 AVFrame(YUV420P) -> CVPixelBufferRef(YUV420SP)
                 AVFrame.data[0] 存储Y分量
                 AVFrame.data[1] 存储U分量
                 AVFrame.data[2] 存储V分量
                 */
                CVPixelBufferRef pixelBuffer = _convertAVFrame2CVPixelBuffer(frame);
                if (!pixelBuffer) return;
                CVPixelBufferRetain(pixelBuffer);
                data->pts = frame->pts * av_q2d(m_fmtCtx->streams[m_videoIdx]->time_base);
                data->videoBuffer = pixelBuffer;
                data->dataType = MMSampleDataType_Decoded_Video;
                if (!m_nextVideoUnits.empty()) {
                    for (auto unit : m_nextVideoUnits) {
                        unit->process(data);
                    }
                }
                CVPixelBufferRelease(pixelBuffer);
            } else { /// 解码音频
                if (!m_swrCtx) {
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
                    m_swrCtx = swrCtx;
                }
                
                int outLineSize;
                int samplesNum = frame->nb_samples;
                int swrOutSamples = swr_get_out_samples(m_swrCtx, samplesNum);
                int outBufferSize = av_samples_get_buffer_size(&outLineSize,
                                                               2,
                                                               swrOutSamples,
                                                               AV_SAMPLE_FMT_FLT,
                                                               1);
                
                uint8_t *outBuffer = (uint8_t *)av_malloc(outBufferSize);
                // 转换
                swr_convert(m_swrCtx,
                            &outBuffer,
                            outLineSize,
                            (const uint8_t **)frame->data,
                            samplesNum);
                
                AudioBufferList *bufferList = m_audioBufferList;
                [MMBufferUtils resetAudioBufferList:bufferList];
                memcpy(bufferList->mBuffers[0].mData, outBuffer, outBufferSize);
                m_audioBufferList->mBuffers[0].mDataByteSize = outBufferSize;
                
                /// 向外传递PCM裸数据
                if (m_config.needPcm && m_pcm_blk) {
                    NSData *data = [NSData dataWithBytes:outBuffer length:outBufferSize];
                    m_pcm_blk(data);
                }
                
                /// bufferList -> CMSampleBufferRef
                CMSampleTimingInfo timingInfo;
                timingInfo.duration              = CMTimeMake(1, kAudioTimeScale);
                timingInfo.presentationTimeStamp = CMTimeMake(data->pts*kAudioTimeScale, kAudioTimeScale);
                timingInfo.decodeTimeStamp       = CMTimeMake(data->dts*kAudioTimeScale, kAudioTimeScale);
                CMSampleBufferRef sampleBuffer = [MMBufferUtils produceAudioBuffer:bufferList
                                                                        timingInfo:timingInfo
                                                                         frameNums:samplesNum];
                data->audioSample = sampleBuffer;
                data->dataType = MMSampleDataType_Decoded_Audio;
                
                if (!m_nextAudioUnits.empty()) {
                    for (auto unit : m_nextAudioUnits) {
                        unit->process(data);
                    }
                }
                av_free(outBuffer);
            }
        }});
}

void MMFFDecoder::destroy() {
    MMUnitBase::destroy();
    _freeAll();
}

MMFFDecoder::~MMFFDecoder() {
    
}

#pragma mark - Private
void MMFFDecoder::_initFFDecoder() {
    AVFormatContext *fmtCtx = (AVFormatContext *)m_config.fmtCtx;
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
    AVStream *audioStream = fmtCtx->streams[audioIdx];

    AVCodec *codec = NULL;
    AVCodecContext *codecCtx = NULL;
    int ret = -1;
    MMDecodeType type = m_config.decodeType;
    if (type == MMDecodeType_Video) {
        /** 硬解码 */
//        ret = av_find_best_stream(fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
//        codecCtx = avcodec_alloc_context3(codec);
//        ret = avcodec_parameters_to_context(codecCtx, videoStream->codecpar);
//        const char *codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
//        enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
//        ret = av_hwdevice_ctx_create(&m_hwDeviceCtx, type, NULL, NULL, 0);
//        codecCtx->hw_device_ctx = av_buffer_ref(m_hwDeviceCtx);

        /** 软解码，解码后格式为YUV420P */
        codec = avcodec_find_decoder(videoStream->codecpar->codec_id);
        codecCtx = avcodec_alloc_context3(codec);
        ret = avcodec_parameters_to_context(codecCtx, videoStream->codecpar);
    } else if (type == MMDecodeType_Audio) {
        codec = avcodec_find_decoder(audioStream->codecpar->codec_id);
        cout << "[mm] decode audio: " << codec->name << endl;
        codecCtx = avcodec_alloc_context3(codec);
        ret = avcodec_parameters_to_context(codecCtx, audioStream->codecpar);
    }

    ret = avcodec_open2(codecCtx, codec, NULL);

    m_frame = av_frame_alloc();
    m_fmtCtx = fmtCtx;
    m_codecCtx = codecCtx;
    m_videoIdx = videoIdx;
    m_audioIdx = audioIdx;
    
    avcodec_flush_buffers(codecCtx);
}

CVPixelBufferRef MMFFDecoder::_convertAVFrame2CVPixelBuffer(AVFrame *frame) {
    int width = frame->width;
    int height = frame->height;

    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn error;
    if (!_pixelBufferPool) {
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:width] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:height] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(frame->linesize[0]) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        /*IOSurface是macOS和iOS中的一个底层技术，可以高效地在进程或应用程序之间共享硬件加速的视频帧，图片和其他图形数据，而无需复制.*/
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        error = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)attributes, &_pixelBufferPool);
        if (error != kCVReturnSuccess) {
            NSLog(@"[mm] pixelbuffer pool create error: %d", error);
        }
    }

    error = CVPixelBufferPoolCreatePixelBuffer(NULL, _pixelBufferPool, &pixelBuffer);
    if (error != kCVReturnSuccess) {
        NSLog(@"[mm] pixelbuffer create error: %d", error);
        return NULL;
    }
    
    uint8_t *ptr_y = frame->data[0];
    uint8_t *ptr_u = frame->data[1];
    uint8_t *ptr_v = frame->data[2];

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *yPtr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(yPtr, ptr_y, frame->linesize[0]*height);

    /* NV12侧存储格式
     YYYY
     UVUV */
    void *uvPtr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    size_t size = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    for(int i = 0; i < height/2; i++) {
        uint8_t *dst_uv = (uint8_t *)uvPtr + i*size; //获取CVPixelBuffer的每一行地址
        uint8_t *src_u = ptr_u + i*frame->linesize[1]; //U分量
        uint8_t *src_v = ptr_v + i*frame->linesize[2]; //V分量
        for (int j = 0; j < width/2; j++) { //每一行数据进行转换，数据进行拷贝，防止内存问题
            memcpy(dst_uv+j*2, src_u+j, 8);
            memcpy(dst_uv+j*2+1, src_v+j, 8);
        }
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return pixelBuffer;
}

void MMFFDecoder::_freeAll() {
    if (m_codecCtx) {
        avcodec_send_packet(m_codecCtx, nullptr);
        avcodec_flush_buffers(m_codecCtx);

        if (m_hwDeviceCtx) {
            av_buffer_unref(&m_hwDeviceCtx);
            m_hwDeviceCtx = nullptr;
        }

        avcodec_close(m_codecCtx);
        m_codecCtx = nullptr;
    }

    if (m_frame) {
        av_free(m_frame);
        m_frame = nullptr;
    }

    if (m_swrCtx) {
        swr_free(&m_swrCtx);
        m_swrCtx = nullptr;
    }

    if (m_audioBufferList) {
        [MMBufferUtils freeAudioBufferList:m_audioBufferList];
        m_audioBufferList = nullptr;
    }
}
