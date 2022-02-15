#import <Foundation/Foundation.h>
#import "AvuConfig.h"
#import "AvuBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuEncodeUnit : NSObject
- (instancetype)initWithConfig:(AvuConfig *)config;
- (void)encode:(AvuBuffer *)buffer;

typedef void (^AvuEncodeCompleteHandle)(NSURL *_Nullable fileUrl, NSError *_Nullable error);
- (void)cancelEncode;
- (void)stopEncode:(AvuEncodeCompleteHandle)handler;
@end

NS_ASSUME_NONNULL_END
