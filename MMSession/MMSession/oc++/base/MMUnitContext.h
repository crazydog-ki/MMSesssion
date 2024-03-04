// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include <functional>

enum MMMsgID {
    MMMsg_VideoRenderFinished,
    MMMsg_AudioNeedBuffer,
    MMMsg_AudioPlayEnd,
};

using MMVideoRenderFinishedBlk = std::function<void(void)>;
using MMAudioNeedBufferBlk = std::function<void(void)>;
using MMAudioPlayEndBlk = std::function<void(void)>;

struct MMMsg {
    MMMsgID msgID;
};

class MMUnitContext {
public:
    void post(MMMsg &msg);
    
    void setVideoRenderFinishedBlk(const MMVideoRenderFinishedBlk &blk);
    void setAudioNeedBufferBlk(const MMAudioNeedBufferBlk &blk);
    void setAudioPlayEndBlk(const MMAudioPlayEndBlk &blk);
private:
    MMVideoRenderFinishedBlk m_videoRenderFinishedBlk;
    MMAudioNeedBufferBlk m_audioNeedBufferBlk;
    MMAudioPlayEndBlk m_audioPlayEndBlk;
};
