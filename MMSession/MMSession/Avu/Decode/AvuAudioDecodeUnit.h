#import <Foundation/Foundation.h>
#import "AvuDecodeUnitProtocol.h"
#import "AvuBufferProcessProtocol.h"

NS_ASSUME_NONNULL_BEGIN
@interface AvuAudioDecodeUnit : NSObject <AvuDecodeUnitProtocol>
@property (nonatomic, strong) AvuDecodeEndCallback decodeEndCallback;
@property (nonatomic, strong) AvuDecodeErrorCallback decodeErrorCallback;
@end

NS_ASSUME_NONNULL_END
