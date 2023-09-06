// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMAudioPlayer.h"
#import "MMBufferUtils.h"

static const int kMaxByteSize    = 1024 * sizeof(float) * 16;
static const int kBufferListSize = 8192;
static const int kBufferCount    = 3;
static const int kMaxAudioCache  = 20;

void MMAudioQueuePropertyCallback(void *inUserData,
                                  AudioQueueRef inAQ,
                                  AudioQueuePropertyID inID) {

    if (inID == kAudioQueueProperty_IsRunning) {
        UInt32 flag = 0;
        UInt32 size = sizeof(flag);
        AudioQueueGetProperty(inAQ, inID, &flag, &size);
    }
}

void MMAudioQueuePullData(void* __nullable inUserData,
                          AudioQueueRef inAQ,
                          AudioQueueBufferRef inBuffer) {
    MMAudioPlayer *player = (MMAudioPlayer *)inUserData;
    if (!player) {
        return;
    }

    OSStatus ret = noErr;
    if (inBuffer == nullptr) {
        ret = AudioQueueAllocateBuffer(player->m_audioQueue,
                                       kMaxByteSize,
                                       &inBuffer);
        if (!inBuffer || ret != noErr) {
            cout << "[yjx] AudioQueueAllocateBuffer - " << ret << endl;
            return;
        }
    }

    if (player->m_config.needPullData) { //向外拉数据
//        player->m_pullDataBlk([&](AudioBufferList * _Nonnull bufferList) {
//            if (bufferList) {
//                UInt32 dataSize = bufferList->mBuffers[0].mDataByteSize;
//                memcpy(inBuffer->mAudioData, bufferList->mBuffers[0].mData, dataSize);
//                inBuffer->mAudioDataByteSize = dataSize;
//                ret = AudioQueueEnqueueBuffer(player->m_audioQueue, inBuffer, 0, NULL);
//            } else {
//                memset(inBuffer->mAudioData, 0, kMaxByteSize);
//                inBuffer->mAudioDataByteSize = kMaxByteSize;
//                ret = AudioQueueEnqueueBuffer(player->m_audioQueue, inBuffer, 0, NULL);
//            }
//        });
    } else { //使用内部缓存
        AudioBufferList *bufferList = player->m_bufferList;
        [MMBufferUtils resetAudioBufferList:bufferList];
        
        std::list<shared_ptr<MMSampleData>> audiobufferQ = player->m_audioQ; //会执行拷贝
        if (!audiobufferQ.empty()) {
            std::unique_lock<std::mutex> lock(player->m_mutex);
            
            shared_ptr<MMSampleData> data = audiobufferQ.back();
            //audiobufferQ.pop_back(); //修改audiobufferQ，不会影响player->m_audioQ
            player->m_audioQ.pop_back();
            
            CMSampleBufferRef sampleBuffer = data->audioSample;
            UInt32 samples = (UInt32)CMSampleBufferGetNumSamples(sampleBuffer);
            bufferList->mBuffers[0].mDataByteSize = samples * MMBufferUtils.asbd.mBytesPerFrame;
            CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, 0, samples, bufferList);
            player->m_cond.notify_one();
            
            cout << "[yjx] consume audio samples: " << (int)CMSampleBufferGetNumSamples(sampleBuffer)
                 << ", pts: " << data->pts
                 << ", queue size: " << (int)audiobufferQ.size()
                 << endl;
        }

        if (bufferList) {
            UInt32 dataSize = bufferList->mBuffers[0].mDataByteSize;
            memcpy(inBuffer->mAudioData, bufferList->mBuffers[0].mData, dataSize);
            inBuffer->mAudioDataByteSize = dataSize;
            ret = AudioQueueEnqueueBuffer(player->m_audioQueue, inBuffer, 0, NULL);
            if (ret != noErr) {
                cout << "[yjx] AudioQueueEnqueueBuffer - " << ret << endl;
            }
        }
    }
}

MMAudioPlayer::MMAudioPlayer(MMAudioPlayConfig config): m_config(config) {
    m_bufferList = [MMBufferUtils produceAudioBufferList:MMBufferUtils.asbd
                                           numberFrames:kBufferListSize];
    _initAudioQueue();
}

void MMAudioPlayer::process(std::shared_ptr<MMSampleData> &data) {
    if (data->isEof) return;
    if (!data->audioSample) {
        return;
    }
    CFRetain(data->audioSample);

    std::unique_lock<std::mutex> lock(m_mutex);
    m_cond.wait(lock, [this] {
        return m_audioQ.size() <= kMaxAudioCache;
    });
    m_audioQ.push_back(data);
    cout << "[yjx] receive audio samples: " << (UInt32)CMSampleBufferGetNumSamples(data->audioSample)
         << ", pts: " << data->pts
         << ", size: " << (int)m_audioQ.size()
         <<  endl;
}

void MMAudioPlayer::play() {
    doTask(MMTaskSync, ^{
        AudioQueueReset(m_audioQueue);
        
        m_audioBufferArr = (AudioQueueBufferRef *)calloc(kBufferCount, sizeof(AudioQueueBufferRef));
        for (int i = 0; i < kBufferCount; i++) {
            if (!m_audioBufferArr[i] || !m_audioBufferArr[i]->mAudioData) {
                AudioQueueAllocateBuffer(m_audioQueue, kMaxByteSize, &m_audioBufferArr[i]);
            }
            MMAudioQueuePullData((void *)this, m_audioQueue, m_audioBufferArr[i]);
        }
        
        isSytemPull = true;
        
        if (m_audioQueue) {
            OSStatus ret = AudioQueueStart(m_audioQueue, NULL);
            cout << "[yjx] AudioQueueStart - " << ret << endl;
        }
    });
}

void MMAudioPlayer::pause() {
    doTask(MMTaskSync, ^{
        if (m_audioQueue) {
            OSStatus ret = AudioQueuePause(m_audioQueue);
            cout << "[yjx] AudioQueuePause - " << ret << endl;
        }
    });
}

void MMAudioPlayer::stop() {
    doTask(MMTaskSync, ^{
        if (m_audioQueue) {
            OSStatus ret = AudioQueueStop(m_audioQueue, YES);
            cout << "[yjx] AudioQueueStop - " << ret << endl;
        }
    });
}

void MMAudioPlayer::flush() {
    doTask(MMTaskSync, ^{
        if (m_audioQueue) {
            OSStatus ret = AudioQueueFlush(m_audioQueue);
            cout << "[yjx] AudioQueueFlush - " << ret << endl;
        }
    });
}

MMAudioPlayer::~MMAudioPlayer() {
    if (m_audioQueue) {
        AudioQueueStop(m_audioQueue, true);
        AudioQueueDispose(m_audioQueue, true);
        m_audioQueue = nil;
    }
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
        m_audioQueue = nil;
        return;
    }
    cout << "[yjx] AudioQueueNewOutput - " << ret << endl;
    ret = AudioQueueAddPropertyListener(m_audioQueue,
                                        kAudioQueueProperty_IsRunning,
                                        MMAudioQueuePropertyCallback,
                                        (void *)(this));
}
