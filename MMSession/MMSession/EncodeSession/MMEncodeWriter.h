// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>
#import "MMSessionProcessProtocol.h"
#import "MMEncodeConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMEncodeWriter : NSObject<MMSessionProcessProtocol>
typedef void (^CompleteHandle)(NSURL *_Nullable fileUrl, NSError *_Nullable error);
- (instancetype)initWithConfig:(MMEncodeConfig *)config;
- (void)startEncode;
- (void)stopEncodeWithCompleteHandle:(CompleteHandle)handler;

typedef void(^WriterEndEncodeBlock)(void);
@property (nonatomic, strong) WriterEndEncodeBlock endEncodeBlk;
@end

NS_ASSUME_NONNULL_END
