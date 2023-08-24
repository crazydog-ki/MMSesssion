// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMUnitBase.h"
#include "MMPreviewConfig.h"
#include "MMVideoGLPreview.h"

class MMPreviewUnit: public MMUnitBase {
public:
    MMPreviewUnit(MMPreviewConfig config);
    MMVideoGLPreview* getRenderView();
    void process(std::shared_ptr<MMSampleData> &data) override;
private:
    MMVideoGLPreview *m_renderView;
    MMPreviewConfig m_config;
};
