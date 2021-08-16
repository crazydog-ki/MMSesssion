// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMDecodeReader.h"

@interface MMDecodeReader ()
@property (nonatomic, strong) dispatch_queue_t readerQueue;
@property (nonatomic, strong) MMDecodeConfig *config;
@property (nonatomic, strong) AVAssetReader *assetReader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *videoOutput;
@property (nonatomic, strong) AVAssetReaderTrackOutput *audioOutput;
@end

@implementation MMDecodeReader
#pragma mark - Public
- (instancetype)initWithConfig:(MMDecodeConfig *)config {
    if (self = [super init]) {
        _readerQueue = dispatch_queue_create("mmsession_reader_queue", DISPATCH_QUEUE_SERIAL);
        _config = config;
        [self _initReader];
    }
    return self;
}

- (BOOL)startDecode {
    __block BOOL ret = NO;
    dispatch_sync(_readerQueue, ^{
        if (self.assetReader.status == AVAssetReaderStatusUnknown) {
            if ([self.assetReader startReading]) {
                NSLog(@"[yjx] start decode success");
                ret = YES;
            } else {
                NSLog(@"[yjx] start decode error: %@", self.assetReader.error);
                ret = NO;
            }
        }
    });
    return ret;
}

- (void)stopDecode {
    dispatch_sync(_readerQueue, ^{
        if (self.assetReader && self.assetReader.status == AVAssetReaderStatusReading) {
            [self.assetReader cancelReading];
        }
    });
}

- (MMSampleData *)pullSampleData:(MMSampleDataType)type {
    if (self.assetReader.status != AVAssetReaderStatusReading) {
        NSLog(@"[yjx] must pull buffer in readering status");
        return nil;
    }
    MMSampleData *sampleData = [[MMSampleData alloc] init];
    if (type == MMSampleDataType_None_Video) {
        CMSampleBufferRef sampleBuffer = [self.videoOutput copyNextSampleBuffer];
        sampleData.pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        if (sampleBuffer) {
            sampleData.statusFlag = MMSampleDataFlagProcess;
            sampleData.pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            sampleData.sampleBuffer = sampleBuffer;
            sampleData.dataType = MMSampleDataType_Decoded_Video;
        } else {
            sampleData.statusFlag = MMSampleDataFlagEnd;
        }
    } else if (type == MMSampleDataType_None_Audio) {
        CMSampleBufferRef sampleBuffer = [self.audioOutput copyNextSampleBuffer];
        if (sampleBuffer) {
            sampleData.statusFlag = MMSampleDataFlagProcess;
            sampleData.pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            sampleData.dataType = MMSampleDataType_Decoded_Audio;
            sampleData.sampleBuffer = sampleBuffer;
        } else {
            sampleData.statusFlag = MMSampleDataFlagEnd;
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
    
    /// 视频轨
    AVAssetTrack *videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (videoTrack) {
        NSDictionary *videoOutputAttr = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
        AVAssetReaderTrackOutput *videoOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:videoOutputAttr];
        if ([_assetReader canAddOutput:videoOutput]) {
            [_assetReader addOutput:videoOutput];
        }
        _videoOutput = videoOutput;
    }
    
    /// 音频轨
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
