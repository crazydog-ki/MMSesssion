>为什么要取"MMSession"这个名字？其中"MM"是Multi-Media的简称，代表该库主要功能是音视频处理，"Session"借用Apple的命名规则，譬如：AVCaptureSession、NSURLSession等。
>该库目前主要for iOS。

# 仓库简介
采用OC++混编，基础技术栈如下：
1. FFmpeg解封装、VT解码、OpenGL ES上屏；

# 开发roadmap：
1. 2023.08.24 -> ffmpeg解封装 + vt解码 + open gl渲染上屏链路打通；
2. 2023.08.27 -> vt解码附带信息crash问题fix
              -> AvCc&AnnexB格式探测
              -> 带B帧视频生产者消费者driveUnit编写（unique_lock+condition_variable）
              -> unitBase支持外部指定处理队列
