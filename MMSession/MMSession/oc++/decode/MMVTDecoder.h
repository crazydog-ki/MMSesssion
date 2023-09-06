// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMDecodeConfig.h"
#include "MMUnitBase.h"

#import <VideoToolbox/VideoToolbox.h>
#ifdef __cplusplus
extern "C" {
#endif
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/samplefmt.h"
#include "libswresample/swresample.h"
#include "libavutil/pixdesc.h"
#ifdef __cplusplus
};
#endif

class MMVTDecoder: public MMUnitBase {
public:
    MMVTDecoder(MMDecodeConfig config);
    void process(std::shared_ptr<MMSampleData> &data) override;
    ~MMVTDecoder();
private:
    MMDecodeConfig m_config;
    VTDecompressionSessionRef m_vtDecodeSession;
    
    void _initVt();
};

