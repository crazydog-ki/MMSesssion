# MMSesssion
>为什么要取"MMSession"这个名字？其中"MM"是Multi-Media的简称，代表该库主要功能是音视频处理，"Session"借用Apple的命名规则，例如：AVCaptureSession、NSURLSession等。

目前还是在Demo开发阶段，已支持的能力有：
1. 相机采集到OpenGL ES上屏（支持YUV与RGBA）
2. 相机录制基于AVAssetWriter写文件
3. 基于AssetReader实现音视频解码，并利用OpenGL ES实现视频帧上屏、利用Audio Queu实现音频帧播放

后续会对Demo进行详细全面的归纳总结，以第三方库的形式给出
