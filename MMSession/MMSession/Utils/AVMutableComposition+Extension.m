// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "AVMutableComposition+Extension.h"
#import "AVAsset+Extension.h"

static const int32_t kCMTrackID_Video = 1;
static const int32_t kCMTrackID_Audio = 2;

@implementation AVMutableComposition (Concat)

- (void)concatVideo:(AVAsset *)videoAsset
          timeRange:(CMTimeRange)timeRange {
    /// 视频轨
    AVMutableCompositionTrack *videoTracks = [self _videoTracks];
    if (!videoTracks) {
        videoTracks = [self addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMTrackID_Video];
    }
    
    CMTime atTime = kCMTimeZero;
    if (0 < videoTracks.segments.count) {
        atTime = CMTimeAdd(videoTracks.timeRange.start, videoTracks.timeRange.duration);
    }
    
    AVAssetTrack *videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    
    NSError *error;
    [videoTracks insertTimeRange:timeRange ofTrack:videoTrack atTime:atTime error:&error];
    
    /// 音频轨
    AVMutableCompositionTrack *audioTracks = [self _audioTracks];
    if (!audioTracks) {
        audioTracks = [self addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMTrackID_Audio];
    }
    
    AVAssetTrack *audioTrack = [videoAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    [audioTracks insertTimeRange:timeRange ofTrack:audioTrack atTime:atTime error:&error];
}

#pragma mark - Private
- (AVMutableCompositionTrack *)_videoTracks {
    return [self trackWithTrackID:kCMTrackID_Video];
}

- (AVMutableCompositionTrack *)_audioTracks {
    return [self trackWithTrackID:kCMTrackID_Audio];
}

@end

