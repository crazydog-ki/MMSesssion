// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMDriveUnit.h"
#define REFRENECE_COUNT 5

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
    m_dataQ.push_back(data);
    m_dataQ.sort([](std::shared_ptr<MMSampleData> v1, std::shared_ptr<MMSampleData> v2) {
        return v1->pts >= v2->pts; //降序
    });
    
    cout << "[yjx] data queue pts - " << endl;
    for (auto iter = m_dataQ.begin(); iter != m_dataQ.end(); iter++) {
        cout << (*iter)->pts << "-";
    }
    cout << endl;
    
    m_con.notify_one();
}

MMDriveUnit::~MMDriveUnit() {
    cout << "[yjx] MMDriveUnit::~MMDriveUnit()" << endl;
}

void MMDriveUnit::_consume() {
    while (true) {
        std::unique_lock<std::mutex> lock(m_mutex);
        m_con.wait(lock, [this] {
            return REFRENECE_COUNT <= m_dataQ.size() || m_reachEof;
        });
        
        if (m_dataQ.empty() && m_reachEof) break;
        
        if (!m_dataQ.empty()) {
            std::shared_ptr<MMSampleData> data = m_dataQ.back();
            m_dataQ.pop_back();
            if (!m_nextVideoUnits.empty()) {
                for (std::shared_ptr<MMUnitBase> unit : m_nextVideoUnits) {
                    cout << "[yjx] consume pts - " << data->pts << endl;
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

