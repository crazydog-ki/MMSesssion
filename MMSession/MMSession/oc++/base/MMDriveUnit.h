// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMUnitBase.h"
#include <condition_variable>
#include <list>

class MMDriveUnit: public MMUnitBase {
public:
    MMDriveUnit();
    ~MMDriveUnit();
    void process(std::shared_ptr<MMSampleData> &data) override;
    void destroy() override;
    int getCacheCount();
private:
    std::condition_variable m_con;
    std::mutex m_mutex;
    std::list<shared_ptr<MMSampleData>> m_dataQueue;
    dispatch_queue_t m_driveQueue;
    bool m_reachEof = false;
    
    void _consume();
};
