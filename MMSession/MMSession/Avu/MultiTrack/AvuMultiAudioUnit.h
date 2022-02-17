#import <Foundation/Foundation.h>
#import "AvuConfig.h"

NS_ASSUME_NONNULL_BEGIN
@interface AvuMultiAudioUnit : NSObject
- (instancetype)initWithConfig:(AvuConfig *)config;
- (void)start;
@end

NS_ASSUME_NONNULL_END
