#import "AvuBufferQueue.h"

@interface AvuBufferQueue ()
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, assign) NSInteger maxCacheNum;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;

@property (nonatomic, strong) NSMutableArray<AvuBuffer *> *bufferQueue;
@property (nonatomic, assign) double seekTime;
@end

@implementation AvuBufferQueue
#pragma mark - AvuBufferProcessProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _maxCacheNum = 5;
        _cacheQueue = dispatch_queue_create("avu_video_cache", DISPATCH_QUEUE_SERIAL);
        _bufferQueue = [NSMutableArray array];
    }
    return self;
}

- (void)processBuffer:(AvuBuffer *)buffer {
    if (!buffer) return;
    double startTime = _config.clipRange.startTime;
    double endTime = _config.clipRange.endTime;
    if (buffer.pts < startTime) {
        return;
    }
    
    if (endTime-1 < buffer.pts) {
        if (self.bufferEndCallback) {
            self.bufferEndCallback();
        }
        return;
    }

    dispatch_sync(self.cacheQueue, ^{
        if (buffer.pts < self.seekTime) {
            return;
        }
        [self.bufferQueue addObject:buffer];
    });
}

- (void)updateConfig:(AvuConfig *)config {
    _config = config;
}

#pragma mark - Public
- (BOOL)exceedMax {
    return _maxCacheNum <= self.bufferQueue.count;
}

- (int)size {
    return (int)_bufferQueue.count;
}

- (void)flush {
    dispatch_sync(self.cacheQueue, ^{
        [self.bufferQueue removeAllObjects];
    });
}

- (AvuBuffer *)dequeue {
    __block AvuBuffer *buffer = nil;
    dispatch_sync(self.cacheQueue, ^{
        if (0 < self.bufferQueue.count) {
            buffer = self.bufferQueue.firstObject;
            for (AvuBuffer *obj in self.bufferQueue) {
                if (obj.pts < buffer.pts) {
                    buffer = obj;
                }
            }
            [self.bufferQueue removeObject:buffer];
        }
    });
    return buffer;
}

- (AvuBuffer *)requestBufferAtTime:(double)time {
    double startTime = _config.clipRange.startTime;
    double endTime = _config.clipRange.endTime;
    if (time < startTime || endTime < time) return nil;
    
    __block AvuBuffer *buffer = nil;
    dispatch_sync(self.cacheQueue, ^{
        /// 1. 获取缓存的最小及最大时间戳，处理特殊case
        double firstPts = self.bufferQueue.firstObject.pts;
        double minTime = firstPts, maxTime = firstPts;
        for (AvuBuffer *obj in self.bufferQueue) {
            if (obj.pts < minTime) minTime = obj.pts;
            if (maxTime < obj.pts) maxTime = obj.pts;
        }
        if (time < minTime) return;
        if (maxTime < time) {
            [self.bufferQueue removeAllObjects];
            return;
        }
        /// 2. 取出缓存中最近的帧
        double delta = MAXFLOAT;
        if (0 < self.bufferQueue.count) {
            for (AvuBuffer *obj in self.bufferQueue) {
                if (fabs(obj.pts-time) < delta) {
                    delta = fabs(obj.pts-time);
                    buffer = obj;
                }
            }
        }
        /// 3. 之前的帧全部移除
        NSMutableArray *tmpArr = [NSMutableArray array];
        for (AvuBuffer *obj in self.bufferQueue) {
            if (obj.pts <= buffer.pts) {
                [tmpArr addObject:obj];
            }
        }
        [self.bufferQueue removeObjectsInArray:tmpArr];
    });
    return buffer;
}

- (void)configSeekTime:(double)seekTime {
    self.seekTime = seekTime;
}
@end

