# MMSession
>为什么要取"MMSession"这个名字？其中"MM"是Multi-Media的简称，代表该库主要功能是音视频处理，"Session"借用Apple的命名规则，例如：AVCaptureSession、NSURLSession等。

目前规划的功能包括如下，未来可能在此基础上继续扩充：
1. 音视频采集、录制
2. 基于AVFoundation、VideoToolBox、AudioToolBox、FFmpeg等实现音视频封装/解封装、编/解码
3. 基于OpenGL ES渲染上屏
4. 音视频多轨
5. 音视频特效

目前还是在Demo开发阶段，已支持的能力有：
1. 相机采集到OpenGL ES上屏（支持YUV与RGBA）
2. 相机录制基于AVAssetWriter写文件
3. 基于AssetReader实现音视频解封装/解码，并利用OpenGL ES实现视频帧上屏、利用Audio Queue实现音频帧播放，以音频时间戳为基准，实现音视频同步
4. 基于FFmpeg实现音视频的解封装/解码，并利用OpenGL ES实现视频帧上屏、利用Audio Queue实现音频帧播放，以音频时间戳为基准，实现音视频同步；实现seek功能；实现编码写文件
5. 打通音视频流进阶处理链路：
Demux(FFmpeg) -> Decode(FFmpeg) -> Render(OpenGL ES)
                                -> Encode(VideoToolBox) -> Mux(AVAssetWriter)

Demux(FFmpeg) -> Decode(FFmpeg) -> Render(AudioQueueRef)
                                -> Encode & Mux(AVAssetWriter)
                              
后续会对Demo进行详细全面的归纳总结，以第三方库的形式给出
