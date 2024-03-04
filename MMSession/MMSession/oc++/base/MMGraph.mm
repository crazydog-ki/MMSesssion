// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMGraph.h"

MMGraph::MMGraph(MMGraphConfig config) {
    m_config = config;
    _buildUnitsConn();
    _configSharedCtx();
    m_videoDriveCmd = [&](shared_ptr<MMSampleData> data) {
        if (m_stopFlag) return;
        if (m_ffVideoParser) {
            m_ffVideoParser->process(data);
        }
    };
    
    m_audioDriveCmd = [&](shared_ptr<MMSampleData> data) {
        if (m_stopFlag) return;
        if (m_ffAudioParser) {
            m_ffAudioParser->process(data);
        }
    };
    
    string videoName = string(typeid(*this).name()) + "video";
    string audioName = string(typeid(*this).name()) + "audio";
    const char *videoStr = videoName.c_str();
    const char *audioStr = audioName.c_str();
    m_videoDriveQueue = CREATE_SERIAL_QUEUE2(videoStr);
    m_audioDriveQueue = CREATE_SERIAL_QUEUE2(audioStr);
}

void MMGraph::destroy() {
    m_stopFlag = true;
    m_audioPlayer->stop();
    
    m_ffAudioParser->destroy();
    m_ffAudioDecoder->destroy();
    m_audioPlayer->destroy();
    
    m_ffVideoParser->destroy();
    m_vtDecoder->destroy();
    m_driveUnit->destroy();
    m_previewUnit->destroy();
}

MMGraph::~MMGraph() {
}

void MMGraph::drive() {
    for (int i = 0; i < REFRENECE_COUNT; i++) { //初始状态先发5帧
        if (m_videoDriveCmd) {
            dispatch_async(m_videoDriveQueue, ^{
                shared_ptr<MMSampleData> data = make_shared<MMSampleData>();
                data->dataType = MMSampleDataType_None_Video;
                m_videoDriveCmd(data);
            });
        }
    }
    m_audioPlayer->play();
    cout << "[mm] graph start drive" << endl;
}

#pragma mark - Setup Units
void MMGraph::_buildUnitsConn() {
    _setupParser();
    _setupDecoder();
    _setupDriveUnit();
    _setupPreview();
    _setupAudioPlayer();
    
    /**视频处理链路*/
    m_ffVideoParser->addNextVideoNode(m_vtDecoder);
    m_vtDecoder->addNextVideoNode(m_driveUnit);
    m_driveUnit->addNextVideoNode(m_previewUnit);
    
    /**音频处理链路*/
    m_ffAudioParser->addNextAudioNode(m_ffAudioDecoder);
    m_ffAudioDecoder->addNextAudioNode(m_audioPlayer);
}

void MMGraph::_configSharedCtx() {
    if (!m_unitCtx) {
        m_unitCtx = make_shared<MMUnitContext>();
    }
    m_ffVideoParser->setUnitContext(m_unitCtx);
    m_vtDecoder->setUnitContext(m_unitCtx);
    m_driveUnit->setUnitContext(m_unitCtx);
    m_previewUnit->setUnitContext(m_unitCtx);
    
    m_ffAudioParser->setUnitContext(m_unitCtx);
    m_ffAudioDecoder->setUnitContext(m_unitCtx);
    m_audioPlayer->setUnitContext(m_unitCtx);
    
    _configMsg();
}

void MMGraph::_configMsg() {
    auto videoRenderFinishBlk = [&]() {
        if (m_videoDriveCmd) {
            dispatch_async(m_videoDriveQueue, ^{
                while (m_audioPlayer->getPts() <= m_previewUnit->getPts()) { //音视频同步
                    [NSThread sleepForTimeInterval:0.001];
                }
                shared_ptr<MMSampleData> data = make_shared<MMSampleData>();
                data->dataType = MMSampleDataType_None_Video;
                m_videoDriveCmd(data);
            });
        }
     };
    m_unitCtx->setVideoRenderFinishedBlk(videoRenderFinishBlk);
    
    auto audioNeedBufferBlk = [&]() {
        if (m_audioDriveCmd) {
            dispatch_async(m_audioDriveQueue, ^{
                shared_ptr<MMSampleData> data = make_shared<MMSampleData>();
                data->dataType = MMSampleDataType_None_Audio;
                m_audioDriveCmd(data);
            });
        }
    };
    m_unitCtx->setAudioNeedBufferBlk(audioNeedBufferBlk);
    
    auto audioPlayEndBlk = [&]() {
        dispatch_async(dispatch_get_main_queue(), ^{ //主线程停掉音频
            if (m_audioPlayer) {
                m_audioPlayer->stop();
            }
        });
    };
    m_unitCtx->setAudioPlayEndBlk(audioPlayEndBlk);
}

void MMGraph::_setupParser() {
    MMParseConfig videoConfig;
    videoConfig.parseType = MMFFParseType_Video;
    videoConfig.inPath = m_config.videoPath;
    m_ffVideoParser = make_shared<MMFFParser>(videoConfig);
    
    MMParseConfig audioConfig;
    audioConfig.parseType = MMFFParseType_Audio;
    audioConfig.inPath = m_config.videoPath;
    m_ffAudioParser = make_shared<MMFFParser>(audioConfig);
}

void MMGraph::_setupDecoder() {
    MMDecodeConfig videoConfig;
    videoConfig.decodeType = MMDecodeType_Video;
    videoConfig.fmtCtx = (void *)m_ffVideoParser->getFmtCtx();
    videoConfig.vtDesc = m_ffVideoParser->getVtDesc();
    videoConfig.targetSize = m_ffVideoParser->getSize();
    videoConfig.pixelformat = MMPixelFormatTypeBGRA;
    m_vtDecoder = make_shared<MMVTDecoder>(videoConfig);
    
    MMDecodeConfig audioConfig;
    audioConfig.decodeType = MMDecodeType_Audio;
    audioConfig.fmtCtx = m_ffAudioParser->getFmtCtx();
    m_ffAudioDecoder = make_shared<MMFFDecoder>(audioConfig);
}

void MMGraph::_setupDriveUnit() {
    m_driveUnit = make_shared<MMDriveUnit>();
}

void MMGraph::_setupPreview() {
    MMPreviewConfig config;
    config.renderYUV = false;
    config.presentRect = m_config.presentRect;
    config.viewFrame = m_config.viewRect;
    m_previewUnit = make_shared<MMPreviewUnit>(config);
    
    UIView *view = m_config.view;
    MMVideoGLPreview *renderView = m_previewUnit->getRenderView();
    renderView.backgroundColor = UIColor.blackColor;
    [view insertSubview:renderView atIndex:0];

    [renderView setupGLEnv];
}

void MMGraph::_setupAudioPlayer() {
    MMAudioPlayConfig config;
    config.needPullData = false;
    m_audioPlayer = make_shared<MMAudioPlayer>(config);
}
