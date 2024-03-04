// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include "MMUnitBase.h"
#include "MMPreviewConfig.h"
#include "MMVideoGLPreview.h"

class MMPreviewUnit: public MMUnitBase {
public:
    MMPreviewUnit(MMPreviewConfig config);
    void process(std::shared_ptr<MMSampleData> &data) override;
    void destroy() override;
    MMVideoGLPreview* getRenderView();
    double getPts();
    ~MMPreviewUnit();
private:
    MMVideoGLPreview *m_renderView;
    MMPreviewConfig m_config;
    double m_pts = 0.0f;
};
