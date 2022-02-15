#import "AvuEncodeUnit.h"
#import "AvuVTEncoder.h"
#import "AvuWriterEncoder.h"

@interface AvuEncodeUnit()
@property (nonatomic, strong) AvuConfig *config;
@property (nonatomic, strong) dispatch_queue_t encodeQueue;
@property (nonatomic, strong) AvuVTEncoder *vtEncoder;
@property (nonatomic, strong) AvuWriterEncoder *avuWriter;
@end

@implementation AvuEncodeUnit
#pragma mark - Public
- (instancetype)initWithConfig:(AvuConfig *)config {
    if (self = [super init]) {
        _config = config;
        _encodeQueue = dispatch_queue_create("avu_encode_queue", DISPATCH_QUEUE_SERIAL);
        [self _initEncodeChain];
    }
    return self;
}

- (void)encode:(AvuBuffer *)buffer {
    dispatch_sync(self.encodeQueue, ^{
        if (buffer.type == AvuBufferType_Video) {
            [self.vtEncoder processBuffer:buffer];
        } else if (buffer.type == AvuType_Audio) {
            [self.avuWriter processBuffer:buffer];
        }
    });
}

- (void)cancelEncode {
    dispatch_sync(self.encodeQueue, ^{
        [self.avuWriter cancelEncode];
    });
}

- (void)stopEncode:(AvuEncodeCompleteHandle)handler {
    dispatch_sync(self.encodeQueue, ^{
        [self.avuWriter stopEncodeWithCompleteHandle:^(NSURL * _Nullable fileUrl, NSError * _Nullable error) {
            handler(fileUrl, error);
        }];
    });
}

- (void)dealloc {
    if (self.vtEncoder) {
        [self.vtEncoder cleanupSession];
        self.vtEncoder = nil;
    }
    
    if (self.avuWriter) {
        self.avuWriter = nil;
    }
}

#pragma mark - Private
- (void)_initEncodeChain {
    AvuConfig *config = _config;
    self.vtEncoder = [[AvuVTEncoder alloc] initWithConfig:config];
    self.avuWriter = [[AvuWriterEncoder alloc] initWithConfig:config];
    
    [self.vtEncoder addNextNode:self.avuWriter];
    
    [self.avuWriter startEncode];
}
@end
