// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMAssetReader.h"

@interface MMAssetReader ()

@property (nonatomic, strong) dispatch_queue_t readerQueue;
@property (nonatomic, strong) MMAssetReaderConfig *config;
@property (nonatomic, strong) AVAssetReader *assetReader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *videoOutput;
@property (nonatomic, strong) AVAssetReaderTrackOutput *audioOutput;
 
@end

@implementation MMAssetReader

- (instancetype)initWithConfig:(MMAssetReaderConfig *)config {
    if (self = [super init]) {
        _readerQueue = dispatch_queue_create("mmsession_reader_queue", DISPATCH_QUEUE_SERIAL);
        _config = config;
        [self _initReader];
    }
    return self;
}

- (BOOL)startReading {
    __block BOOL ret = NO;
    dispatch_sync(_readerQueue, ^{
        if (self.assetReader.status == AVAssetReaderStatusUnknown) {
            if ([self.assetReader startReading]) {
                NSLog(@"[yjx] start reading success");
                ret = YES;
            } else {
                NSLog(@"[yjx] start reading error");
                ret = NO;
            }
        }
    });
    return ret;
}

- (void)stopReading {
    dispatch_sync(_readerQueue, ^{
        if (self.assetReader && self.assetReader.status == AVAssetReaderStatusReading) {
            [self.assetReader cancelReading];
        }
    });
}

- (MMSampleData *)pullSampleBuffer:(MMSampleDataType)type {
    if (self.assetReader.status != AVAssetReaderStatusReading) {
        NSLog(@"[yjx] must pull buffer in readering status");
        return nil;
    }
    MMSampleData *sampleData = [[MMSampleData alloc] init];
    sampleData.bufferType = type;
    if (type == MMSampleDataTypeVideo) {
        CMSampleBufferRef sampleBuffer = [self.videoOutput copyNextSampleBuffer];
        if (sampleBuffer) {
            sampleData.flag = MMSampleDataFlagProcess;
            sampleData.sampleBuffer = sampleBuffer;
        } else {
            sampleData.flag = MMSampleDataFlagEnd;
        }
    } else if (type == MMSampleDataTypeAudio) {
        CMSampleBufferRef sampleBuffer = [self.audioOutput copyNextSampleBuffer];
        if (sampleBuffer) {
            sampleData.flag = MMSampleDataFlagProcess;
            sampleData.sampleBuffer = sampleBuffer;
        } else {
            sampleData.flag = MMSampleDataFlagEnd;
        }
    }
    return sampleData;
}

#pragma mark - Private
- (void)_initReader {
    AVAsset *videoAsset = _config.videoAsset;
    if (!videoAsset) {
        videoAsset = [AVAsset assetWithURL:_config.videoURL];
    }
    NSError *error;
    _assetReader = [AVAssetReader assetReaderWithAsset:videoAsset error:&error];
    
    // 视频轨
    AVAssetTrack *videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (videoTrack) {
        NSDictionary *videoOutputAttr = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
        AVAssetReaderTrackOutput *videoOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:videoOutputAttr];
        if ([_assetReader canAddOutput:videoOutput]) {
            [_assetReader addOutput:videoOutput];
        }
        _videoOutput = videoOutput;
    }
    
    // 音频轨
    AVAssetTrack *audioTrack = [videoAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    if (audioTrack) {
        AudioChannelLayout acl;
        bzero(&acl, sizeof(acl));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        NSData *aclVal = [NSData dataWithBytes:&acl length:sizeof(acl)];
        NSDictionary *audioOutputAttr = @{AVFormatIDKey: @(kAudioFormatLinearPCM),
                                  AVNumberOfChannelsKey: @(2),
                                        AVSampleRateKey: @(44100),
                                     AVChannelLayoutKey: aclVal};
        AVAssetReaderTrackOutput *audioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:audioOutputAttr];
        if ([_assetReader canAddOutput:audioOutput]) {
            [_assetReader addOutput:audioOutput];
        }
        _audioOutput = audioOutput;
    }
}

@end
