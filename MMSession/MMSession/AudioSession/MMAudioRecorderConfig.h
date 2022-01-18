// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MMAudioFormat) {
    MMAudioFormatPCM = 1 << 0,
    MMAudioFormatAAC = 1 << 1
};

@interface MMAudioRecorderConfig : NSObject
@property (nonatomic, assign) MMAudioFormat audioFormat;
@property (nonatomic, assign) NSUInteger sampleRate;
@property (nonatomic, assign) NSUInteger channelsCount;

@property (nonatomic, strong) NSString *audioFilePath;
@end

NS_ASSUME_NONNULL_END
