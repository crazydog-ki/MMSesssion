>为什么要取"MMSession"这个名字？其中"MM"是Multi-Media的简称，代表该库主要功能是音视频处理，"Session"借用Apple的命名规则，譬如：AVCaptureSession、NSURLSession等。
>该库目前主要for iOS。

# 仓库简介
采用`OC++混编`，基础技术栈如下：
1. 音视频播放、生产者&消费者驱动；
    视频：`FFmpeg解封装` --> `VT解码`     --> `生产消费驱动` --> `OpenGLES渲染`
    音频：`FFmpeg解封装` --> `FFmpeg解码` --> `AudioQueueRef播放`
2. H264/H264（B帧）支持；
