// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMAudioPlayer.h"
#import "MMBufferUtils.h"

static const int kMaxByteSize    = 1024 * sizeof(float) * 16;
static const int kBufferListSize = 8192;
static const int kBufferCount    = 3;
static const int kMaxAudioCache  = 20;

void MMAudioQueuePropertyCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    if (inID == kAudioQueueProperty_IsRunning) {
        UInt32 flag = 0;
        UInt32 size = sizeof(flag);
        AudioQueueGetProperty(inAQ, inID, &flag, &size);
    }
}

void MMAudioQueuePullData(void* __nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    MMAudioPlayer *player = (MMAudioPlayer *)inUserData;
    if (!player) {
        return;
    }

    OSStatus ret = noErr;
    if (nullptr == inBuffer) {
        ret = AudioQueueAllocateBuffer(player->m_audioQueue, kMaxByteSize, &inBuffer);
        if (!inBuffer || ret != noErr) {
            cout << "[mm] AudioQueueAllocateBuffer: " << ret << endl;
            return;
        }
    }
    
    bool isPushMode = !player->m_config.needPullData;
    bool isEof = player->m_reachEof;
    bool isStop = player->m_status==MMAudioPlayerStatus_Stop;
    if (isPushMode) { //推模式
        AudioBufferList *bufferList = player->m_bufferList;
        [MMBufferUtils resetAudioBufferList:bufferList];
        /*
         这个过程创建了dataQueue作为一个新的std::list实例，它包含了和player->m_sampleDataQueue相同的元素。由于列表中
         的元素是std::shared_ptr<MMSampleData>类型，拷贝构造函数会复制这些智能指针，而不是它们所指向的对象。这意味着两个
         列表共享对相同MMSampleData对象的引用，而这些对象的生命周期则由这些智能指针的引用计数共同管理。
         */
        // list<shared_ptr<MMSampleData>> dataQueue = player->m_sampleDataQueue; //会调用std::list的拷贝构造函数
        if (!player->m_sampleDataQueue.empty() && !isStop) {
            std::unique_lock<std::mutex> lock(player->m_mutex);
            shared_ptr<MMSampleData> data = player->m_sampleDataQueue.front();
            player->m_sampleDataQueue.pop_front();
            player->m_pts = data->pts;
            CMSampleBufferRef sampleBuffer = data->audioSample;
            UInt32 samples = (UInt32)CMSampleBufferGetNumSamples(sampleBuffer);
            bufferList->mBuffers[0].mDataByteSize = samples * MMBufferUtils.asbd.mBytesPerFrame;
            CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, 0, samples, bufferList);
            player->m_cond.notify_one();
        }
        
        UInt32 dataSize = bufferList->mBuffers[0].mDataByteSize;
        memcpy(inBuffer->mAudioData, bufferList->mBuffers[0].mData, dataSize);
        inBuffer->mAudioDataByteSize = dataSize;
        ret = AudioQueueEnqueueBuffer(player->m_audioQueue, inBuffer, 0, NULL);
        if (ret != noErr) {
            cout << "[mm] AudioQueueEnqueueBuffer: " << ret << endl;
        }
        
        while (!isEof && !isStop && player->m_sampleDataQueue.size() <= kMaxAudioCache/2) { //音频要抓紧生产
            MMMsg msg;
            msg.msgID = MMMsg_AudioNeedBuffer;
            player->m_sharedUnitCtx->post(msg);
        }
        
        if ((isEof || isStop) && player->m_sampleDataQueue.empty()) {
            MMMsg msg;
            msg.msgID = MMMsg_AudioPlayEnd;
            player->m_sharedUnitCtx->post(msg);
        }
    } else { //拉模式
        /*
         player->m_pullDataBlk([&](AudioBufferList * _Nonnull bufferList) {
             if (bufferList) {
                 UInt32 dataSize = bufferList->mBuffers[0].mDataByteSize;
                 memcpy(inBuffer->mAudioData, bufferList->mBuffers[0].mData, dataSize);
                 inBuffer->mAudioDataByteSize = dataSize;
                 ret = AudioQueueEnqueueBuffer(player->m_audioQueue, inBuffer, 0, NULL);
             } else {
                 memset(inBuffer->mAudioData, 0, kMaxByteSize);
                 inBuffer->mAudioDataByteSize = kMaxByteSize;
                 ret = AudioQueueEnqueueBuffer(player->m_audioQueue, inBuffer, 0, NULL);
             }
         });
         */
    }
}

