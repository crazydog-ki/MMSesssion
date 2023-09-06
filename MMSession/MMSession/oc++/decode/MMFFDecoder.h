//// Created by crazydog-ki
//// Email  : jxyou.ki@gmail.com
//// Github : https://github.com/crazydog-ki

#include "MMUnitBase.h"
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
#include "MMDecodeConfig.h"

typedef void (*pcm_blk)(NSData *);

class MMFFDecoder: public MMUnitBase {
public:
    MMFFDecoder(MMDecodeConfig config);
    void process(std::shared_ptr<MMSampleData> &data) override;
    ~MMFFDecoder();
private:
    MMDecodeConfig m_config;
    
    AVFormatContext *m_fmtCtx = nullptr;
    AVCodecContext  *m_codecCtx = nullptr;
    AVFrame         *m_frame = nullptr;
    AVBufferRef     *m_hwDeviceCtx = nullptr;
    SwrContext      *m_swrCtx = nullptr;
    AudioBufferList *m_audioBufferList = nullptr;
    
    CVPixelBufferPoolRef _pixelBufferPool = nullptr;
    
    int m_videoIdx;
    int m_audioIdx;
    
    pcm_blk m_pcm_blk = nullptr;
    
    void _initFFDecoder();
    CVPixelBufferRef _convertAVFrame2CVPixelBuffer(AVFrame *frame);
    void _freeAll();
};
