// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMUnitBase.h"

MMUnitBase::MMUnitBase() {
    m_processQueue = dispatch_queue_create(typeid(*this).name(), DISPATCH_QUEUE_SERIAL);
}

void MMUnitBase::doTask(MMUnitTask taskExec, dispatch_block_t task) {
    if (MMTaskAsync==taskExec) {
        dispatch_async(m_processQueue, ^{
            task();
        });
    } else {
        dispatch_sync(m_processQueue, ^{
            task();
        });
    }
}

void MMUnitBase::process(std::shared_ptr<MMSampleData> &data) {
}
