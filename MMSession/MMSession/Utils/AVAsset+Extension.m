//
//  AVAsset+Extension.m
//  MMSession
//
//  Created by bytedance on 2021/8/3.
//

#import "AVAsset+Extension.h"

@implementation AVAsset (Extension)

- (double)rotation {
    double rotation = 0;
    NSArray *tracks = [self tracksWithMediaType:AVMediaTypeVideo];
    if ([tracks count] > 0) {
        AVAssetTrack *videoTrack = tracks.firstObject;
        CGAffineTransform t = videoTrack.preferredTransform;
        
        if (t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0){
            /// Portrait
            rotation = M_PI_2;
        } else if (t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0){
            /// PortraitUpsideDown
            rotation = M_PI_2 * 3;
        } else if (t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0){
            /// LandscapeRight
            rotation = 0;
        } else if (t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0){
            /// LandscapeLeft
            rotation = M_PI;
        }
    }
    return rotation;
}

@end
