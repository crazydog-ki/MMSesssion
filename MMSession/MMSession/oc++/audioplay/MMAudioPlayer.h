// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMAudioPlayConfig.h"
#include "MMUnitBase.h"

typedef std::function<void(AudioBufferList*)> AudioBufferBlock;
typedef std::function<void(AudioBufferBlock)> PullAudioDataBlock;

class MMAudioPlayer: public MMUnitBase {
    friend void MMAudioQueuePullData(void *inUserData,
                                     AudioQueueRef inAQ,
                                     AudioQueueBufferRef inBuffer);
public:
    MMAudioPlayer(MMAudioPlayConfig config);
    void process(std::shared_ptr<MMSampleData> &data) override;
    void play();
    void pause();
    void stop();
    void flush();
    ~MMAudioPlayer();
private:
    MMAudioPlayConfig m_config;
    
    AudioQueueBufferRef *m_audioBufferArr; //音频流缓冲区
    AudioBufferList *m_bufferList = nullptr;
    AudioQueueRef m_audioQueue;
    std::list<shared_ptr<MMSampleData>> m_audioQ;
    
    std::mutex m_mutex;
    std::condition_variable m_cond;
    bool isSytemPull = false;
    
    PullAudioDataBlock m_pullDataBlk;
    
    void _initAudioQueue();
};
