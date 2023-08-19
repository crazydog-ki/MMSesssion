// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMParseConfig.h"
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

class MMFFParser: public MMUnitBase  {
public:
    MMFFParser(MMParseConfig config);
    void seekToTime(double time);
    CGSize size();
    void* getFmtCtx();
    CMVideoFormatDescriptionRef getVtDesc();
    
    ~MMFFParser();
    
    void process(MMSampleData *data) override;
private:
    void _init();
    void _freeAll();
    CGFloat _getRotation();
    CMSampleBufferRef _convert_to_samplebuffer(AVPacket *packet);
    
    MMParseConfig m_config;
    AVFormatContext *m_fmtCtx;
    AVBSFContext *m_bsfCtx;
    AVPacket *m_packet;
    AVStream *m_videoStream;
    AVStream *m_audioStream;
    int m_videoIdx;
    int m_audioIdx;
    BOOL m_stopFlag;
    BOOL m_hasSendKeyframe;
};



