#import "AvuFFmpegParser.h"

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

@interface AvuFFmpegParser ()
{
    AVFormatContext *_fmtCtx;
    AVPacket        *_packet;
    AVStream        *_videoStream;
    AVStream        *_audioStream;
    int             _videoIdx;
    int             _audioIdx;
    AVCodecID       _codecId;
    double          _width;
    double          _height;
    
    CMVideoFormatDescriptionRef _videoDesc;
    
    AVBSFContext    *_bsfCtx;
}
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) dispatch_queue_t ffParseQueue;
@property (nonatomic, strong) NSMutableArray *nextNodes;
@end

@implementation AvuFFmpegParser
#pragma mark - AvuBufferProcessProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _ffParseQueue = dispatch_queue_create("avu_ffmpeg_parse_queue", DISPATCH_QUEUE_SERIAL);
        _nextNodes = [NSMutableArray array];
        [self _initFFParser];
    }
    return self;
}

- (void)processBuffer:(AvuBuffer *)buffer {
    dispatch_sync(_ffParseQueue, ^{
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
            
            BOOL isVideo = _config.type==AvuType_Video;
            if (ret == AVERROR_EOF) {
                // [self _freeAll];
                NSLog(@"[avu] ffmpeg parse end，%p", self);
                break;
            } else if (packet->stream_index == videoIdx) { /// 视频轨
                if (!isVideo) continue;
                buffer.pts = packet->pts * av_q2d(videoStream->time_base);
                buffer.dts = packet->dts * av_q2d(videoStream->time_base);
                buffer.duration = packet->duration * av_q2d(videoStream->time_base);
                BOOL isKeyFrame = packet->flags==AV_PKT_FLAG_KEY;
//                NSLog(@"[avu] video buffer pts: %lf, dts: %lf, duration: %lf, isKeyFrame: %d", buffer.pts, buffer.dts, buffer.duration, isKeyFrame);
//                
                CMSampleBufferRef sampleBuffer = [self _generateSampleBuffer:packet];
                buffer.sampleBuffer = sampleBuffer;
                for (id<AvuBufferProcessProtocol> node in self.nextNodes) {
                    [node processBuffer:buffer];
                }
                if (sampleBuffer) {
                    CFRelease(sampleBuffer);
                    sampleBuffer = NULL;
                }
            } else if (packet->stream_index == audioIdx) { /// 音频轨
                if (isVideo) continue;
                buffer.pts         = packet->pts * av_q2d(audioStream->time_base);
                buffer.dts         = packet->dts * av_q2d(audioStream->time_base);
                buffer.duration    = packet->duration * av_q2d(audioStream->time_base);
//                NSLog(@"[avu] audio buffer pts: %lf, dts: %lf, duration: %lf", buffer.pts, buffer.dts, buffer.duration);
            
                buffer.channel     = audioStream->codecpar->channels;
                buffer.sampleRate  = audioStream->codecpar->sample_rate;
                
                buffer.parsedData = packet;
                
                for (id<AvuBufferProcessProtocol> node in self.nextNodes) {
                    [node processBuffer:buffer];
                }
            }
            break;
        }
    });

}

- (void)addNextNode:(id<AvuBufferProcessProtocol>)node {
    dispatch_sync(_ffParseQueue, ^{
        [self.nextNodes addObject:node];
    });
}

#pragma mark - Public
- (void)seekToTime:(double)time {
    if (!_fmtCtx) {
        NSLog(@"[avu] not suppport seek because of fmtCtx is nil");
        return;
    }
    
    dispatch_sync(_ffParseQueue, ^{
        AVFormatContext *ifmtCtx = self->_fmtCtx;
        AVStream *videoSteam = self->_videoStream;
        AVStream *audioStream = self->_audioStream;
        
        BOOL isVideo = self->_config.type==AvuType_Video;
        int64_t seekTime = -1;
        int ret = -1;
        if (isVideo) {
            seekTime = (int64_t)time*videoSteam->time_base.den;
            NSLog(@"[avu] seek time: %lld", seekTime);
            ret = av_seek_frame(ifmtCtx, self->_videoIdx, seekTime, AVSEEK_FLAG_BACKWARD);
        } else {
            seekTime = (int64_t)time*audioStream->time_base.den;
            ret = av_seek_frame(ifmtCtx, self->_audioIdx, seekTime, AVSEEK_FLAG_BACKWARD);
        }
    });
}

- (CMVideoFormatDescriptionRef)videoDesc {
    return _videoDesc;
}

- (CGSize)videoSize {
    return CGSizeMake(_width, _height);
}

- (void *)getFmtCtx {
    if (!_fmtCtx) {
        return NULL;
    }
    return (void *)_fmtCtx;
}

- (void)stopParse {
    dispatch_sync(self.ffParseQueue, ^{
        [self _freeAll];
    });
}

- (void)dealloc {
    [self _freeAll];
}