MMAudioPlayer::MMAudioPlayer(MMAudioPlayConfig config): m_config(config) {
    m_bufferList = [MMBufferUtils produceAudioBufferList:MMBufferUtils.asbd numberFrames:kBufferListSize];
    _initAudioQueue();
}

void MMAudioPlayer::destroy() {
    MMUnitBase::destroy();
    m_status = MMAudioPlayerStatus_Stop;
    std::unique_lock<std::mutex> lock(m_mutex);
    if (m_audioQueue) {
        pause();
        flush();
        stop();
        AudioQueueDispose(m_audioQueue, true);
        m_audioQueue = nullptr;
    }
    m_sampleDataQueue.clear();
}

void MMAudioPlayer::process(std::shared_ptr<MMSampleData> &data) {
    if (data->isEof) {
        m_reachEof = true;
        return;
    }
    if (!data->audioSample) {
        return;
    }
    CFRetain(data->audioSample);

    std::unique_lock<std::mutex> lock(m_mutex);
    m_cond.wait(lock, [this] {
        return m_sampleDataQueue.size() <= kMaxAudioCache;
    });
    m_sampleDataQueue.push_back(data);
//    cout << "[mm] receive audio samples: " << (UInt32)CMSampleBufferGetNumSamples(data->audioSample)
//         << ", pts: "  << data->pts
//         << ", size: " << (int)m_sampleDataQueue.size()
//         << endl;
}

void MMAudioPlayer::play() {
    if (m_status == MMAudioPlayerStatus_Play) return;
    doTask(MMTaskSync, ^{
        AudioQueueReset(m_audioQueue);
        m_audioBufferArr = (AudioQueueBufferRef *)calloc(kBufferCount, sizeof(AudioQueueBufferRef));
        for (int i = 0; i < kBufferCount; i++) {
            if (!m_audioBufferArr[i] || !m_audioBufferArr[i]->mAudioData) {
                AudioQueueAllocateBuffer(m_audioQueue, kMaxByteSize, &m_audioBufferArr[i]);
            }
            MMAudioQueuePullData((void *)this, m_audioQueue, m_audioBufferArr[i]);
        }
        
        if (m_audioQueue) {
            OSStatus ret = AudioQueueStart(m_audioQueue, NULL);
            if (ret != noErr) {
                cout << "[mm] AudioQueueStart: " << ret << endl;
            }
        }
        m_status = MMAudioPlayerStatus_Play;
    });
}

void MMAudioPlayer::pause() {
    if (m_status == MMAudioPlayerStatus_Pause) return;
    doTask(MMTaskAsync, ^{
        if (m_audioQueue) {
            OSStatus ret = AudioQueuePause(m_audioQueue);
            cout << "[mm] AudioQueuePause: " << ret << endl;
        }
        m_status = MMAudioPlayerStatus_Pause;
    });
}

void MMAudioPlayer::stop() {
    if (m_status == MMAudioPlayerStatus_Stop) return;
    doTask(MMTaskSync, ^{
        if (m_audioQueue) {
            OSStatus ret = AudioQueueStop(m_audioQueue, YES);
            if (ret != noErr) {
                cout << "[mm] AudioQueueStop: " << ret << endl;
            }
        }
        m_status = MMAudioPlayerStatus_Stop;
    });
}

void MMAudioPlayer::flush() {
    doTask(MMTaskSync, ^{
        if (m_audioQueue) {
            OSStatus ret = AudioQueueFlush(m_audioQueue);
            cout << "[mm] AudioQueueFlush: " << ret << endl;
        }
    });
}

double MMAudioPlayer::getPts() {
    return m_pts;
}

MMAudioPlayer::~MMAudioPlayer() {
}

#pragma mark - Private
void MMAudioPlayer::_initAudioQueue() {
    AudioStreamBasicDescription asbd = MMBufferUtils.asbd;
    OSStatus ret = AudioQueueNewOutput(&asbd,
                                       MMAudioQueuePullData,
                                       (void *)this,
                                       NULL,
                                       NULL,
                                       0,
                                       &m_audioQueue);
    if (ret != noErr) {
        AudioQueueDispose(m_audioQueue, YES);
        cout << "[mm] AudioQueueNewOutput: " << ret << endl;
        m_audioQueue = nullptr;
        return;
    }
    ret = AudioQueueAddPropertyListener(m_audioQueue,
                                        kAudioQueueProperty_IsRunning,
                                        MMAudioQueuePropertyCallback,
                                        (void *)(this));
}
