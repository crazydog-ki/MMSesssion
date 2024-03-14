// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMFFParser.h"
#include <chrono>

MMFFParser::MMFFParser(MMParseConfig config): m_config(config) {
    _init();
}

void MMFFParser::destroy() {
    MMUnitBase::destroy();
    m_stopFlag = true;
    _freeAll();
}

MMFFParser::~MMFFParser() {
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
    /*
     在使用FFmpeg解封装AVCC格式的MP4文件时，SPS（序列参数集）和PPS（图像参数集）通常不会以单独的AVPacket形式出现，
     因为它们被封装在MP4文件的视频轨道的特定位置中，而不是作为独立的视频帧流传输。这与解封装Annex B格式的流有所不同，
     在Annex B格式的流中，SPS和PPS可能以单独的NALU单元出现在数据流中。

     对于AVCC格式的MP4文件，SPS和PPS数据一般在解封装过程中被解析，并存储在AVCodecParameters结构的extradata字段中。
     这些数据在解码视频帧之前被读取并使用，以便正确配置解码器。

     如果你需要访问SPS和PPS数据，你可以直接从视频流的codecpar结构的extradata字段获取，而不是从av_read_frame读取的
     AVPacket中获取。
     
     
     SPS、PPS在H.264裸流和MP4封装格式中存储方式的差异？？？
     
     在H.264编码和封装过程中，extradata的处理与存储方式依赖于所使用的封装格式。在原始的H.264码流（即裸流）中，SPS
     （序列参数集）和PPS（图像参数集）确实以NALU（网络抽象层单元）的形式存在。但是，当这个码流被封装到特定的容器格式中时，
     如MP4，处理方式会有所不同。

     `H.264码流中的extradata`：在H.264的裸码流（通常是Annex B格式）中，SPS和PPS数据以特定的NALU出现，它们直接嵌入在视
     频数据流中。这些NALU可以被解码器直接读取来获取视频序列的必要配置信息。

     `封装到MP4后的extradata``：当H.264码流被封装到MP4（或其他格式如MKV等）文件中时，SPS和PPS信息被提取出来并存储在
     封装格式的特定位置，通常是在`文件的元数据区域`。在MP4文件中，这些信息不再以NALU的形式存储，而是`以extradata的形式`
     存在于视频轨道（track）的头部信息中。这样做的目的是让解码器能够在开始解码任何帧之前就获得这些必要的信息。

     对于MP4文件，extradata通常存储在avcC（AVC Configuration Box）中，这是一个特定的box，它包含了SPS和PPS等信息，
     以及其他解码H.264流所需的参数。avcC box位于样本描述（sample description）box内部，后者描述了轨道中样本的编码信息。

     `extradata与封装层的转移`：因此，可以说当H.264码流被封装为MP4格式后，extradata（包括SPS和PPS）确实被转移到了封装层。
     在MP4文件中，这些信息被组织并存储在一种格式化的方式中，以便解码器能够轻松访问并初始化解码过程。这种转移使得视频文件的播放
     更加高效，因为解码器可以直接从文件的元数据中获得所有必需的初始化信息，而无需扫描整个视频数据流来查找这些参数集。
     */
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
        NSLog(@"[mm] CMVideoFormatDescriptionCreate erro - %d", ret);
    }
    CFRelease(extensions);
    CFRelease(atoms);
    CFRelease(par);
    return vtDesc;
}

