#import "AvuBufferQueue.h"

typedef struct AvuPcmQueue {
    UInt8 *data;
    UInt32 size;
} AvuPcmQueue;

static const NSInteger kMaxPcmCacheSize = 1024 * 1024;
/// 实际最大缓存
static const NSInteger kPcmCacheSize = 8192 * sizeof(float) * 2;

@interface AvuBufferQueue ()
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, assign) NSInteger maxCacheNum;
@property (nonatomic, strong) dispatch_queue_t cacheQueue;

@property (nonatomic, strong) NSMutableArray<AvuBuffer *> *convertBufferQueue;
@property (nonatomic, strong) NSMutableArray<AvuBuffer *> *bufferQueue;
@property (nonatomic, assign) AvuPcmQueue pcmQueue;

@property (nonatomic, assign) AvuSeekType seekType;
@property (nonatomic, assign) double seekTime;
@end

@implementation AvuBufferQueue
#pragma mark - AvuBufferProcessProtocol
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _maxCacheNum = 5;
        _cacheQueue = dispatch_queue_create("avu_video_cache", DISPATCH_QUEUE_SERIAL);
        _convertBufferQueue = [NSMutableArray array];
        _bufferQueue = [NSMutableArray array];
        _pcmQueue.data = (UInt8 *)calloc(kMaxPcmCacheSize, 1);
        _pcmQueue.size = 0;
        _seekType = AvuSeekType_No;
    }
    return self;
}

- (void)processBuffer:(AvuBuffer *)buffer {
    if (!buffer) return;
    
    // 音频
    if (buffer.type == AvuBufferType_Audio && buffer.bufferList) {
        AudioBufferList *bufferList = buffer.bufferList;
        UInt8 *data = bufferList->mBuffers[0].mData;
        UInt32 size = bufferList->mBuffers[0].mDataByteSize;
//        NSLog(@"[yjx] push audio buffer, data: %p, size: %d", data, size);
        [self push:data size:size];
        return;
    }

    // 视频
    double startTime = self.config.clipRange.startTime;
    double endTime = self.config.clipRange.endTime;
    if (buffer.pts < startTime || endTime < buffer.pts+buffer.duration) return; // 处理特殊case
    
    dispatch_sync(self.cacheQueue, ^{
        [self.convertBufferQueue addObject:buffer];
        [self.convertBufferQueue sortUsingComparator:^NSComparisonResult(AvuBuffer *  _Nonnull obj1, AvuBuffer *  _Nonnull obj2) {
            return obj1.pts > obj2.pts;
        }];
        
        int count = (int)self.convertBufferQueue.count;
        
        if (5 < count) {
            AvuBuffer *firstBuffer = self.convertBufferQueue.firstObject;
            [self.bufferQueue addObject:firstBuffer];
            // 排序
            [self.bufferQueue sortUsingComparator:^NSComparisonResult(AvuBuffer *  _Nonnull obj1, AvuBuffer *  _Nonnull obj2) {
                return obj1.pts > obj2.pts;
            }];
            [self.convertBufferQueue removeObjectAtIndex:0];
        }
    });
}

- (void)updateConfig:(AvuConfig *)config {
    _config = config;
}

#pragma mark - Public
- (void)dealloc {
    if (_pcmQueue.data) {
        free(_pcmQueue.data);
        _pcmQueue.data = nil;
        _pcmQueue.size = 0;
    }
}

- (int)size {
    return (int)_bufferQueue.count;
}

- (BOOL)exceedMax {
    BOOL isExceed = (_config.type==AvuType_Video && _maxCacheNum <= self.bufferQueue.count) ||
                    (_config.type==AvuType_Audio && kPcmCacheSize < self.pcmQueue.size);
    return isExceed;
}

- (void)configSeekTime:(double)seekTime {
    self.seekTime = seekTime;
}

- (void)flush {
    dispatch_sync(self.cacheQueue, ^{
        [self.bufferQueue removeAllObjects];
    });
}

- (BOOL)isHitCacheAt:(double)time {
    __block BOOL isHit = NO;
    dispatch_sync(self.cacheQueue, ^{
        AvuBuffer *startBuffer = self.bufferQueue.firstObject;
        AvuBuffer *endBuffer = self.bufferQueue.lastObject;
        double minTime = startBuffer.pts;
        double maxTime = endBuffer.pts+endBuffer.duration;
        isHit = minTime<=time && time<=maxTime;
    });
    return isHit;
}

