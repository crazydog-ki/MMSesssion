>为什么要取"MMSession"这个名字？其中"MM"是Multi-Media的简称，代表该库主要功能是音视频处理，"Session"借用Apple的命名规则，譬如：AVCaptureSession、NSURLSession等。
>该库目前主要for iOS。

# 仓库简介
采用`OC++混编`，基础技术栈如下：
1. `FFmpeg解封装`、`VT解码`、`OpenGL ES上屏`、`AudioQueueRef播放`
2. 生产者消费者模式

# 开发roadmap：
1. 2023.08.24 
    1. `ffmpeg解封装` + `vt解码` + `open gl渲染`上屏链路打通
2. 2023.08.27 
    1. vt解码附带信息crash问题fix
    2. `AvCc&AnnexB`格式探测
    3. `带B帧`视频`生产者消费者`driveUnit编写（unique_lock+condition_variable）
    4. unitBase支持外部指定处理队列
3. 2023.09.06
    1. audio基于`ffmpeg解封装&解码`、`AudioQueueRef播放`（`推模式`）链路打通
    2. 优化目录结构
