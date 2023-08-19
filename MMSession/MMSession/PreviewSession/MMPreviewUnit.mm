// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMPreviewUnit.h"

MMPreviewUnit::MMPreviewUnit(MMPreviewConfig config): m_config(config) {
    MMVideoPreviewConfig *renderConfig = [[MMVideoPreviewConfig alloc] init];
    renderConfig.renderYUV = config.renderYUV;
    renderConfig.rotation = config.rotation;
    renderConfig.presentRect = config.presentRect;
    m_renderView = [[MMVideoGLPreview alloc] initWithConfig:renderConfig];
}

void MMPreviewUnit::process(std::shared_ptr<MMSampleData> &data) {
    if (m_renderView) {
        CVPixelBufferRef pixelBuffer = data->videoBuffer;
        [m_renderView processPixelBuffer:pixelBuffer];
    }
}
