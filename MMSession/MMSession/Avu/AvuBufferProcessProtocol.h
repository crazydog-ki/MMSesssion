#import <Foundation/Foundation.h>
#import "AvuConfig.h"
#import "AvuBuffer.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, AvuDecodeErrorType) {
    AvuDecodeErrorType_Parse  = 1 << 0,
    AvuDecodeErrorType_Decode = 1 << 1,
};

//NSString *const AVUU_DECODE = @"avu_decode";
//NSString *const AVU_ENCODE = @"avu_encode";

typedef void (^AvuDecodeEndCallback)(void);
typedef void (^AvuDecodeErrorCallback)(AvuDecodeErrorType, NSError *);
typedef void (^AvuDecodeErrorCallback)(AvuDecodeErrorType, NSError *);
typedef void (^AvuParseErrorCallback)(AvuDecodeErrorType, NSError *);

typedef void (^AvuCompleteHandle)(NSURL *_Nullable fileUrl, NSError *_Nullable error);

@protocol AvuBufferProcessProtocol <NSObject>
- (instancetype)initWithConfig:(AvuConfig *)config;
- (void)processBuffer:(AvuBuffer *)buffer;
@optional
- (void)addNextNode:(id<AvuBufferProcessProtocol>)node;
- (void)updateConfig:(AvuConfig *)config;
@end

NS_ASSUME_NONNULL_END
