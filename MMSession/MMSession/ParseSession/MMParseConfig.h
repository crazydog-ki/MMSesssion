// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MMFFParseType) {
    MMFFParseType_Video = 1,
    MMFFParseType_Audio = 2
};

@interface MMParseConfig : NSObject
@property (nonatomic, strong) NSString *inPath;
@property (nonatomic, assign) MMFFParseType parseType;
@end

NS_ASSUME_NONNULL_END
