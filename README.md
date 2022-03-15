>为什么要取"MMSession"这个名字？其中"MM"是Multi-Media的简称，代表该库主要功能是音视频处理，"Session"借用Apple的命名规则，譬如：AVCaptureSession、NSURLSession等。

# 仓库简介
目前规划的功能包括如下，未来可能在此基础上继续扩充：
1. 音视频采集、录制（待丰富相机各项操作）；
2. 基于AVFoundation、VideoToolBox、AudioToolBox、FFmpeg等实现音视频封装/解封装、编/解码；
3. 基于OpenGL ES渲染上屏；
4. 音视频多轨画中画上屏；
5. 音视频帧支持特效渲染（待支持各种shader特效添加）；

目前还是在Demo开发阶段，已支持的能力有：
1. 相机采集到OpenGL ES上屏（支持YUV与RGBA）；
2. 相机录制基于AVAssetWriter写文件；
3. 基于AssetReader实现音视频解封装/解码，并利用OpenGL ES实现视频帧上屏、利用Audio Queue实现音频帧播放，以音频时间戳为基准，实现音视频同步；
4. 基于FFmpeg实现音视频的解封装/解码，并利用OpenGL ES实现视频帧上屏、利用Audio Queue实现音频帧播放，以音频时间戳为基准，实现音视频同步；实现seek功能；实现编码写文件等等；
5. 基于FFmpeg实现音视频的解封装，利用VideoToolBox实现视频解码、FFmpeg实现音频解码，并利用OpenGL ES实现视频帧上屏、Audio Queue实现音频帧播放，以音频时间戳为基准，实现音视频同步；实现seek功能；实现编码写文件等等。打通音视频流进阶处理链路，细节处待完善：
6. 支持音视频多轨、画中画上屏（待优化）；
```
视频处理链路
* 渲染方案1：Demux(FFmpeg) -> Decode(FFmpeg) -> Render(OpenGL ES)
* 渲染方案2：Demux(FFmpeg) -> Decode(VideoToolBox) -> Render(OpenGL ES)

* 合成方案1：Demux(FFmpeg) -> Decode(FFmpeg) -> Encode(VideoToolBox) -> Mux(AVAssetWriter)
* 合成方案2：Demux(FFmpeg) -> Decode(VideoToolBox) -> Encode(VideoToolBox) -> Mux(AVAssetWriter)
```

```
音频处理链路
* 渲染：Demux(FFmpeg) -> Decode(FFmpeg) -> Render(AudioQueueRef)
* 合成：Demux(FFmpeg) -> Decode(FFmpeg) -> Encode & Mux(AVAssetWriter)
```
