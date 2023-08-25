// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#ifndef MMUnitBase_hpp
#define MMUnitBase_hpp

#include <iostream>
#include <list>
#include "MMSampleData.h"
using namespace::std;

typedef NS_OPTIONS(NSUInteger, MMUnitTask) {
    MMTaskAsync = 1 << 0,
    MMTaskSync = 1 << 1
};

class MMUnitBase {
public:
    MMUnitBase();
    void addNextVideoNode(const shared_ptr<MMUnitBase> &node) {
        doTask(MMTaskSync, ^{
            m_nextVideoUnits.push_back(node);
        });
    }
    void addNextAudioNode(const shared_ptr<MMUnitBase> &node) {
        doTask(MMTaskSync, ^{
            m_nextAudioUnits.push_back(node);
        });
    }
    
    void doTask(MMUnitTask taskExec, dispatch_block_t task);
    
    virtual void process(std::shared_ptr<MMSampleData> &data);
    
    std::list<shared_ptr<MMUnitBase>> m_nextVideoUnits;
    std::list<shared_ptr<MMUnitBase>> m_nextAudioUnits;
private:
    dispatch_queue_t m_processQueue;
};

#endif /* MMUnitBase_hpp */