// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#include <iostream>
#include <queue>
using namespace std;

NS_ASSUME_NONNULL_BEGIN

struct MMAudioNode {
    void *data;
    int  dataSize;
};

class MMAudioQueue {
private:
    pthread_mutex_t queueLock;
    queue<MMAudioNode *> *Q;
public:
    MMAudioQueue();
    ~MMAudioQueue();
    
    void enqueue(MMAudioNode *node);
    MMAudioNode* dequeue();
    bool isFull();
};

NS_ASSUME_NONNULL_END
