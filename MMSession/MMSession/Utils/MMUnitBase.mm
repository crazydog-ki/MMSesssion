// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMUnitBase.h"

MMUnitBase::MMUnitBase() {
    m_processQueue = CREATE_SERIAL_QUEUE;
}

void MMUnitBase::doTask(MMUnitTask taskExec, dispatch_block_t task, dispatch_queue_t queue) {
    if (MMTaskAsync==taskExec) {
        dispatch_async(queue ? queue: m_processQueue, ^{
            task();
        });
    } else {
        dispatch_sync(queue ? queue: m_processQueue, ^{
            task();
        });
    }
}

void MMUnitBase::process(std::shared_ptr<MMSampleData> &data) {
}
