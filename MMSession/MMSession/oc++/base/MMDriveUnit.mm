// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMDriveUnit.h"

MMDriveUnit::MMDriveUnit() {
    m_driveQueue = CREATE_SERIAL_QUEUE;
    doTask(MMTaskAsync, ^{
        _consume();
    }, m_driveQueue);
}

void MMDriveUnit::process(std::shared_ptr<MMSampleData> &data) {
    if (data->isEof) {
        m_reachEof = true;
        m_con.notify_one();
        return;
    }
    std::unique_lock<std::mutex> lock(m_mutex);
    CVPixelBufferRetain(data->videoBuffer);
    m_dataQueue.push_back(data);
    m_dataQueue.sort([](std::shared_ptr<MMSampleData> v1, std::shared_ptr<MMSampleData> v2) {
        return v1->pts >= v2->pts; //按pts降序
    });
    
    m_con.notify_one();
}

void MMDriveUnit::destroy() {
    MMUnitBase::destroy();
    m_reachEof = true;
    m_dataQueue.clear();
}

MMDriveUnit::~MMDriveUnit() {
}

int MMDriveUnit::getCacheCount() {
    std::unique_lock<std::mutex> lock(m_mutex);
    return (int)m_dataQueue.size();
}

void MMDriveUnit::_consume() {
    while (true) {
        std::unique_lock<std::mutex> lock(m_mutex);
        m_con.wait(lock, [this] {
            return REFRENECE_COUNT <= m_dataQueue.size() || m_reachEof; //队列长度大于5才消费，兼容hevc
        });
        
        if (m_dataQueue.empty() && m_reachEof) break;
        
        if (!m_dataQueue.empty()) {
            std::shared_ptr<MMSampleData> data = m_dataQueue.back();
            m_dataQueue.pop_back();
            if (!m_nextVideoUnits.empty()) {
                for (std::shared_ptr<MMUnitBase> unit : m_nextVideoUnits) {
                    unit->process(data);
                }
            }
            if (data->videoBuffer) {
                CVPixelBufferRelease(data->videoBuffer);
                data->videoBuffer = nullptr;//这里不置空，MMSampleData析构函数内部可能会double free
            }
        }
    }
}

