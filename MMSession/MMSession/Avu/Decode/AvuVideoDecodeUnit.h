#import <Foundation/Foundation.h>
#import "AvuDecodeUnitProtocol.h"
#import "AvuBufferProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AvuVideoDecodeUnit : NSObject <AvuDecodeUnitProtocol>
@property (nonatomic, strong) AvuDecodeEndCallback decodeEndCallback;
@property (nonatomic, strong) AvuDecodeErrorCallback decodeErrorCallback;
@property (nonatomic, strong) AvuConfig *config;
@end

NS_ASSUME_NONNULL_END
