// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAudioQueue.h"

static const int kMaxCacheCount = 80;

MMAudioQueue::MMAudioQueue() {
    pthread_mutex_init(&queueLock, NULL);
    Q = new queue<MMAudioNode *>;
}

MMAudioQueue::~MMAudioQueue() {
    while (!Q->empty()) {
        MMAudioNode *node = Q->front();
        if (node->data) {
            free(node->data);
            node->data = nullptr;
        }
        Q->pop();
    }
    delete Q;
}

void MMAudioQueue::enqueue(MMAudioNode *node) {
    pthread_mutex_lock(&queueLock);
    Q->push(node);
    pthread_mutex_unlock(&queueLock);
}

MMAudioNode* MMAudioQueue::dequeue() {
    if (Q->empty()) return nullptr;
    pthread_mutex_lock(&queueLock);
    MMAudioNode *node = Q->front();
    Q->pop();
    pthread_mutex_unlock(&queueLock);
    return node;
}

bool MMAudioQueue::isFull() {
    return kMaxCacheCount < Q->size();
}

