#import <Foundation/Foundation.h>
#import "AvuBufferProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuVideoEncodeAttr : NSObject
@property (nonatomic, assign) double pts;
@property (nonatomic, assign) double dts;
@property (nonatomic, assign) double duration;
@end

@interface AvuVTEncoder : NSObject <AvuBufferProcessProtocol>
- (void)cleanupSession;
@end

NS_ASSUME_NONNULL_END
