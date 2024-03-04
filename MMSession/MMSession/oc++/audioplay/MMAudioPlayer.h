// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMAudioPlayConfig.h"
#include "MMUnitBase.h"

typedef std::function<void(AudioBufferList*)> AudioBufferBlock;
typedef std::function<void(AudioBufferBlock)> PullAudioDataBlock;

enum MMAudioPlayerStatus {
    MMAudioPlayerStatus_Idle,
    MMAudioPlayerStatus_Play,
    MMAudioPlayerStatus_Pause,
    MMAudioPlayerStatus_Stop
};

class MMAudioPlayer: public MMUnitBase {
    friend void MMAudioQueuePullData(void *inUserData,
                                     AudioQueueRef inAQ,
                                     AudioQueueBufferRef inBuffer);
public:
    MMAudioPlayer(MMAudioPlayConfig config);
    void destroy() override;
    void process(std::shared_ptr<MMSampleData> &data) override;
    void play();
    void pause();
    void stop();
    void flush();
    double getPts();
    ~MMAudioPlayer();
private:
    MMAudioPlayConfig m_config;
    
    MMAudioPlayerStatus m_status = MMAudioPlayerStatus_Idle;
    
    AudioQueueRef m_audioQueue;
    AudioQueueBufferRef *m_audioBufferArr = nullptr; //音频流缓冲区
    AudioBufferList *m_bufferList = nullptr;
    
    std::list<shared_ptr<MMSampleData>> m_sampleDataQueue;
    
    std::mutex m_mutex;
    std::condition_variable m_cond;
    
    double m_pts = 0.0f;
    
    bool m_reachEof = false;
    
    PullAudioDataBlock m_pullDataBlk;
    
    void _initAudioQueue();
};
