#import <Foundation/Foundation.h>
#import "AvuBufferProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuWriterEncoder : NSObject <AvuBufferProcessProtocol>
typedef void (^AvuCompleteHandle)(NSURL *_Nullable fileUrl, NSError *_Nullable error);

- (void)startEncode;
- (void)cancelEncode;
- (void)stopEncodeWithCompleteHandle:(AvuCompleteHandle)handler;
@end

NS_ASSUME_NONNULL_END
