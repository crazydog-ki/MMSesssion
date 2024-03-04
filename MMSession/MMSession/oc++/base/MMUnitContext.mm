// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMUnitContext.h"

void MMUnitContext::post(MMMsg &msg) {
    switch (msg.msgID) {
        case MMMsg_VideoRenderFinished:
            if (m_videoRenderFinishedBlk) {
                m_videoRenderFinishedBlk();
            }
            break;
        case MMMsg_AudioNeedBuffer:
            if (m_audioNeedBufferBlk) {
                m_audioNeedBufferBlk();
            }
            break;
        case MMMsg_AudioPlayEnd:
            if (m_audioPlayEndBlk) {
                m_audioPlayEndBlk();
            }
        default:
            break;
    }
}

void MMUnitContext::setVideoRenderFinishedBlk(const MMVideoRenderFinishedBlk &blk) {
    m_videoRenderFinishedBlk = blk;
}

void MMUnitContext::setAudioNeedBufferBlk(const MMAudioNeedBufferBlk &blk) {
    m_audioNeedBufferBlk = blk;
}

void MMUnitContext::setAudioPlayEndBlk(const MMAudioPlayEndBlk &blk) {
    m_audioPlayEndBlk = blk;
}