#pragma mark - Private
- (void)_initFFParser {
    _videoIdx = -1;
    _audioIdx = -1;
    int ret = -1;
    AVInputFormat *ifmt = NULL;
    AVDictionary *opts = NULL;
    AVFormatContext *fmtCtx = avformat_alloc_context();
    
    NSString *path = nil;
    BOOL isVideo = (_config.type==AvuType_Video);
    if (isVideo) {
        path = _config.videoPath;
    } else {
        path = _config.audioPath;
    }
    ret = avformat_open_input(&fmtCtx, path.UTF8String, ifmt, &opts);
    if (ret < 0) {
        if (fmtCtx) {
            avformat_free_context(fmtCtx);
            fmtCtx = NULL;
        }
        
        if (self.parseErrorCallback) {
            NSError *error = [NSError errorWithDomain:@"avu_decode"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"avu_parse_ffmpeg_open_input_error"}];
            self.parseErrorCallback(AvuDecodeErrorType_Parse, error);
        }
        
        NSLog(@"[avu] ffmpeg open input error: %d", ret);
        return;
    }
    
    ret = avformat_find_stream_info(fmtCtx, NULL);
    if (ret < 0) {
        avformat_close_input(&fmtCtx);
        if (self.parseErrorCallback) {
            NSError *error = [NSError errorWithDomain:@"avu_decode"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"avu_parse_ffmpeg_find_stream_info_error"}];
            self.parseErrorCallback(AvuDecodeErrorType_Parse, error);
        }
        NSLog(@"[avu] ffmpeg find stream info error: %d", ret);
        return;
    }
    
    for (int i = 0; i < fmtCtx->nb_streams; i++) {
        FFAVMediaType type = fmtCtx->streams[i]->codecpar->codec_type;
        AVStream *st = fmtCtx->streams[i];
        if (type == AVMEDIA_TYPE_VIDEO) {
            _videoIdx = i;
            _videoStream = st;
            
            _codecId = st->codecpar->codec_id;
            _width = st->codecpar->width;
            _height = st->codecpar->height;
        } else if (type == AVMEDIA_TYPE_AUDIO) {
            _audioIdx = i;
            _audioStream = st;
        }
        
        /// 丟帧优化
        if (isVideo && type != AVMEDIA_TYPE_VIDEO) {
            st->discard = AVDISCARD_ALL;
        }
        if (!isVideo && type != AVMEDIA_TYPE_AUDIO) {
            st->discard = AVDISCARD_ALL;
        }
    }
    _fmtCtx = fmtCtx;
    
    _packet = (AVPacket *)malloc(sizeof(AVPacket));
    av_init_packet(_packet);
    
    if (isVideo) {
        [self _initVtDesc];
    }
}

- (void)_initVtDesc {
    AVAsset *asset  = [AVAsset assetWithURL:[NSURL fileURLWithPath:_config.videoPath]];
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    CFDictionaryRef extensions = NULL;
    if (tracks.count) {
        AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        CMVideoFormatDescriptionRef formatDesc = (__bridge CMVideoFormatDescriptionRef)videoTrack.formatDescriptions.firstObject;
        if (formatDesc) {
            extensions = CMFormatDescriptionGetExtensions(formatDesc);
        }
    }

    enum AVCodecID codecId = _codecId;
    int32_t w = _width;
    int32_t h = _height;
    
    CMVideoCodecType codecType = NULL;
    if (codecId == AV_CODEC_ID_H264) {
        codecType = kCMVideoCodecType_H264;
    } else if (codecId == AV_CODEC_ID_HEVC) {
        codecType = kCMVideoCodecType_HEVC;
    }
    OSStatus ret = CMVideoFormatDescriptionCreate(NULL,
                                                  codecType,
                                                  w,
                                                  h,
                                                  extensions,
                                                  &_videoDesc);
    if (ret != noErr) {
        if (self.parseErrorCallback) {
            NSError *error = [NSError errorWithDomain:@"avu_decode"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"avu_parse_init_vt_desc_error"}];
            self.parseErrorCallback(AvuDecodeErrorType_Parse, error);
        }
        NSLog(@"[avu] init vt desc error: %d", (int)ret);
    }
}

- (CMSampleBufferRef)_generateSampleBuffer:(AVPacket *)packet {
    CMBlockBufferRef dataBuffer = NULL;
    CMSampleBufferRef sampleBuffer = NULL;
    OSStatus ret = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                      packet->data,
                                                      packet->size, kCFAllocatorNull, NULL, 0,
                                                      packet->size, false,
                                                      &dataBuffer);
    if (ret == noErr) {
        ret = CMSampleBufferCreate(kCFAllocatorDefault,
                                   dataBuffer, true, 0, 0,
                                   _videoDesc, 1, 0, NULL, 0, NULL,
                                   &sampleBuffer);
    }

    if (dataBuffer) {
        CFRelease(dataBuffer);
        dataBuffer = NULL;
    }

    if (ret != noErr) {
        return NULL;
    }
    return sampleBuffer;
}

- (void)_freeAll {
    if (_fmtCtx) {
        avformat_close_input(&_fmtCtx);
        _fmtCtx = NULL;
    }
    
    if (_packet) {
        av_packet_unref(_packet);
        free(_packet);
        _packet = nil;
    }
    
    if (_videoDesc) {
        CFRelease(_videoDesc);
        _videoDesc = NULL;
    }
    
    if (_bsfCtx) {
        av_bsf_free(&_bsfCtx);
        _bsfCtx = NULL;
    }
}
@end