- (AvuSeekType)getSeekTypeAt:(double)time {
    __block AvuSeekType seekType = AvuSeekType_No;
    dispatch_sync(self.cacheQueue, ^{
        AvuBuffer *startBuffer = self.bufferQueue.firstObject;
        AvuBuffer *endBuffer = self.bufferQueue.lastObject;
        double minTime = startBuffer.pts;
        double maxTime = endBuffer.pts+endBuffer.duration;
        
        if (time < minTime) {
            seekType = AvuSeekType_Back;
        } else if (maxTime < time) {
            seekType = AvuSeekType_No; // time和maxTime在同一个gop
            seekType = AvuSeekType_Forward; // time和maxTime不在同一个gop
        }
    });
    return seekType;
}

- (AvuBuffer *)requestVideoBufferAtTime:(double)time {
    double startTime = _config.clipRange.startTime;
    double endTime = _config.clipRange.endTime;
    if (time < startTime || endTime < time) return nil;
    
    __block AvuBuffer *buffer = nil;
    dispatch_sync(self.cacheQueue, ^{
        /// 1. 不在缓存范围内
        if (self.bufferQueue.count < 1) return;
        
        AvuBuffer *startBuffer = self.bufferQueue.firstObject;
        AvuBuffer *endBuffer = self.bufferQueue.lastObject;
//        NSMutableString *str = [NSMutableString string];
//        for (int i = 0; i < self.bufferQueue.count; i++) {
//            [str appendFormat:@"%lf", self.bufferQueue[i].pts];
//            [str appendString:@", "];
//        }
//        NSLog(@"[yjx] pts: %@", str);
        
        double minTime = startBuffer.pts;
        double maxTime = endBuffer.pts+endBuffer.duration;
        
        if (time < minTime) { // 逆向seek
            buffer = startBuffer;
            _seekType = AvuSeekType_Back;
            // 只保留第一帧
            int count = (int)self.bufferQueue.count-1;
            while (--count && 0<count) {
                [self.bufferQueue removeLastObject];
            }
            return;
        }
        
        if (maxTime < time) { // 可能需要正向seek，需要判断是否在同一个gop里面
            buffer = endBuffer;
            _seekType = AvuSeekType_Forward;
            // 只保留最后一帧
            int count = (int)self.bufferQueue.count-1;
            if (count == -1 || count == 0) return; // 缓存队列为空，或者只有1个，直接返回
            while (--count) { 
                [self.bufferQueue removeObjectAtIndex:0];
            }
//            NSLog(@"[yjx] need forward seek, maxTime: %lf, time: %lf", maxTime, time);
            return;
        }
        
        /// 2. 在缓存范围内
        int index = 0;
        for (AvuBuffer *tmp in self.bufferQueue) {
            // 精准命中
            if (tmp.pts<=time && time<=tmp.pts+tmp.duration) {
                buffer = tmp;
//                NSLog(@"[yjx] hit time: %lf", tmp.pts);
                break;
            }
            index++;
        }
        if (buffer) {
            [self.bufferQueue removeObjectAtIndex:index];
            return;
        }
    });
    return buffer;
}

- (AvuBuffer *)requestAudioBufferAtTime:(double)time {
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
        if (time < minTime && 0.1<fabs(time-minTime)) {
            return;
        }
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

- (void)push:(UInt8 *)data size:(UInt32)size {
    dispatch_sync(self.cacheQueue, ^{
        memcpy(_pcmQueue.data+_pcmQueue.size, data, size);
        _pcmQueue.size += size;
    });
}

- (void)pop:(UInt8 *)data offset:(UInt32)offset size:(UInt32)size {
    dispatch_sync(self.cacheQueue, ^{
        if (_pcmQueue.size < size) {
            NSLog(@"[avu] pcm queue is full");
            return;
        }
        memcpy(data+offset, _pcmQueue.data, size);
        UInt32 leftSize = _pcmQueue.size-size;
        memmove(_pcmQueue.data, _pcmQueue.data+size, leftSize);
        _pcmQueue.size = leftSize;
    });
}
@end