void MMFFParser::process(std::shared_ptr<MMSampleData> &data) {
    if (m_stopFlag) return;
    
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

            /*
             `av_read_frame`函数是FFmepeg库中用于从媒体文件中读取下一个帧数据的关键函数，他是解封装demux过程中反复调用的，用于顺
             序地读取文件中的数据包，包括视频帧、音频帧等，这个函数对于从文件或者流中提取编码的媒体数据至关重要，为后续的解码和处理提供
             原料。
             
             参数含义：
             `AVPacket *pkt`：指向AVPacket结构的指针，用于存储读取的帧数据。AVPacket包含了解封装后的数据包信息，如数据指针、数据
             大小、流索引、时间戳等。
             */
            int ret = -1;
            ret = av_read_frame(fmtCtx, packet);

            if (ret < 0) { // error or eof
                if (ret == AVERROR_EOF) {
                    data->isEof = true;
                    cout << "[mm] ffmpeg parse eof" << endl;
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
                    std::cout << "[mm] av_read_frame error: " << ret << std::endl;
                }
                break;
            }

            if (packet->stream_index == videoIdx) { /// 视频轨
                if (!isVideo) continue;
                /* bsf对SPS、PPS等数据进行格式转换，使其可被解码器处理
                const AVBitStreamFilter *pFilter = NULL;
                if (m_videoFmt == AV_CODEC_ID_H264) {
                    pFilter = av_bsf_get_by_name("h264_annexbtomp4");
                } else if (m_videoFmt == AV_CODEC_ID_HEVC) {
                    pFilter = av_bsf_get_by_name("hevc_annexbtomp4");
                }
                if (!_bsfCtx) {
                    av_bsf_alloc(pFilter, &_bsfCtx);
                    avcodec_parameters_copy(_bsfCtx->par_in, videoStream->codecpar);
                    av_bsf_init(_bsfCtx);
                }
                av_bsf_send_packet(_bsfCtx, packet);
                while (av_bsf_receive_packet(_bsfCtx, packet) == 0) {
                }
                 */
                
                /*
                 FFmpeg处理Annex B格式的H.264视频流并将其转换为适合解码器（如VideoToolbox）处理的格式，通常涉及以下几个步骤：

                 1. 解析流并分离NAL单元
                 FFmpeg会解析输入的AnnexB格式的H.264流，识别起始码（通常是0x000001或0x00000001），并据此分离出NAL（网络抽象层）单元。NAL单元是H.264编码视频的基本单位，包含视频数据或其他信息。

                 2. 转换NAL单元格式
                 在Annex B格式中，NAL单元由起始码直接前缀。FFmpeg会将这些NAL单元转换为AVCC（Advanced Video Coding Configuration）格式，该格式使用长度前缀而非起始码。具体而言，FFmpeg会替换起始码为一个4字节的长度字段，
                 指明NAL单元的大小。这种格式转换使得解码器能够更容易地处理视频数据，因为解码器可以直接根据长度字段读取完整的NAL单元，而无需搜索起始码。

                 3. 构建格式化的输入
                 对于某些解码器或播放器，特别是基于硬件的解码器如VideoToolbox，FFmpeg可能还需要进一步处理转换后的数据。例如，它可能需要将转换后的NAL单元
                 打包进一个特定格式的容器中（如MP4），或者为解码器提供额外的流信息（如SPS（序列参数集）和PPS（图像参数集））。
                 */
                
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
                /*
                 时间戳信息通常与具体的视频帧（在封装格式层面）或流（在传输层面）相关联，而不是存储在视频编码层
                 （如H.264）的配置参数（SPS或PPS）中。例如，在MP4或MKV这样的容器格式中，pts和dts信息会被存
                 储在容器的特定结构中，用于控制播放时帧的显示时间。

                 当使用例如FFmpeg这样的库进行视频处理时，pts和dts信息可以从解封装后的AVPacket结构体中获得，
                 而SPS和PPS信息可用于初始化解码器来正确解码视频帧。
                 
                 带B帧的视频，解封装出来的pts不是递增的（dts递增），是按照解码顺序出现的
                 */
                data->pts           = packet->pts * av_q2d(videoStream->time_base);
                data->dts           = packet->dts * av_q2d(videoStream->time_base);
                data->duration      = packet->duration * av_q2d(videoStream->time_base);
                data->videoIdx      = videoIdx;
                data->format        = m_videoFmt;
                data->parsedData    = packet;
                data->isKeyFrame    = isKey;
                
                //NSLog(@"[mm] video packet is keyframe: %d, pts: %lf, dts: %lf", isKey, data->pts, data->dts);

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
                
                //NSLog(@"[mm] audio packet pts - %lf, dts - %lf", data->pts, data->dts);

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

#pragma mark - Private
void MMFFParser::_init() {
    bool isVideo = (m_config.parseType==MMFFParseType_Video);
    
    int ret = -1;
    /*
     `avformat_alloc_context`函数：
        1. av_class设置
        2. IO默认关闭或者打开函数io_open、io_close、io_close2
        3. 默认选项设置
     
     `AVFormatContext`结构体在FFmpeg解封装过程中扮演着重要的作用：
        1. 存储媒体文件信息：包含了关于媒体文件的重要信息，如流的数量、流的类型（视频、音频或字幕）、
           容器格式等。这为后续的数据处理提供了必要的上下文。
        2. 管理数据流：每个媒体文件可能包含多个数据流（例如，一个视频流、多个音频流用于不同语言、字幕流等）。
           通过AVStream数组来管理这些不同的数据流，并为每个流提供编解码器参数（AVCodecParameters）
           等信息。
        3. 提供I/O操作：通过AVIOContext处理媒体数据的输入和输出操作。这可以是从文件读取数据，
           也可以是从网络接收数据。自定义的I/O操作（如读取加密视频）也可以通过设置AVFormatContext中的相应
           字段来实现。
        4. 存储格式特定信息：包含特定于容器格式的元数据，如标题、作者、版权信息等。此外，它还可以包含格式特定
           的选项，比如用于调优解封装性能的标志。
        5. 时间基准转换：AVFormatContext中的时间基准（time base）信息对于正确解释时间戳至关重要。每个
           AVStream都有自己的时间基准，AVFormatContext提供了将这些时间戳转换为统一格式的基础。
     */
    AVFormatContext *fmtCtx = avformat_alloc_context();
    
    /*
     `avformat_open_input`函数：
        1. 输入格式检测：如果没有指定输入格式（fmt为NULL），FFmpeg会尝试自动检测输入媒体的格式。
        2. 读取和分析媒体头：avformat_open_input读取媒体文件或流的头部信息，AVFormatContext中的
           streams数组会被填充基础的流信息，如流的数量和大致类型（视频、音频、字幕等）。然而，这些信息通常
           仅足够表示流的存在，并不包括具体的编解码细节，如编解码器的类型、配置参数等。
        3. 初始化AVFormatContext：基于读取到的信息，初始化传入的或新分配的AVFormatContext结构体，包括流信息、
           持续时间、元数据等。
     
     获取详细的编解码信息，例如编解码器ID、视频分辨率、音频采样率等，需要调用avformat_find_stream_info函数，该函数会分析更多
     数据，试图填充每个AVStream的codecpar字段。
     
     MP4解析过程包括：
        1. 解析顶层box：如ftyp（文件类型）和moov（包含所有元数据）。
        2. 读取流信息：通过解析moov下的trak和mdia等box，获取每个流的详细信息。
        3. 填充AVStream：对于每个找到的流，FFmpeg会创建一个AVStream实例，包含了该流的编解码信息（通过解析stsd box获得）、时间基和其他重要的流信息。这些AVStream实例会被添加到AVFormatContext的流数组中。
        4. 设置时间和索引：解析mvhd（影片头box）来获取整个影片的持续时间和时间基，解析stbl（样本表box）来设置每个
           流的时间戳和关键帧索引等。
        5. 准备读取媒体数据：通过mdat box的位置信息，FFmpeg准备读取实际的媒体数据。
     
     `avformat_open_input`负责打开文件、识别文件格式，并解析包含全局元数据的box，例如ftyp和moov
     `avformat_find_stream_info`负责深入每个流的具体信息，通过解析trak、mdia、minf和stbl等box来获取每个流的
      详细编码信息。
     */
    auto st = std::chrono::high_resolution_clock::now();
    ret = avformat_open_input(&fmtCtx, m_config.inPath.c_str(), NULL, NULL);
    auto p1 = std::chrono::high_resolution_clock::now();
    
    if (ret < 0) {
        if (fmtCtx) {
            avformat_free_context(fmtCtx);
            fmtCtx = NULL;
        }
        return;
    }
    
    ret = avformat_find_stream_info(fmtCtx, NULL);
    auto p2 = std::chrono::high_resolution_clock::now();
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
    
    if (isVideo) {
        std::chrono::duration<double, std::milli> deta1 = p1 - st;
        std::chrono::duration<double, std::milli> deta2 = p2 - p1;
        cout << "[mm] avformat_open_input cost: " << deta1.count()
             << ", " << "avformat_find_stream_info cost: "
             << deta2.count() << endl;
        
        MMVideoFormat videoFormat = NULL;
        if (m_videoStream->codecpar->codec_id == AV_CODEC_ID_H264) {
            videoFormat = MMVideoFormatH264;
            cout << "[mm] decode video: h264" << endl;
        } else if (m_videoStream->codecpar->codec_id == AV_CODEC_ID_HEVC) {
            videoFormat = MMVideoFormatH265;
            cout << "[mm] decode video: h265" << endl;
        }
        m_videoFmt = videoFormat;
        
        //元信息
        AVDictionary *metadata = fmtCtx->metadata;
        AVDictionaryEntry *tag = NULL;
        while ((tag = av_dict_get(metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
            cout << "[mm] metadata key: " << tag->key << ", value: " << tag->value << endl;
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
